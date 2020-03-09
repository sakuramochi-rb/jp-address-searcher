require 'csv'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object/json'
module Searcher
  class Address
    attr_accessor(
      :orgcode, # 全国地方公共団体コード JIS X401, X0402
      :zipcode_5, # 旧郵便番号 5桁
      :zipcode_7, # 旧郵便番号 7桁
      :prefectures_kana, # 都道府県
      :city_name_kana, # 市区町村
      :town_area_kana, # 町域
      :prefectures, # 都道府県
      :city_name, # 市区町村
      :town_area # 町域
    )
  end

  # 検索結果。1レコードが1郵便番号(7桁)単位
  class SearchResult
    attr_accessor :zipcode_7, :keyword, :addresses

    def initialize (args)
      self.zipcode_7 = args[:zipcode_7]
      self.keyword = args[:keyword]
      self.addresses = args[:addresses]
    end

    class_attribute :field_names, :records, :search_index_by_zipcode_7,  :search_index_by_ngram_keywords, :master_data_file_path, :search_result_cache, :preloaded
    SearchResult.records = []
    SearchResult.search_index_by_zipcode_7 = {}

    SearchResult.search_index_by_ngram_keywords = {}

    # KEN_ALL_CSVの保存場所
    SearchResult.master_data_file_path = "db/masterdata/KEN_ALL.CSV"
      # KEN_ALL.CSVの列定義
    SearchResult.field_names = [
        :orgcode, # 全国地方公共団体コード JIS X401, X0402
        :zipcode_5, # 旧郵便番号 5桁
        :zipcode_7, #郵便番号 7桁
        :prefectures_kana, # 都道府県
        :city_name_kana, # 市区町村
        :town_area_kana, # 町域
        :prefectures, # 都道府県
        :city_name, # 市区町村
        :town_area, # 町域
        :col10,
        :col11,
        :col12,
        :col13,
        :col14,
        :col15,
    ]
    SearchResult.search_result_cache = {}
    SearchResult.preloaded = false

    def SearchResult.preload
      # parse records. build indexes
      CSV.foreach(SearchResult.master_data_file_path, { :encoding => "CP932" }).with_index(0) do |line, index|
        record = {}
        line.each_with_index do |e,i|
          record[SearchResult.field_names[i]] = e
        end
        # 空白を取り除く
        record[:zipcode_5].strip!
        SearchResult.records[index] = record

        # 郵便番号のindexを構築
        if SearchResult.search_index_by_zipcode_7.has_key?(record[:zipcode_7])
          SearchResult.search_index_by_zipcode_7[record[:zipcode_7]].push(index)
        else
          SearchResult.search_index_by_zipcode_7[record[:zipcode_7]] = [index]
        end

        [:zipcode_7, :prefectures, :city_name, :town_area].each do |key|
          record[key].each_char.each_cons(2).map{|chars| chars.join}.each do |chars|
            if SearchResult.search_index_by_ngram_keywords[key] == nil
              SearchResult.search_index_by_ngram_keywords[key] = { chars => [index] }
            else
              SearchResult.search_index_by_ngram_keywords[key].has_key?(chars) ?
                  SearchResult.search_index_by_ngram_keywords[key][chars].push(index) :
                  SearchResult.search_index_by_ngram_keywords[key][chars] = [index]
            end
          end
        end
      end
      SearchResult.preloaded = true
    end
=begin
キーワードから、レコードを検索する
=end
    def SearchResult.find_by_keyword(keyword)
      search_results = _find_by_keyword(keyword)

      search_result_map_group_by_zipcode_7 =
        search_results.inject({}) do |prev,curr|
            record = SearchResult.records[curr]
            if prev.has_key?(record[:zipcode_7])
              prev[record[:zipcode_7]].push(record)
            else
              prev[record[:zipcode_7]] = [record]
            end
            prev
        end

      search_result_map_group_by_zipcode_7.keys.map do |key|
        SearchResult.new({
          :zipcode_7 => search_result_map_group_by_zipcode_7[key][0][:zipcode_7],
          :keyword => keyword,
          :addresses => search_result_map_group_by_zipcode_7[key]
        })
      end
    end

    class << self
      private
      def _find_by_keyword(keyword)
        SearchResult.preload unless SearchResult.preloaded?
        keyword = "" if keyword == nil || ! keyword.is_a?(String)
        keyword.strip!

        if SearchResult.search_result_cache.has_key?(keyword)
          return search_result_cache[keyword]
        end

        # 検索キーワードをindexに合わせてn-gram形式に分解
        ngram_keywords = keyword.length >= 2 ? keyword.each_char.each_cons(2).map{|chars| chars.join } : [keyword]

        search_results = []
        [:zipcode_7, :prefectures, :city_name, :town_area].each do |field_name|
          if keyword.length >= 2
            rch_results.push(
                ngram_keywords
                    .map {|ngram_keyword| SearchResult.search_index_by_ngram_keywords[field_name][ngram_keyword] || [] } # n-gram化したキーワードの一部に合致したら該当とみなす
                    .flatten)

          else
            # キーワードの長さがn-gramのnを下回るケース
            search_results.push(
              ngram_keywords
                .map {|ngram_keyword| SearchResult.search_index_by_ngram_keywords[field_name].keys.select{|key| key.include?(ngram_keyword) }} # n-gram形式のキーに部分一致した場合、そのキーのindexが有効とみなす
                .flatten
                .map {|ngram_keyword| SearchResult.search_index_by_ngram_keywords[field_name][ngram_keyword] || [] }
                .flatten)
          end
        end
        search_results.flatten!

        # 同一郵便番号が複数行に渡っている場合、分割された側のレコードも取得する
        search_results =
          search_results.map do |record_id|
            index = SearchResult.search_index_by_zipcode_7[SearchResult.records[record_id][:zipcode_7]]
            index !=nil && index.length > 1 ? index : record_id
          end
        search_results.flatten!
        search_results.uniq!
        SearchResult.search_result_cache[keyword] = search_results
        search_results
      end
    end
  end
end
