require 'docile'
require 'colored'
require 'open4'

# Building environment variables
@env         = {__global__: {}, default: {}}
@flags       = {}
@current_env = :default

def flags(args)
  param = nil
  args.each do |arg|
    if arg[0..1] == '--'
      param = arg[2..-1].to_sym
      @flags[param] = true unless @flags.has_key? param
    else
      case param
      when :debug
        @flags[param] = true
      when :env
        @flags[param] = arg.to_sym
        @current_env  = arg.to_sym
      else
        @flags[param] = arg
      end
    end
  end
end

class ThrushItemBuilder
  def initialize
    @params = {}
  end

  def method_missing(m, *args)
    @params[m.to_sym] = args[0]
  end

  def build
    @params
  end
end

def config(env, &block)
  ev = Docile.dsl_eval(ThrushItemBuilder.new, &block).build
  @current_env = env.to_sym if @current_env == :default && ev.has_key?(:default) && ev[:default] == true
  @env[env] = ev
end

def global(&block)
  config(:__global__, &block)
end

def env(key)
  return @env[@current_env][key] if @env[@current_env].has_key? key
  return @env[:__global__][key] if @env[:__global__].has_key? key
  nil
end

def cmd_vals(key, cmdval)
  return cmdval[key] if cmdval.has_key? key
  env(key)
end

def env?(env)
  @current_env == env
end

def flag?(key)
  k = key.to_sym
  @flags.has_key?(k) && @flags[k]
end

def debug?
  flag? :debug
end

def flag(key)
  k = key.to_sym
  if flag? k
    @flags[k]
  end
end

# Defining commands
@commands = []

#TODO: Fix the local, ssh functions so that they will work even if they don't have a block passed in
def local(command, &block)
  lc = ThrushItemBuilder.new
  lc.command command
  lc.type :local
  @commands << Docile.dsl_eval(lc, &block).build
end

def rsync(&block)
  rc = ThrushItemBuilder.new
  rc.type :rsync
  @commands << Docile.dsl_eval(rc, &block).build
end

def ssh(command, &block)
  sc = ThrushItemBuilder.new
  sc.command command
  sc.type :ssh
  @commands << Docile.dsl_eval(sc, &block).build
end

def header(h)
  len = h.gsub(/\e\[(\d+)m/, '').length
  l   = '-' * len
  "\n#{ h }\n#{ l }\n"
end

def run!
  client = env(:client).nil? ? 'Thrush' : env(:client)
  if @flags.has_key?(:help)
    puts header("#{ client } client help for (ENV = #{ @current_env.upcase })").blue.bold
    puts "#{ env(:help) }\n"
    exit
  end

  puts header("#{ client } client for (ENV = #{ @current_env.upcase })").blue.bold
  puts "** DEBUG MODE **".yellow if debug?
  i = 1

  @commands.each do |cmd_values|
    if cmd_values.has_key?(:exc)
      found = false
      cmd_values[:exc].each { |flag| found = true if flag? flag }
      next if found
    end

    if cmd_values.has_key?(:inc)
      found = false
      cmd_values[:inc].each { |flag| found = true if flag? flag }
      next unless found
    end

    sudo          = cmd_vals(:sudo, cmd_values)
    debug_command = ''

    case cmd_values[:type]
    when :local
      cmd = sudo ? %w(sudo) : []
      cmd << cmd_vals(:command, cmd_values)

      command = cmd.join(' ')

      if debug?
        debug_command = command
        command       = ''
      end
    when :rsync
      debug = debug? ? 'n' : ''
      rsh   = cmd_vals(:rsh, cmd_values)

      # TODO: The default rsync values I've hardcoded including --no-o, --no-g and other defaults should be flags that someone can pass in.
      cmd   = []
      cmd << 'sudo' if rsh.nil? && sudo
      cmd << "rsync -#{ debug }vazcO --no-o --no-g"
      cmd << "--rsh=#{ rsh }" unless rsh.nil?

      ignore = cmd_vals(:ignore, cmd_values)
      ignore.each { |exclude| cmd << "--exclude '#{ exclude }'" } unless ignore.nil? || ignore.empty?
      
      delete = cmd_vals(:delete, cmd_values)
      cmd << "--delete" unless delete.nil? || delete == false

      if rsh == 'ssh'
        cmd << "--rsync-path='sudo rsync'" if sudo

        path = cmd_vals(:path, cmd_values)
        cmd << "--rsync-path='#{ path }'" unless path.nil? || path.empty?
      end

      cmd << cmd_vals(:src, cmd_values)

      if rsh == 'ssh'
        cmd << "#{ cmd_vals(:hostname, cmd_values) }:#{ cmd_vals(:dest, cmd_values) }"
      else
        cmd << cmd_vals(:dest, cmd_values)
      end

      command = cmd.join(' ')
      debug_command = command if debug?
    when :ssh
      cmd = ["ssh #{ cmd_vals(:hostname, cmd_values) }"]
      cmd << 'sudo' if sudo
      cmd << "#{ cmd_vals(:command, cmd_values) }"

      command = cmd.join(' ')
      if debug?
        debug_command = command
        command       = ''
      end
    else
      command       = ''
      debug_command = ''
    end

    puts "\n#{ i }. #{ cmd_values[:step] }".green if cmd_values[:step]
    i += 1

    unless debug_command.empty?
      puts "Command to run: #{ debug_command }"
    end

    unless command.empty?
      #This code is simpler than requiring open4, but the output is delayed
      #puts `#{ command }`
      #unless $?.to_i == 0
      #  puts "Command failed: #{ command }"
      #  break
      #end

      #status = Open4::popen4('sh') do |pid, stdin, stdout, stderr|
      #  stdin.puts command
      #  stdin.close
      #
      #  while (line = stdout.gets)
      #    puts line
      #  end
      #
      #  while (line = stderr.gets)
      #    puts line.red
      #  end
      #end
      #
      #unless status == 0
      #  puts "Command failed: #{ command }".red
      #  break
      #end

      pid, stdin, stdout, stderr = Open4::popen4('sh')
      stdin.puts command
      stdin.close

      output = false
      while (line = stdout.gets)
        output = true
        puts line
      end

      ignored, status = Process.waitpid2 pid
      if status.to_i == 0
        puts 'OK' unless output
      else
        puts "Command failed (#{ status.exitstatus }): #{ command }".red
        while (line = stderr.gets)
          puts line.red
        end
        break
      end
    end
  end
end
