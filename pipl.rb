class PIPL
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

  class Reference
    attr_accessor :value
    def initialize(value)
      @value = value
    end
  end

  class SequenceProcess
    class SendStep
      def initialize(channel_id, name_id)
        @channel_id = channel_id
        @name_id = name_id
      end
      def output(refs)
        refs[@name_id].value
      end
      def proceed(refs, sequence)
        refs[@channel_id].value.send sequence
      end
    end

    class ReadStep
      def initialize(channel_id, name_id)
        @channel_id = channel_id
        @name_id = name_id
      end
      def input(refs, name)
        refs[@name_id].value = name
      end
      def proceed(refs, sequence)
        refs[@channel_id].value.read sequence
      end
    end

    class FunctionStep
      def initialize(function, ids)
        @function = function
        @ids = ids || []
      end
      def proceed(refs, sequence)
        args = @ids.map { |id| refs[id] }
        @function.call(*args)
        sequence.proceed
      end
    end

    def initialize(pipl)
      @pipl = pipl
      @steps = []
      @i = 0
      @refs = {}
    end

    def add_send(channel, name)
      @steps << PIPL::SequenceProcess::SendStep.new(make_ref(channel), make_ref(name))
    end

    def add_read(channel, name=nil)
      name ||= PIPL::Channel.new @pipl
      @steps << PIPL::SequenceProcess::ReadStep.new(make_ref(channel), make_ref(name))
      name
    end

    def add_function(function, *channels)
      channels.each { |ch| make_ref(ch) }
      @steps << PIPL::SequenceProcess::FunctionStep.new(function, channels)
    end

    def proceed
      if @i < @steps.length
        @step = @steps[@i]
        @i += 1
        @step.proceed @refs, self
      end
    end

    def output
      out = @step.output @refs
      proceed
      out
    end

    def input(name)
      @step.input @refs, name
      proceed
    end

    private
      def make_ref(channel)
        @refs[channel] ||= PIPL::Reference.new(channel)
        channel
      end
  end

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

  def make_channel
    return PIPL::Channel.new self
  end

  def make_sequence
    return PIPL::SequenceProcess.new self
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
    @channel = @pipl.make_channel
    @channel.send( SendCharProcess.new(@channel, "1") )
    @pipl.run
    @channel.send( SendCharProcess.new(@channel, "2") )
    @pipl.run
    @channel.read( ReadCharProcess.new(@channel) )
    @pipl.run

    @channel2 = @pipl.make_channel
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
require 'stringio'

def make_send_characters_process(w, string)
  ps = @pipl.make_sequence
  string.split(//).each do |c|
    ps.add_send(w, c)
  end
  ps
end

def make_print_process(io, w, count)
  ps = @pipl.make_sequence
  c = @pipl.make_channel
  count.times do
    ps.add_read(w, c)
    ps.add_function(lambda { |c| io.print c.value }, c)
  end
  ps
end

puts "\n-- send characters - 1 sender/1 reader - 1 channel"
@w = @pipl.make_channel
@s = "Hello World\n"
out = "OUTPUT: "
make_send_characters_process(@w, @s).proceed
make_print_process(StringIO.new(out, 'a'), @w, @s.length).proceed
@pipl.run
print out

puts "\n-- send characters - 3 senders/3 readers - 1 channel"
outa = "OUTPUT A: "
outb = "OUTPUT B: "
outc = "OUTPUT C: "
count = 16

@w = @pipl.make_channel
make_send_characters_process(@w, "Hello World").proceed
make_send_characters_process(@w, "Goodbye all").proceed
make_send_characters_process(@w, "foo bar baz").proceed

make_print_process(StringIO.new(outa, 'a'), @w, count).proceed
make_print_process(StringIO.new(outb, 'a'), @w, count).proceed
make_print_process(StringIO.new(outc, 'a'), @w, count).proceed
@pipl.run

make_send_characters_process(@w, " aaa\n").proceed
make_send_characters_process(@w, " bbb\n").proceed
make_send_characters_process(@w, " ccc\n").proceed
@pipl.run
print "#{outa}#{outb}#{outc}"

puts "\n-- send characters - 3 senders/1 reader - 1 channel"
out = "OUTPUT: "
@w = @pipl.make_channel
make_send_characters_process(@w, "HlWl").proceed
make_send_characters_process(@w, "eood Goodbye all").proceed
make_send_characters_process(@w, "l r").proceed
make_print_process(StringIO.new(out, 'a'), @w, 37).proceed
@pipl.run
make_send_characters_process(@w, " foo bar baz\n").proceed
@pipl.run
print out

puts "\n-- send characters - 1 sender/3 readers - 1 channel"
outa = "OUTPUT A: "
outb = "OUTPUT B: "
outc = "OUTPUT C: "
count = 16

@w = @pipl.make_channel
@s = "
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
make_send_characters_process(@w, @s).proceed
make_print_process(StringIO.new(outa, 'a'), @w, count).proceed
make_print_process(StringIO.new(outb, 'a'), @w, count).proceed
make_print_process(StringIO.new(outc, 'a'), @w, count).proceed
@pipl.run
make_send_characters_process(@w, "   abcabcabc\n\n\n").proceed
@pipl.run
print "#{outa}#{outb}#{outc}"

### simple adder program
# p[s].0 | a(1).a(2).a(p).0 | a[m].a[n].a[o].o(m+n).0
#
# p - name of print string process
# a - name of adder process
# 1,2 - names for numbers
#
# a(1) - sends 1 on channel a
# a(2) - sends 2 on channel a
# a(p) - sends name of print string process on channel a
#
# a[m] - reads number from channel a
# a[n] - reads number from channel a
# a[o] - reads name of process to send output from channel a
# o(m+n) - sends summed result on channel referenced by o
puts "\n-- add two numbers"
def add2(n1, n2)
  @p = @pipl.make_channel
  @w = @pipl.make_channel

  @puts = @pipl.make_sequence
  c = @puts.add_read(@p)
  @puts.add_function(lambda { |c| puts "OUTPUT #{n1} + #{n2} = #{c.value}" }, c)

  @s1 = @pipl.make_sequence
  @s1.add_send(@w, n1)
  @s1.add_send(@w, n2)
  @s1.add_send(@w, @p)

  @s2 = @pipl.make_sequence
  acc = @pipl.make_channel
  m = @s2.add_read(@w)
  n = @s2.add_read(@w)
  o = @s2.add_read(@w)
  @s2.add_function(lambda { |m, n, acc| acc.value = m.value + n.value }, m, n, acc)
  @s2.add_send(o, acc)

  @puts.proceed
  @s1.proceed
  @s2.proceed
  @pipl.run
end
add2(1,2)
add2(2,3)
add2(3,4)
