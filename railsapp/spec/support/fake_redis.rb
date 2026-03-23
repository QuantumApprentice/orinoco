# frozen_string_literal: true

class FakeRedis
  def initialize
    @strings = {}
    @hashes = Hash.new { |hash, key| hash[key] = {} }
  end

  def pipelined
    yield self
  end

  def set(key, value)
    @strings[key] = value
    "OK"
  end

  def get(key)
    @strings[key]
  end

  def del(*keys)
    deleted = 0

    keys.each do |key|
      deleted += 1 if @strings.delete(key)
      deleted += 1 if @hashes.delete(key)
    end

    deleted
  end

  def hset(key, field, value)
    @hashes[key][field] = value
    true
  end

  def hgetall(key)
    @hashes[key].dup
  end
end
