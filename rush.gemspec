Gem::Specification.new do |s|
  s.name = 'rush'
  s.version = '0.0.1'
  s.date = '2013-10-24'
  s.summary = 'Rush: Shell DSL'
  s.description = 'A DSL for building shell scripts'
  s.authors = ['Z.d. Peacock']
  s.email = 'zdp@thoomtech.com'
  s.files = ['lib/rush.rb']
  s.homepage = 'http://github.com/thoom/rush'
  s.license = 'MIT'
  s.add_runtime_dependency 'docile', '~>1.1'
  s.add_runtime_dependency 'colored', '~>1.2'
  s.add_runtime_dependency 'open4', '~>1.3'
end
