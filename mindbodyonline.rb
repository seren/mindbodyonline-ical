require 'nokogiri'
require 'mechanize'
require 'icalendar'
require 'sinatra'


# Converts "1 hour & 15 minutes" and "2 hours" style time into seconds
def convert_string_to_seconds(str)
  # #"1 hour & 15 minutes""
  # duration_string = str.gsub(/hours?/,'3600').gsub(/minutes?/,'60')
  # #"1 3600 & 15 60"
  # duration_string_array = duration_string.gsub(/[^\w]/," ").split(" ")
  # #["1", "3600", "15", "60"]
  # duration_int_array = duration_string_array.map{ |x| x.to_i }
  # #[1, 3600, 15, 60]
  # duration_int_pairs = duration_int_array.each_slice(2).to_a
  # #[[1, 3600], [15, 60]]
  # duration_seconds = duration_int_pairs.reduce(0) { |sum,x| sum + (x[0] * x[1]) }
  # #4500
  # return duration_seconds
  return str.gsub(/hours?/,'3600').gsub(/minutes?/,'60').gsub(/[^\w]/," ").split(" ").map{ |x| x.to_i }.each_slice(2).to_a.reduce(0) { |sum,x| sum + (x[0] * x[1]) }
end


# Config sinatra port
set :port, 19494
before { content_type 'text/calendar' }

# Give univited visitors a blank page
get '/' do

end

#get '/robots.txt' do
#  User-agent:*
#  Disallow: /yogatimes
#end


# The actual URI to use
get '/mindbodyonline' do

  # Get the studio "id" parameter.
  begin
    studio_id = params["studio_id"].gsub(/[\D]/,'')
  rescue
    "Bad"
  end

  # 
  if studio_id.nil? || studio_id.empty? || studio_id != "4095"
    "Nope"
  else

#  redis = Redis.new
#  if redis[studio_id]
#    send_file redis[studio_id], :type => 'text/calendar'
#  else
  cache_dir = ("/tmp/cache")
  cache_file = File.join(cache_dir,studio_id)
  Dir.mkdir(cache_dir) unless File.exists?(cache_dir)
  if File.exist?(cache_file) && (File.mtime(cache_file) > (Time.now - 3600*6))
    puts "cache hit"
    File.read(cache_file)
    #send_file cache_file, :type => 'text/calendar'
  else

  # The urls we need to hit
  url_base = "https://clients.mindbodyonline.com"
  url1 = url_base + "/ws.asp?studioid=" + studio_id + "&stype=-7&sView=week&sLoc=0"
  url2 = url_base + "/ASP/home.asp?studioid=" + studio_id

  # Pretend to be Safari and grab the frame url with the schedule table
  a = Mechanize.new
  a.user_agent_alias = 'Mac Safari'
  a.get(url1)
  page = a.get(url2)
  frame_url = page.frame_with(:name => "mainFrame").href
  html = a.get(url_base+"/ASP/"+frame_url).body

  # We could probably do our processing with mechanize as well  
  data = Nokogiri::HTML(html)
  header = data.css('tr[class="floatingHeaderRow"]')
  total_columns = data.css('tr[class="floatingHeaderRow"] th').count
  all_rows = data.css('table#classSchedule-mainTable tr')

  # Get the column titles
  column_names = header.css('th').map { |e| e.attribute('id').value }


  # We have to initialize day_text
  day_text = ""
  @all_yoga_classes = {}

  # Run through the rows, grabbing the day info and the class info
  all_rows.each do |r|
    # If there's only one td with the header class, it's a day row
    if r.css('td[class="header"]').count == 1
      day_text = r.css('td[class="header"]').text
    else
      # Do a sanity check to make sure this row has the same number of columns as our header row
      if r.css('td').count == total_columns
        # Get an array of text from the cells
        values = r.css('td').map { |v| v.text }
        # Merge the cell text into a hash with the column headers as keys
        yoga_class = Hash[*column_names.zip(values).flatten]
        # Get rid of weird characters that are in the cell text
        yoga_class.each { |k,v| v.gsub!(/[^a-zA-Z0-9:;\-_#\@\(\)]/," ") }
        yoga_class.each { |k,v| v.strip! }
        yoga_class['trainer'] = trainer = yoga_class["trainerNameHeader"]
        yoga_class['class_name'] = class_name = yoga_class["classNameHeader"]
        yoga_class['location'] = location = yoga_class["locationNameHeader"]
        yoga_class['room'] = room = yoga_class["resourceNameHeader"]
        yoga_class['start_time'] = start_time = yoga_class["startTimeHeader"]
        # Combine the date and class time
        yoga_class['start_date'] = start_date = Time.parse(day_text+" "+start_time)
        # Add the duration seconds to get the end time
        yoga_class["end_date"] = start_date + convert_string_to_seconds(yoga_class["durationHeader"])
        # Make a uid that won't change unless the class info changes
        uid = start_date.strftime("%Y%m%dT%H%M%S")+class_name.gsub(/[^\w]/,'')+trainer.gsub(/[^\w]/,'')
        yoga_class["description"] = "#{class_name} @ #{start_time},#{trainer.empty? ? "" : " with "+trainer}#{location.empty? ? "" : " at the "+location+" location"}#{room.empty? ? "" : " in the "+room}. #{url2}"
        # Add the class hash to the aggregate hash
        @all_yoga_classes[uid] = yoga_class
      end
    end
  end


  # Create a calendar to contain all the class eventesAdd ical objects
  cal = Icalendar::Calendar.new

  # Set the timezone to Pacific
  cal.timezone do
      timezone_id             "America/Los_Angeles"
      x_lic_location "America/Los_Angeles"
      daylight do
          timezone_offset_from  "-0800"
          timezone_offset_to    "-0700"
          timezone_name         "PDT"
          dtstart               "19700308TO20000"
          add_recurrence_rule   "FREQ=YEARLY;BYMONTH=3;BYDAY=2SU"
      end
      standard do
          timezone_offset_from  "-0700"
          timezone_offset_to    "-0800"
          timezone_name         "PST"
          dtstart               "19701101T020000"
          add_recurrence_rule   "FREQ=YEARLY;BYMONTH=11;BYDAY=1SU"
      end
  end

  # Use a generic created date since we don't know
  now = Time.parse("2013-01-01").strftime("%Y%m%dT%H%M%S")
  @all_yoga_classes.each do |k,v|
    event = cal.event
    event.start = v['start_date'].strftime("%Y%m%dT%H%M%S")
    event.end = v["end_date"].strftime("%Y%m%dT%H%M%S")
    event.summary = v["classNameHeader"] + (v["trainer"].empty? ? "" : " ("+v["trainer"]+")")
    event.description = v["description"]
    event.location = v["locationNameHeader"]
    event.klass = "PUBLIC"
    event.created = now
    event.last_modified = now
    event.uid = k
  end

#  # Cache the result in redis
#  redis[studio_id] = cal.to_ical
#  redis.expire(studio_id, 3600*6)

  data = cal.to_ical
  File.open(cache_file,"w"){ |f| f << data }

  # Output the ical calendar
  #send_file cal.to_ical, :type => 'text/calendar'
  cal.to_ical
  end

end
end

