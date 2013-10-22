require "mechanize"
require "mechanize/http/content_disposition_parser"
require "uri"
require 'net/http'
require 'cgi'
require 'nokogiri'


if ARGV.size < 3
  puts "coursera-downloader.rb <username> <password> <course>"
  exit 1
end

def course_uri(course_name)
  URI("https://class.coursera.org/#{course_name}")
end

def initial_response(uri)
  Net::HTTP.get_response(uri)
end

def do_login(initial_response, username, password)
  uri = URI('https://class.coursera.org/progfun-2012-001')
  cookies = ""

  Net::HTTP.start(uri.host, uri.port,:use_ssl => uri.scheme == 'https') do |http|
    request = Net::HTTP::Post.new(uri)
    request['Cookie'] = "csrftoken=#{initial_response["Set-Cookie"].split(";")[0].split("=")[1]}"
    request["X-CSRFToken"] = initial_response["Set-Cookie"].split(";")[0].split("=")[1]
    request["Referer"] = "https://accounts.coursera.org/signin"

    request.set_form_data('email' => username, 'password' => password)

    response = http.request(request)
    cookies = response["set-cookie"]
  end

  return cookies
end

def build_cookie_string(cookies)
  cauth = cookies["CAUTH"]
  return "maestro_login_flag=1;CAUTH=#{cauth}"
end

def course_content_uri(course_name)
 URI("https://class.coursera.org/#{course_name}/lecture/index")
end


def get_content_site(cookie_string, course_name)
  data = ""
  uri = course_content_uri(course_name)
  Net::HTTP.start(uri.host, uri.port,:use_ssl => uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri)
    request["Cookie"] = cookie_string

    data = http.request(request).body
  end

  return data
end

def get_download_links(data)
  page = Nokogiri::HTML(data)
  result = []

  page.css('div.course-lecture-item-resource').each do |div|
     div.css('a').each do |link|
      result << link.attributes['href'].value
     end
  end

  return result
end

username = ARGV[0]
password = ARGV[1]
course_name = ARGV[2]

initial_resp = initial_response(course_uri(course_name))
cookies = do_login(initial_resp, username, password)
cookie_string = build_cookie_string(cookies)

data = get_content_site(cookie_string, course_name)
links = get_download_links(data)

agent = Mechanize.new
# Download all files to the current directory
links.each do |link|
  unless (link=~ URI::regexp).nil?
    uri = link
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
        # First try to access direct the content-disposition header, because mechanize
        # split the file at "/" and "\" and only use the last part. So we get trouble
        # with "/" in filename.
        if not head.response["Content-Disposition"].nil?
          content_disposition = Mechanize::HTTP::ContentDispositionParser.parse head.response["Content-Disposition"]
          filename = content_disposition.filename if content_disposition
        end

        # If we have no file found in the content disposition take the head filename
        filename ||= head.filename
        filename = URI.decode(filename.gsub(/http.*\/\//,""))
      end

      # Replace unwanted characters from the filename
      filename = filename.gsub(":","").gsub("_","").gsub("/","_")

      if File.exists?(filename)
        p "Skipping #{filename} as it already exists"
      else
        p "Downloading #{uri} to #{filename}..."
        begin
          gotten = agent.get(uri)
          gotten.save(filename)
          p "Finished"
        rescue Mechanize::ResponseCodeError => exception
          if exception.response_code == '403'
            p "Failed to download #{filename} for #{exception}"
          else
            raise exception # Some other error, re-raise
          end
        end
      end
    end
  end
end
