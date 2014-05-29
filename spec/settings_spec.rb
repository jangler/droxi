#!/usr/bin/env ruby

require 'minitest/autorun'

require_relative '../settings'

describe Settings do
  describe 'when attempting access with a bogus key' do
    it 'must return nil' do
      key = :bogus_key
      Settings.delete(key)
      Settings[key].must_equal nil
    end
  end

  describe 'when attempting access with a valid key' do
    it 'must return the associated value' do
      key, value = :valid_key, 3.14
      Settings[key] = value
      Settings[key].must_equal value
      Settings.delete(key)
    end
  end

  describe 'when assigning a value to a key' do
    key, value = :valid_key, 3.14

    it 'must return the value' do
      Settings.delete(key)
      (Settings[key] = value).must_equal value
    end

    it 'must assign the value to the key' do
      Settings.delete(key)
      Settings[key] = value
      Settings[key].must_equal value
      Settings.delete(key)
    end
  end

  describe 'when deleting a bogus key' do
    it 'must return nil' do
      key = :bogus_key
      Settings.delete(key)
      Settings.delete(key).must_equal nil
    end
  end

  describe 'when deleting a valid key' do
    key, value = :valid_key, 3.14

    it 'must return the associated value' do
      Settings[key] = value
      Settings.delete(key).must_equal value
    end

    it 'must delete the key' do
      Settings[key] = value
      Settings.delete(key)
      Settings[key].must_equal nil
    end
  end

  describe 'when checking inclusion of a key' do
    key, value = :valid_key, 3.14

    it 'must return true for valid keys' do
      Settings[key] = value
      Settings.include?(key).must_equal true
      Settings.delete(key)
    end

    it 'must return false for bogus keys' do
      Settings.delete(key)
      Settings.include?(key).must_equal false
    end
  end
end
