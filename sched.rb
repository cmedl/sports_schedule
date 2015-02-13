#!/usr/bin/ruby

require 'csv'

schedRand = Random.new


def date_convert(sDate, sTime)
  months = {"January" => 1,
            "February" => 2,
            "March" => 3,
            "April" => 4,
            "May" => 5,
            "June" => 6,
            "July" => 7,
            "August" => 8,
            "September" => 9,
            "October" => 10,
            "November" => 11,
            "December" => 12}
  aDate = sDate.split(',')
  wday = aDate[0]
  mon = months[aDate[1].split(' ')[0]]
  day = aDate[1].split(' ')[1]
  year = aDate[2].to_i
  year += 2000 if year < 100 # if year represented as 2 digits
  aTime = sTime.split(' ')[0].split(':')
  hour = aTime[0].to_i
  min = aTime[1].to_i
  ampm = sTime.split(' ')[1]
  hour += 12 if ampm == "PM" and hour != 12
  #puts(year.to_s() +" " +mon.to_s() +" " +day.to_s() +" " +hour.to_s() +" " +min.to_s())
  return DateTime.new(year.to_i,mon.to_i,day.to_i,hour.to_i,min.to_i),hour,min,wday
end


########################################################
class Balance
  # Balance Rules:
  # Balance-Ruletype => Priority (1 = highest, 0 means rule does not apply)
  @location_balance= {"Carleton" => 4}
  @time_balance = {'share_6ams' => 1,
                   'share_630ams' => 2,
                   'share_7ams' => 3}

end

class Division
  def initialize()
    @division = {}
    read
    #dump_all
  end
  def read()
    File.open("division.cfg") do |file|
      while line = file.gets
        entry = line.split(":")
        @division[entry[0]] = [entry[1].to_i, entry[2].to_i, entry[3].to_i]
      end
    end
  end
  def total_teams(division)
    teams = @division[division][0] + @division[division][1] + @division[division][2] 
    puts("Total Teams for " +division +" is: " +teams.to_s)
  end
  def a_teams(division)
    teams = @division[division][0]
    puts("Total A Teams for " +division +" is: " +teams.to_s)
  end
  def b_teams(division)
    teams = @division[division][1]
    puts("Total B Teams for " +division +" is: " +teams.to_s)
  end
  def c_teams(division)
    teams = @division[division][2]
    puts("Total C Teams for " +division +" is: " +teams.to_s)
  end
  def dump_all
    @division.each_key do |division|
      puts(division)
      a_teams(division)
      b_teams(division)
      c_teams(division)
      total_teams(division)
    end
  end
end

class CsvSched
  def initialize(file)
    @file = file
    @sched = nil
    @hours = {}
    populate
    get_time_distributions
  end

  def populate
    read_and_validate
    #calculate_hours
    #print_hours
  end

  protected
  @@headings = ['Week', 'ScheduleDate', 'ScheduleType', 'GameNumber', 'StartTime', 'EndTime', 'Duration', 'DivisionName', 'HomeTeam', 'VisitorTeam']
  def read_and_validate()
    exit unless @sched == nil
    @sched = CSV.read(@file, headers:true)
    if @sched.headers() == nil
      puts("PROBLEM PARSING HEADERS FROM FILE")
      exit
    end
    @@headings.each do |heading|
      if !@sched.headers.include? heading
        puts("Heading '" +heading +"' does not exist") 
        exit
      end
    end
  end

  def get_time_distributions
    @sched.each do |icetime|
      next unless icetime['ScheduleDate']
      puts(icetime)
      # Insert proper datetime to be used later for sorting
      # Correct teamnames where they are "A1" instead of "PW_A1", etc
      date,hour,min,wday = date_convert(icetime['ScheduleDate'],icetime['StartTime'])
      #puts(date.to_s + " " + wday)
      icetime['DateTime'] = date
      icetime['Hour'] = hour
      icetime['Minute'] = min
      icetime['Weekday'] = wday
    end
  end
end

class Scheduler
  def initialize()
    @div = Division.new()
    #@sched = OldCsvSched.new("sched_from_andy_unavailRemoved.csv")
    @sched = CsvSched.new("test1.csv")
  end
end

schedule = Scheduler.new()
