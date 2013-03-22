require 'nokogiri'
#require 'open-uri'
require 'mechanize'
require 'icalendar'
require 'sinatra'


def convert_string_to_seconds(str)
  duration_string = str.gsub('hour','3600').gsub('minute','60')
  duration_string_array = duration_string.gsub(/[^\w]/," ").split(" ")
  duration_int_array = duration_string_array.map{ |x| x.to_i }
  duration_int_pairs = duration_int_array.each_slice(2).to_a
  duration_seconds = duration_int_pairs.reduce(0) { |sum,x| sum + (x[0] * x[1]) }
  return duration_seconds
end



set :port, 19494
get '/' do

end

get '/yogatimes' do

begin
studio_id = params["id"].gsub(/[\D]/,'')
rescue
"Bad"
end

if studio_id.nil? || studio_id.empty? || studio_id != "4095"
  "Nope"
else

url_base = "https://clients.mindbodyonline.com"
url1 = url_base + "/ws.asp?studioid=" + studio_id + "&stype=-7&sView=week&sLoc=0"
url2 = url_base + "/ASP/home.asp?studioid=" + studio_id
url = "http://www.seren.net/mindbody/main_class.html"
#elements = [ "startTimeHeader" , "classNameHeader", "trainerNameHeader", "locationNameHeader", "resourceNameHeader", "durationHeader" ]
#reg_width=Regexp.new('width: (\d*)px')


a = Mechanize.new
a.user_agent_alias = 'Mac Safari'
a.get(url1)
page = a.get(url2)
frame_url = page.frame_with(:name => "mainFrame").href
html = a.get(url_base+"/ASP/"+frame_url).body


data = Nokogiri::HTML(html)
#data = Nokogiri::HTML(File.read("/Users/seren/Desktop/Pilgrimage of the Heart Yoga Online2_files/main_class.html"))
header = data.css('tr[class="floatingHeaderRow"]')
total_columns = data.css('tr[class="floatingHeaderRow"] th').count
#classtable = data.css('table#classSchedule-mainTable')
#dates = classtable.css('td[class="header"] b')
all_rows = data.css('table#classSchedule-mainTable tr')

# Get the widths as ID for each column that we want
#widths = elements.reduce({}) do |acc,e|
#  width = header.at_css('th#'+e)[:style].match(reg_width)[1]
#  raise "Found identical column widths. Column widths are used to ID cell contents, so the need to be unique." if acc.has_key?(width)
#  acc[width] = e
#  acc
#end
# or
# Get the column names
column_names = header.css('th').map { |e| e.attribute('id').value }

day_text = ""
@all_yoga_classes = {}
all_rows.each do |r|
  # If there's only one column with the right class, it's a day row
  if r.css('td[class="header"]').count == 1
    day_text = r.css('td[class="header"]').text
  else
    if r.css('td').count == total_columns
      values = r.css('td').map { |v| v.text }
      yoga_class = Hash[*column_names.zip(values).flatten]
      yoga_class.each { |k,v| v.gsub!(/[^a-zA-Z0-9:;\-_#\@\(\)]/," ") }
      yoga_class.each { |k,v| v.strip! }
      trainer = yoga_class["trainerNameHeader"]
      class_name = yoga_class["classNameHeader"]
      location = yoga_class["locationNameHeader"]
      start_time = yoga_class["startTimeHeader"]
      class_time = Time.parse(day_text+" "+start_time)
      yoga_class["end_time"] = class_time + convert_string_to_seconds(yoga_class["durationHeader"])
      yoga_class["uid"] = class_time.strftime("%Y%m%dT%H%M%S")+class_name.gsub(/[^\w]/,'')+trainer.gsub(/[^\w]/,'')
      yoga_class["description"] = "#{class_name} @ #{start_time}, #{trainer.empty? ? "" : "with "+trainer} at the #{location.empty? ? "" : "at the "+location+" location"}."
      @all_yoga_classes[class_time] = yoga_class
    end
  end
end

# Add ical objects
cal = Icalendar::Calendar.new

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

now = Time.parse("2012-12-01").strftime("%Y%m%dT%H%M%S")
@all_yoga_classes.each do |k,v|
  event = cal.event
  event.start = k.strftime("%Y%m%dT%H%M%S")
  event.end = v["end_time"].strftime("%Y%m%dT%H%M%S")
  event.summary = v["classNameHeader"]
  event.description = v["description"]
  event.location = v["locationNameHeader"]
  event.klass = "PUBLIC"
  event.created = now
  event.last_modified = now
  event.uid = v["uid"]
end

cal.to_ical
  # this tells sinatra to render the Embedded Ruby template /views/shows.erb
#  erb :classes
end

end


#@all_yoga_classes.each { |k,v| puts(k.to_s + " " + v["end_time"].to_s + "   " + v["durationHeader"] + "   --" + v["classNameHeader"] + "--") }
#puts cal.to_ical

