require 'sqlite3'
require 'date'

class Logger
  attr_reader :connection

  def initialize(filename: 'time_log.db', output_format: '%d-%m-%y')
    @connection = SQLite3::Database.new(filename)
    @format = output_format
    setup_database
    self
  end
  def add_or_update(mins: 0, date: today, log_type: '')
    if !exists?(table: 'Logs', values: { date: date, log_type: log_type })
      @connection.execute(<<~EOS)
        INSERT INTO Logs (date, minutes, log_type)
        VALUES ('#{date}', #{mins}, '#{log_type}')
      EOS
    else
      update(
        table: 'Logs',
        select_column: {
          date: date,
        },
        update_columns: {
          minutes: "minutes+#{mins}",
        },
      )
    end
    if @connection.execute(<<~EOS, [log_type]).empty?
        SELECT 1 FROM LogTypes
        WHERE name=?
      EOS
      @connection.execute("INSERT INTO LogTypes (name) VALUES ('#{log_type}')")
    end
    self
  end
  def all
    get_lines.map { |line| YAML.load(line) }
  end
  def delete(table: '', remove: {})
    sql = "DELETE FROM #{table} WHERE #{remove.to_a[0][0]}=?"
    @connection.execute(sql, [remove.to_a[0][1]])
  end
  def sum(option = 'week')
    total_sum = 0
    end_date =
      if option == 'month'
        month_start
      elsif option == 'year'
        parse_date(today).prev_year
      elsif option == 'day'
        parse_date(today) - 1
      else
        parse_date(today) - 7
      end
    get_lines.each do |line|
      record = YAML.load(line)
      total_sum += record.values[0] if parse_date(record.keys[0]) >= end_date
    end
    total_sum
  end
  def find(date)
    open_file('r') do |file|
      last_date = nil
      file
        .readlines
        .reverse
        .each do |line|
          record = YAML.load(line)
          return nil if record.nil?
          parsed_date = parse_date(record.keys[0])
          return record if date == parsed_date.strftime(@format)
          return nil if !last_date.nil? && parsed_date > last_date
          last_date = parsed_date
        end
    end
    nil
  end
  def record?(date = today)
    !find(date).nil?
  end
  def average(month = DateTime.now.month)
    count = 0
    total = 0
    get_lines.reverse.each do |line|
      record = YAML.load(line)
      record_month = parse_date(record.keys[0]).month
      break if record_month < month
      if record_month == month
        total += record.values[0]
        count += 1.0
      end
    end
    count != 0 ? total / count : 0
  end

  private

  def create(table, attributes)
    sql = <<~EOS
      INSERT INTO #{table}(#{attributes.keys.join('')})
      VALUES (#{'?' * attributes.length})
      EOS
  end
  def setup_database
    tables = { Logs: <<~EOS, LogTypes: <<~EOS }
      CREATE TABLE Logs
        (id integer primary key,
         date datetime default current_timestamp,
         minutes integer,
         log_type string
        )
      EOS
      CREATE TABLE LogTypes
        (id integer primary key,
         name string
        )
      EOS

    tables.each do |table_name, sql|
      if !table?(table_name)
        @connection.execute(sql)
        puts "Created table: #{table_name}"
      end
    end
  end
  def update(table: '', select_column: {}, update_columns: {})
    sql = <<~EOS
            UPDATE #{table}
            SET #{update_columns.map { |pair| pair.join('=') }.join(',')}
            WHERE #{select_column.to_a[0][0].to_s}='#{select_column.to_a[0][1]}'
          EOS
    @connection.execute(sql)
  end
  def table?(name)
    sql = <<~EOS
        SELECT count(name)
        FROM sqlite_master
        WHERE type='table'
        AND name='#{name}'
      EOS
    @connection.execute(sql)[0][0] != 0
  end
  def exists?(table: '', values: {})
    where_sql = ''
    values.each { |column, value| where_sql += "#{column}=? AND " }
    sql = <<~EOS
            SELECT 1
            FROM #{table}
            WHERE #{where_sql[0..-6]}
          EOS
    !@connection.execute(sql, values.map { |_, v| v }).empty?
  end
  def open_file(mode = 'r')
    file = File.open(@filename, mode)
    yield file
    file.close
  end
  def get_lines
    lines = []
    open_file do |file|
      file.readlines.each { |line| lines << line unless line == "---\n" }
    end
    lines.keep_if { |entry| !entry.nil? }
  end
  def save(array)
    open_file('w') { |file| file.puts array }
  end
  def parse_date(date)
    DateTime.parse(Date.strptime(date, @format).to_s)
  end
  def today
    DateTime.now.strftime(@format)
  end
  def month_start(date = DateTime.now)
    parse_date(date.strftime('01-%m-%Y'))
  end
end
