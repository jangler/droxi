require 'minitest/autorun'

require_relative '../commands'

describe Commands do
  describe 'when executing a shell command' do
    it 'must print the output' do
      lines = []
      Commands.shell('echo testing') { |line| lines << line }
      lines.must_equal(['testing'])
    end
  end
end
