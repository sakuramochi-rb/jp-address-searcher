require 'csv'

namespace :searcher_index do
	task :build => :environment do |task,args|
		CSV.read
	end
end
