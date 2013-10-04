require 'spec_helper'

describe PIPL do
  let(:pipl) { PIPL.new }

  describe 'channels' do
    it 'can create channels' do
      w = pipl.create_channel
      w.should_not be_nil
    end
  end

  context 'sequential processes' do
    it 'can create sequential processes' do
      s = pipl.create_sequence
      s.should_not be_nil
    end

    context 'after creating a sequence' do
      let(:w) { pipl.create_channel }
      let(:s) { pipl.create_sequence }

      it 'can append a send action to a sequence' do
        s.add_send(w, '')
      end

      it 'can append a read action to a sequence' do
        s.add_read(w)
      end

      context 'when appending a send action to a sequence' do
        it 'rejects a channel that is not channel-like' do
          expect { s.add_send('', '') }.to raise_error
        end

        it 'accepts a name that is not a channel' do
          s.add_send(w, 'not-a-channel')
        end

        it 'accepts a name that is identical to the channel' do
          s.add_send(w, w)
        end
      end

      context 'when appending a read action to a sequence' do
        it 'rejects a channel that is not channel-like' do
          expect { s.add_read('', '') }.to raise_error
        end

        it 'accepts a name that is not a channel' do
          s.add_read(w, 'not-a-channel')
        end

        it 'accepts a name that is identical to the channel' do
          s.add_read(w, w)
        end

        context 'when a name is given' do
          it 'returns the given name' do
            exp = pipl.create_channel
            got = s.add_read(w, exp)
            got.should equal exp
          end
        end

        context 'when no name is given' do
          it 'returns a new channel' do
            ch = s.add_read(w)
            ch.should_not be_nil
            ch.should_not equal w
          end
        end
      end
    end
  end

  context 'after creating some sequental processes' do
    it 'can run sequential processes' do
      s1 = pipl.create_sequence
      s2 = pipl.create_sequence
      pipl.run s1, s2
    end
  end

  context 'to execute the simplest program - w(x).0 | w[z].0' do
    let(:name) { rand(100) }

    it 'creates channel w' do
      w = pipl.create_channel
      w.should_not be_nil
    end

    context 'after creating channels' do
      let(:w) { pipl.create_channel }

      it 'creates send process w(x).0' do
        sender = pipl.create_sequence
        sender.should_not be_nil
        sender.add_send(w, name)
      end

      it 'creates read process w[x].0' do
        reader = pipl.create_sequence
        reader.should_not be_nil
        reader.add_read(w)
      end

      context 'after creating sequential processes' do
        let(:sender) { pipl.create_sequence }
        let(:reader) { pipl.create_sequence }

        before(:each) do
          sender.add_send(w, name)
          reader.add_read(w)
        end

        it 'runs sequential processes in parallel' do
          pipl.run sender, reader
        end

        context 'when running program' do
          it 'outputs name from sending process' do
            sender.output.should equal(name)
            sender.should_receive(:output)
            sender.should_not_receive(:input)
            pipl.run sender, reader
          end

          it 'inputs name into reading process' do
            reader.should_receive(:input).with(name)
            reader.should_not_receive(:output)
            pipl.run sender, reader
          end
        end
      end
    end
  end
end
