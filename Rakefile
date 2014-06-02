task :default => :test

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

desc 'generate man page'
task :man do
  gemspec = IO.read('droxi.gemspec')

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

  contents = IO.read('droxi.1.template').
    sub('{date}', date(gemspec)).
    sub('{version}', /\d+\.\d+\.\d+/.match(gemspec)[0]).
    sub('{commands}', commands)

  Dir.mkdir('build') unless Dir.exists?('build')
  IO.write('build/droxi.1', contents)
end
