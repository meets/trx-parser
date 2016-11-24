require 'rexml/document'
require 'csv'
require 'pry'


class CsvRow
  attr_accessor :category, :class, :method, :id, :outcome

  def outcome_s
    return "未実行" if outcome == "NotRunnable"
    return "未定義" if outcome == "Inconclusive"
    return "失敗" if outcome == "Failed"
    return "成功" if outcome == "Passed"
    outcome
  end

  def to_a
    [@id, @category, @class, @method, outcome_s]
  end
end


File.open('./tmp/test.trx') do |file|

  res = file.read


  doc = REXML::Document.new res

  results = []
  doc.elements.each('/TestRun/TestDefinitions/UnitTest') { |e|
    item = CsvRow.new

    # ID
    item.id = e.attributes["id"]

    # カテゴリリスト
    categories = e.get_elements("TestCategory/TestCategoryItem")
    unless categories.nil?
      item.category = categories.map{|c| c.attributes["TestCategory"] }.join(" | ")
    end

    # フィーチャー
    properties = e.get_elements("Properties/Property")
    unless properties.nil?
      properties.each { |prop|
        key = prop.get_elements("Key")[0].get_text
        value = prop.get_elements("Value")[0].get_text
        next if key == "__Internal_AsyncTypeName__" || key == "__Internal_DeclaringClassName__"
        item.category = "#{key} [#{value}]"
      }
    end

    # テストメソッド
    test_method = e.get_elements("TestMethod")[0]
    item.class = test_method.attributes["className"].match(/([^,]+)/)[1].gsub(/\+/, ' ')
    item.method = test_method.attributes["name"]

    results << item
  }

  # カテゴリ名順に並べる
  results.sort_by! {|e|
    e.category
  }

  # 結果
  outcomes = {}
  doc.elements.each('/TestRun/Results/UnitTestResult') { |e|
    id = e.attributes["testId"]
    outcome = e.attributes["outcome"]
    outcomes[id] = outcome
  }

  # CSV出力
  CSV.open("./tmp/out.csv", "wb") do |csv|

    csv << ["ID", "カテゴリ", "クラス名", "メソッド名", "結果"]
    results.each { |item|

      item.outcome = outcomes[item.id]
      csv << item.to_a
    }
  end

end
