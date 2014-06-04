require 'fileutils'
require 'minitest/autorun'

def suppress_warnings
  prev_verbose, $VERBOSE = $VERBOSE, nil
  yield
  $VERBOSE = prev_verbose
end

suppress_warnings { require_relative '../lib/droxi/settings' }

describe Settings do
  KEY, VALUE = :test_key, :test_value
  RC_PATH = File.expand_path('~/.config/droxi/testrc')
  Settings.config_file_path = RC_PATH

  describe 'when attempting access with a bogus key' do
    it 'must return nil' do
      Settings.delete(KEY)
      Settings[KEY].must_equal nil
    end
  end

  describe 'when attempting access with a valid key' do
    it 'must return the associated value' do
      Settings[KEY] = VALUE
      Settings[KEY].must_equal VALUE
    end
  end

  describe 'when assigning a value to a key' do
    it 'must assign the value to the key and return the value' do
      Settings.delete(KEY)
      (Settings[KEY] = VALUE).must_equal VALUE
      Settings[KEY].must_equal VALUE
    end
  end

  describe 'when deleting a bogus key' do
    it 'must return nil' do
      Settings.delete(KEY)
      Settings.delete(KEY).must_equal nil
    end
  end

  describe 'when deleting a valid key' do
    it 'must delete the key and return the associated value' do
      Settings[KEY] = VALUE
      Settings.delete(KEY).must_equal VALUE
      Settings[KEY].must_equal nil
    end
  end

  describe 'when checking inclusion of a key' do
    it 'must return true for valid keys' do
      Settings[KEY] = VALUE
      Settings.include?(KEY).must_equal true
    end

    it 'must return false for bogus keys' do
      Settings.delete(KEY)
      Settings.include?(KEY).must_equal false
    end
  end

  describe 'when reading settings from disk' do
    it 'must return an empty hash when rc file is missing' do
      FileUtils.rm(RC_PATH) if File.exist?(RC_PATH)
      Settings.read.must_equal({})
    end

    it 'must parse options correctly for valid rc file' do
      IO.write(RC_PATH, "access_token=x\noldpwd=y\nbogus=z\nnonsense\n")
      suppress_warnings do
        Settings.read.must_equal(access_token: 'x', oldpwd: 'y')
      end
    end

    it 'must restore identical settings from previous save' do
      hash = { access_token: 'x', oldpwd: 'y' }
      hash.each { |key, value| Settings[key] = value }
      Settings.save.must_be_nil
      hash.each_key { |key| Settings.delete(key) }
      Settings.read.must_equal hash
    end
  end
end
