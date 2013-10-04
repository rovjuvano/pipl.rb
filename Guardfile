require 'guard/rspec'

class ::Guard::RSpec
  alias :run_on_change_orig :run_on_change
  def run_on_change(paths)
    res = run_on_change_orig(paths)
    if !res
      #system('git commit -a')
    end
    res
  end
end

guard 'rspec', :version => 2, :all_after_pass => false, :all_on_start => true, :cli => '--color --format documentation' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }
end
