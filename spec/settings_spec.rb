require 'minitest/autorun'

require_relative '../settings'

describe Settings do
  KEY, VALUE = :test_key, :test_value

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
end
