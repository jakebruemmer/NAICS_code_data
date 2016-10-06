require "nokogiri"
require "net/http"
require "csv"

# We'll start here for the scraping
STARTING_URI = URI("https://www.naics.com/naics-drilldown-table/")
TITLE_MATCH_REGEX = /(?<code>\d{2,6})\s(?<title>.*)|Sector\s(?<code>\d{2})\s--\s(?<title>.*)/

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

next_level_urls = []

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
        url_to_add = tr.css("a")[0].attributes['href'].value
        next_level_urls << url_to_add unless next_level_urls.include?(url_to_add)
        f << [tr.css(".first_child")[0].text.strip, tr.css("td")[1].text.strip, tr.css(".last_child")[0].text.strip]
      end
    end
  end
end

# This will get the descriptive and historical NAICS code information for each NAICS code
# Just write all of this information to one CSV that can then be joined in with all of the other CSVs
CSV.open("NAICS_low_level_detail.csv", "w") do |f|
  next_level_urls.each_with_index do |url, i|
    # Write the header
    if i == 0
      f << ["NAICS_code", "Title", "Description"]
      next
    end
    page = Nokogiri::HTML(Net::HTTP.get(URI(url)))

    # First check for two digit NAICS code pages because they're slightly different
    code = nil
    title = nil
    description = []
    if url.split("=")[-1].length == 2
      code = TITLE_MATCH_REGEX.match(page.xpath("//h3[not(@class)]")[0].text.gsub(/[[:space:]]/, " "))['code']
      title = TITLE_MATCH_REGEX.match(page.xpath("//h3[not(@class)]")[0].text.gsub(/[[:space:]]/, " "))['title']
      page.xpath("//div[contains(@class, 'entry-content')]/p").each do |p|
        description << p.text
      end
    else
      puts url
      puts page.xpath("//h3[contains(@class, 'sixDigit')]")[0].text
      code = TITLE_MATCH_REGEX.match(page.xpath("//h3[contains(@class, 'sixDigit')]")[0].text.gsub(/[[:space:]]/, " "))['code']
      title = TITLE_MATCH_REGEX.match(page.xpath("//h3[contains(@class, 'sixDigit')]")[0].text.gsub(/[[:space:]]/, " "))['title']
     
    # Use xpath to find paragraph and list element information
      description << page.xpath("//p[contains(@class, 'copy sixDigitCopy')]")[0].text

      list_items = page.xpath("//p[contains(@class, 'copy sixDigitCopy')]/../ul")
      list_items.css("li").each do |li|
        description << li.text
      end
    end

    description = description.join("\n")

    f << [code, title, description]
  end
end
