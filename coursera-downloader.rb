require "mechanize"
require "URI"

if ARGV.size < 3
  puts "coursera-downloader.rb <username> <password> <course>"
  exit 1
end

username = ARGV[0]
password = ARGV[1]
course_name = ARGV[2]

agent = Mechanize.new
# Login to the coursera site
site = agent.get("http://class.coursera.org/#{course_name}/auth/auth_redirector?type=login&subtype=normal&email=&visiting=&minimal=true")
login_form = site.forms.first

login_form.email = username
login_form.password = password

agent.submit(login_form, login_form.buttons.first)

# Load the lecture site
content_site = agent.get("https://class.coursera.org/#{course_name}/lecture/index")
agent.pluggable_parser.default = Mechanize::Download

# Download all PDF and mp4 files to the current directory
content_site.links.each do |link|
  unless (link.uri.to_s =~ URI::regexp).nil?
    uri = link.uri.to_s

    if (uri =~ /\.mp4/) || (uri =~ /\.pdf/)
      p "Downloading #{uri}"
      agent.get(uri).save()
      p "Finished"
    end
  end
end
