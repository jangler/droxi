`ls spec/*_spec.rb`.each_line do |spec|
  require_relative File.basename(spec.chomp, '.rb')
end
