# Run all spec tests
Dir.glob('spec/*_spec.rb').each do |spec|
  require_relative File.basename(spec, '.rb')
end
