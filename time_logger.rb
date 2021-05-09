require 'yaml'
require 'date'

class Logger
  def initialize(filename="time_log")
    @filename = filename
    File.new(@filename, "w") if !File.file? @filename
  end
  def create
    open_file('a') do |file|
      file.write({DateTime.now.strftime("%d-%m-%y") => 0}.to_yaml)
    end
  end
  def update(mins)
    create if !record?
    lines = get_lines
    print lines
    record = YAML.load(lines[-1])
    lines[-1] = ({record.keys[0] => record[record.keys[0]] + mins}).to_yaml
    open_file("w") do |file|
      file.puts lines
    end
    record
  end
  def all
    open_file do |file|
      return file.readlines.map{ |line| YAML.load(line) }[1..-1]
    end
  end
  def delete
  end
  def sum
  end
  def record?(date=nil)
    record_date = date.nil? ? DateTime.now.strftime("%d-%m-%y") : date
    open_file('r') do |file|
      last_date = nil
      file.readlines.reverse.each do |line|
        record = YAML.load(line)
        return false if record.nil?
        record.each_pair do |date, minutes|
          parsed_date = DateTime.parse(Date.strptime(date, "%d-%m-%y").to_s)
          return true if record_date == parsed_date.strftime("%d-%m-%y")
          return false if !last_date.nil? && parsed_date > last_date
          last_date = parsed_date
        end
      end
    end
    false
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
    lines
  end
end
