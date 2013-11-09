require 'icalendar'
require 'json'

class BodymindClassSchedule

  attr_accessor :all_yoga_classes, :studio_id, :temp_html

  CACHE_DIR = "/tmp/cache"
  CACHE_VALID_HOURS = 6


  def initialize(opt={})
    @studio_id = opt[:studio_id]
    @cache_file = File.join(CACHE_DIR,studio_id.to_s)
    @cache_file_temp_html = File.join(CACHE_DIR,"#{studio_id.to_s}_temp_html")
  end

  def load
    if cache_out_of_date?
      puts "cache out of date"
      bmreader = BodymindReader.new({:studio_id => studio_id})
      @temp_html, @all_yoga_classes = bmreader.refresh
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
    File.open(@cache_file_temp_html,"w"){ |f| f << @temp_html }
  end

  # We convert dates back to Time objects from the integer (unix timestamp) form that we store in json
  def read_cache
    @all_yoga_classes = JSON.parse(File.read(@cache_file))
    @temp_html = File.read(@cache_file_temp_html)
    # convert date strings to time objects
    @all_yoga_classes.each do |k,v|
      @all_yoga_classes[k]['start_date'] = Time.at(v['start_date'])
      @all_yoga_classes[k]['end_date'] = Time.at(v['end_date'])
    end
  end

  def print_ical
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
      event.summary = v["classNameHeader"]
  #    event.summary = v["classNameHeader"] + (v["trainer"].empty? ? "" : " ("+v["trainer"]+")")
      event.description = v["description"]
      event.location = v["locationNameHeader"]
      event.klass = "PUBLIC"
      event.created = now
      event.last_modified = now
      event.uid = k
    end

    # Output the ical calendar
    # send_file cal.to_ical, :type => 'text/calendar'
    cal.to_ical
  end

  def print_html
    string = []
    @all_yoga_classes.each do |k,v|
      string << class_start = v['start_date'].strftime("%Y%m%dT%H%M%S")
      string << class_end = v["end_date"].strftime("%Y%m%dT%H%M%S")
      string << summary = v["classNameHeader"]
  #   string << summary = v["classNameHeader"] + (v["trainer"].empty? ? "" : " ("+v["trainer"]+")")
      string << description = v["description"]
      string << location = v["locationNameHeader"]
      string << klass = "PUBLIC"
      string << uid = k
      string << ""
    end
    string.join("<br>\n")
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
    File.delete(@cache_file_temp_html) if File.exist?(@cache_file_temp_html)
  end

end