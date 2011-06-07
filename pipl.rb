class Channel
  def initialize(pipl)
    @pipl = pipl
    @queue = []
    @type = :none
  end

  def send(sender)
puts "[#{self}] send: #{sender}"
    if waiting_for_send?
      reader = dequeue :reader
      @pipl.enqueue_step(sender, reader)
    else
      enqueue(sender, :sender)
    end
  end

  def read(reader)
puts "[#{self}] read: #{reader}"
    if waiting_for_read?
      sender = dequeue :sender
      @pipl.enqueue_step(sender, reader)
    else
      enqueue(reader, :reader)
    end
  end

  private
    def waiting_for_send?
      @type == :reader
    end

    def waiting_for_read?
      @type == :sender
    end

    def enqueue(item, type)
      @queue.push(item)
      @type = type
    end

    def dequeue(type)
      if @queue.count <= 1
        @type = :none
      end
      @queue.shift
    end
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
    @queue = []
    @step_number = 0
  end

  # running
  def run
    while running?
      step
    end
  end

  def running?
    @queue.count > 0
  end

  def step
    @step_number += 1
    step = dequeue_step
    complete_step(step)
  end

  # programming
  def enqueue_step(sender, reader)
    @queue.push( PIPL::Step.new(sender, reader) )
  end

  private
    def dequeue_step
      @queue.shift
    end

    def complete_step(step)
      puts '%04i: %s -> %s' % [@step_number, step.sender.inspect, step.reader.inspect]
    end
end

#describe "PIPL" do
#  it "should do stuff" do
    @pipl = PIPL.new
    @channel = Channel.new(@pipl)
    @channel.send("1")
    @pipl.run
    @channel.send("2")
    @pipl.run
    @channel.read("a")
    @pipl.run

    @channel2 = Channel.new(@pipl)
    @channel2.send("21")
    @pipl.run
    @channel2.send("22")
    @pipl.run
    @channel2.read("2a")
    @pipl.run
    @channel2.read("2b")
    @pipl.run
    @channel2.read("2c")
    @pipl.run
    @channel2.send("23")
    @pipl.run

    @channel.read("b")
    @pipl.run
    @channel.read("c")
    @pipl.run
    @channel.send("3")
    @pipl.run
#  end
#end


### simplest pipl program
# w(x).0 | w[z].0
#
# - z - Name
# - w - Channel
# - w(x).0 - Process - sends name on channel
# - w[z].0 - Process - reads name on channel

class ProcessSend
  def initialize(w)
    @w = w
  end

  def proceed
    @w.send(:z)
  end
end

class ProcessRead
  def initialize(w)
    @w = w
  end

  def proceed
    @w.read(:x)
  end
end

@w = Channel.new(@pipl)
@p1 = ProcessSend.new(@w)
@p2 = ProcessRead.new(@w)
@p1.proceed
@pipl.run()
@p2.proceed
@pipl.run()

