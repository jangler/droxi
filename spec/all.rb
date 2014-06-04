# Use SimpleCov coverage-tracking library if available
begin
  require 'simplecov'
  SimpleCov.start do
    add_filter '_spec.rb'
  end
rescue LoadError
  nil
end

# Run all spec tests
Dir.glob('spec/*_spec.rb').each do |spec|
  require_relative File.basename(spec, '.rb')
end
