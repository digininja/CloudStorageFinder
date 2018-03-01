#!/usr/bin/env ruby

# == Spider Finder - Trawl SpiderOak accounts looking for shared information
#
# Take a name list and see if it exists as an account, if so then run through
# a set of common share names # to see if one exists for that user. Dump out
# any data that is found.
#
# For more information on how this works see the project page
#   https://digi.ninja/projects/spidering_spideroak.php
#
# == Version
#
#  1.0 - Released
#  1.1 - Update to work with current SpiderOak
#
# == Usage
#
# spider_finder.rb <namelist> <folderlist>
#
#   --help, -h: show help
#	--log-file, -l: filename to log output to
#	--valid-accounts, -a: assume the accounts specified exist
#	-v: verbose
#
# <wordlist>: the names to brute force
# <folderlist>: the folders to brute force
#
# Author:: Robin Wood (robin@digi.ninja)
# Copyright:: Copyright (c) Robin Wood 2018
# Licence:: Creative Commons Attribution-Share Alike Licence
#

require 'rexml/document'
require 'net/http'
require 'uri'
require 'getoptlong'

# Display the usage
def usage
	puts"spider_finder 1.0 Robin Wood (robin@digi.ninja) (https://digi.ninja)

Usage: spider_finder [OPTION] ... <namelist> <folderlist>
	--help, -h: show help
	--log-file, -l: filename to log output to
	--valid-accounts, -a: assume the accounts specified exist
	-v: verbose

	<namelist>: the list of names to use
	<folderlist>: the list of folders to use

"
	exit
end

def get_content account, folder
	puts "Checking for folder name: " + folder if @verbose

	host = 'https://spideroak.com'
#	If you request a folder that doesn't exist on a valid account you get a 200, if the account doesn't exist then you get a 404
	page = '/browse/share/' + account + "/" + folder

	puts "Requesting #{page}" if @verbose

	begin
		http = Net::HTTP.new("spideroak.com", 443)
		http.use_ssl = true
		http.start
		response = http.get(page)

	#	puts resp.class.to_s
#		puts data.inspect

		# The code is a string rather than a number even though 
		# all the codes are numeric
		puts "Response code: " + response.code if @verbose

		if response.code == "200"
			data = response.body

			if data.match(/.*title="Atom feed" href="([^"]*)"/)
				rss = $1
				puts "Testing RSS = " + host + rss if @verbose
				id = nil
				if rss.match(/\/share\/([^\/]*)\/.*/)
					id = $1
				else
					return nil
				end

				rss_response = http.request(Net::HTTP::Get.new(rss))
				puts "RSS Response code: " + rss_response.code if @verbose

				if rss_response.code == "200"
					rss_data = rss_response.body

					puts "*************************"
					puts "Folder found: " + host + page + " ( " + host + rss + " )"
					@logging.puts "Folder found: " + host + page + " ( " + host + rss + " )" unless @logging.nil?
					doc = REXML::Document.new(rss_data)
					if doc.elements['feed'].nil?
						puts "Nothing found in the folder"
						@logging.puts "Nothing found in the folder" unless @logging.nil?
					else
						if !doc.elements['feed'].elements['title'].nil?
							puts "Feed title: " + doc.elements['feed'].elements['title'].text
							@logging.puts "Feed title: " + doc.elements['feed'].elements['title'].text unless @logging.nil?
						end
						puts
						@logging.puts "Files" unless @logging.nil?
						@logging.puts "=====" unless @logging.nil?
						puts "Files"
						puts "====="

						doc.elements['feed'].elements.each('entry') do |entry|
							if !entry.elements['title'].nil?
								puts "File title: " + entry.elements['title'].text
								@logging.puts "File title: " + entry.elements['title'].text unless @logging.nil?
							end
							if !entry.elements['link'].nil? and entry.elements['link'].has_attributes?
								if !entry.elements['link'].attributes['href'].nil?
									link = entry.elements['link'].attributes['href']
									link.gsub!(/^\/[^\/]*\/[^\/]*\/[^\/]*\//, "")
									puts "Download link: https://spideroak.com/share/" + id + "/" + folder + "/" + link
									@logging.puts "Download link: https://spideroak.com/share/" + id + "/" + folder + "/" + link unless @logging.nil?
								end
							end
							if !entry.elements['updated'].nil?
								puts "Last updated: " + entry.elements['updated'].text
								@logging.puts "Last updated: " + entry.elements['updated'].text unless @logging.nil?
							end
							@logging.puts unless @logging.nil?
							puts
						end
							
					end
				elsif rss_response.code == "401"
					puts "*************************"
					puts "Password protected folder found: " + host + page + " ( " + host + rss + " )"
					puts
					@logging.puts "*************************" unless @logging.nil?
					@logging.puts "Password protected folder found: " + host + page + " ( " + host + rss + " )" unless @logging.nil?
					@logging.puts "" unless @logging.nil?
				end
			else
				puts "No RSS found" if @verbose
			end
		else
			puts "Folder not found" if @verbose
		end

		return
	rescue Timeout::Error
		@logging.puts "Timeout" unless @logging.nil?
		puts "Timeout"
		return nil
	rescue => e
		puts e.backtrace
		puts e.inspect
		exit
		puts "Error requesting page: " + e.to_s
		@logging.puts "Error requesting page: " + e.to_s unless @logging.nil?
		return nil
	end
end

def check_account account
	host = 'https://spideroak.com'
#	If you request a folder that doesn't exist on a valid account you get a 200, if the account doesn't exist then you get a 404
#	The folder name has to be more than two characters
	page = '/browse/share/' + account + "/blah"
	url = URI.parse(host)

	begin
		http = Net::HTTP.new(url.host, url.port)
		http.use_ssl = (url.port == 443)
		resp, data = http.get2(page)
		if resp.class == Net::HTTPOK
			puts "Account found: " + account
			@logging.puts "Account found: " + account unless @logging.nil?
			return true
		elsif resp.class == Net::HTTPMovedPermanently
			headers = resp.header
			if headers.key?('location')
				location = headers['location']
				if location.match(/\.\.\/([^\/]*).*/)
					account = $1
					puts "Account found: " + account
					@logging.puts "Account found: " + account unless @logging.nil?
					return true
				end
			end
			return false
		elsif resp.class == Net::HTTPNotFound
			puts "Account not found: " + account if @verbose
			@logging.puts "No account: " + account unless @logging.nil?
			return false
		else
			@logging.puts "Unhandled response code: " + resp.class.to_s unless @logging.nil?
			@logging.puts data unless @logging.nil?
			puts "Unhandled response code: " + resp.class.to_s
			puts data
			return false
		end
	rescue Timeout::Error
		@logging.puts "Timeout" unless @logging.nil?
		puts "Timeout"
		return false
	rescue => e
		puts "Error requesting page: " + e.to_s
		@logging.puts "Error requesting page: " + e.to_s unless @logging.nil?
		return false
	end
end

opts = GetoptLong.new(
	[ '--valid-accounts', '-a', GetoptLong::NO_ARGUMENT ],
	[ '--help', '-h', GetoptLong::NO_ARGUMENT ],
	[ '--log-file', '-l', GetoptLong::REQUIRED_ARGUMENT ],
	[ '--verbose', "-v" , GetoptLong::NO_ARGUMENT ]
)

# setup the defaults
@verbose = false
@logging = nil
valid_accounts = false

begin
	opts.each do |opt, arg|
		case opt
			when "--valid-accounts"
				valid_accounts = true
			when '--verbose'
				@verbose = true
			when '--help'
				usage
			when "--log-file"
				begin
					@logging = File.open(arg, "w")
				rescue
					puts "Could not open the logging file\n"
					exit
				end
		end
	end
rescue
	usage
end

if ARGV.length != 2
	usage
	exit 0
end

names_filename = ARGV.shift

if !File.exists? names_filename
	puts "Names file doesn't exist"
	puts
	usage
	exit
end

folders_filename = ARGV.shift

if !File.exists? folders_filename
	puts "Folders file doesn't exist"
	puts
	usage
	exit
end

folders = []
File.open(folders_filename, "r").each do |folder|
	folders << folder.strip
end

File.open(names_filename, 'r').each { |name|
	name.strip!
	if name == ""
		next
	end

	puts "Checking for account: " + name
	@logging.puts "Checking for account: " + name unless @logging.nil?

	if valid_accounts or check_account(name)
		folders.each do |folder|
			get_content name, folder
		end

		@logging.flush unless @logging.nil?
		STDOUT.flush
	end
}

@logging.close unless @logging.nil?
