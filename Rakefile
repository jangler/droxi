task :default => :test

task :test do
  sh 'ruby spec/all.rb'
end

task :run do
  sh './droxi'
end

task :man do
  def commands
    require_relative 'commands'
    Commands::NAMES.sort.map do |name|
      cmd = Commands.const_get(name.upcase.to_sym)
      ".TP\n#{cmd.usage}\n#{cmd.description}\n"
    end.join.strip
  end

  contents = IO.read('droxi.1.template').
    sub('{date}', Time.now.strftime('%B %Y')).
    sub('{commands}', commands)

  Dir.mkdir('build') unless Dir.exists?('build')
  IO.write('build/droxi.1', contents)
end
