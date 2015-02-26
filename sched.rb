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
    _read
  end

  def _read
    File.open("division.cfg") do |file|
      while line = file.gets
        entry = line.split(":")
        @division[entry[0]] = [entry[1].to_i, entry[2].to_i, entry[3].to_i, entry[4].chomp]
      end
    end
  end
  
  def get_all_teams(division)
    teams = []
    (1..count_a_teams(division)).each do |team_num| teams.push(prefix(division) + 'A' + team_num.to_s) end
    (1..count_b_teams(division)).each do |team_num| teams.push(prefix(division) + 'B' + team_num.to_s) end
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
  def initialize(test_file)
    @file = "peewee_sched.db"
    @div = Division.new()
    #@sched = OldCsvSched.new("sched_from_andy_unavailRemoved.csv")
    @csv_sched = CsvSched.new(test_file)
    @sched = @csv_sched.get_unallocated_ice
    @db = SQLite3::Database.new(@file)
  end

  def _create
    @db.execute("CREATE TABLE if not exists schedule (
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

    @db.execute("CREATE TABLE if not exists time_balance (
                 Team VARCHAR,
                 Time VARCHAR,
                 Priority 
                 Count INTEGER);")

    @db.execute("CREATE TABLE if not exists location_balance (
                 Team VARCHAR,
                 Location VARCHAR,
                 Count INTEGER);")

    @db.execute("CREATE TABLE if not exists solo_balance (
                 Team VARCHAR,
                 Count INTEGER);")
  end

  def _insert_new_icetimes
    insert_q = "INSERT INTO schedule VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)" 
    @sched.each do |icetime|
      @db.execute(insert_q, 
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

  def _print_final_allocations
    query = 'select count(hour) from schedule where hour = ? and (HomeTeam = ? or VisitorTeam = ?)' 
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
        @db.execute(query, hour, team, team) do |data| 
          #p data[0] if data[0] != 0
          sum+= data[0] if data[0] != 0
          team_sum[team] = 0 unless team_sum.has_key?(team)
          team_sum[team]+=data[0]
          count+=sum
          found = true if data[0] > 0
          temp_line << "|%3s" %data[0]
        end
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

  def _dump_balance
    (1..23).each do |hour|
      query = 'select count(hour) from schedule where hour is ?' 
      @db.execute(query, hour) do |data| puts(hour.to_s + ":" +data[0].to_s) end
    end
  end

  def _count_times_to_balance(time)
    query = 'select count(starttime) from schedule where starttime like ? and HomeTeam is NULL'
    @db.execute(query, time) do |data| return data[0] end
  end

  def _count_times_to_balance(time)
    query = 'select count(starttime) from schedule where starttime like ? and HomeTeam is NULL'
    @db.execute(query, time) do |data| return data[0] end
  end

  def _count_total_hours_in_week(week)
    query = 'select count(week) from schedule where week = ?'
    @db.execute(query, week) do |data| return data[0] end
  end

  def _get_teams_matching_hours_count(hour, count)
    query = 'select count(hour) from schedule where hour == ? and (hometeam = ? or visitorteam = ?);'
    team_counts = []
    @div.get_all_teams('Peewee').each do |team|
      @db.execute(query, hour, team, team).each do |data| 
        team_counts.push(team) if data[0] == count 
      end
    end
    #p team_counts unless team_counts == {}
    return team_counts 
  end

  def _find_preallocations(week)
    query = 'select weekday from schedule where week = ? and (hometeam = ? or visitorteam = ?);'
    week_preallocations = {}
    #@db.execute('update schedule set hometeam = "PW_B1",visitorteam = "PW_B1" where datetime = "2014-10-05T18:30:00+00:00";')
    #@db.execute('update schedule set hometeam = "PW_B1" where datetime = "2014-10-04T18:00:00+00:00";')
    @div.get_all_teams('Peewee').each do |team|
      week_preallocations[team] = [] 
      @db.execute(query, week, team, team).each do |data| 
        week_preallocations[team].push(data[0])
      end
    end
    #p week_preallocations unless week_preallocations == {}
    return week_preallocations
  end

  def _get_weeks()
    query = 'select distinct week from schedule order by datetime;'
    weeks = []
    @db.execute(query).each do |week| weeks.push(week[0]) end 
    return weeks
  end

  def _get_times_for_day(week, weekday)
    query = 'select location,hour,minute,datetime from schedule where week = ? and weekday = ? and hometeam is NULL'
    timeslots = []
    @db.execute(query,week,weekday).each do |data| timeslots.push(data) end
    return timeslots
  end

  def _update_times_for_day(hometeam, visitorteam, location, datetime)
    query = 'update schedule set hometeam = ?, visitorteam = ? where location = ? and datetime = ?'
    @db.execute(query,hometeam,visitorteam,location,datetime)
  end


  def generate
    _create
    _insert_new_icetimes
    time_600a = _count_times_to_balance("6:00:00 AM")# Count # of Time-Balance worthy icetimes
    time_630a = _count_times_to_balance("6:30:00 AM")
    time_7a = _count_times_to_balance("7:%AM")
    time_8a = _count_times_to_balance("8:%AM")
    time_8p = _count_times_to_balance("8:%PM")
    #_dump_balance
    _get_weeks.each do |week|

      #next unless week == "Sep 22 - 28" 
      #next unless week == "Nov 10 - 16" 
      #next unless week == "Dec 1 - 7" 
      
      puts "---------------", week
      future_allocations = _find_preallocations(week)
      allocations = _find_preallocations(week)
      #_get_teams_matching_hours_count(18, 0) 
      #_get_teams_matching_hours_count(18, 1) 
      #_get_teams_matching_hours_count(18, 2) 
      #_get_teams_matching_hours_count(18, 3) 
      ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].each do |weekday|
        # count allocations for the week
        # count allocations SO FAR this week
        # Any allocations from this weekday are not in the future
        @div.get_all_teams('Peewee').each do |team|
          future_allocations[team].delete(weekday)
        end
        
        teams_with_zero_days = []
        teams_with_one_day = []
        teams_with_future_days = []
        teams_with_one_future_day = []
        allocations.each do |team,days| teams_with_zero_days.push(team) if days.length == 0 && nil == days.find_index(weekday) end
        allocations.each do |team,days| teams_with_one_day.push(team) if days.length == 1 && nil == days.find_index(weekday) end
        future_allocations.each do |team,days| teams_with_future_days.push(team) if days.length == 1 && nil == days.find_index(weekday) end
        teams_with_one_day.each do |team| teams_with_one_future_day.push(team) if teams_with_future_days.find_index(team) end

        _get_times_for_day(week, weekday).each do |timeslot|
          p weekday
          puts "0:",teams_with_zero_days.to_s
          puts "F:",teams_with_one_future_day.to_s
          puts "1:",teams_with_one_day.to_s
          if teams_with_zero_days.length != 0 
            team1_array = teams_with_zero_days 
          elsif teams_with_one_future_day.length != 0 
            team1_array = teams_with_one_future_day
          else
            team1_array = teams_with_one_day
          end


          # MEDL PROBLEM
          # When scheduling on a day where the only candidates are those with FUTURE ice times already allocated
          # Need to select one from each day, if possible.


          #team1_array = teams_with_zero_days.length != 0 ? teams_with_zero_days : teams_with_one_day
          team1 = get_random_element(team1_array)
          team1_array.delete(team1)
          if teams_with_zero_days.length != 0 
            team2_array = teams_with_zero_days 
          elsif teams_with_one_future_day.length != 0 
            team2_array = teams_with_one_future_day
          else
            team2_array = teams_with_one_day
          end
          #team2_array = teams_with_zero_days.length != 0 ? teams_with_zero_days : teams_with_one_day
          team2 = get_random_element(team2_array)
          team2_array.delete(team2)
          _update_times_for_day(team1,team2,timeslot[0],timeslot[3])
          allocations[team1].push(weekday)
          allocations[team2].push(weekday)
        end
       #timeslots = _get_times_for_day(week, weekday).each 
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

#schedule = Scheduler.new("test1.csv")
schedule = Scheduler.new("sched_big_empty.csv")
schedule.generate
schedule._print_final_allocations
