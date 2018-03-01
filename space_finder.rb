#!/usr/bin/env ruby

# == Space Finder - Trawl Digital Ocean Spaces for interesting files
#
# == Version
#
#  1.0 - Released
#
# == Usage
#
# bucket_finder.rb <wordlist>
#
# -l, --log-file <file name>:
#   filename to log output to
# -d, --download:
# 	download any public files found
# -r, --region:
# 	specify the start region
# -h, --help:
#	show help
#
# <wordlist>: the names to brute force
#
# Author:: Robin Wood (robin@digi.ninja
# Copyright:: Copyright (c) Robin Wood 2018
# Licence:: Creative Commons Attribution-Share Alike Licence
#

require 'rexml/document'
require 'net/http'
require 'uri'
require 'getoptlong'
require 'fileutils'

# This is needed because the standard parse can't handle square brackets
# so this encodes them before parsing
module URI
  class << self

    def parse_with_safety(uri)
      parse_without_safety uri.gsub('[', '%5B').gsub(']', '%5D')
    end

    alias parse_without_safety parse
    alias parse parse_with_safety
  end
end

# Display the usage
def usage
	puts"space_finder.rb 1.0 Robin Wood (robin@digi.ninja) (https://digi.ninja)

Usage: space_finder [OPTION] ... wordlist
    -h, --help: show help
    -d, --download: download the files
    -l, --log-file: filename to log output to
    -h, --hide-private: hide private spaces, just show public ones
    -n, --hide-not-found: hide missing spaces
    -r, --region: the region to check, options are:
                   all - All regions
                   nyc - New York
                   ams - Amsterdam
                   sgp - Singapore
    -v: verbose

    wordlist: the wordlist to use

"
	exit
end

def get_page host, page
	url = "https://" + page + host
	uri = URI.parse(url)

	@logging.puts "URL: #{url}" unless @logging.nil?
	puts "Checking Space URL: #{url}" if @verbose

	begin
		http= Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		http.start
		res = http.get("/")
	rescue Timeout::Error
		puts "Timeout"
		@logging.puts "Timeout" unless @logging.nil?
		return ''
	rescue => e
		puts "Error requesting page: " + e.to_s
		@logging.puts "Error requesting page: " + e.to_s unless @logging.nil?
		return ''
	end

	return res.body
end

def parse_results doc, space_name, host, download, depth = 0
	tabs = ''

	depth.times {
		tabs += "\t"
	}

	if !doc.elements['ListBucketResult'].nil?
		puts tabs + "Space found in region #{host.split(".")[1]}: " + space_name + " ( https://" + space_name + host + " )"
		@logging.puts tabs + "Space Found: " + space_name + " ( https://" + space_name + "/" + host + " )" unless @logging.nil?
		doc.elements.each('ListBucketResult/Contents') do |ele|
			protocol = 'https://'
			filename = ele.elements['Key'].text

			url = protocol + space_name + host + '/' + URI.escape(filename)

			response = nil
			parsed_url = URI.parse(url)
			downloaded = false
			readable = false

			# the directory listing contains directory names as well as files
			# so if a filename ends in a / then it is actually a directory name
			# so don't try to download it
			if download and filename != '' and filename[-1].chr != '/'
				fs_dir = space_name + File.dirname(URI.parse(url).path)

				if !File.exists? fs_dir
					puts "Making directory #{fs_dir}" if @verbose
					FileUtils.mkdir_p fs_dir
				end

				begin
					http = Net::HTTP.new(parsed_url.host, parsed_url.port)
					http.use_ssl = true
					http.start
					response = http.head(parsed_url.path)
					if response.code.to_i == 200
						open(fs_dir + '/' + File.basename(filename), 'wb') { |file|
							file.write(response.body)
						}
						downloaded = true
						readable = true
					else
						readable = false
						downloaded = false
					end
				rescue Timeout::Error
					puts "Timeout downloading file #{url}"
					@logging.puts "Timeout" unless @logging.nil?
					return ''
				rescue => e
					puts "Error downloading page: " + e.to_s
					@logging.puts "Error requesting page: " + e.to_s unless @logging.nil?
					return ''
				end
			else
				begin
					http = Net::HTTP.new(parsed_url.host, parsed_url.port)
					http.use_ssl = true
					http.start
					response = http.head(parsed_url.path)
					readable = (response.code.to_i == 200)
					downloaded = false
				rescue Timeout::Error
					puts "Timeout checking file #{url}"
					@logging.puts "Timeout" unless @logging.nil?
					return ''
				rescue => e
					puts "Error checking page: " + e.to_s
					@logging.puts "Error requesting page: " + e.to_s unless @logging.nil?
					return ''
				end
			end

			if (readable)
				if downloaded
					puts tabs + "\t" + "<Downloaded> " + url
					@logging.puts tabs + "\t" + "<Downloaded> " + url unless @logging.nil?
				else
					puts tabs + "\t" + "<Public> " + url
					@logging.puts tabs + "\t" + "<Public> " + url unless @logging.nil?
				end
			else
				unless @hide_private
					puts tabs + "\t" + "<Private> " + url
					@logging.puts tabs + "\t" + "<Private> " + url unless @logging.nil?
				end
			end
		end

	elsif doc.elements['Error']
		err = doc.elements['Error']
		if !err.elements['Code'].nil?
			case err.elements['Code'].text
				when "NoSuchKey"
					puts tabs + "The specified key does not exist: " + space_name
					@logging.puts tabs + "The specified key does not exist: " + space_name unless @logging.nil?
				when "AccessDenied"
					puts tabs + "Space found in region #{host.split(".")[1]} but access denied: #{space_name}"
					@logging.puts tabs + "Space found but access denied: " + space_name unless @logging.nil?
				when "NoSuchBucket"
					unless @hide_not_found
						puts tabs + "Space does not exist in region #{host.split(".")[1]}: #{space_name}"
						@logging.puts tabs + "Space does not exist: " + space_name unless @logging.nil?
					end
			end
		else
#			puts res.body
		end
	else
		puts tabs + ' No data returned'
		@logging.puts tabs + ' No data returned' unless @logging.nil?
	end
end

opts = GetoptLong.new(
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--region', '-r', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--log-file', '-l', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--download', '-d', GetoptLong::NO_ARGUMENT ],
	[ '--hide-private', GetoptLong::NO_ARGUMENT ],
	[ '--hide-not-found', '-n', GetoptLong::NO_ARGUMENT ],
	[ "--verbose", "-v" , GetoptLong::NO_ARGUMENT ]
)

# setup the defaults
download = false
@verbose = false
region = "nyc"
@logging = nil
@hide_private = false
@hide_not_found = false

begin
	opts.each do |opt, arg|
		case opt
			when '--hide-not-found'
				@hide_not_found = true
			when '--hide-private'
				@hide_private = true
			when '--help'
				usage
			when '--download'
				download = true
			when "--log-file"
				begin
					@logging = File.open(arg, "w")
				rescue
					puts "Could not open the logging file\n"
					exit
				end
			when "--verbose"
				@verbose = true
			when "--region"
				region = arg
		end
	end
rescue
	usage
end

if ARGV.length != 1
	puts "Missing wordlist (try --help)"
	exit 0
end

filename = ARGV.shift

hosts = []

case region
	when "all"
		hosts << ('.ams3.digitaloceanspaces.com')
		hosts << ('.nyc3.digitaloceanspaces.com')
		hosts << ('.sgp1.digitaloceanspaces.com')
	when "ams"
		hosts << ('.ams3.digitaloceanspaces.com')
	when "nyc"
		hosts << ('.nyc3.digitaloceanspaces.com')
	when "sgp"
		hosts << ('.sgp1.digitaloceanspaces.com')
	else
		puts "Unknown region specified"
		puts
		usage
end

if !File.exists? filename
	puts "Wordlist file doesn't exist"
	puts
	usage
	exit
end

File.open(filename, 'r').each do |name|
	name.strip!
	if name == ""
		next
	end

	hosts.each do |host|
		data = get_page host, name
		if data != ''
			doc = REXML::Document.new(data)
			parse_results doc, name, host, download, 0
		end
	end
end

@logging.close unless @logging.nil?
