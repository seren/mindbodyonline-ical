require_relative 'lib/bodymind_class_schedule'
require_relative 'lib/bodymind_reader'

# require 'sinatra'
require 'pry'

studio_id = 4095
bmclass = BodymindClassSchedule.new({:studio_id => studio_id})
# bmclass.flush_cache
bmclass.load
# binding.pry
puts bmclass.print_ical


# # Config sinatra port
# set :port, 19494
# set :server, 'webrick'
# #before { content_type 'text/calendar' }

# # Give univited visitors a blank page
# get '/' do
# end

# #get '/robots.txt' do
# #  User-agent:*
# #  Disallow: /yogatimes
# #end


# # The actual URI to use
# get '/mindbodyonline' do

#   # Get the studio "id" parameter.
#   begin
#     studio_id = params["studio_id"].gsub(/[\D]/,'')
#   rescue
#     "Bad"
#   end

#   # 
#   if studio_id.nil? || studio_id.empty? || studio_id != "4095"
#     "Nope"
#   else
#     bmclass = BodymindClassSchedule.new({:studio_id => studio_id})
#     bmclass.load
#     bmclass.print_ical
#     bmclass.print_html
#   end
# end

