# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone(phone)
  phone = phone.gsub(/[^0-9]+/, '')
  if phone.length == 10
    phone
  elsif (phone.length == 11) && phone.start_with?('1')
    phone[1..10]
  else
    'Wrong number!'
  end
end

def get_hour(date)
  Time.strptime(date, '%m/%d/%y %H:%S').hour
end

def get_weekday(date)
  time = Time.strptime(date, '%m/%d/%y %H:%S')
  time.strftime('%A')
end

def calculate_frequencies(data)
  result = data.each_with_object(Hash.new(0)) do |number, total|
    total[number] += 1
  end
  result.sort_by { |_key, value| -value }
end

def display_top_values(data)
  5.times do |i|
    puts "#{data[i].first}: #{data[i].last}"
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') { |file| file.puts form_letter }
end

puts 'EventManager initialized.'

contents = CSV.open('event_attendees.csv',
                    headers: true,
                    header_converters: :symbol)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

contents = CSV.open('event_attendees_full.csv',
                    headers: true,
                    header_converters: :symbol)

dates = contents.map do |row|
  row[:regdate]
end

hours = dates.map { |date| get_hour(date) }
weekdays = dates.map { |date| get_weekday(date) }

puts 'The top registration hours are:'
hour_frequencies = calculate_frequencies(hours)
display_top_values(hour_frequencies)

puts 'The top registration weekdays are'
weekday_frequencies = calculate_frequencies(weekdays)
display_top_values(weekday_frequencies)
