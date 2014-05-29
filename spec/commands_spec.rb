require 'minitest/autorun'

require_relative '../commands'

describe Commands do
  describe 'when executing a shell command' do
    it 'must print the output' do
      Commands.shell('echo testing')
    end
  end
end
