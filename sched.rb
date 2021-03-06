#!/usr/bin/ruby
# TO RUN:
# rm peewee_sched.db;./sched.rb
#
# ASSUMPTIONS: 
# 1. Only one tier (A/B/C) per division could have an odd# of teams, never two teams
#

require 'csv'
require 'sqlite3'
require 'test/unit'

$rand_obj= Random.new
def get_random_element(array)
  return array[$rand_obj.rand(array.length)]
end
def get_random_intersection_element(array1, array2)
  p array1.class
  p array2.class
  array = array1 & array2
  x = "DUDE array"
  x << array.to_s
  puts x
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
  def initialize
    @times = {}
    @locations = ['CU']
    _read
  end

  def _read
    File.open("time_balance.cfg") do |file|
      while line = file.gets
        entry = line.split(",")
        @times[entry[0]] = []
        entry.each_index do |idx|
          next if idx == 0
          @times[entry[0]].push(entry[idx].chomp)
        end
      end
    end
    #puts "---------"
    #puts @times.keys
    #puts "---------"
    @times.each do |div,div_times|
      div_times.each do |time|
        x = ""
        x << div << ":" << time 
        #puts x
      end
    end
  end

  def get_bad_times(division)
    return @times[division]
  end
end

class Constraints
  def initialize
    # @constraints[division][team][day][
    @constraints = {}
  end

  def insert(division, team, start_day, end_day=start_day, start_hour=0, end_hour=24)
  end

  def get_teams_with_constraints(division, day) 
  end
end

class Division
  # Expected format: division_string:#A:#B:#C:schedule_prefix
  def initialize
    @division = {}
    _read
  end

  def _read
    File.open("division.cfg") do |file|
      while line = file.gets
        entry = line.split(",")
        @division[entry[0]] = [entry[1].to_i, entry[2].to_i, entry[3].to_i, entry[4].chomp, entry[5]]
      end
    end
    puts(@division['Peewee'][4])
  end
  
  def get_all_teams(division)
    return get_a_teams(division) + get_b_teams(division) + get_c_teams(division)
  end
  def get_a_teams(division)
    teams = []
    (1..count_a_teams(division)).each do |team_num| teams.push(prefix(division) + 'A' + team_num.to_s) end
    return teams
  end
  def get_b_teams(division)
    teams = []
    (1..count_b_teams(division)).each do |team_num| teams.push(prefix(division) + 'B' + team_num.to_s) end
    return teams
  end
  def get_c_teams(division)
    teams = []
    (1..count_c_teams(division)).each do |team_num| teams.push(prefix(division) + 'C' + team_num.to_s) end
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
  def has_odd_number_of_teams(division)
    return count_total_teams(division) % 2
  end
  def has_odd_number_of_a_teams(division)
    return count_a_teams(division) % 2
  end
  def has_odd_number_of_b_teams(division)
    return count_b_teams(division) % 2
  end
  def has_odd_number_of_c_teams(division)
    return count_c_teams(division) % 2
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

class SchedDb
  def initialize(test_file)
    # TODO this shouldn't be here, need to fix up some functions
    @div = Division.new()
    @file = "peewee_sched.db"
    #@sched = OldCsvSched.new("sched_from_andy_unavailRemoved.csv")
    @DB = SQLite3::Database.new(@file)
    _create
  end

  def _create
    @DB.execute("CREATE TABLE if not exists schedule (
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
                 DateTime VARCHAR, 
                 Weekday VARCHAR,
                 Hour INTEGER,
                 Minute INTEGER);")

    @DB.execute("CREATE TABLE if not exists constraints (
                 Week VARCHAR,
                 Division VARCHAR,
                 Team VARCHAR,
                 StartDay VARCHAR,
                 EndDay VARCHAR, 
                 StartHour INTEGER,
                 EndHour INTEGER,
                 Reason VARCHAR);")

    @DB.execute("CREATE TABLE if not exists location_balance (
                 Team VARCHAR,
                 Location VARCHAR,
                 Count INTEGER);")

    @DB.execute("CREATE TABLE if not exists solo_balance (
                 Team VARCHAR,
                 Count INTEGER);")
  end

  def insert_constraint(division, team, week, start_day, end_day, start_hour, end_hour)
    insert_q = "INSERT INTO constraint VALUES (?,?,?,?,?,?,?)" 
    @DB.execute(insert_q,
                division,
                week,
                start_day,
                end_day, 
                start_hour,
                end_hour)
  end

  def get_all_constraints(division, week)
  end

  def insert_new_icetimes(sched)
    insert_q = "INSERT INTO schedule VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)" 
    sched.each do |icetime|
      @DB.execute(insert_q, 
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

  def dump_balance
    (1..23).each do |hour|
      query = 'select count(hour) from schedule where hour is ?' 
      @DB.execute(query, hour) do |data| puts(hour.to_s + ":" +data[0].to_s) end
    end
  end

  def count_hours_for_team(hour, team)
    query = 'select count(hour) from schedule where hour = ? AND (HomeTeam = ? or VisitorTeam = ?)' 
    @DB.execute(query, hour, team, team) do |data| return data[0] end
  end

  def count_hours_to_schedule(week, weekday)
    query = 'select count(weekday) from schedule where week = ? AND weekday = ? and HomeTeam is NULL'
    homeice = 0
    visitorice = 0
    @DB.execute(query, week, weekday) do |data| homeice = data[0] end
    query = 'select count(weekday) from schedule where week = ? AND weekday = ? and VisitorTeam is NULL'
    @DB.execute(query, week, weekday) do |data| visitorice = data[0] end
    return homeice + visitorice
  end

  def get_teams_allocated_this_day(week, weekday)
    query = 'select hometeam,visitorteam from schedule where week = ? and weekday = ? and (hometeam = ? or visitorteam = ?);'
    teams_allocated = []
    @div.get_all_teams('Peewee').each do |team|
      @DB.execute(query, week, weekday, team, team).each do |data| 
        teams_allocated.push(data[0])
        teams_allocated.push(data[1])
      end
    end
    return teams_allocated.uniq
  end

  def count_teams_to_schedule(week, weekday)
    query = 'select count(weekday) from schedule where week = ? AND weekday = ? and HomeTeam is NULL'
    @DB.execute(query, week, weekday) do |data| return data[0] end
  end

  def count_times_to_balance(time)
    query = 'select count(starttime) from schedule where starttime like ? and HomeTeam is NULL'
    @DB.execute(query, time) do |data| return data[0] end
  end

  def count_total_hours_in_week(week)
    query = 'select count(week) from schedule where week = ?'
    @DB.execute(query, week) do |data| return data[0] end
  end

  def get_teams_matching_hours_count(hour, count)
    query = 'select count(hour) from schedule where hour == ? and (hometeam = ? or visitorteam = ?);'
    team_counts = []
    @div.get_all_teams('Peewee').each do |team|
      @DB.execute(query, hour, team, team).each do |data| 
        team_counts.push(team) if data[0] == count 
      end
    end
    #p team_counts unless team_counts == {}
    return team_counts 
  end

  def find_preallocations(week)
    query = 'select weekday from schedule where week = ? and (hometeam = ? or visitorteam = ?);'
    week_preallocations = {}
    #@DB.execute('update schedule set hometeam = "PW_B1",visitorteam = "PW_B1" where datetime = "2014-10-05T18:30:00+00:00";')
    #@DB.execute('update schedule set hometeam = "PW_B1" where datetime = "2014-10-04T18:00:00+00:00";')
    @div.get_all_teams('Peewee').each do |team|
      week_preallocations[team] = [] 
      @DB.execute(query, week, team, team).each do |data| 
        week_preallocations[team].push(data[0])
      end
    end
    #p week_preallocations unless week_preallocations == {}
    return week_preallocations
  end

  def get_weeks()
    query = 'select distinct week from schedule order by datetime;'
    weeks = []
    @DB.execute(query).each do |week| weeks.push(week[0]) end 
    return weeks
  end

  def get_times_for_day(week, weekday)
    query = 'select location,starttime,datetime from schedule where week = ? and weekday = ? and hometeam is NULL'
    timeslots = []
    @DB.execute(query,week,weekday).each do |data| timeslots.push(data) end
    return timeslots
  end

  def get_bad_time_for_day(week, weekday, starttime)
    query = 'select location,starttime,datetime from schedule where week = ? and weekday = ? and hometeam is NULL and starttime = ?'
    timeslots = []
    @DB.execute(query,week,weekday,starttime).each do |data| timeslots.push(data) end
    return timeslots
  end

  def update_times_for_day(hometeam, visitorteam, location, datetime)
    query = 'update schedule set hometeam = ?, visitorteam = ? where location = ? and datetime = ?'
    @DB.execute(query,hometeam,visitorteam,location,datetime)
  end
end

class TimeAllocations
  def initialize(week, db)
    @week = week
    @db = db
    @div = Division.new()
    @future_allocations = @db.find_preallocations(week)
    @allocations = @db.find_preallocations(week)
  end

  def allocate_two_teams(weekday,starttime)
    # count allocations for the week
    # count allocations SO FAR this week
    # Any allocations from this weekday are not in the future
    @div.get_all_teams('Peewee').each do |team|
      @future_allocations[team].delete(weekday)
    end
    
    teams_with_zero_days = []
    teams_with_one_day = []
    teams_with_future_days = []
    teams_with_one_future_day = []
    @allocations.each do |team,days| teams_with_zero_days.push(team) if days.length == 0 && nil == days.find_index(weekday) end
    @allocations.each do |team,days| teams_with_one_day.push(team) if days.length == 1 && nil == days.find_index(weekday) end
    @future_allocations.each do |team,days| teams_with_future_days.push(team) if days.length == 1 && nil == days.find_index(weekday) end
    teams_with_one_day.each do |team| teams_with_one_future_day.push(team) if teams_with_future_days.find_index(team) end

    #p weekday
    #x = "0:";x << teams_with_zero_days.to_s
    #puts x unless teams_with_zero_days.length == 0
    #x = "F:";x << teams_with_one_future_day.to_s
    #puts x unless teams_with_one_future_day.length == 0
    #x = "1:";x << teams_with_one_day.to_s
    #puts x unless teams_with_one_day.length == 0

    day_filter = []
    if teams_with_zero_days.length != 0 
      team1_array = teams_with_zero_days 
    elsif teams_with_one_future_day.length != 0 
      team1_array = teams_with_one_future_day 
    else
      team1_array = teams_with_one_day
    end
    team1 = get_random_element(team1_array)
    team1_array.delete(team1)


    # TODO PROBLEM????  (or solved because of scheduling in reverse chronological order?)
    # When scheduling on a day where the only candidates are those with FUTURE ice times already allocated
    # Need to select one from each day, if possible.

    day_filter = []
    if teams_with_zero_days.length != 0 
      team2_array = teams_with_zero_days 
    elsif teams_with_one_future_day.length != 0 
      team2_array = teams_with_one_future_day 
    else
      team2_array = teams_with_one_day
    end
    team2 = get_random_element(team2_array)
    team2_array.delete(team2)

    x = "------ Scheduling: "
    x << team1 << " and " << team2
    puts x
    @allocations[team1].push(weekday)
    @allocations[team2].push(weekday)
    return team1,team2
  end
end

class Scheduler
  def initialize(test_file)
    @div = Division.new()
    @csv_sched = CsvSched.new(test_file)
    @sched = @csv_sched.get_unallocated_ice
    @db = SchedDb.new(test_file)
  end

  # TODO this needs to be rearchitected
  def print_final_allocations
    teams = @div.get_all_teams('Peewee')
    line = "____"
    teams.each do |team| line << "|%3s" %team[-3..-1] || team end
    line << "|TOT|"
    count = 0
    team_sum = {}
    (1..23).each do |hour|
      sum = 0
      temp_line = "\n|%3s" %hour
      found = false
      teams.each do |team|
        data = @db.count_hours_for_team(hour,team)
        #p data[0] if data[0] != 0
        sum+= data if data != 0
        team_sum[team] = 0 unless team_sum.has_key?(team)
        team_sum[team]+=data
        count+=sum
        found = true if data > 0
        temp_line << "|%3s" %data
      end
      line << temp_line << "|%3s|" %sum if found
    end
    line << "\n----"
    teams.each do |team| line << "----" end
    line << "----"
    line << "\n|TOT"
    teams.each do |team|
      line << "|%3s" %team_sum[team]
    end
    p count
    puts line
  end

  def print_weekly_allocations
    @db.get_weeks.each do |week|
      x = "----WEEK: " << week
      puts x
      allocations = @db.find_preallocations(week)
      allocations.each do |team,days| x = ""; x << team << ": " << days.length.to_s; puts x end
    end
  end

  def _alloc_and_update(timeslot, allocations, weekday)
    location = timeslot[0]
    starttime = timeslot[1]
    datetime = timeslot[2]
    team1,team2 = allocations.allocate_two_teams(weekday, starttime)
    x = "%s %s %s %s %s" %[starttime ,weekday ,team1 ,team2 ,timeslot.to_s]
    puts x
    @db.update_times_for_day(team1,team2,location,datetime)
  end

  def _count_hours_to_schedule(week, weekday)
    return @db.count_hours_to_schedule(week,weekday)
  end
  def _count_teams_to_schedule(week, weekday, division, teams_scheduled)
    # TODO MEDL enhance with constraints, or handle constraints elsewhere?
    total_teams = @div.count_total_teams(division)
    return total_teams - teams_scheduled.length
  end
  def _get_teams_scheduled(week, weekday, division)
    teams_scheduled = @db.get_teams_allocated_this_day(week, weekday)
    return teams_scheduled
  end

  def schedule_teams_with_constraints(week)
  end

  def generate(division)
    time_balance = Balance.new
    bad_times = time_balance.get_bad_times(division)
    @db.insert_new_icetimes(@sched)
    #time_600a = @db.count_times_to_balance("6:00:00 AM")# Count # of Time-Balance worthy icetimes
    #time_630a = @db.count_times_to_balance("6:30:00 AM")
    #time_7a = @db.count_times_to_balance("7:%AM")
    #time_8a = @db.count_times_to_balance("8:%AM")
    #time_8p = @db.count_times_to_balance("8:%PM")
    @db.get_weeks.each do |week|
      allocations = TimeAllocations.new(week, @db)

      schedule_teams_with_constraints(week)
      #next unless week == "Dec 1 - 7" 
      
      puts "---------------", week
      #_get_teams_matching_hours_count(18, 0) 
      #_get_teams_matching_hours_count(18, 1) 
      #_get_teams_matching_hours_count(18, 2) 
      #_get_teams_matching_hours_count(18, 3) 
      
      odd_num_teams = @div.has_odd_number_of_teams(division)
      # TODO we should do this always...
      if odd_num_teams 
        total_teams = @div.count_total_teams(division)
        odd_a_teams = @div.has_odd_number_of_a_teams(division)
        odd_b_teams = @div.has_odd_number_of_b_teams(division)
        odd_c_teams = @div.has_odd_number_of_c_teams(division)
        sunday_spots = _count_hours_to_schedule(week, 'Sunday')
        saturday_spots = _count_hours_to_schedule(week, 'Saturday')
        teams_scheduled_sunday = _get_teams_scheduled(week, 'Sunday', division)
        teams_scheduled_saturday = _get_teams_scheduled(week, 'Saturday', division)
        sunday_teams = _count_teams_to_schedule(week, 'Sunday', division, teams_scheduled_sunday)
        saturday_teams = _count_teams_to_schedule(week, 'Saturday', division, teams_scheduled_saturday )
        puts "" << odd_num_teams.to_s << ":" << odd_a_teams.to_s << ":" << odd_b_teams.to_s << ":" << odd_c_teams.to_s << ":" 
        if (saturday_teams > saturday_spots) || (sunday_teams > sunday_spots)
          if odd_a_teams
            odd_teams = @div.get_a_teams(division)
          elsif odd_b_teams
            odd_teams = @div.get_b_teams(division)
          else 
            odd_teams = @div.get_c_teams(division)
          end
          preallocations = @db.find_preallocations(week)
             
          # 1. Find out if a/b/c
          # 2. Find one odd team to make miss a Sunday
          # 3. Add constraint for that team for Saturday
          # 4. Find one other odd team to make miss a Saturday.
          # 5. Add constraint for that team for Sunday.
          # 6. Schedule those teams for one weekday slot.
        else
          puts("WHAT NO WORK TO do - " << week << " " << saturday_teams.to_s << ":" << saturday_spots.to_s << ":" << sunday_teams.to_s << ":" << sunday_spots.to_s )
        end
      end
      ['Sunday','Saturday','Friday','Thursday','Wednesday','Tuesday','Monday'].each do |weekday|
        bad_times.each do |bad_starttime|
          #puts "MEDL1.0 - " << " : " << weekday << " : " << bad_starttime.to_s  
          @db.get_bad_time_for_day(week, weekday, bad_starttime) do |timeslot|
            #puts "MEDL1 - " << timeslot.to_s << " : " << weekday << " : "  
            _alloc_and_update(timeslot, allocations, weekday)
          end
        end
        
        @db.get_times_for_day(week, weekday).each do |timeslot|
          _alloc_and_update(timeslot, allocations, weekday)
        end
       #p timeslots
       #p timeslots.class
       #timeslots.each do |timeslot|
       #   p timeslot
       # end
      end
    end

    # generated_one_week_at_a_time
    # - For each team, per week, query preallocated ice (manually by convenor) 
    #   - get back the day it is on, store in array to get a COUNT of days allocated.
    
    # Count # of location-balance worthy icetimes
    # Count # of solo ice times
    # Count # day-of-week ice
    # Count # weekday ice
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

schedule = Scheduler.new("test1.csv")
#schedule = Scheduler.new("sched_big_empty.csv")
schedule.generate('Peewee')
#schedule.print_weekly_allocations
schedule.print_final_allocations



class TestConstraints < Test::Unit::TestCase
  def test_insert
    pass
  end
end


