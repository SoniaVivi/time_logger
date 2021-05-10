require 'yaml'
require 'date'

class Logger
  def initialize(filename="time_log", format="%d-%m-%y")
    @filename = filename
    @format = "%d-%m-%y"
    File.new(@filename, "w") if !File.file? @filename
  end
  def create
    open_file('a') do |file|
      file.write({today => 0}.to_yaml)
    end
  end
  def update(mins, date=today)
    create if !record?
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
      DateTime.now.prev_month
    elsif option == "year"
      DateTime.now.prev_year
    elsif option == "day"
      DateTime.now - 1
    else
      DateTime.now - 7
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
        return false if record.nil?
        parsed_date = parse_date(record.keys[0])
        return record if date == parsed_date.strftime(@format)
        return nil if !last_date.nil? && parsed_date > last_date
        last_date = parsed_date
      end
    end
    nil
  end
  def record?(date=today)
    find(date).nil? ? false : true
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
end
