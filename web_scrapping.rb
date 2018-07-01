require 'open-uri'
require 'csv'

def restrict html, starting_regexp, stopping_regexp
  start = html.index(starting_regexp)
  stop = html.index(stopping_regexp, start)
  html[start..stop]
end

def scrape_title html
  %r{<h1 property="v:itemreviewed">(.*?)</h1>} =~ html
  $1
end

def clean_author str
  str.split(' ').join(' ')
end

def scrape_authors html
  authors = %r{<a.*?href=".*?autori.*?"\s*title=".*?".*?>(.+?)</a\s*>}m
  html.scan(authors).flatten.map do |author|
    clean_author(author)
  end
end

def scrape_price html
  %r{<span>\s*Naša cena:\s*</span>(.*?),<sup>(.*?)\s*</sup>} =~ html
  $1.concat('.', $2)
end

def scrape_book_info html
  retval = {}
  retval[:title] = scrape_title html
  retval[:authors] = scrape_authors html
  retval[:price] = scrape_price html
  retval
end

def scrape_links html
  links = %r{<h3 class="short"><a href=(.*?)\s*title=".*?">.*?</a></h3>}
  html.scan(links).flatten.map do |link|
    link.tr('"', '')
  end
end

def scrape_affinity_list html
  start = %r{<div class=".*?">\s*<h2>\s*Odporúčame tieto knihy\s*</h2>}
  stop = %r{<div class="product_page_banner">}
  text = restrict html, start, stop
  scrape_links(text)
end

def output_csv arr
  CSV.open('result.csv', 'w') do |writer|
    header = []
    arr.each.with_index do |book, index|
      temp = []
      book.each_pair do |k, v|
        header << k if index == 0
        v = v.join(', ') if v.class == Array
        temp << v
      end
      writer << header if index == 0
      writer << temp
    end
  end
end

def trip url, steps = 10
  whole_trip = []
  start = %r{<header>\s*<h1}m
  stop = %r{<div\s*class="original-price"\s*>}

  steps.times do
    html = open(url).read
    text = restrict(html, start, stop)
    book_info = scrape_book_info(text)
    book_info[:url] = url
    whole_trip << book_info

    aff_list = scrape_affinity_list(html)

    url = aff_list.reject do |link|
      whole_trip.any? do |book|
        book[:url] == link
      end
    end[0]
    break if url == nil
  end
  output_csv(whole_trip)
end

trip 'https://www.pantarhei.sk/knihy/pre-deti-a-mladez/pre-deti-a-mladez-ostatne/vsetci-za-jedneho.html'
