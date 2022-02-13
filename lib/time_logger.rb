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
    formatted_date = date.class == String ? format_date(date) : date.to_s
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
    sql = "DELETE FROM #{table} WHERE #{to_sql(remove)}"
    @connection.execute(sql)
  end
  def sum(log_type: '', option: '', start: nil)
    aggregate(
      aggregate_function: 'sum',
      log_type: log_type,
      option: option,
      start: start,
    )
  end
  def average(log_type: '', option: '', start: nil)
    aggregate(
      aggregate_function: 'avg',
      log_type: log_type,
      option: option,
      start: start,
    )
  end
  def import_from_yaml(log_type: '', filename: 'time_log')
    get_lines(filename).each do |entry|
      date = entry.match(/(?<='|)[\d-]+(?=':|:)/).to_s
      minutes = entry.match(/(?<=: )\d+(?=\n)/).to_s
      add_or_update(log_type: log_type, date: parse_date(date), mins: minutes)
    end
  end
  def set_user_preference(name: '', new_val: '')
    update(
      table: 'UserPreferences',
      select_column: {
        name: name,
      },
      update_columns: {
        val: "'#{new_val}'",
      },
    )
  end
  def get_preferences(preferences: [])
    preferences.map { |name| get_user_preference(name: name) }
  end
  def get_user_preference(name: '')
    result =
      @connection.execute(
        'SELECT val from UserPreferences WHERE name=?',
        [name],
      )[
        0
      ][
        0
      ]
    return result if name != 'default_log_type'
    if result.empty?
      r = @connection.execute('SELECT name FROM LogTypes LIMIT 1')
      r.empty? ? r : r[0][0]
    else
      result
    end
  end
  def format_date(date)
    return nil if date.nil?
    str = Date.strptime(date, '%d-%m-%y')
    str
  end

  private

  def create(table, attributes)
    sql = <<~EOS
      INSERT INTO #{table}(#{attributes.keys.join('')})
      VALUES (#{'?' * attributes.length})
      EOS
  end
  def setup_database
    tables = { Logs: <<~EOS, LogTypes: <<~EOS, UserPreferences: <<~EOS }
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
      CREATE TABLE UserPreferences
        (id integer primary key,
         name string,
         val string
        )
      EOS

    tables.each do |table_name, sql|
      if !table?(table_name)
        @connection.execute(sql)
        puts "Created table: #{table_name}"
        if table_name == :UserPreferences
          [
            "INSERT INTO UserPreferences (name, val)
            VALUES ('row_size', '3');",
            "INSERT INTO UserPreferences (name, val)
            VALUES ('width', '24');",
            "INSERT INTO UserPreferences (name, val)
            VALUES ('default_log_type', '');",
            "INSERT INTO UserPreferences (name, val)
            VALUES ('time_unit', 'minutes');",
            "INSERT INTO UserPreferences (name, val)
            VALUES ('kanji', 'false');",
            "INSERT INTO UserPreferences (name, val)
            VALUES ('hiragana', 'false');",
            "INSERT INTO UserPreferences (name, val)
            VALUES ('motivational_message', '');",
          ].each { |sql| @connection.execute(sql) }
        end
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
  def aggregate(log_type: '', option: '', start: nil, aggregate_function: '')
    sql = <<~EOS
            SELECT #{aggregate_function}(minutes)
            FROM Logs
            WHERE log_type=?
            AND date>=? AND date<?
          EOS

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
        "SELECT #{aggregate_function}(minutes) FROM Logs WHERE log_type=?",
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
  def to_sql(conditions)
    where_sql = ''
    conditions.each { |column, value| where_sql += "#{column}='#{value}' AND " }
    where_sql[0..-6]
  end
  def get_lines(filename)
    lines = []
    file = File.open(filename, 'r')
    file.readlines.each { |line| lines << line unless line == "---\n" }
    file.close
    lines.keep_if { |entry| !entry.nil? }
  end
  def parse_date(date)
    Date.strptime(date, @format)
  end
  def today
    DateTime.now.strftime('%d-%m-%y')
  end
  def month_start(date = DateTime.now)
    parse_date(date.strftime('01-%m-%Y'))
  end
end
