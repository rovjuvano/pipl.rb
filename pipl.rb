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
      print '%04i: ' % [@step_number]
      step.reader.input step.sender.output
    end
end

#describe "PIPL" do
#  it "should do stuff" do
class SendCharProcess
  def initialize(w, c)
    @w = w
    @c = c
  end

  def output
    @c
  end
end

class ReadCharProcess
  def initialize(w)
    @w = w
  end

  def input(c)
    puts "#{@w}: #{c}"
  end
end


    @pipl = PIPL.new
    @channel = Channel.new(@pipl)
    @channel.send( SendCharProcess.new(@channel, "1") )
    @pipl.run
    @channel.send( SendCharProcess.new(@channel, "2") )
    @pipl.run
    @channel.read( ReadCharProcess.new(@channel) )
    @pipl.run

    @channel2 = Channel.new(@pipl)
    @channel2.read ReadCharProcess.new(@channel2)
    @pipl.run
    @channel2.read ReadCharProcess.new(@channel2)
    @pipl.run
    @channel2.send SendCharProcess.new(@channel2, "a")
    @pipl.run
    @channel2.send SendCharProcess.new(@channel2, "b")
    @pipl.run
    @channel2.read ReadCharProcess.new(@channel2)
    @pipl.run

    @channel.read( ReadCharProcess.new(@channel) )
    @pipl.run
    @channel.read( ReadCharProcess.new(@channel) )
    @pipl.run
    @channel.send( SendCharProcess.new(@channel, "3") )
    @pipl.run

    @channel2.send SendCharProcess.new(@channel2, "c")
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

class ProcessSendCharacters
  def initialize(w, string)
    @w = w
    @c = string.split //
    proceed
  end

  def output
    c = @c.shift
    if @c.length > 0
      proceed
    end
    return c
  end

  private
    def proceed
      @w.send(self)
    end
end

class ProcessPrint
  def initialize(w, io)
    @w = w
    @io = io
    proceed
  end

  def input(name)
    @io.print name
    proceed
  end

  private
    def proceed
      @w.read(self)
    end
end

@w = Channel.new(@pipl)
@p1 = ProcessSendCharacters.new(@w, "Hello World\n")
require 'stringio'
out = 'OUTPUT: '
@p2 = ProcessPrint.new(@w, StringIO.new(out, 'a'))
@pipl.run()
print "\n#{out}"

# 3 senders - 3 readers - 1 channel
@w = Channel.new(@pipl)
@p1a = ProcessSendCharacters.new(@w, "Hello World")
@p1b = ProcessSendCharacters.new(@w, "Goodbye all")
@p1c = ProcessSendCharacters.new(@w, "foo bar baz")
outa = 'OUTPUT A: '
outb = 'OUTPUT B: '
outc = 'OUTPUT C: '
@p2a = ProcessPrint.new(@w, StringIO.new(outa, 'a'))
@p2b = ProcessPrint.new(@w, StringIO.new(outb, 'a'))
@p2c = ProcessPrint.new(@w, StringIO.new(outc, 'a'))
@pipl.run()
@p1d = ProcessSendCharacters.new(@w, " aaa\n")
@p1e = ProcessSendCharacters.new(@w, " bbb\n")
@p1f = ProcessSendCharacters.new(@w, " ccc\n")
@pipl.run()
print "\n#{outa}#{outb}#{outc}"

# 3 senders - 1 reader - 1 channel
@w = Channel.new(@pipl)
@p1a = ProcessSendCharacters.new(@w, "HlWl")
@p1b = ProcessSendCharacters.new(@w, "eood Goodbye all")
@p1c = ProcessSendCharacters.new(@w, "l r")
out = 'OUTPUT: '
@p2 = ProcessPrint.new(@w, StringIO.new(out, 'a'))
@pipl.run()
@p1d = ProcessSendCharacters.new(@w, " foo bar baz\n")
@pipl.run()
print "\n#{out}"

# 1 sender - 3 readers - 1 channel
@w = Channel.new(@pipl)
@p1 = ProcessSendCharacters.new(@w, "
HGf
eoo
loo
ld 
obb
 ya
Wer
o  
rab
lla
dlz".gsub(/\n/m, '')
)
outa = 'OUTPUT A: '
outb = 'OUTPUT B: '
outc = 'OUTPUT C: '
@p2a = ProcessPrint.new(@w, StringIO.new(outa, 'a'))
@p2b = ProcessPrint.new(@w, StringIO.new(outb, 'a'))
@p2c = ProcessPrint.new(@w, StringIO.new(outc, 'a'))
@pipl.run()
@p1d = ProcessSendCharacters.new(@w, "   abcabcabc\n\n\n")
@pipl.run()
print "\n#{outa}#{outb}#{outc}"
