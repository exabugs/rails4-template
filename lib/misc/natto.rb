# coding: utf-8
require 'nkf'  
module Misc
  class Natto

    def tf(text)
      terms = Hash.new
      count = 0;
      ::Natto::MeCab.new.parse(text) do |n|
        puts "#{n.surface}\t#{n.feature}"
        info = n.feature.force_encoding("UTF-8")
        if /^名詞/ =~ info && /代名詞/ !~ info
          word = n.surface.force_encoding("UTF-8")
          # 英数字 全角->半角, カタカナ 半角->全角
          word = NKF.nkf('-m0Z1 -w', word)
          word.downcase!
          terms[word] ||= 0
          terms[word] += 1
          count += 1
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
      tf1 = tf(text)
      ret = {}
      tf1.each {|a|
        ret[a[:k]] = a[:w]
      }
      ret
    end

  end
end
