class PIPL
  def initialize()
    @engine = Engine.new
    @main = ParallelProcess.new(@engine)
  end

  def new_name
    Object.new
  end

  # Public: Create a new sequence of processes starting with a read.
  def read(channel_id, name_id)
    @main.read(channel_id, name_id)
  end

  # Public: Create a new sequence of processes starting with a send.
  def send(channel_id, name_id)
    @main.send(channel_id, name_id)
  end

  # Public: Same as read, but process replicates.
  def read!(channel_id, name_id)
    @main.read!(channel_id, name_id)
  end

  # Public: Same as send, but process replicates.
  def send!(channel_id, name_id)
    @main.send!(channel_id, name_id)
  end

  class Refs < Hash
    def default(key)
      key
    end
    def dup
      Refs.new.merge self
    end
  end

  # Public: Run to completion.
  def run
    @main.proceed(Refs.new)
    @main = ParallelProcess.new(@engine)
    @engine.run
  end

  class Engine
    def initialize
      @queue = []
      @readers = {}
      @senders = {}
    end

    # Public: Handle new read request on channel from process.
    def enqueue_reader(channel, process)
      enqueue @readers, channel, process
    end

    # Public: Handle new send request on channel from process.
    def enqueue_sender(channel, process)
      enqueue @senders, channel, process
    end

    # Public: Handle removing alternate process after choice processes proceeds.
    def dequeue_reader(channel, process)
      dequeue @readers, channel, process
    end

    # Public: Handle removing alternate process after choice processes proceeds.
    def dequeue_sender(channel, process)
      dequeue @senders, channel, process
    end

    # Internal: enqueue helper
    def enqueue(queue, channel, process)
      ( queue[channel] ||= [] ) << process
      enqueue_step channel
    end

    # Internal: dequeue helper
    def dequeue(queue, channel, process)
      queue[channel].delete(process)
    end

    # Internal: Enqueue step if necessary.
    def enqueue_step(channel)
      if waiting?(@readers, channel) && waiting?(@senders, channel)
        @queue << channel
      end
    end

    # Internal: Check if channel has any processes waiting in queue.
    def waiting?(queue, channel)
      queue[channel] && queue[channel].length > 0
    end

    # Public: Run to completion.
    def run
      while @queue.length > 0
        step select(@queue)
      end
    end

    # Internal: Complete send/read on channel.
    def step(channel)
      step select(@queue) if !channel

      reader = select(@readers[channel])
      sender = select(@senders[channel])
      reader.read sender.send if reader && sender
    end

    # Internal: Remove process from queue for completing step.
    def select(queue)
      queue.delete_at rand(queue.length)
    end
  end

  # Internal: Abstract parent class for Read and Send processes.
  class SimpleProcess
    # Public: Append read process.
    def read(channel_id, name_id)
      @next = ReadProcess.new(@pipl, channel_id, name_id, false)
    end

    # Public: Same as read, but process replicates.
    def read!(channel_id, name_id)
      @next = ReadProcess.new(@pipl, channel_id, name_id, true)
    end

    # Public: Append send process.
    def send(channel_id, name_id)
      @next = SendProcess.new(@pipl, channel_id, name_id, false)
    end

    # Public: Same as send, but process replicates.
    def send!(channel_id, name_id)
      @next = SendProcess.new(@pipl, channel_id, name_id, true)
    end

    # Public: Append parallel process.
    def parallel
      @next = ParallelProcess.new(@pipl)
    end

    # Public: Append choice process.
    def choice
      @next = ChoiceProcess.new(@pipl)
    end
  end

  # Internal: Abstract parent class for Parallel and Choice processes.
  class ComplexProcess
    def initialize(pipl)
      @pipl = pipl
      @processes = []
    end

    # Public: Create a new sequence of processes starting with a read.
    def read(channel_id, name_id)
      @processes << make_read(channel_id, name_id, false)
      @processes.last
    end

    # Public: Same as read, but process replicates.
    def read!(channel_id, name_id)
      @processes << make_read(channel_id, name_id, true)
      @processes.last
    end

    # Public: Create a new sequence of processes starting with a send.
    def send(channel_id, name_id)
      @processes << make_send(channel_id, name_id, false)
      @processes.last
    end

    # Public: Same as send, but process replicates.
    def send!(channel_id, name_id)
      @processes << make_send(channel_id, name_id, true)
      @processes.last
    end
  end

  class ParallelProcess < ComplexProcess
    def make_read(channel_id, name_id, replicate)
      ReadProcess.new(@pipl, channel_id, name_id, replicate)
    end

    def make_send(channel_id, name_id, replicate)
      SendProcess.new(@pipl, channel_id, name_id, replicate)
    end

    def proceed(refs)
      if @processes.length > 0
        @processes.shift.proceed(refs)
        @processes.each { |p| p.proceed(refs.dup) }
      end
    end
  end

  class ChoiceProcess < ComplexProcess
    def make_read(channel_id, name_id, replicate)
      ChoiceReadProcess.new(@pipl, self, channel_id, name_id, replicate)
    end

    def make_send(channel_id, name_id, replicate)
      ChoiceSendProcess.new(@pipl, self, channel_id, name_id, replicate)
    end

    def proceed(refs)
      @processes.each { |p| p.proceed(refs) }
    end

    def notify
      @processes.each { |p| p.kill }
    end
  end

  class ReadProcess < SimpleProcess
    def initialize(pipl, channel_id, name_id, replicate)
      @pipl = pipl
      @channel_id = channel_id
      @name_id = name_id
      @replicate = replicate
    end

    def proceed(refs)
      @refs = refs
      @pipl.enqueue_reader @refs[@channel_id], self
    end

    def read(value)
      puts "read: #{@name_id} = #{value}"
      if @next
        refs = @replicate ? @refs.dup : @refs
        refs[@name_id] = value
        @next.proceed(refs)
      end
      proceed(@refs) if @replicate
    end
  end

  class SendProcess < SimpleProcess
    def initialize(pipl, channel_id, name_id, replicate)
      @pipl = pipl
      @channel_id = channel_id
      @name_id = name_id
      @replicate = replicate
    end

    def proceed(refs)
      @refs = refs
      @pipl.enqueue_sender @refs[@channel_id], self
    end

    def send()
      if @next
        refs = @replicate ? @refs.dup : @refs
        @next.proceed(refs)
      end
      proceed(@refs) if @replicate
      @refs[@name_id]
    end
  end

  class ChoiceReadProcess < ReadProcess
    # Override
    def initialize(pipl, parent, channel, replicate)
      super(pipl, channel, replicate)
      @parent = parent
    end

    def kill
      @pipl.dequeue_reader @channel, self
    end

    # Override
    def read(value)
      @parent.notify
      super(value)
    end
  end

  class ChoiceSendProcess < SendProcess
    # Override
    def initialize(pipl, parent, channel, name, replicate)
      super(pipl, channel, name, replicate)
      @parent = parent
    end

    def kill
      @pipl.dequeue_sender @channel, self
    end

    # Override
    def send
      @parent.notify
      super(value)
    end
  end
end

