require 'icalendar'
require 'json'

# Produces ical output based on objects read from cache or produced by the reader class
class MindbodyClassSchedule

  attr_accessor :all_yoga_classes, :studio_id

  CACHE_DIR = "/tmp/cache"
  CACHE_VALID_HOURS = 6

  WEEKS_TO_LOAD = 3

  def initialize(opt={})
    @studio_id = opt[:studio_id]
    @cache_file = File.join(CACHE_DIR,studio_id.to_s)
    # flush_cache
  end

  def load
    if cache_out_of_date?
      puts "cache out of date"
      mbreader = MindbodyReader.new({:studio_id => studio_id})
      @all_yoga_classes = mbreader.refresh
      (WEEKS_TO_LOAD-1).times { @all_yoga_classes.merge!(mbreader.next_week) }
      save_cache
    else
      puts "reading cache"
      read_cache
    end
  end

  def deep_copy(o)
    Marshal.load(Marshal.dump(o))
  end

  # We convert the dates to something that will survive being converted to and from json.
  # We normally keep the dates as Time objects so that we can easily do math on them and output them in different formats
  def save_cache
    Dir.mkdir(CACHE_DIR) unless File.exists?(CACHE_DIR)
    all_yoga_classes_with_integer_times = deep_copy(@all_yoga_classes)
    all_yoga_classes_with_integer_times.each do |k,v|
      all_yoga_classes_with_integer_times[k]['start_date'] = v['start_date'].to_i
      all_yoga_classes_with_integer_times[k]['end_date'] = v['end_date'].to_i
    end
    File.open(@cache_file,"w"){ |f| f << all_yoga_classes_with_integer_times.to_json }
  end

  # We convert dates back to Time objects from the integer (unix timestamp) form that we store in json
  def read_cache
    @all_yoga_classes = JSON.parse(File.read(@cache_file))
    # convert date strings to datetime objects
    @all_yoga_classes.each do |k,v|
      @all_yoga_classes[k]['start_date'] = DateTime.parse(Time.at(v['start_date']).to_s)
      @all_yoga_classes[k]['end_date'] = DateTime.parse(Time.at(v['end_date']).to_s)
    end
  end

  def print_ical
    # Create a calendar to contain all the class eventesAdd ical objects
    cal = Icalendar::Calendar.new

    # Set the timezone to Pacific
    cal.timezone do |t|
      t.tzid             = "America/Los_Angeles"
      t.x_lic_location   = "America/Los_Angeles"
      t.daylight do |d|
          d.tzoffsetfrom = "-0800"
          d.tzoffsetto   = "-0700"
          d.tzname       = "PDT"
          d.dtstart      = "19700308T020000"
          d.rrule        = "FREQ=YEARLY;BYMONTH=3;BYDAY=2SU"
      end
      t.standard do |s|
          s.tzoffsetfrom = "-0700"
          s.tzoffsetto   = "-0800"
          s.tzname       = "PST"
          s.dtstart      = "19701101T020000"
          s.rrule        = "FREQ=YEARLY;BYMONTH=11;BYDAY=1SU"
      end
    end

    # Use a generic created date since we don't know
    now = DateTime.parse('2013-01-01')
    @all_yoga_classes.each do |k,v|
      event = cal.event
      event.uid = k
      event.created = now
      event.last_modified = now
      event.dtstart = v['start_date']
      event.dtend = v['end_date']
      event.summary = v["class_name_with_sub_mark"]
  #    event.summary = v["classNameHeader"] + (v["trainer"].empty? ? "" : " ("+v["trainer"]+")")
      event.description = v['description']
      event.location = v['location']
      event.ip_class = 'PUBLIC'
    end

    # Output the ical calendar
    # send_file cal.to_ical, :type => 'text/calendar'
    cal.to_ical
  end

  def print_html
    puts "none yet"
  end

  def cache_out_of_date?
    # Test or create cache dir
    if File.exist?(@cache_file) && (File.mtime(@cache_file) > (Time.now - 3600*CACHE_VALID_HOURS))
      puts "cache hit"
      return false
    else
      puts "cache miss"
      return true
    end
  end

  def flush_cache
    File.delete(@cache_file) if File.exist?(@cache_file)
  end

end
