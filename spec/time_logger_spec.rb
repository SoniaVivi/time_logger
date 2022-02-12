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
  it 'deletes Log records' do
    time_log.add_or_update(log_type: 'Gaming', mins: 101)

    log_quantity = count_records.('Logs')
    log_type_quantity = count_records.('LogTypes')

    time_log.delete(table: 'Logs', remove: { log_type: 'Gaming' })
    time_log.delete(table: 'LogTypes', remove: { name: 'Gaming' })

    expect(count_records.('Logs')).to be < log_quantity
    expect(count_records.('LogTypes')).to be < log_type_quantity
  end
  it 'displays all records' do
    time_log.add_or_update(log_type: 'dog_walking', mins: 44, date: '01-01-01')
    time_log.add_or_update(log_type: 'dog_walking', mins: 44, date: '02-02-02')
    time_log.add_or_update(log_type: 'dog_walking', mins: 44, date: '03-03-03')

    expect(time_log.all(display: 'dog_walking', width: 20, row_size: 3)).to eq(
      ['01-01-01: 44', '02-02-02: 44', '03-03-03: 44'].map { |text|
        text.center(20)
      }.join(' | ') +
        "\n#{"#{DateTime.now.strftime('%d-%m-%y')}: 132".center(20)} | ",
    )

    time_log.add_or_update(log_type: 'Gaming', mins: 45, date: '03-03-03')

    expect(time_log.all(display: 'LogTypes', width: 40, row_size: 1)).to eq(
      %w[dog_walking Gaming].map { |text| text.center(40) + "\n" }.join(''),
    )
  end
  it 'returns sum of all records with X log_type' do
    expect(time_log.sum(log_type: 'dog_walking')).to eq(44 * 3)
    expect(
      time_log.sum(log_type: 'dog_walking', option: 'month', start: '01-01'),
    ).to eq(44)
    expect(
      time_log.sum(log_type: 'dog_walking', option: 'year', start: 03),
    ).to eq(44)
    expect(time_log.sum(log_type: 'dog_walking', option: 'all_time')).to eq(
      44 * 6,
    )
  end
  it 'returns average of all records with X log_type' do
    time_log.add_or_update(log_type: 'dog_walking', mins: 44, date: '01-01-01')
    time_log.add_or_update(log_type: 'dog_walking', mins: 44, date: '01-01-01')
    expect(
      time_log.average(log_type: 'dog_walking', option: 'year', start: '01'),
    ).to eq(44.0 * 3)
  end
end
