require_relative "time_logger"

def logger_cli
  logger = Logger.new
  if ARGV.length == 0 || ARGV[0] == '-v'
    logger.all.each {|data| display_record(data)}
  elsif !ARGV[0][/\d/].nil?
    display_record logger.update(ARGV[0].to_i)
  elsif ARGV[0] == '-u'
    display_record logger.update(ARGV[2].to_i, ARGV[1])
  elsif ARGV[0] == '-d'
    logger.delete ARGV[1]
  elsif ARGV[0] == '-s'
    time =
    if ["-week", "-month", "-year"].include? ARGV[1]
      logger.sum ARGV[1]
    else
      logger.sum "day"
    end
    puts ARGV[2] == "-hours" ? time / 60.0 : time
  else
    puts "-v: View all records", "[MINS]: Create or update entry for today",
         "-u [DATE] [MINS]: Update record at DATE (DD-MM-YY)",
         "-d [DATE]: Deletes records at DATE (DD-MM-YY)",
         "-s [none/-day/-week/-month/-year] [none/-mins/-hours] Total time for last X amount of time",
         "no arguments: same as -v"
  end

end

def display_record(data)
  print "\n#{data.keys[0]}: #{data.values[0]}\n"
end

logger_cli
