require 'yaml'
require 'date'

class Logger
  def initialize(filename="time_log", format="%d-%m-%y")
    @filename = filename
    @format = "%d-%m-%y"
    File.new(@filename, "w") if !File.file? @filename
  end
  def create(mins=0, date=today)
    open_file('a') do |file|
      file.write({date => mins}.to_yaml)
    end
    if date != today
      lines = get_lines
      lines.map! {|line| YAML.load(line)}
      lines.sort! {|a, b| parse_date(a.keys[0]) <=> parse_date(b.keys[0])}
      save lines.map {|line| line.to_yaml}
    end
  end
  def update(mins, date=today)
    create(mins, date) if !record?(date)
    lines = get_lines.reverse
    new_record = nil
    lines.map! do |line|
      record = YAML.load(line)
      if record.keys[0] == date
        new_record = ({record.keys[0] => record[record.keys[0]] + mins}).to_yaml
      else
        line
      end
    end
    save lines.reverse
    YAML.load(new_record)
  end
  def all
    get_lines.map{ |line| YAML.load(line) }
  end
  def delete(date=today)
    lines = get_lines
    lines.delete_if {|record| YAML.load(record).keys[0] == date}
    save lines
    nil
  end
  def sum(option="week")
    total_sum = 0
    end_date =
    if option == "month"
      month_start
    elsif option == "year"
      parse_date(today).prev_year
    elsif option == "day"
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
      file.readlines.reverse.each do |line|
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
  def record?(date=today)
    !find(date).nil?
  end
  def average(month=DateTime.now.month)
    count = 0
    sum = 0
    get_lines.each do |line|
      record = YAML.load(line)
      record_month = parse_date(record.keys[0]).month
      break if record_month < month
      if record_month == month
        sum += record.values[0]
        count += 1.0
      end
    end
    count != 0 ? sum / count : 0
  end

  private

  def open_file(mode="r")
    file = File.open(@filename, mode)
    yield file
    file.close
  end
  def get_lines
    lines = []
    open_file do |file|
      file.readlines.each { |line| lines << line unless line == "---\n"}
    end
    lines.keep_if{|entry| !entry.nil?}
  end
  def save(array)
    open_file("w") {|file| file.puts array }
  end
  def parse_date(date)
    DateTime.parse(Date.strptime(date, @format).to_s)
  end
  def today
    DateTime.now.strftime(@format)
  end
  def month_start(date=DateTime.now)
    parse_date(date.strftime('01-%m-%Y'))
  end
end
