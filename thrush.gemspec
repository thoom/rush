Gem::Specification.new do |s|
  s.name         = 'thrush'
  s.version      = '0.0.1'
  s.date         = '2013-10-25'
  s.summary      = 'Thrush: Shell DSL'
  s.description  = 'A DSL for building shell scripts'
  s.authors      = ['Z.d. Peacock']
  s.email        = 'zdp@thoomtech.com'
  s.has_rdoc	 = false
  s.require_path = "lib"
  s.files        = %w( README.md LICENSE )
  s.files        += Dir.glob("lib/**/*")
  s.files        += Dir.glob("test/**/*")
  s.homepage     = 'http://github.com/thoom/thrush'
  s.license      = 'MIT'
  
  s.add_runtime_dependency 'docile', '~>1.1'
  s.add_runtime_dependency 'colored', '~>1.2'
  s.add_runtime_dependency 'open4', '~>1.3'
end