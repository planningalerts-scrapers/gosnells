require 'scraperwiki'
require 'mechanize'

use_cache = false
cache_fn = 'cache.html'
starting_url = 'http://apps.gosnells.wa.gov.au/ICON/Pages/XC.Track/SearchApplication.aspx?d=thisweek&k=LodgementDate'
comment_url = 'mailto:council@gosnells.wa.gov.au?Subject='

def clean(a)
  a.gsub("\r", ' ').gsub("\n", ' ').squeeze(' ').strip
end

def scrape_table(doc, comment_url)
  doc.at('#ctl00_ctMain_pnlMain').search('.result').each do |result|
    h = tds.map{|td| td.inner_html}

    record = {
      'date_received' => Date.strptime(result.at('div').text.gsub(/.*Submitted: /m, ''), '%d/%m/%Y').to_s,
      'description' => clean_whitespace(result.at('div').children[4].text),
    }
    
    if ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? 
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  end
end

if use_cache and File.exist?(cache_fn)
  body = ''
  File.open(cache_fn, 'r') {|f| body = f.read() }
  doc = Nokogiri(body)
else
  agent = Mechanize.new
  # Click on "I Agree"
  doc = agent.get(starting_url)
  doc = doc.forms.first.submit(doc.forms.first.button_with(:value => "I Agree"), "Accept-Encoding" => "identity")
  File.open(cache_fn, 'w') {|f| f.write(doc.body) }
end

found = false
doc.search('.result').each do |result|
  found = true

  a = result.search('a')[0]
  council_reference = a.inner_text
  address = clean(result.search('strong')[0].inner_text)
  info_url = (URI(starting_url) + a.attribute('href')).to_s

  lodged = clean(result.children[10].children[0].inner_text)
  lodged =~ /Lodged: (\S+) /;
  on_notice_from = $~.captures.first;

  record = {
    'council_reference' => council_reference,
    'address' => address,
    'description' => result.children[4].inner_text,
    'info_url' => info_url,
    'comment_url' => comment_url + CGI::escape("Planning application " + council_reference),
    'date_scraped' => Date.today.to_s,
    'on_notice_from' => Date.parse(on_notice_from).to_s,
  }
  if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
    ScraperWiki.save_sqlite(['council_reference'], record)
  else
    puts 'Skipping already saved record ' + record['council_reference']
  end
end

raise "No records found." unless found
