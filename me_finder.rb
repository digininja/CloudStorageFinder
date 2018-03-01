#!/usr/bin/env ruby

# == Mobile Me Finder - Trawl Mobile Me for interesting files
#
# Mobile Me give users their own pubilc URL in the form:
#   https://public.me.com/<user name>
#
# This script crawls all the users supplied, lists files found 
# and optionally downloads them
#
# == Usage
#
# me_finder.rb <wordlist>
#
# -v, --verbose:
# 	verbose mode, output all information found about files
# -d, --download:
# 	download any public files found
# -l, --log-file <file name>:
#   filename to log output to
# -h, --help:
#	show help
#
# <wordlist>: the names to brute force
#
# Author:: Robin Wood (robin@digininja.org
# Copyright:: Copyright (c) Robin Wood 2011
# Licence:: Creative Commons Attribution-Share Alike Licence
#

puts"me_finder 1.0 Robin Wood (robin@digi.ninja) (https://digi.ninja)"
puts
puts "As Mobile Me no longer exists, this is here purely for historical reasons"
puts

exit

require 'rexml/document'
require 'net/http'
require 'net/https'
require 'uri'
require 'getoptlong'
require 'fileutils'

HOST = "https://public.me.com"
PATH = "/ix/"
QUERY_STRING = '?protocol=roap&item=properties&depth=1&lang=en'
# With the default UA you don't get the hidden folders such as .Trashes
USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.6; rv:2.0.1) Gecko/20100101 Firefox/4.0.1'

# Handle ctrl-c a bit nicer than throwing exceptions all over the screen
#
trap "SIGINT", 'shutdown'

def shutdown
	puts 
	exit
end

# Crude I know but all I need this for is the size so it works
#
class String
	def numeric?
		# Check if every character is a digit
		!!self.match(/\A[0-9]+\Z/)
	end
end

# Used with the file size to give human readable sizes
#
class Numeric
	def to_human
		if self == 0
			return "0B"
		end
		units = %w{B KB MB GB TB}
		e = (Math.log(self)/Math.log(1024)).floor
		s = "%.3f" % (to_f / 1024**e)
		s.sub(/\.?0*$/, units[e])
	end
end

# This will remove the message
# warning: peer certificate won't be verified in this SSL session
#
class Net::HTTP
	alias_method :old_initialize, :initialize
	def initialize(*args)
		old_initialize(*args)
		@ssl_context = OpenSSL::SSL::SSLContext.new
		@ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
	end
end

# This is needed because the standard parse can't handle square brackets
# so this encodes them before parsing
#
module URI
  class << self

    def parse_with_safety(uri)
      parse_without_safety uri.gsub('[', '%5B').gsub(']', '%5D')
    end

    alias parse_without_safety parse
    alias parse parse_with_safety
  end
end

def download_file path, tabs, verbose = false
	if /\/ix\/(.*)\/(.*)/.match(path)
		fs_dir = $1
		filename = $2

		if !File.exists? fs_dir
			FileUtils.mkdir_p fs_dir
		end

		begin
			url = URI.parse(HOST)
	#		proxy = Net::HTTP::Proxy('localhost', 8080)
	#		http = proxy.new(url.host, url.port)
			http = Net::HTTP.new(url.host, url.port)
			http.use_ssl = (url.port == 443)
			req = path
			resp, data = http.get2(req, {'User-Agent' => USER_AGENT})

			if resp.class == Net::HTTPSuccess || resp.class == Net::HTTPOK
				open(fs_dir + '/' + filename, 'wb') { |file|
					file.write(data)
				}
				puts tabs + "File downloaded"
				@logging.puts tabs + "File downloaded" unless @logging.nil?
			else
				puts tabs + 'Failed to download file'
				@logging.puts tabs + 'Failed to download file' unless @logging.nil?
			end
		rescue Timeout::Error
			puts "Timeout"
			@logging.puts "Timeout" unless @logging.nil?
			return ''
		rescue => e
			puts "Error requesting page: " + e.to_s
			puts e.backtrace
			return ''
		end
	end
end

# Display the usage
def usage
	puts"me_finder 1.0 Robin Wood (robin@digininja.org) (www.digininja.org)

Usage: me_finder [OPTION] ... wordlist
	--help, -h: show help
	--download, -d: download the files
	--log-file, -l: filename to log output to
	--verbose, -v: verbose

	wordlist: the wordlist to use

"
	exit
end

def get_page path, page
	url = URI.parse(HOST)

	begin
#		proxy = Net::HTTP::Proxy('localhost', 8080)
#		http = proxy.new(url.host, url.port)
		http = Net::HTTP.new(url.host, url.port)
		http.use_ssl = (url.port == 443)
		req = path + page + QUERY_STRING
		resp, data = http.get2(req, {'User-Agent' => USER_AGENT})

		if resp.class == Net::HTTPSuccess
			return data
		elsif resp.class == Net::HTTPUnauthorized
			return 'Private'
		else
			if resp.class != Net::HTTPPaymentRequired
				puts "Get page returned something not yet handled"
				@logging.puts "Get page returned something not yet handled" unless @logging.nil?
				puts resp.class
				@logging.puts resp.class unless @logging.nil?
			end
			return nil
		end
	rescue Timeout::Error
		puts "Timeout"
		@logging.puts "Timeout" unless @logging.nil?
		return ''
	rescue => e
		puts "Error requesting page: " + e.to_s
		@logging.puts "Error requesting page: " + e.to_s unless @logging.nil?
		puts e.backtrace
		@logging.puts e.backtrace unless @logging.nil?
		return ''
	end
	return nil
end

def parse_results doc, me_name, download, depth = 0, verbose = false
	tabs = ''

	depth.times {
		tabs += "\t"
	}

	data_found = false
	if !doc.elements['multistatus'].nil?
		first = true
		doc.elements.each('multistatus/D:response') do |ele|
			# The first entry is the description of the directory you are currently in so can be ignored
			if first
				first = false
				next
			end
			data_found = true
			url = ele.elements['D:href'].text

			if !ele.elements['D:propstat'].nil? 
				if !ele.elements['D:propstat'].elements['D:prop'].nil?
					if ele.elements['D:propstat'].elements['D:prop'].elements['D:resourcetype'].has_text?
						puts tabs + "Directory found: " + HOST + url
						@logging.puts tabs + "Directory found: " + HOST + url unless @logging.nil?
						data = get_page '', url
						doc = REXML::Document.new(data)
						parse_results doc, me_name, download, depth + 1, verbose
					else
						puts tabs + "File found: " + HOST + url
						@logging.puts tabs + "File found: " + HOST + url unless @logging.nil?
				
						if verbose
							if !ele.elements['D:propstat'].elements['D:prop'].elements['D:creationdate'].nil? and ele.elements['D:propstat'].elements['D:prop'].elements['D:creationdate'].has_text?
								puts tabs + "\tCreation date: " + ele.elements['D:propstat'].elements['D:prop'].elements['D:creationdate'].text
								@logging.puts tabs + "\tCreation date: " + ele.elements['D:propstat'].elements['D:prop'].elements['D:creationdate'].text unless @logging.nil?
							end
							# Not sure what the difference between these two are but as they are there I may as well output them
							if !ele.elements['D:propstat'].elements['D:prop'].elements['D:modificationdate'].nil?  and ele.elements['D:propstat'].elements['D:prop'].elements['D:modificationdate'].has_text?
								puts tabs + "\tModification date: " + ele.elements['D:propstat'].elements['D:prop'].elements['D:modificationdate'].text
								@logging.puts tabs + "\tModification date: " + ele.elements['D:propstat'].elements['D:prop'].elements['D:modificationdate'].text unless @logging.nil?
							end
							if !ele.elements['D:propstat'].elements['D:prop'].elements['D:getlastmodified'].nil? and ele.elements['D:propstat'].elements['D:prop'].elements['D:getlastmodified'].has_text?
								puts tabs + "\tLast modified: " + ele.elements['D:propstat'].elements['D:prop'].elements['D:getlastmodified'].text
								@logging.puts tabs + "\tLast modified: " + ele.elements['D:propstat'].elements['D:prop'].elements['D:getlastmodified'].text unless @logging.nil?
							end
							if !ele.elements['D:propstat'].elements['D:prop'].elements['D:getcontentlength'].nil? and ele.elements['D:propstat'].elements['D:prop'].elements['D:getcontentlength'].has_text?
								size = ele.elements['D:propstat'].elements['D:prop'].elements['D:getcontentlength'].text
								
								if size.numeric?
									human_size = ' (' + size.to_i.to_human + ')'
								else
									human_size = ''
								end
								puts tabs + "\tSize: " + size + human_size
								@logging.puts tabs + "\tSize: " + size + human_size unless @logging.nil?
							end
						end

						if download
							download_file url, tabs, verbose
						end
					end
				end
				status = ele.elements['D:propstat'].elements['D:status'].text
				if status != 'HTTP/1.1 200 OK'
					puts tabs + "Status isn't 200, needs investigating: " + status.inspect
					@logging.puts tabs + "Status isn't 200, needs investigating: " + status.inspect unless @logging.nil?
				end
			end
		end
		if !data_found
			puts tabs + "No files found"
			@logging.puts tabs + "No files found" unless @logging.nil?
		end
	else
		puts tabs + 'No files found'
		@logging.puts tabs + 'No files found' unless @logging.nil?
	end

	return data_found
end

opts = GetoptLong.new(
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--log-file', '-l', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--download', '-d', GetoptLong::NO_ARGUMENT ],
	[ '--verbose', "-v" , GetoptLong::NO_ARGUMENT ]
)

# setup the defaults
download = false
verbose = false
@logging = nil

begin
	opts.each do |opt, arg|
		case opt
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
			when '--verbose'
				verbose = true
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

if !File.exists? filename
	puts "Wordlist file doesn't exist"
	puts
	usage
	exit
end

File.open(filename, 'r').each { |me_name|
	me_name.strip!
	if me_name == ""
		next
	end

	data = get_page PATH, me_name
	
	if (data.nil?)
		puts "Account not found: " + me_name
		@logging.puts "Account not found: " + me_name unless @logging.nil?
	elsif data == 'Private'
		puts "Account private: " + me_name
		@logging.puts "Account private: " + me_name unless @logging.nil?
	else
		puts "Account found: " + me_name + " ( https://public.me.com/" + me_name + " )"
		@logging.puts "Account found: " + me_name + " ( https://public.me.com/" + me_name + " )" unless @logging.nil?
		doc = REXML::Document.new(data)
		parse_results doc, me_name, download, 0, verbose
		puts
		@logging.puts unless @logging.nil?
	end
}
