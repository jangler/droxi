require 'minitest/autorun'

require_relative '../lib/droxi/cache'

describe Cache do
  before do
    @cache = Cache.new
  end

  def file(path)
    { 'path' => path, 'is_dir' => false }
  end

  def dir(path)
    { 'path' => path, 'is_dir' => true, 'contents' => [] }
  end

  describe 'when adding file metadata to the cache' do
    it 'must associate the path with the metadata hash' do
      @cache.add(file('/file'))
      @cache['/file'].wont_be_nil
    end

    it 'must associate the path with its parent directory' do
      @cache.add(dir('/dir'))
      @cache.add(file('/dir/file'))
      @cache['/dir']['contents'].size.must_equal 1
    end

    it 'must not duplicate data associated with parent directory' do
      @cache.add(dir('/dir'))
      @cache.add(file('/dir/file'))
      @cache.add(file('/dir/file'))
      @cache['/dir']['contents'].size.must_equal 1
    end

    it 'must add and associate directory contents' do
      folder = dir('/dir')
      contents = 3.times.map { |i| file("/dir/file#{i}") }
      folder['contents'] = contents
      @cache.add(folder)
      @cache.size.must_equal 4
    end
  end

  describe 'when removing a path from the cache' do
    it 'must delete the metadata from the hash' do
      @cache.add(file('/file'))
      @cache.remove('/file')
      @cache.must_be :empty?
    end

    it 'must delete the metadata from the parent directory' do
      @cache.add(dir('/dir'))
      @cache.add(file('/dir/file'))
      @cache.remove('/dir/file')
      @cache['/dir']['contents'].must_be :empty?
    end

    it 'must delete contents recursively' do
      @cache.add(dir('/dir'))
      @cache.add(file('/dir/file'))
      @cache.remove('/dir')
      @cache.must_be :empty?
    end
  end

  describe 'when querying whether the cache has full info on a path' do
    it 'must return true for files' do
      @cache.add(file('/file'))
      @cache.full_info?('/file').must_equal true
    end

    it 'must return false for fictional files' do
      @cache.full_info?('/file').wont_equal true
    end

    it 'must return false for directories without contents' do
      @cache.add('path' => '/dir', 'is_dir' => true)
      @cache.full_info?('/dir').wont_equal true
    end

    it 'must return true for directories with contents' do
      @cache.add(dir('/dir'))
      @cache.full_info?('/dir').must_equal true
    end
  end
end
