require "icon_scraper"

IconScraper.scrape_with_params(
  url: "http://apps.gosnells.wa.gov.au/ICON",
  period: "last14days"
) do |record|
  IconScraper.save(record)
end
