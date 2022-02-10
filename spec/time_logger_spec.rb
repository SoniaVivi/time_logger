require './lib/time_logger'
require 'date'

RSpec.configure do |c|
  c.example_status_persistence_file_path = 'spec/examples.txt'
end

RSpec.describe 'Logger' do
  time_log = Logger.new(filename: ':memory:')
  count_records = ->(name) { time_log.connection.execute(<<~EOS)[0][0] }
    SELECT count(*)
    FROM #{name}
  EOS

  has_table = ->(name) { time_log.connection.execute(<<~EOS)[0][0] != 0 }
    SELECT count(name)
    FROM sqlite_master
    WHERE type='table'
    AND name='#{name}'
  EOS

  it 'creates database' do
    expect(time_log.connection.nil?).to eq(false)
  end
  it 'creates Log and LogTypes tables' do
    expect(has_table.('Logs')).to eq(true)
    expect(has_table.('LogTypes')).to eq(true)
  end
  it 'creates Log records and appropriate LogType entry' do
    time_log.add_or_update(log_type: 'dog_walking', mins: 44)
    expect(count_records.('Logs')).to eq(1)
    expect(count_records.('LogTypes')).to eq(1)
    expect(
      time_log.connection.execute('SELECT minutes FROM Logs LIMIT 1')[0][0],
    ).to eq (44)
  end
  it 'does not create duplicate LogTypes or Logs rows' do
    time_log.add_or_update(log_type: 'dog_walking', mins: 44)
    time_log.add_or_update(log_type: 'dog_walking', mins: 44)
    expect(count_records.('Logs')).to eq(1)
    expect(
      time_log.connection.execute('SELECT minutes FROM Logs LIMIT 1')[0][0],
    ).to eq (44 * 3)
    expect(count_records.('LogTypes')).to eq(1)
  end
end
