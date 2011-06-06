class Channel
  def initialize
    @queue = []
    @type = :none
  end

  def waiting_for_send?
    @type == :reader
  end

  def waiting_for_read?
    @type == :sender
  end

  def enqueue_sender(sender)
    enqueue(sender, :sender)
  end

  def enqueue_reader(reader)
    enqueue(reader, :reader)
  end

  def dequeue_sender
    dequeue :sender
  end

  def dequeue_reader
    dequeue :reader
  end

  private
    def enqueue(item, type)
      if @type == type || @type == :none
        @queue.push(item)
        @type = type
      else
        s = type == :sender ? 'readers' : 'senders'
        raise ArgumentError, "Trying to enqueue #{type} with #{s} in the queue"
      end
    end

    def dequeue(type)
      if @type == type
        if @queue.count <= 1
          @type = :none
        end
        @queue.shift
      else
        s = @type == :none ? 'nothing' : type == :sender ? 'senders' : 'readers'
        raise ArgumentError, "Trying to dequeue #{type} with #{s} in the queue"
      end
    end
end

class Communication
  attr :channel, :name
end

class PIPL
  class Step
    attr :sender, :reader
    def initialize(sender, reader)
      @sender = sender
      @reader = reader
    end
  end

  def initialize
    @steps = []
    @step_number = 0

    @channels = []
    @next_channel_id = 0
  end

  # running
  def run
    @running = true
    while @running
      step
    end
  end

  def running?
    @running
  end

  def step
    @step_number += 1
    step = dequeue_step
    if step.nil?
      @running = false
    else
      complete_step(step)
    end
  end

  private
    def complete_step(step)
      puts '%04i: %s -> %s' % [@step_number, step.sender.inspect, step.reader.inspect]
    end

  # programming
  public
  
  def make_channel_reference
    id = @next_channel_id
    @next_channel_id += 1
    @channels[id] = Channel.new
    id
  end

  def send(channel_ref, sender)
puts "sending [#{channel_ref}]: #{sender}"
    channel = dereference_channel(channel_ref)
    if channel.waiting_for_send?
      reader = channel.dequeue_reader
      enqueue_step(sender, reader)
    else
      channel.enqueue_sender(sender)
    end
  end

  def read(channel_ref, reader)
puts "reading [#{channel_ref}]: #{reader}"
    channel = dereference_channel(channel_ref)
    if channel.waiting_for_read?
      sender = channel.dequeue_sender
      enqueue_step(sender, reader)
    else
      channel.enqueue_reader(reader)
    end
  end

  private
    def enqueue_step(sender, reader)
      @steps.push( PIPL::Step.new(sender, reader) )
    end

    def dequeue_step
      @steps.shift
    end

    def dereference_channel(channel_ref)
      if @channels[channel_ref]
        @channels[channel_ref]
      else
        raise ArgumentError, "Could not fine channel referenced by #{channel_ref}"
      end
    end

end

#describe "PIPL" do
#  it "should do stuff" do
    @pipl = PIPL.new
    @channel_ref = @pipl.make_channel_reference
    @pipl.send(@channel_ref, "1")
    @pipl.run
    @pipl.send(@channel_ref, "2")
    @pipl.run
    @pipl.read(@channel_ref, "a")
    @pipl.run

    @channel_ref2 = @pipl.make_channel_reference
    @pipl.send(@channel_ref2, "21")
    @pipl.run
    @pipl.send(@channel_ref2, "22")
    @pipl.run
    @pipl.read(@channel_ref2, "2a")
    @pipl.run
    @pipl.read(@channel_ref2, "2b")
    @pipl.run
    @pipl.read(@channel_ref2, "2c")
    @pipl.run
    @pipl.send(@channel_ref2, "23")
    @pipl.run

    @pipl.read(@channel_ref, "b")
    @pipl.run
    @pipl.read(@channel_ref, "c")
    @pipl.run
    @pipl.send(@channel_ref, "3")
    @pipl.run
#  end
#end






