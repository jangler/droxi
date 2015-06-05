Gem::Specification.new do |s|
  s.name        = 'droxi'
  s.version     = IO.read('lib/droxi.rb')[/VERSION = '(.+)'/, 1]
  s.date        = '2015-06-04'
  s.summary     = 'An ftp-like command-line interface to Dropbox'
  s.description = "A command-line Dropbox interface based on GNU coreutils, \
                   GNU ftp, and lftp. Features include smart tab completion, \
                   globbing, and interactive help.".squeeze(' ')
  s.authors     = ['Brandon Mulcahy']
  s.email       = 'brandon@jangler.info'
  s.files       = `git ls-files`.split
  s.homepage    = 'http://jangler.info/code/droxi'
  s.license     = 'MIT'

  s.executables << 'droxi'
  s.add_runtime_dependency 'dropbox-sdk', '~> 1.6', '>= 1.6.4'
  s.required_ruby_version = '>= 2.0.0'
end
