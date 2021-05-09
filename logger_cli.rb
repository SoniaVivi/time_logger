require_relative "time_logger"

def logger_cli
  logger = Logger.new
  case ARGV[0]
  when nil, '-v'
    logger.all.each {|data| display_record(data)}
  when /\d/
    display_record logger.update(ARGV[0].to_i)
  when '-u'
    display_record logger.update(ARGV[2].to_i, ARGV[1])
  when'-d'
    logger.delete ARGV[1]
  when '-s'
    valid_option = ["-day", "-week", "-month", "-year"].include?(ARGV[1])
    time = valid_option ? logger.sum(ARGV[1][1..-1]) : logger.sum("month")
    puts ARGV[2] == "-hours" ? time / 60.0 : time
  when '-avg'
    puts ARGV[1] ? logger.average(ARGV[1].to_i) : logger.average
  else
    puts "-v: View all records", "[MINS]: Create or update entry for today",
         "-u [DATE] [MINS]: Update record at DATE (DD-MM-YY)",
         "-d [DATE]: Deletes records at DATE (DD-MM-YY)",
         "-s [none/-day/-week/-month/-year] [none/-mins/-hours] Total time for last X amount of time",
         "-avg [none/month index] Average for current month or at month index (ex. May == 5) "
         "no arguments: same as -v"
  end

end

def display_record(data)
  print "\n#{data.keys[0]}: #{data.values[0]}\n"
end

logger_cli
