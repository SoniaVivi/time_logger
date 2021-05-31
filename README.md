# Time Logger

Basic program that logs minutes per day spent doing anything you wish

**Usage**

Run `ruby logger_cli.rb [OPTIONS]`

**Options**

-v: View all records

[MINS]: Create or update entry for today

-u [DATE] [MINS]: Update record at DATE (DD-MM-YY) or creates record at DATE if does not exist

-d [DATE]: Deletes records at DATE (DD-MM-YY)

-s [none/-day/-week/-month/-year] [none/-mins/-hours] Total time for last X amount of time

-avg [none/month index] Average for current month or at month index (ex. May == 5)

no arguments: same as -v
