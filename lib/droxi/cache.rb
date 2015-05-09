# Special +Hash+ of remote file paths to cached file metadata.
class Cache < Hash
  # Add a metadata +Hash+ and its contents to the +Cache+ and return the
  # +Cache+.
  def add(metadata)
    path = metadata['path'].downcase
    store(path, metadata)
    dirname = File.dirname(path)
    if dirname != path
      contents = fetch(dirname, {}).fetch('contents', nil)
      contents << metadata if contents && !contents.include?(metadata)
    end
    return self unless metadata.include?('contents')
    metadata['contents'].each { |content| add(content) }
    self
  end

  # Remove a path's metadata from the +Cache+ and return the +Cache+.
  def remove(path)
    path = path.downcase
    recursive_remove(path)
    contents = fetch(File.dirname(path), {}).fetch('contents', nil)
    contents.delete_if { |item| item['path'].downcase == path } if contents
    self
  end

  # Return +true+ if the path's information is cached, +false+ otherwise.
  def full_info?(path, require_contents = true)
    path = path.downcase
    info = fetch(path, nil)
    info && (!require_contents || !info['is_dir'] || info.include?('contents'))
  end

  private

  # Recursively remove a path and its sub-files and directories.
  def recursive_remove(path)
    path = path.downcase
    contents = fetch(path, {}).fetch('contents', nil)
    contents.each { |item| recursive_remove(item['path']) } if contents
    delete(path)
  end
end
