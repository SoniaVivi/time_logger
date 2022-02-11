require 'sqlite3'
require 'date'
require 'time'

class Logger
  attr_reader :connection

  def initialize(filename: 'time_log.db', output_format: '%d-%m-%y')
    @connection = SQLite3::Database.new(filename)
    @format = output_format
    setup_database
    self
  end
  def add_or_update(mins: 0, date: today, log_type: '')
    formatted_date = format_date(date)
    if !exists?(
         table: 'Logs',
         values: {
           date: formatted_date,
           log_type: log_type,
         },
       )
      @connection.execute(<<~EOS)
        INSERT INTO Logs (date, minutes, log_type)
        VALUES ('#{formatted_date}', #{mins}, '#{log_type}')
      EOS
    else
      update(
        table: 'Logs',
        select_column: {
          date: formatted_date,
          log_type: log_type,
        },
        update_columns: {
          minutes: "minutes + #{mins}",
        },
      )
    end
    if !exists?(table: 'LogTypes', values: { name: log_type })
      @connection.execute("INSERT INTO LogTypes (name) VALUES ('#{log_type}')")
    end
    self
  end
  def all(display: '', width: 24, row_size: 3)
    if display != 'LogTypes'
      records =
        @connection.execute(
          'SELECT date, minutes FROM Logs WHERE log_type=? ORDER BY date ASC',
          [display],
        )
      records =
        records
          .each_with_index
          .map do |data, i|
            date_segments = data[0].split('-').reverse
            "#{[*date_segments[0..-2], date_segments[-1][-2..-1]].join('-')}: #{data[1]}"
              .center(width) + (((i + 1) % row_size) == 0 ? "\n" : ' | ')
          end
          .join('')
      return records
    end
    records = @connection.execute('SELECT name FROM LogTypes ORDER BY id ASC')
    records
      .each_with_index
      .map do |name, i|
        name[0].center(width) + (((i + 1) % row_size) == 0 ? "\n" : ' | ')
      end
      .join('')
  end
  def delete(table: '', remove: {})
    sql = "DELETE FROM #{table} WHERE #{remove.to_a[0][0]}=?"
    @connection.execute(sql, [remove.to_a[0][1]])
  end
  def sum(log_type: '', option: '', start: nil)
    sql =
      'SELECT sum(minutes) FROM Logs WHERE log_type=? AND date>=? AND date<?'
    case option
    when 'year'
      @connection.execute(
        sql,
        [
          log_type,
          format_date('01-01-' + start.to_s).to_s,
          (format_date('01-01-' + start.to_s) + 365).to_s,
        ],
      )
    when 'all_time'
      @connection.execute(
        'SELECT sum(minutes) FROM Logs WHERE log_type=?',
        [log_type],
      )
    when 'month'
      @connection.execute(
        sql,
        [
          log_type,
          format_date('01-' + start).to_s,
          (format_date('01-' + start) + 30).to_s,
        ],
      )
    else
      @connection.execute(
        sql,
        [log_type, month_start.to_s, (format_date(today) + 1).to_s],
      )
    end[0][0] # prettier-ignore
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
            WHERE #{to_sql(select_column)}
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
    where_sql = to_sql values
    sql = <<~EOS
            SELECT 1
            FROM #{table}
            WHERE #{where_sql}
          EOS
    !@connection.execute(sql).empty?
  end
  def to_sql(conditions)
    where_sql = ''
    conditions.each { |column, value| where_sql += "#{column}='#{value}' AND " }
    where_sql[0..-6]
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
  def format_date(date)
    Date.strptime(date, '%d-%m-%Y')
  end
  def parse_date(date)
    Date.strptime(date, @format)
  end
  def today
    DateTime.now.strftime('%d-%m-%Y')
  end
  def month_start(date = DateTime.now)
    parse_date(date.strftime('01-%m-%Y'))
  end
end
