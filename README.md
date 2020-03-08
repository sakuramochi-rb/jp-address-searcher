# README

郵便番号CSV http://www.post.japanpost.jp/zipcode/dl/kogaki/zip/ken_all.zip より、都道府県, 市区町村, 町域の日本語検索を行うプログラム


## 使用方法

rake(rails) taskを実行してください。第一引数が検索キーワードになります

### 実行例
```
bundle exec rails searcher:execute["本木東町"]
```
### 出力例
```
"1230854","東京都","足立区","本木東町"
```


初回検索時に読み込みを行うため、複数回実行する場合はrails consoleから呼び出す事で高速に実行できます
```
bundle exec rails console

Searcher::SearchResult.preload
Searcher::SearchResult.find_by_keyword("本木東町")
```

