# frozen_string_literal: true

class FakeSqsClient
  Response = Struct.new(:messages)

  attr_reader :receive_calls, :delete_calls, :send_calls

  def initialize(receive_batches: [])
    @receive_batches = receive_batches.dup
    @receive_calls = []
    @delete_calls = []
    @send_calls = []
  end

  def receive_message(**kwargs)
    @receive_calls << kwargs
    Response.new(@receive_batches.shift || [])
  end

  def delete_message(**kwargs)
    @delete_calls << kwargs
    true
  end

  def send_message(**kwargs)
    @send_calls << kwargs
    { message_id: "fake-message-id" }
  end
end
