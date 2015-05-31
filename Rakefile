task default: :build

desc 'run unit tests'
task :test do
  sh 'ruby spec/all.rb'
end

desc 'run unit tests in verbose mode'
task :verbose_test do
  sh 'ruby -w spec/all.rb'
end

desc 'check code with rubocop'
task :cop do
  sh 'rubocop bin lib spec'
end

desc 'run program'
task :run do
  sh 'ruby bin/droxi'
end

desc 'run program in debug mode'
task :debug do
  sh 'ruby bin/droxi --debug'
end

desc 'install gem'
task :gem do
  sh 'rm -f droxi-*.gem'
  sh 'gem build droxi.gemspec'
  sh 'gem install ./droxi-*.gem'
end

desc 'create rdoc documentation'
task :doc do
  sh 'rdoc `find lib -name *.rb`'
end

desc 'build executable'
task :build do
  def build_exe
    filenames = `find lib -name *.rb`.split + ['bin/droxi']

    contents = "#!/usr/bin/env ruby\n\n"
    contents << `cat -s #{filenames.join(' ')} \
                 | grep -v require_relative`

    IO.write('build/droxi', contents)
    File.chmod(0755, 'build/droxi')
  end

  Dir.mkdir('build') unless Dir.exist?('build')
  build_exe
end

PREFIX = ENV['PREFIX'] || ENV['prefix'] || '/usr/local'
BIN_PATH = "#{PREFIX}/bin"

desc 'install executable'
task :install do
  require 'fileutils'
  begin
    FileUtils.mkdir_p(BIN_PATH)
    FileUtils.cp('build/droxi', BIN_PATH)
  rescue => error
    puts error
  end
end

desc 'uninstall executable'
task :uninstall do
  require 'fileutils'
  begin
    FileUtils.rm("#{BIN_PATH}/droxi")
  rescue => error
    puts error
  end
end

desc 'remove files generated by other targets'
task :clean do
  sh 'rm -rf build coverage doc droxi-*.gem'
end
