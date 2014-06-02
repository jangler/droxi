Gem::Specification.new do |s|
  s.name        = 'droxi'
  s.version     = '0.0.0'
  s.date        = '2014-06-01'
  s.summary     = 'droxi'
  s.description = 'ftp-like command-line interface to Dropbox'
  s.authors     = ['Brandon Mulcahy']
  s.email       = 'brandon@jangler.info'
  s.files       = ['lib/droxi.rb', 
                   'lib/droxi/commands.rb',
                   'lib/droxi/settings.rb',
                   'lib/droxi/state.rb']
  s.homepage    = 'https://github.com/jangler/droxi'
  s.license     = 'MIT'

  s.executables << 'droxi'
  s.add_development_dependency('dropbox_sdk')
end
