class PIPL
  class Channel
    def send(sender)
      @sender = sender
    end

    def read(reader)
      @reader = reader
    end

    def sync
      @reader.input @sender.output
    end
  end

  class Sequence
    def add_send(channel, name)
      @channel = channel
      @name = name
      channel.send self
    end

    def add_read(channel)
      @channel = channel
      name = PIPL::Channel.new
      channel.read self
      name
    end

    def proceed
       @channel.sync if @name
    end

    def output
      @name
    end

    def input(name)
    end
  end

  class Parallel
    def initialize
      @processes = []
    end

    def add_process(process)
      @processes << process
    end

    def proceed
      @processes.each { |p| p.proceed }
    end
  end

  def create_channel
    return PIPL::Channel.new
  end

  def create_sequence
    return PIPL::Sequence.new
  end

  def create_parallel_process
    return PIPL::Parallel.new
  end

  def run(process)
    process.proceed
  end
end
