#!/usr/bin/ruby

require 'csv'
require 'sqlite3'

$rand_obj= Random.new
def get_random_element(array)
  return array[$rand_obj.rand(array.length)]
end

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
  hour += 12 if ampm == "PM" && hour != 12
  #puts(year.to_s() +" " +mon.to_s() +" " +day.to_s() +" " +hour.to_s() +" " +min.to_s())
  return DateTime.new(year.to_i,mon.to_i,day.to_i,hour.to_i,min.to_i),hour,min,wday
end


########################################################
class Balance
  # Balance Rules:
  # Balance-Ruletype => Priority (1 = highest, 0 means rule does not apply)
  @location_balance= ["Carleton",]
  @time_balance = {'6:00:00 AM' => 1,
                   '6:30:00 AM' => 2,
                   '7:%AM' => 3,
                   '8:%AM' => 4}
end

class Division
  # Expected format: division_string:#A:#B:#C:schedule_prefix
  def initialize
    @division = {}
    read
    dump_all
  end
  def read
    File.open("division.cfg") do |file|
      while line = file.gets
        entry = line.split(":")
        @division[entry[0]] = [entry[1].to_i, entry[2].to_i, entry[3].to_i, entry[4].chomp]
      end
    end
  end
  def all_teams(division)
    teams = []
    (1..count_a_teams(division)).each do |team_num| teams.push(prefix(division) + team_num.to_s) end
    return teams
  end

    
  def count_total_teams(division)
    return count_a_teams(division) + count_b_teams(division) + count_c_teams(division)
  end
  def count_a_teams(division)
    return @division[division][0]
  end
  def count_b_teams(division)
    return @division[division][1]
  end
  def count_c_teams(division)
    return @division[division][2]
  end
  def prefix(division)
    return @division[division][3]
  end

  def dump_all
    @division.each_key do |division|
      puts(division)
      puts("Total A Teams for " +division +" is: " +count_a_teams(division).to_s)
      puts("Total B Teams for " +division +" is: " +count_b_teams(division).to_s)
      puts("Total C Teams for " +division +" is: " +count_c_teams(division).to_s)
      puts("Total Teams for " +division +" is: " +count_total_teams(division).to_s)
      all_teams(division)
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

  def get_unallocated_ice
    #@sched.each do |icetime|
    #  g = Generator.new(icetime)
    #  
    return @sched
  end

  protected
  @@headings = ['Week', 'ScheduleDate', 'ScheduleType', 'GameNumber', 'StartTime', 'EndTime', 'Duration', 'DivisionName', 'HomeTeam', 'VisitorTeam']
  def read_and_validate
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
      #puts(icetime)
      # Insert proper datetime to be used later for sorting
      # Correct teamnames where they are "A1" instead of "PW_A1", etc
      date,hour,min,wday = date_convert(icetime['ScheduleDate'],icetime['StartTime'])
      #puts(date.to_s + " " + wday)
      #puts(hour.to_s + ":" + min.to_s)
      
      icetime['DateTime'] = date
      icetime['Hour'] = hour
      icetime['Minute'] = min
      icetime['Weekday'] = wday
    end
  end

end



class Scheduler
  def initialize
    @file = "peewee_sched.db"
    @div = Division.new()
    #@sched = OldCsvSched.new("sched_from_andy_unavailRemoved.csv")
    @csv_sched = CsvSched.new("test1.csv")
    @sched = @csv_sched.get_unallocated_ice
  end

  def _create
    return if File.exists?(@file)
    SQLite3::Database.new(@file) do |db|
      db.execute("CREATE TABLE schedule (
                  Week VARCHAR,
                  ScheduleDate VARCHAR,
                  Location VARCHAR,
                  ScheduleType VARCHAR,
                  GameNumber VARCHAR,
                  StartTime VARCHAR,
                  EndTime VARCHAR,
                  Duration INTEGER,
                  DivisionName VARCHAR,
                  HomeTeam VARCHAR,
                  VisitorTeam VARCHAR,
                  DateTime, VARCHAR, 
                  Weekday VARCHAR,
                  Hour INTEGER,
                  Minute INTEGER);")

      db.execute("CREATE TABLE time_balance (
                  Team VARCHAR,
                  Time VARCHAR,
                  Priority 
                  Count INTEGER);")

      db.execute("CREATE TABLE location_balance (
                  Team VARCHAR,
                  Location VARCHAR,
                  Count INTEGER);")

      db.execute("CREATE TABLE solo_balance (
                  Team VARCHAR,
                  Count INTEGER);")
    end
  end

  def _insert_new_icetimes
    SQLite3::Database.new(@file) do |db|
      insert_q = "INSERT INTO schedule VALUES (NULL,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)" 
      @sched.each do |icetime|
        db.execute(insert_q, 
                   icetime['Week'], 
                   icetime['ScheduleDate'],
                   icetime['Location'], 
                   icetime['ScheduleType'], 
                   icetime['GameNumber'], 
                   icetime['StartTime'], 
                   icetime['EndTime'], 
                   icetime['Duration'].to_i, 
                   icetime['DivisionName'], 
                   icetime['HomeTeam'], 
                   icetime['VisitorTeam'], 
                   icetime['DateTime'].to_s, 
                   icetime['Weekday'], 
                   icetime['Hour'], 
                   icetime['Minute'])
      end
    end
  end

  def _dump_all
    SQLite3::Database.new(@file) do |db|
    end
  end

  def _dump_balance
    SQLite3::Database.new(@file) do |db|
      (1..23).each do |hour|
        query = 'select count(hour) from schedule where hour is ?' 
        db.execute(query, hour) do |data| puts(hour.to_s + ":" +data[0].to_s) end
      end
    end
  end

  def _count_times_to_balance(time)
    SQLite3::Database.new(@file) do |db|
      query = 'select count(starttime) from schedule where starttime like ? and HomeTeam is NULL'
      db.execute(query, time) do |data| return data[0] end
    end
  end

  def _count_times_in_week(week)
    SQLite3::Database.new(@file) do |db|
      query = 'select count(week) from schedule where week = ?'
      db.execute(query, week) do |data| return data[0] end
    end
  end

  def _find_team_counts(week, weekday, time)
    SQLite3::Database.new(@file) do |db|
      query = 'select count(starttime) from schedule where starttime like ? and HomeTeam is NULL'
      db.execute(query, time) do |data| return data[0] end
    end
  end


  def generate
    _create
    _insert_new_icetimes
    time_600a = _count_times_to_balance("6:00:00 AM")# Count # of Time-Balance worthy icetimes
    time_630a = _count_times_to_balance("6:30:00 AM")
    time_7a = _count_times_to_balance("7:%AM")
    time_8a = _count_times_to_balance("8:%AM")
    time_8p = _count_times_to_balance("8:%PM")
    _dump_balance
    
    # Count # of location-balance worthy icetimes
    # Count # of solo ice times
    # Count # of Other-Tier practie ice times
    # Count every other TIME also.
    # PLAN the balancing for the future weeks, based on previous allocations
    #      and the current unallocated counts, taking into account rules, and
    #      constraints.
    # PER WEEK:
    #   GET # of ice times total
    #   GET # of teams total in the division
    #   if DIVISION has any ODD# team tiers, decide if special scheduling for weekday ice for them is needed
    #
  end
end

schedule = Scheduler.new()
schedule.generate
