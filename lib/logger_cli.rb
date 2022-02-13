require 'number_to_kanji'
require_relative 'time_logger'

def logger_cli
  logger = Logger.new
  is_length = ->(length) { ARGV.length == length }
  width, default_log_type, row_size, motivational_message, display_kanji =
    logger.get_preferences(
      preferences: %w[
        width
        default_log_type
        row_size
        motivational_message
        kanji
      ],
    )
  display_kanji = display_kanji == 'true' ? true : false
  display = ->(date: nil, log_type: nil) do
    data = logger.connection.execute(<<~EOS)[0]
        SELECT id,
               date,
               minutes,
               log_type
        FROM Logs
        #{
          if date.nil?
            ''
          else
            " WHERE id=#{
              logger.connection.execute(
                'SELECT id FROM Logs WHERE date=? AND log_type=?',
                [logger.format_date(date).to_s, log_type],
              )[
                0
              ][
                0
              ]
            } "
          end
        } ORDER BY id DESC LIMIT 1
        EOS

    minutes = display_kanji ? NumberToKanji.call(data[2]) : data[2]
    print "Date: #{data[1]} | Minutes: #{minutes} | Log Type: #{data[3]}"
    (print "\n#{motivational_message}\n") if motivational_message
  end

  case ARGV[0]
  when nil, '-v'
    puts logger.all(
           display: is_length.(2) ? ARGV[1] : default_log_type,
           width: width.to_i,
           row_size: row_size.to_i,
           display_kanji: display_kanji,
         )
  when /\d/
    logger.add_or_update(
      mins: ARGV[0].to_i,
      log_type: is_length.(2) ? ARGV[1].to_s : default_log_type,
    )
    display.()
  when '-u'
    log_type = is_length.(4) ? ARGV[3] : default_log_type
    logger.add_or_update(date: ARGV[1], mins: ARGV[2].to_i, log_type: log_type)
    display.(date: ARGV[1], log_type: log_type)
  when '-d'
    logger.delete(
      table: 'Logs',
      remove: {
        date: logger.format_date(ARGV[1]),
        log_type: ARGV[2],
      },
    )
  when '-s'
    units, sum_type = get_units_and_span

    time =
      logger.sum(
        log_type: ARGV[1],
        option: !sum_type.nil? ? sum_type[1..-1] : nil,
        start: !sum_type.nil? ? ARGV[-1] : nil,
      )
    puts units == '-hours' ? time / 60.0 : time
  when '-avg'
    units, average_type = get_units_and_span

    time =
      logger.average(
        log_type: ARGV[1],
        option: !average_type.nil? ? average_type[1..-1] : nil,
        start: !average_type.nil? ? ARGV[-1] : nil,
      )
    puts units == '-hours' ? time / 60.0 : time
  when '-set'
    logger.set_user_preference(name: ARGV[1], new_val: ARGV[2..-1].join(' '))
  when '-prefs'
    puts %w[
           row_size
           width
           default_log_type
           time_unit
           kanji
           motivational_message
         ].map { |pref_name|
           "#{pref_name}: #{logger.get_user_preference(name: pref_name)}"
         }
  when '-import'
    return puts 'MUST INPUT LOG TYPE' if is_length.(1)
    logger.import_from_yaml(
      log_type: ARGV[1],
      filename: is_length.(3) ? ARGV[2] : 'time_log',
    )
  else
    puts <<-EOS
  [MINS] [NONE/LOG TYPE]
    Create or update entry for today with default log type or LOG TYPE
  -v [NONE/LOG TYPE/-log_types]
    View records of default log type
    View records of LOG TYPE
    View all log types
  -u [DATE] [MINS] [NONE/LOG TYPE]
    Update record at DATE (DD-MM-YY) with default log type or LOG TYPE
  -d [DATE] [LOG TYPE]
    Delete record with LOG TYPE at DATE
  -s [LOG TYPE] [NONE/-mins/-hours] [NONE/SUM TYPE] [NONE/DATE]
    Shows sum of records with LOG TYPE.
    SUM TYPE options (defaults to -month):
      -all_time
      -year (DATE must be in YY format)
      -month (DATE must be in MM-YY format)
  -avg [LOG TYPE] [NONE/-mins/-hours] [NONE/AVERAGE TYPE] [NONE/DATE]
    Shows average of records with LOG TYPE.
    AVERAGE TYPE options (defaults to -month):
      -all
      -year (DATE must be in YY format)
      -month (DATE must be in MM-YY format)
  -set [NAME] [VALUE]
    Set user preference with NAME to VALUE
  -prefs
    Display preferences
  -import [LOG TYPE] [NONE/FILEPATH]
    Imports entries from YAML file
  [NONE]
    same as -v
EOS
  end
end
def get_units_and_span
  [
    get_argv_value('-mins', %w[-mins -hours]),
    get_argv_value(nil, %w[-all_time -year -month]),
  ]
end

def get_argv_value(default_value, values)
  value = default_value
  ARGV.each { |option| value = option if values.include?(option) }
  value
end

logger_cli
