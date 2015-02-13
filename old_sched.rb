#!/usr/bin/ruby

require 'csv'

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
    dump_all
  end
  def read()
    File.open("division_file") do |file|
      while line = file.gets
        entry = line.split(":")
        @division[entry[0]] = [entry[1].to_i, entry[2].to_i, entry[3].to_i]
      end
    end
    puts("Done reading division file")
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
      # Insert proper datetime to be used later for sorting
      # Correct teamnames where they are "A1" instead of "PW_A1", etc
      date,hour,min,wday = date_convert(icetime['ScheduleDate'],icetime['StartTime'])
      puts(date.to_s + " " + wday)
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






=begin
class DateConvert
  @@months = {"January" => 1,
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
  def initialize(sDate, sTime)
    @sDate = sDate
    @sTime = sTime
  end

  def convert()
    aDate = @sDate.split(',')
    wday = aDate[0]
    mon = @@months[aDate[1].split(' ')[0]]
    day = aDate[1].split(' ')[1]
    year = aDate[2].to_i
    year += 2000 if year < 100 # if year represented as 2 digits
    aTime = @sTime.split(' ')[0].split(':')
    hour = aTime[0].to_i
    min = aTime[1].to_i
    ampm = @sTime.split(' ')[1]
    hour += 12 if ampm == "PM" and hour != 12
    #puts(year.to_s() +" " +mon.to_s() +" " +day.to_s() +" " +hour.to_s() +" " +min.to_s())
    return DateTime.new(year.to_i,mon.to_i,day.to_i,hour.to_i,min.to_i),hour,min
  end
end

class OldCsvSched
  def initialize(file)
    @file = file
    @sched = nil
    @hours = {}
    populate
  end

  def populate
    read_and_validate
    #calculate_hours
    #print_hours
  end

  protected
  @@headings = ['Week', 'ScheduleDate', 'ScheduleType', 'GameNumber', 'StartTime', 'EndTime', 'Duration', 'DivisionName', 'HomeTeam', 'VisitorTeam']
  @@teams = ['PW_A1','PW_A2','PW_A3','PW_A4','PW_A5','PW_A6','PW_A7','PW_A8','PW_A9','PW_A10','PW_A11','PW_A12',
             'PW_B1','PW_B2','PW_B3','PW_B4','PW_B5','PW_B6','PW_B7','PW_B8','PW_B9','PW_B10','PW_B11','PW_B12',
             'PW_C1','PW_C2','PW_C3','PW_C4','PW_C5','PW_C6','PW_C7','PW_C8','PW_C9','PW_C10','PW_C11','PW_C12']
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
    @sched.each do |icetime|
      next unless icetime['ScheduleDate']
      # Insert proper datetime to be used later for sorting
      # Correct teamnames where they are "A1" instead of "PW_A1", etc
      date,hour,min,wday = date_convert(icetime['ScheduleDate'],icetime['StartTime'])
      puts(date)
      icetime['DateTime'] = date
      icetime['Hour'] = hour
      icetime['Minute'] = min
      icetime['Weekday'] = wday
      @@teams.each do |team|
        icetime['HomeTeam'] = 'PW_'+team if icetime['HomeTeam'] == team 
        icetime['VisitorTeam'] = 'PW_'+team if icetime['VisitorTeam'] == team 
      end
    end
  end

  def calculate_hours()
    @sched.each do |icetime|
      next if icetime['ScheduleType'] == 'unavailable'
      next if icetime['ScheduleType'] == nil 
      start_time = icetime['StartTime']
      home_team = icetime['HomeTeam']
      visitor_team = icetime['VisitorTeam']
      hour = icetime['Hour']
      minute = icetime['Minute']
      @hours[hour] = {} unless @hours.key?(hour)
      @hours[hour][minute] = {} unless @hours[hour].key?(minute)
      unless home_team.start_with?('Nepean')
        @hours[hour][minute][home_team] = 0 unless @hours[hour][minute].key?(home_team) 
        @hours[hour][minute][home_team] += 1 
      end
      unless visitor_team.start_with?('Nepean')
        @hours[hour][minute][visitor_team] = 0 unless @hours[hour][minute].key?(visitor_team) 
        @hours[hour][minute][visitor_team] += 1 
      end
      #puts(icetime['DateTime'])
      #puts("#{icetime['Hour']}:#{icetime['Minute']}")
    end
  end
  def calculate_hours_old()
    @sched.each do |icetime|
      next if icetime['ScheduleType'] == 'unavailable'
      next if icetime['ScheduleType'] == nil 
      start_time = icetime['StartTime']
      home_team = icetime['HomeTeam']
      visitor_team = icetime['VisitorTeam']
      @hours[start_time] = {} unless @hours.key?(start_time)
      unless home_team.start_with?('Nepean')
        @hours[start_time][home_team] = 0 unless @hours[start_time].key?(home_team) 
        @hours[start_time][home_team] += 1 
      end
      unless visitor_team.start_with?('Nepean')
        @hours[start_time][visitor_team] = 0 unless @hours[start_time].key?(visitor_team) 
        @hours[start_time][visitor_team] += 1 
      end
      puts(icetime['DateTime'])
      puts(@hours.keys)
    end
  end

  def print_hours()
    if @hours == {}
      puts("Hey, can't count hours yet as we haven't read them")
      exit
    end
    tmp_hours = deep_copy(@hours)
    puts(tmp_hours.keys)
    @hours = {}
    _hour = 1
    while _hour < 25
      unless tmp_hours.key?(_hour)
        puts(tmp_hours[_hour].keys)
        _minute = 1
        while _minute < 61
          unless tmp_hours[_hour].key?(_minute)
            @@teams.each do |team|
              unless tmp_hours[_hour][_minute].key?(team)
                @hours[_hour][_minute][team] = tmp_hours[_hour][_minute][team] 
              end
            end
          end
          _minute += 1
        end
      end
      _hour += 1
    end


    #@hours.keys.sort do |hour|
      #puts(hour.to_s +" " + @hours[hour.to_s])
    #end
    @hours.each do |time, teams|
      sleep(1)
      puts("#{time}  #{teams.to_s}")
    end
  end
end

def generate_schedule()
  sched1 = CsvSched.new("sched_from_andy_unavailRemoved.csv")
  puts("MEDL at the end")
end
generate_schedule

=end
