require "nokogiri"
require "net/http"
require "csv"

# We'll start here for the scraping
STARTING_URI = URI("https://www.naics.com/naics-drilldown-table/")

base_page = Nokogiri::HTML(Net::HTTP.get(STARTING_URI))

# This will get the table that we're looking for since all of the stuff is in the only table on the page
starting_table = base_page.css("table")


# The data is nicely structured so we can just write directly to the CSV with simple iteration
drilldown_urls = []

CSV.open("top_level_codes.csv", "w") do |f|
  starting_table.children.each do |tr|
    # Take care of the header row
    if tr.css("a").empty? && !tr.css("th").empty?
      # This is only going to write the header row to the CSV file
      f << [tr.css(".first_child")[0].text.strip, tr.css("th")[1].text.strip, tr.css(".last_child")[0].text.strip]
    elsif !tr.css("a").empty?
      # Store the URLs to go through later      
      url_to_add = tr.css("td a")[1].attributes["href"].value
      drilldown_urls << url_to_add unless drilldown_urls.include?(url_to_add)
      f << [tr.css(".first_child")[0].text.strip, tr.css("td a")[1].text.strip, tr.css(".last_child")[0].text.strip]
    end
  end
end

drilldown_urls.each do |url|
  f_name = "#{url.split("/").last.split("=").last}.csv"
  CSV.open(f_name, "w") do |f|
    page = Nokogiri::HTML(Net::HTTP.get(URI(url)))
    starting_table = page.css("table")
    starting_table.children.each do |tr|
      # Take care of the header row
      if tr.css("a").empty? && !tr.css("th").empty?
        # This is only going to write the header row to the CSV file
        f << [tr.css(".first_child")[0].text.strip, tr.css("th")[1].text.strip, tr.css(".last_child")[0].text.strip]
      elsif !tr.css("a").empty?
        f << [tr.css(".first_child")[0].text.strip, tr.css("td")[1].text.strip, tr.css(".last_child")[0].text.strip]
      end
    end
  end
end
