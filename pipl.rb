class PIPL
  class Channel
    def initialize(pipl)
      @pipl = pipl
      @send_queue = []
      @read_queue = []
    end

    def send(sender)
puts "[#{self}] send: #{sender}"
      if waiting_for_send?
        @pipl.enqueue_step self
      end
      @send_queue << sender
    end

    def read(reader)
puts "[#{self}] read: #{reader}"
      if waiting_for_read?
        @pipl.enqueue_step self
      end
      @read_queue << reader
    end

    def sync
      if has_active_steps?
        sender = @send_queue.shift
        reader = @read_queue.shift
        reader.input sender.output
      end
    end

    def cancel(process)
      #puts "cancelling #{process} at #{__LINE__}"
      @send_queue.delete process
      @read_queue.delete process
    end

    private
      def waiting_for_send?
        @send_queue.length < @read_queue.length
      end

      def waiting_for_read?
        @read_queue.length < @send_queue.length
      end

      def has_active_steps?
        @send_queue.length > 0 && @read_queue.length > 0
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
      def cancel(refs, sequence)
        #puts "#{self} step: was not chosen at #{__LINE__}"
        refs[@channel_id].value.cancel sequence
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
      def cancel(refs, sequence)
        #puts "#{self} step: was not chosen at #{__LINE__}"
        refs[@channel_id].value.cancel sequence
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

    def set_choice(choice)
      @choice = choice
    end

    def cancel
      #puts "#{self}[#{@i}]: was not chosen at #{__LINE__}"
      @step.cancel @refs, self
    end

    def proceed
      if @i < @steps.length
        @step = @steps[@i]
        @i += 1
        @step.proceed @refs, self
      end
    end

    def output
      if @choice
        @choice.chosen self
        @choice = nil
      end
      out = @step.output @refs
      proceed
      out
    end

    def input(name)
      if @choice
        @choice.chosen self
        @choice = nil
      end
      @step.input @refs, name
      proceed
    end

    private
      def make_ref(channel)
        @refs[channel] ||= PIPL::Reference.new(channel)
        channel
      end
  end

  class ReplicatingSequenceProcess < SequenceProcess
    def output
      out = replicate.output
      @i = 0
      proceed
      out
    end

    def input(name)
      replicate.input name
      @i = 0
      proceed
    end

    private
      def replicate
        copy = PIPL::SequenceProcess.new @pipl
        copy.instance_variable_set('@steps', @steps)
        copy.instance_variable_set('@step', @steps[@i - 1])
        copy.instance_variable_set('@i', @i)
        copy.instance_variable_set('@refs', refs_copy)
        copy
      end

      def refs_copy
        copy = {}
        @refs.each_pair do |key, ref|
          copy[key] = PIPL::Reference.new(ref.value)
        end
        copy
      end
  end

  class ParallelProcess
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

  class ChoiceProcess
    def initialize
      @processes = []
    end

    def add_process(process)
      @processes << process
    end

    def chosen(process)
      #puts "#{process} was chosen at #{__LINE__}"
      @processes.each do |p|
        p.cancel unless p == process
      end
    end

    def proceed
      @processes.each do |p|
        p.set_choice self
        p.proceed
      end
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

  def make_replicating_sequence
    return PIPL::ReplicatingSequenceProcess.new self
  end

  def make_parallel_process
    return PIPL::ParallelProcess.new
  end

  def make_choice_process
    return PIPL::ChoiceProcess.new
  end

  # running
  def run(process)
    process.proceed
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
  def enqueue_step(channel)
    @queue.push channel
  end

  private
    def dequeue_step
      @queue.shift
    end

    def complete_step(channel)
      print '%04i: ' % [@step_number]
      channel.sync
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
    @pipl.step if @pipl.running?
    @channel.send( SendCharProcess.new(@channel, "2") )
    @pipl.step if @pipl.running?
    @channel.read( ReadCharProcess.new(@channel) )
    @pipl.step

    @channel2 = @pipl.make_channel
    @channel2.read ReadCharProcess.new(@channel2)
    @pipl.step if @pipl.running?
    @channel2.read ReadCharProcess.new(@channel2)
    @pipl.step if @pipl.running?
    @channel2.send SendCharProcess.new(@channel2, "a")
    @pipl.step
    @channel2.send SendCharProcess.new(@channel2, "b")
    @pipl.step
    @channel2.read ReadCharProcess.new(@channel2)
    @pipl.step if @pipl.running?

    @channel.read( ReadCharProcess.new(@channel) )
    @pipl.step
    @channel.read( ReadCharProcess.new(@channel) )
    @pipl.step if @pipl.running?
    @channel.send( SendCharProcess.new(@channel, "3") )
    @pipl.step

    @channel2.send SendCharProcess.new(@channel2, "c")
    @pipl.step

puts "\n-- cancel"
@ch = @pipl.make_channel

@ch.send( SendCharProcess.new(@ch, "1") )
@ps = SendCharProcess.new(@ch, "X1")
@ch.send @ps
@ch.send( SendCharProcess.new(@ch, "2") )
@ch.send( SendCharProcess.new(@ch, "X2") )

@ch.read( ReadCharProcess.new(@ch) )
@pr = ReadCharProcess.new(@ch)
@ch.read @pr
@ch.read( ReadCharProcess.new(@ch) )

@ch.cancel @ps
@ch.cancel @pr
@pipl.step
@pipl.step
@pipl.step # null step
puts @pipl.running? ? 'still running' : 'stopped'

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
@pipl = PIPL.new

def make_send_characters_process(w, string)
  ps = @pipl.make_sequence
  string.split(//).each do |c|
    ps.add_send(w, c)
  end
  ps
end

def make_print_process(io, w)
  ps = @pipl.make_replicating_sequence
  c = @pipl.make_channel
  #n = 0
  #ps.add_function(lambda { puts "#{c.object_id}: #{n}"; n += 1 })
  ps.add_read(w, c)
  ps.add_function(lambda { |c| io.print c.value }, c)
  ps
end

puts "\n-- send characters - 1 sender/1 reader - 1 channel"
@w = @pipl.make_channel
@p = @pipl.make_parallel_process
@s = "Hello World\n"
out = "OUTPUT: "
@p.add_process make_send_characters_process(@w, @s)
@p.add_process make_print_process(StringIO.new(out, 'a'), @w)
@pipl.run @p
print out

puts "\n-- send characters - 3 senders/3 readers - 1 channel"
outa = "OUTPUT A: "
outb = "OUTPUT B: "
outc = "OUTPUT C: "

@w = @pipl.make_channel
@p1 = @pipl.make_parallel_process
@p1.add_process make_send_characters_process(@w, "Hello World")
@p1.add_process make_send_characters_process(@w, "Goodbye all")
@p1.add_process make_send_characters_process(@w, "foo bar baz")

@p1.add_process make_print_process(StringIO.new(outa, 'a'), @w)
@p1.add_process make_print_process(StringIO.new(outb, 'a'), @w)
@p1.add_process make_print_process(StringIO.new(outc, 'a'), @w)
@pipl.run @p1

@p2 = @pipl.make_parallel_process
@p2.add_process make_send_characters_process(@w, " aaa\n")
@p2.add_process make_send_characters_process(@w, " bbb\n")
@p2.add_process make_send_characters_process(@w, " ccc\n")
@pipl.run @p2
print "#{outa}#{outb}#{outc}"

puts "\n-- send characters - 3 senders/1 reader - 1 channel"
out = "OUTPUT: "
@w = @pipl.make_channel
@p1 = @pipl.make_parallel_process
@p1.add_process make_send_characters_process(@w, "HlWl")
@p1.add_process make_send_characters_process(@w, "eood Goodbye all")
@p1.add_process make_send_characters_process(@w, "l r")
@p1.add_process make_print_process(StringIO.new(out, 'a'), @w)
@pipl.run @p1
@p2 = make_send_characters_process(@w, " foo bar baz\n")
@pipl.run @p2
print out

puts "\n-- send characters - 1 sender/3 readers - 1 channel"
outa = "OUTPUT A: "
outb = "OUTPUT B: "
outc = "OUTPUT C: "

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
@p1 = @pipl.make_parallel_process
@p1.add_process make_send_characters_process(@w, @s)
@p1.add_process make_print_process(StringIO.new(outa, 'a'), @w)
@p1.add_process make_print_process(StringIO.new(outb, 'a'), @w)
@p1.add_process make_print_process(StringIO.new(outc, 'a'), @w)
@pipl.run @p1
@p2 = make_send_characters_process(@w, "   abcabcabc\n\n\n")
@pipl.run @p2
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

  @p = @pipl.make_parallel_process
  @p.add_process @puts
  @p.add_process @s1
  @p.add_process @s2
  @pipl.run @p
end
add2(1,2)
add2(2,3)
add2(3,4)

puts "\n-- choice"
def choice(i, n)
  @cp = @pipl.make_choice_process
  @choices = []
  n.times do |j|
    @w = @pipl.make_channel
    @choices << @w

    @n = @pipl.make_sequence
    c = @n.add_read(@w)
    @n.add_function(lambda { |c| puts "Choose #{j}: #{c.value}" }, c)
    c = @n.add_read(@w)
    @n.add_function(lambda { |c| puts "Choose #{j}: #{c.value}" }, c)

    @cp.add_process @n
  end

  @s = @pipl.make_sequence
  @s.add_send @choices[i], "chose #{i}"
  @s.add_send @choices[i], "done"
  (0...n).to_a.shuffle.each do |j|
    @s.add_send @choices[j], "not chosen #{j}" if i != j
  end

  @p = @pipl.make_parallel_process
  @p.add_process @cp
  @p.add_process @s
  @pipl.run @p
end
choice 0, 3
choice 1, 3
choice 2, 3
