namespace :searcher do
	task :execute, [:keyword] => :environment do |task,args|
    Searcher::SearchResult.find_by_keyword(args[:keyword]).each do |record|
      prefectures = record.addresses[0][:prefectures]
      city_name = record.addresses[0][:city_name]
      town_area = record.addresses.map{|e| e[:town_area]}.join
      puts "\"#{record.zipcode_7}\",\"#{prefectures}\",\"#{city_name}\",\"#{town_area}\""
    end
	end
end
