require 'spec_helper'

describe PIPL do
  let(:pipl) { PIPL.new }
  context 'simplest program - w(x).0 | w[z].0' do
    let(:name) { rand(100) }
    context 'creating channel w' do
      let(:w) { pipl.create_channel }

      it 'includes method to create channel' do
        w.should_not be_nil
      end

      context 'creating send sequence' do
        let(:sender) { pipl.create_sequence }

        it 'includes method to create sequential process' do
          sender.should_not be_nil
        end

        it 'includes method to append send action to sequence' do
          sender.add_send(w, name)
        end

        context 'creating read sequence' do
          let(:reader) { pipl.create_sequence }

          it 'includes method to append read action to sequence' do
            reader.add_read(w)
          end

          it 'creates a new channel when adding a read action' do
            ch = reader.add_read(w)
            ch.should_not be_nil
            ch.should_not equal w
          end

          context 'creating parallel process' do
            let(:p) { pipl.create_parallel_process }

            before(:each) do
              sender.add_send(w, name)
              reader.add_read(w)
            end

            it 'includes method to create parallel process' do
              p.add_process sender
              p.add_process reader
            end

            context 'running processes' do
              before(:each) do
                p.add_process sender
                p.add_process reader
              end

              it 'includes method to run process' do
                pipl.run p
              end

              it 'sends name of channel' do
                sender.should_not_receive(:input)
                reader.should_receive(:input).with(name)
                reader.should_not_receive(:output)
                pipl.run p
              end
            end
          end
        end
      end
    end
  end
end
