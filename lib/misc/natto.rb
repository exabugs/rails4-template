# coding: utf-8
require 'nkf'  
module Misc
  class Natto

    def tf(text, nbest = 2)

      # 英数字 全角->半角, カタカナ 半角->全角
      text = NKF.nkf('-m0Z1 -w', text)

      array = text.split(/[。、 ]/)
      mecab = ::Natto::MeCab.new(:nbest => nbest)
      terms = Hash.new
      count = 0;
      
      check_0 = {"名詞"=>1}
      check_1 = {"一般"=>1,"固有名詞"=>1, "数"=>1, "サ変接続"=>1, "形容動詞語幹"=>1, "副詞可能"=>1}

      array.each do |tgt|
        mecab.parse(tgt) do |n|
          #puts "#{n.surface}\t#{n.feature}"
          info = n.feature.force_encoding("UTF-8").split(",")
          if check_0[info[0]] && check_1[info[1]]
            #puts "ーーーーーーーーーーーーーーーーーーーーー #{n.surface}\t#{n.feature}"
            word = n.surface.force_encoding("UTF-8")
            word.downcase!
            terms[word] ||= 0
            terms[word] += 1
            count += 1
          end
        end
      end
      ret = Array.new
      terms.each {|key,value|
        f = value.to_f/count
        ret << {:k => key, :v => f, :w => f}
      }
      ret
    end

    def condition(text)
      tf1 = tf(text, 1)
      ret = {}
      tf1.each {|a|
        ret[a[:k]] = a[:w]
      }
      ret
    end

  end
end

