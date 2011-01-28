require 'helper'

module RCS
module Collector

# dirty hack to fake the trace function
# re-open the class and override the method
class DBCache
  def self.trace(a, b)
  end
end

class TestCache < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    DBCache.destroy!
    assert_false File.exist?(Dir.pwd + "/config/cache.db")
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.
  def teardown
    DBCache.destroy!
  end

  def test_private_method
    # create! is a private method, nobody should call it
    assert_raise NoMethodError do
      DBCache.create!
    end
  end

  def test_empty!
    # this should create the cache from scratch
    DBCache.empty!

    # check if the file was created
    assert_true File.exist?(Dir.pwd + "/config/cache.db")
  end

  def test_zero_length
    # not existent should return always zero
    assert_equal 0, DBCache.length

    DBCache.empty!
    # empty (but initialized) cache
    assert_equal 0, DBCache.length
  end

  def test_signature
    # since the cache is not initialized,
    # the call should create it and store the value
    DBCache.signature = "test signature"

    # check if the file was created
    assert_true File.exist?(Dir.pwd + "/config/cache.db")

    # check the correct value
    assert_equal "test signature", DBCache.signature
  end

  def test_empty_init
    # clear the cache
    DBCache.empty!

    assert_nil DBCache.signature
    assert_equal 0, DBCache.length
  end

  def test_class_keys
    entries = {'BUILD001' => 'secret class key', 'BUILD002' => "another secret"}
    entry = {'BUILD003' => 'top secret'}

    # since the cache is not initialized,
    # the call should create it and store the value
    DBCache.add_class_keys entries
    DBCache.add_class_keys entry

    # check if the file was created
    assert_true File.exist?(Dir.pwd + "/config/cache.db")

    # we have added 3 elements
    assert_equal 3, DBCache.length

    # check the correct values
    assert_equal "top secret", DBCache.class_keys['BUILD003']
    assert_equal "another secret", DBCache.class_keys['BUILD002']
    assert_equal "secret class key", DBCache.class_keys['BUILD001']
  end

  def test_config
    # random ids
    bid = SecureRandom.random_number(1024)
    cid = SecureRandom.random_number(1024)
    # random binary bytes for the config
    config = SecureRandom.random_bytes(1024)
    
    # not yet in cache
    assert_false DBCache.new_conf? bid

    # save a config in the cache
    DBCache.save_conf(bid, cid, config)

    # should be in cache
    assert_true DBCache.new_conf? bid
    # the bid - 1 does not exist in cache
    assert_false DBCache.new_conf? bid - 1

    # retrieve the config
    ccid, cconfig = DBCache.new_conf bid

    assert_equal cid, ccid
    assert_equal config, cconfig
    
    # delete the config
    DBCache.del_conf bid
    assert_false DBCache.new_conf? bid
  end

  def test_upload
    # random ids
    bid = SecureRandom.random_number(1024)
    u1 = SecureRandom.random_number(1024)
    u2 = u1 + SecureRandom.random_number(1024) # ensure it is greater
    # random string for the download
    filename1 = SecureRandom.base64(100)
    filename2 = SecureRandom.base64(100)
    # random content for the files
    content1 = SecureRandom.random_bytes(1024)
    content2 = SecureRandom.random_bytes(1024)

    # not yet in cache
    assert_false DBCache.new_uploads? bid

    uploads = {u1 => {:filename => filename1, :content => content1},
               u2 => {:filename => filename2, :content => content2}}

    # save in the cache
    DBCache.save_uploads(bid, uploads)

    # should be in cache
    assert_true DBCache.new_uploads? bid
    # the bid - 1 does not exist in cache
    assert_false DBCache.new_uploads? bid - 1

    # retrieve the first upload
    upload1, left = DBCache.new_upload bid
    # we have two files in the upload table, left should be one
    assert_equal 1, left

    # consistency check
    assert_equal u1, upload1[:id]
    assert_equal filename1, upload1[:upload][:filename]
    assert_equal content1, upload1[:upload][:content]

    # delete the entry
    DBCache.del_upload upload1[:id]

    # retrieve the second upload
    upload2, left = DBCache.new_upload bid
    # we have two files in the upload table, left should be one
    assert_equal 0, left

    # consistency check
    assert_equal u2, upload2[:id]
    assert_equal filename2, upload2[:upload][:filename]
    assert_equal content2, upload2[:upload][:content]

    # delete the entry
    DBCache.del_upload upload2[:id]

    # no more uploads
    assert_false DBCache.new_uploads? bid

    # the table is empty, should return nil
    upload3, left = DBCache.new_upload bid
    assert_nil upload3
  end

  def test_download
    # random ids
    bid = SecureRandom.random_number(1024)
    d1 = SecureRandom.random_number(1024)
    d2 = SecureRandom.random_number(1024)
    # random string for the filename
    filename1 = SecureRandom.base64(100)
    filename2 = SecureRandom.base64(100)

    # not yet in cache
    assert_false DBCache.new_downloads? bid

    downloads = {d1 => filename1, d2 => filename2}

    # save in the cache
    DBCache.save_downloads(bid, downloads)

    # should be in cache
    assert_true DBCache.new_downloads? bid
    # the bid - 1 does not exist in cache
    assert_false DBCache.new_downloads? bid - 1

    # retrieve the entries
    cdown = DBCache.new_downloads bid

    assert_equal downloads[d1], cdown[d1]
    assert_equal downloads[d2], cdown[d2]

    # delete the entry
    DBCache.del_downloads bid
    assert_false DBCache.new_downloads? bid

    # the table is empty, should return {}
    down = DBCache.new_downloads bid
    assert_true down.empty?
  end

  def test_filesystem
    # random ids
    bid = SecureRandom.random_number(1024)
    f1 = SecureRandom.random_number(1024)
    f2 = SecureRandom.random_number(1024)
    # random string for the paths
    path1 = SecureRandom.base64(100)
    path2 = SecureRandom.base64(100)

    # not yet in cache
    assert_false DBCache.new_filesystems? bid

    filesystems = {f1 => {:depth => 1, :path => path1},
                   f2 => {:depth => 2, :path => path2}}

    # save in the cache
    DBCache.save_filesystems(bid, filesystems)

    # should be in cache
    assert_true DBCache.new_filesystems? bid
    # the bid - 1 does not exist in cache
    assert_false DBCache.new_filesystems? bid - 1

    # retrieve the entries
    cfiles = DBCache.new_filesystems bid

    assert_equal filesystems[f1], cfiles[f1]
    assert_equal filesystems[f2], cfiles[f2]

    # delete the entry
    DBCache.del_filesystems bid
    assert_false DBCache.new_filesystems? bid

    # the table is empty, should return {}
    file = DBCache.new_filesystems bid
    assert_true file.empty?
  end

end

end #Collector::
end #RCS::
