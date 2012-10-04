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

# Download all files to the current directory
content_site.links.each do |link|
  unless (link.uri.to_s =~ URI::regexp).nil?
    uri = link.uri.to_s
    filename = ""
    if (uri =~ /\.mp4/) || (uri =~ /srt/) || (uri =~ /\.pdf/) || (uri =~ /\.pptx/)
     begin
       head = agent.head(uri)
     rescue Mechanize::ResponseCodeError => exception
       if exception.response_code == '403'
         filename = URI.decode(exception.page.filename).gsub(/.*filename=\"(.*)\"+?.*/, '\1')
       else
         raise exception # Some other error, re-raise
       end
     else
      filename = head.filename
      filename = URI.decode(filename.gsub(/http.*\//,"")).gsub("_", " ").gsub("/", "_")
     end
      
      if File.exists?(filename) 
       p "Skipping #{filename} as it already exists"
      else
       p "Downloading #{uri} to #{filename}..."
       gotten = agent.get(uri)
       gotten.save(filename)
       p "Finished"
      end
    end
  end
end
