task :default => :build

desc 'run unit tests'
task :test do
  sh 'ruby spec/all.rb'
end

desc 'run program'
task :run do
  require_relative 'lib/droxi'
  Droxi.run
end

desc 'install gem'
task :gem do
  sh 'rm *.gem'
  sh 'gem build droxi.gemspec'
  sh 'gem install ./droxi-*.gem'
end

desc 'create rdoc documentation'
task :doc do
  sh 'rdoc `find lib -name *.rb`'
end

desc 'build executable and man page'
task :build do
  def build_exe
    filenames = `find lib -name *.rb`.split + ['bin/droxi']

    contents = "#!/usr/bin/env ruby\n\n"
    contents << `cat -s #{filenames.join(' ')} \
                 | grep -v require_relative \
                 | grep -v "require 'droxi'"`

    IO.write('build/droxi', contents)
    File.chmod(0755, 'build/droxi')
  end

  def date(gemspec)
    require 'time'
    Time.parse(/\d{4}-\d{2}-\d{2}/.match(gemspec)[0]).strftime('%B %Y')
  end

  def commands
    require_relative 'lib/droxi/commands'
    Commands::NAMES.sort.map do |name|
      cmd = Commands.const_get(name.upcase.to_sym)
      ".TP\n#{cmd.usage}\n#{cmd.description}\n"
    end.join.strip
  end

  def build_page
    gemspec = IO.read('droxi.gemspec')

    contents = IO.read('droxi.1.template').
      sub('{date}', date(gemspec)).
      sub('{version}', /\d+\.\d+\.\d+/.match(gemspec)[0]).
      sub('{commands}', commands)

    IO.write('build/droxi.1', contents)
  end

  Dir.mkdir('build') unless Dir.exists?('build')
  build_exe
  build_page
end

PREFIX = ENV['PREFIX'] || ENV['prefix'] || '/usr/local'
BIN_PATH = "#{PREFIX}/bin"
MAN_PATH = "#{PREFIX}/share/man/man1"

desc 'install executable and man page'
task :install do
  require 'fileutils'
  begin
    FileUtils.mkdir_p(BIN_PATH)
    FileUtils.cp('build/droxi', BIN_PATH)
    FileUtils.mkdir_p(MAN_PATH)
    FileUtils.cp('build/droxi.1', MAN_PATH)
  rescue Exception => error
    puts error
  end
end

desc 'uninstall executable and man page'
task :uninstall do
  require 'fileutils'
  begin
    FileUtils.rm("#{BIN_PATH}/droxi")
    FileUtils.rm("#{MAN_PATH}/droxi.1")
  rescue Exception => error
    puts error
  end
end
