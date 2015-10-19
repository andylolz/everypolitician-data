require 'colorize'
require 'csv'
require 'pry'
require 'roman-numerals'
require 'wikidata'

def fetch_term(q)
  t = Wikidata::Item.find(q) or raise "No such item"
  name = t.labels['fr'].value
  data = { 
    id: RomanNumerals.to_decimal(name.sub(/e.*/,'')),
    name: name.sub(' française',''),
    start_date: t.property('P580').date.to_date.to_s,
    end_date: t.property('P582') ? t.property('P582').date.to_date.to_s : nil,
    wikidata: q,
  }
  puts data.values.to_csv

  if prev = t.property('P155')
    fetch_term(prev.id) 
  end
end

puts %w(id name start_date end_date wikidata).to_csv
# Start at most-recent term, and follow the 'follows' backwards
fetch_term('Q3570385')
