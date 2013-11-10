require 'nokogiri'
require 'mechanize'

class BodymindReader

  attr_accessor :studio_id, :current_page


  def initialize(opt={})
    # Get the studio "id" parameter.
    @studio_id = opt[:studio_id].to_s
  end

  def refresh
    # get fresh data
    # The urls we need to hit
    url_base = "https://clients.mindbodyonline.com"
    url1 = url_base + "/ws.asp?studioid=" + studio_id + "&stype=-7&sView=week&sLoc=0"
    url2 = url_base + "/ASP/home.asp?studioid=" + studio_id
    url3 = url_base + "/asp/main_class.asp"

    # Pretend to be Safari and grab the frame url with the schedule table
    a = Mechanize.new
    # agent.set_proxy('127.0.0.1', 8888)
    a.user_agent_alias = 'Mac Safari'
    # Set cookies
    a.get(url1)
    # Get initial pages
    page2 = a.get(url2)
    frame2 = page2.frame_with(:name => "mainFrame")
    frame_url = frame2.href

    # Get first calendar page
    @current_page = a.get(url_base+"/ASP/"+frame_url)
    return [body_html, generate_schedule_hash_from_current_page]
  end

  def next_week
    load_next_weeks_calendar
    return [body_html, generate_schedule_hash_from_current_page]
  end




  # private

  def body_html
    @current_page.body
  end

  def next_weeks_date
    # Get the date of next week
    r = /.*tmpDate = \"(.*)\";.*/
    # Finds each line with tmpDate. Returns just the date from the 3rd matched line.
    txtDate = body_html.split("\n").map {|x| r.match(x) }.compact[2][1]
  end

  def current_date(p=@current_page)
    p.form_with(:id => "frmLogonTop")["date"]
  end

  def load_next_weeks_calendar
    form = @current_page.form_with(:id => 'ClassScheduleSearch2Form')
    form.field_with(:id => 'txtDate').value = next_weeks_date
    new_page = form.submit
    @current_page = new_page
  end

  def generate_schedule_hash_from_current_page
    # We could probably do our processing with mechanize as well  
    data = Nokogiri::HTML(body_html)
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
          yoga_class["description"] = "#{class_name} @ #{start_time},#{trainer.empty? ? "" : " with "+trainer}#{location.empty? ? "" : " at the "+location+" location"}#{room.empty? ? "" : " in the "+room}."
          # Add the class hash to the aggregate hash
          @all_yoga_classes[uid] = yoga_class
        end
      end
    end
    return @all_yoga_classes
  end

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


end