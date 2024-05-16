require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def save_regs_by_hour(regs_hash)
  File.open('regs_by_hour', 'w') do |file|
    file.puts 'Hour  | Number of Registrations'
    file.puts '------------------------------'
    regs_hash.each do |key, value|
      file.puts "#{format('%02d', key)}-#{format('%02d', (key + 1) % 24)} | #{value}"
    end
    file.puts '------------------------------'
  end
end

def save_regs_by_day(regs_hash)
  File.open('regs_by_day', 'w') do |file|
    file.puts 'Weekday | Number of Registrations'
    file.puts '------------------------------'
    regs_hash.each do |key, value|
      file.puts "#{key}       | #{value}"
    end
    file.puts '------------------------------'
  end
end

def clean_phone_number(num)
  num = num.scan(/\d/).join

  if num.length == 10
    return num
  elsif num.length == 11 && num[0] == '1'
    return num[1..]
  end

  'Invalid Number.'
end

def get_registration_date(datetime_string)
  format = '%m/%d/%y %H:%M'
  Time.strptime(datetime_string, format)
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)
hours_array = []
days_array = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
  hours_array.push(get_registration_date(row[:regdate]).strftime('%H:%M')[0..1].to_i)
  days_array.push(get_registration_date(row[:regdate]).wday)
end

regs_by_hour = hours_array.tally.sort_by { |key, _count| key }.to_h
regs_by_wday = days_array.tally.sort_by { |key, _count| key }.to_h

save_regs_by_hour(regs_by_hour)
save_regs_by_day(regs_by_wday)
