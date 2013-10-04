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

    def add_read(channel, name=nil)
      @channel = channel
      name ||= PIPL::Channel.new
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

  def create_channel
    return PIPL::Channel.new
  end

  def create_sequence
    return PIPL::Sequence.new
  end

  def run(*processes)
    processes.each { |p| p.proceed }
  end
end
