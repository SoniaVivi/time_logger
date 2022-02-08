require './lib/time_logger.rb'

RSpec.configure do |c|
  c.example_status_persistence_file_path = 'spec/examples.txt'
end

RSpec.describe 'Logger' do
  it 'returns something' do
  end
end
