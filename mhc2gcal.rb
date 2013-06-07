#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

## mhc2gcal
## Copyright (C) 2007 Nao Kawanishi <river2470@gmail.com>
## Author: Nao Kawanishi <river2470@gmail.com>
## Copyright (C) 2011 Munechika Sumikawa <sumikawa@sumikawa.jp>

## "mhc2ical" is base code of mhc2gcal
## Original author: Yojiro UO <yuo@iijlab.net>
## "today" is base code of mhc2ical
## Original author: Yoshinari Nomura <nom@quickhack.net>

## "ol2gcal" is also base code of mhc2gcal
## Original author: <zoriorz@gmail.com>

Version = '0.5.0'

require 'yaml'
require 'rubygems'
require 'google/api_client'
require 'date'
require 'mhc-schedule'
require 'mhc-kconv'
require 'nkf'
require 'optparse'

def string_to_date(string, range)
  date_from = nil
  date_to   = nil

  case (string.downcase)
  when 'today'
    date_from = MhcDate.new
  when 'tomorrow'
    date_from = MhcDate.new.succ
  when /^(sun|mon|tue|wed|thu|fri|sat)/
    date_from = MhcDate.new.w_this(string.downcase)
  when /^\d{8}$/
    date_from = MhcDate.new(string)
  when /^\d{6}$/
    date_from = MhcDate.new(string + '01')
    if range
      date_to = date_from.succ(range.to_i)
    else
      date_to = MhcDate.new(string + format("%02d", date_from.m_days))
    end
  when /^\d{4}$/
    date_from = MhcDate.new(string + '0101')
    if range
      date_to = date_from.succ(range.to_i)
    else
      date_to = MhcDate.new(string + '1231')
    end
  else
    return nil
  end
  date_to = date_from.succ((range || '0').to_i) if !date_to
  return [date_from, date_to]
end

def string_to_date2(s1, s2)
  item = []
  [s1, s2].each { |string|
    case (string.downcase)
    when 'today'
      item << MhcDate.new
    when 'tomorrow'
      item << MhcDate.new.succ
    when /^(sun|mon|tue|wed|thu|fri|sat)/
      item << MhcDate.new.w_this(string.downcase)
    when /^\d{8}$/
      item << MhcDate.new(string)
    when /^\d{6}$/
      item << MhcDate.new(string + '01')
    when /^\d{4}$/
      item << MhcDate.new(string + '0101')
    else
      item << nil
    end
  }
  return item
end

date_from  = date_to = MhcDate.new
proxy_mode = false
proxy_auth = false

OPTS = {
  :category    => '!Holiday',
  :secret      => 'Private',
  :verbose     => false,
  :description => false,
}
opt = OptionParser.new
opt.on('--category=CATEGORY',
       'Pick only in CATEGORY. \'!\' and space separated multiple values are allowed') {
  |v| OPTS[:category] = v }
opt.on('--secret=CATEGORY',
       'Change the title of the event to \'SECRET\' space separated multiple values are allowed') {
  |v| OPTS[:secret] = v }
opt.on('--date={string[+n],string-string}',
       'Set a period of date. String is one of these: today, tomorrow, sun... sat, yyyymmdd, yyyymm, yyyyyyyymm lists all days in the month and yyyy lists all days in the year. List n+1 days of schedules if +n is given. The default value is \'today+0\'') { |v| 
  begin
    case (v)
    when /^([^-]+)\-(.+)/
      date_from, date_to = string_to_date2($1, $2) || raise
    when /^([^+]+)(\+(-?[\d]+))?/
      date_from, date_to = string_to_date($1, $3) || raise
    else
      raise
    end
  rescue
    abort("Abort: Date option is wrong")
  end
}
opt.on('--description', 'Add description') { OPTS[:description] = true }
opt.on('--verbose', 'Verbose mode') { OPTS[:verbose] = true }
#opt.on('--proxy-addr=addr', 'Set the address of http proxy') { |v| OPTS[:proxy_addr] = v }
#opt.on('--proxy-port=port', 'Set the port number of http proxy') { |v| OPTS[:proxy_port] = v }
#opt.on('--proxy-user=user', 'Set the username of http proxy') { |v| OPTS[:proxy_user] = v }
#opt.on('--proxy-pass=pass', 'Set the password of http proxy') { |v| OPTS[:proxy_pass] = v }
opt.parse!(ARGV)

if OPTS[:secret] =~ /!/
  OPTS[:secret] = OPTS[:secret].delete('!')
end
secrets = OPTS[:secret].split.collect{|x| x.downcase}

oauth_yaml = YAML.load_file(File.expand_path('~/.google-api.yaml'))
gcal_yaml  = YAML.load_file(File.expand_path('~/.gcal.gapi'))

client = Google::APIClient.new({:application_version => Version, :application_name => 'mhc2gcal'})
client.authorization.client_id = oauth_yaml["client_id"]
client.authorization.client_secret = oauth_yaml["client_secret"]
client.authorization.scope = oauth_yaml["scope"]
client.authorization.refresh_token = oauth_yaml["refresh_token"]
client.authorization.access_token = oauth_yaml["access_token"]
if client.authorization.refresh_token && client.authorization.expired?
  client.authorization.fetch_access_token!
end

if gcal_yaml["gcal_mode"] == 'delete'
  GCAL_DEL = true
else
  GCAL_DEL = false
end

if OPTS[:proxy_addr] && OPTS[:proxy_port]
#  GoogleCalendar::Service.proxy_addr=proxy_addr
#  GoogleCalendar::Service.proxy_port=proxy_port
  if OPTS[:proxy_user] && OPTS[:proxy_pass]
#    GoogleCalendar::Service.proxy_user=proxy_user
#    GoogleCalendar::Service.proxy_pass=proxy_pass
    puts "Connect to Google Calendar through proxy(#{proxy_user}:#{proxy_pass}@#{proxy_addr}:#{proxy_port})"
  else
    puts "Connect to Google Calendar through proxy(#{proxy_addr}:#{proxy_port})"
  end
else
  puts "Connect to Google Calendar directly"
end
srv = client.discovered_api('calendar', 'v3')

# init arrays for EVENTs in Google Calendar and MHC
gcal_gevs = []
mhc_gevs = []

# collect EVENTs from Google Calendarin the period of date
puts "Collect EVENTs from Google Calendar"
stg_date = date_from.dec(90)
stgcal = Time.mktime(stg_date.y.to_i, stg_date.m.to_i, stg_date.d.to_i, 0, 0, 0).gmtime.xmlschema
st = Time.mktime(date_from.y.to_i, date_from.m.to_i, date_from.d.to_i, 0, 0, 0).gmtime.xmlschema
en = Time.mktime(date_to.y.to_i, date_to.m.to_i, date_to.d.to_i, 23, 59, 59).gmtime.xmlschema

page_token = nil
result = client.execute(:api_method => srv.events.list,
                        :parameters => {'calendarId' => gcal_yaml["calender_id"],
                          'maxResults' => '100',
                          'timeZone' => gcal_yaml["timezone"],
                          'timeMin' => st,
                          'timeMax' => en})
while true
  events = result.data.items
  events.each do |event|
    if event['start']['date'] == nil or 
       event['end']['date'].to_s != Date.new(date_from.y.to_i, date_from.m.to_i, date_from.d.to_i).to_s
      gcal_gevs.push(event)
    end
  end
  if !(page_token = result.data.next_page_token)
    break
  end
  result = client.execute(:api_method => srv.events.list,
                          :parameters => {'calendarId' => gcal_yaml["calender_id"],
                            'maxResults' => '100',
                            'timeZone' => gcal_yaml["timezone"],
                            'timeMin' => st,
                            'timeMax' => en,
                            'pageToken' => page_token})
end

# collect EVENTs from MHC in the period of date
puts "Collect EVENTs from MHC"
db = MhcScheduleDB.new
db.search(date_from, date_to, OPTS[:category]).each{|date, mevs|
  mevs.each { |mev|
    secret_event = false
    secrets.each { |secret_category|
      regexp = Regexp.new(secret_category, nil)
      if regexp =~ mev.category_as_string.downcase
        secret_event = true
        break
      end
    }
    event = {}
    if secret_event == true
      event['summary'] = "SECRET"
    else
      event['summary'] = NKF.nkf("-w", mev.subject)
    end
    if mev.location and mev.location != ""
      event['location'] = NKF.nkf("-w", mev.location)
    end
    if mev.time_b
      st = Time.parse("#{date.y}/#{date.m}/#{date.d} #{mev.time_b}").xmlschema
      if mev.time_e
        if mev.time_e.to_i < 86400
          en = Time.parse("#{date.y}/#{date.m}/#{date.d} #{mev.time_e}").xmlschema
        else
          en = Time.parse("#{date.y}/#{date.m}/#{date.d} 23:59").xmlschema
        end
      else
        en = Time.parse("#{date.y}/#{date.m}/#{date.d} #{mev.time_b}").xmlschema
      end
      event['start'] = { 'dateTime' => st }
      event['end'] = { 'dateTime' => en }
    else
      allday_start = Date::new(date.y.to_i, date.m.to_i, date.d.to_i)
      allday_end = allday_start + 1
      event['start'] = { 'date' => allday_start.to_s }
      event['end'] = { 'date' => allday_end.to_s }
    end
    if OPTS[:description]
      headers = "Category: " + mev.category_as_string + "\n"
      switch = false
      mev.non_xsc_header.split("\n").each{|line|
        if line =~ /^(subject|from|to|cc|x-ur[il]):/i
          headers += line + "\n"
          switch = true
        elsif switch && line =~ /^[ \t]/
          headers += line + "\n"
        else
          switch = false
        end
      }
      event['description'] = NKF.nkf("-w", headers + "\n" + mev.description.to_s).gsub(/\s+\z/m,"")
    end
    mhc_gevs.push(event)
  }
}

gcal_gevs.uniq
mhc_gevs.uniq

# compare and delete EVENTs only in Google Calendar
gcal_gevs.each { |gcal_gev|
  find_the_same_event = false
  mhc_gevs.each { |mhc_gev|
    if mhc_gev['summary'] == gcal_gev['summary'] &&
        mhc_gev['location'] == gcal_gev['location'] &&
        mhc_gev['start'] == gcal_gev['start'].to_hash &&
        mhc_gev['end'] == gcal_gev['end'].to_hash &&
        mhc_gev['description'] == gcal_gev['description']
      find_the_same_event = true
      break
    end
  }
  if find_the_same_event != true
    if gcal_yaml["gcal_mode"] == 'delete'
      result = client.execute(:api_method => srv.events.delete,
                              :parameters => {
                                'calendarId' => gcal_yaml["calender_id"],
                                'eventId' => gcal_gev['id']
                              }) 
      if result.status > 300
        ret = JSON.parse(result.response.body)
        puts "ERROR: " + ret['error']['message']
      end
    end
    if OPTS[:verbose]
      if gcal_yaml["gcal_mode"] == 'delete'
        puts "Delete EVENT only in Google Calendar"
      else
        puts "Keep EVENT only in Google Calendar"
      end
      puts "  What: #{gcal_gev['summary']}"
      puts "  When: #{gcal_gev['start'].to_hash} - #{gcal_gev['end'].to_hash}"
      puts "  Where: #{gcal_gev['location']}"
    end
  end
}

# compare and create EVENTs only in MHC
mhc_gevs.each { |mhc_gev|
  find_the_same_event = false
  gcal_gevs.each { |gcal_gev|
    if mhc_gev['summary'] == gcal_gev['summary'] &&
        mhc_gev['location'] == gcal_gev['location'] &&
        mhc_gev['start'] == gcal_gev['start'].to_hash &&
        mhc_gev['end'] == gcal_gev['end'].to_hash &&
        mhc_gev['description'] == gcal_gev['description']
      find_the_same_event = true
      break
    end
  }
  if find_the_same_event != true
    result = client.execute(:api_method => srv.events.insert,
                            :parameters => {'calendarId' => gcal_yaml["calender_id"]},
                            :body => JSON.dump(mhc_gev),
                            :headers => {'Content-Type' => 'application/json'})
    if result.status > 300
      ret = JSON.parse(result.response.body)
      puts "ERROR: " + ret['error']['message']
    end
    if OPTS[:verbose]
      puts "Create EVENT only in MHC"
      puts "  What: #{mhc_gev['summary']}"
      puts "  When: #{mhc_gev['start']} - #{mhc_gev['end']}"
      puts "  Where: #{mhc_gev['location']}"
    end
  end
}
