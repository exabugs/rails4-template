# coding: utf-8
require 'nkf'  
module Misc
  class Natto

    def self.tf(text, nbest = 2)

      # 英数字 全角->半角, カタカナ 半角->全角
      text = NKF.nkf('-m0Z1 -w', text)

      array = text.split(/[。、 ]/)
      mecab = ::Natto::MeCab.new(:nbest => nbest)
      terms = Hash.new(0)
      count = 0;
      
      check_0 = {"名詞"=>1}
      check_1 = {"一般"=>1,"固有名詞"=>1, "数"=>1, "サ変接続"=>1, "形容動詞語幹"=>1, "副詞可能"=>1}

      array.each do |tgt|
        mecab.parse(tgt) do |n|
          puts "#{n.surface}\t#{n.feature}"
          info = n.feature.force_encoding("UTF-8").split(",")
          if check_0[info[0]] && check_1[info[1]]
            puts "ーーーーーーーーーーーーーーーーーーーーー #{n.surface}\t#{n.feature}"
            word = n.surface.force_encoding("UTF-8")
            word.downcase!
            terms[word] += 1
            count += 1
          end
        end
      end

      terms.inject([]) do |ret, (key,value)|
        f = value.to_f/count
        ret << {:k => key, :v => f, :w => f}
        ret
      end

    end

    def self.to_tf_hash(text)
      tf(text,1).inject({}) do |ret, a|
        ret[a[:k]] = a[:w]
        ret
      end
    end

    def self.search(collection, text)
      condition = to_tf_hash(text)
      collection.where("tf.v.k" => { "$all" => condition.keys})
    end

    def self.similar_search(collection, text)
      condition = to_tf_hash(text)

      map = %Q|
        function() {
          var sum = 0;
          var a = this.tf.v;
          for (var i = 0; i < a.length; i++) {
            var info = a[i];
            if (condition[info.k]) {
              sum += info.w * condition[info.k];
            }
          }
          if (0 < sum) emit(this._id, sum / this.tf.l);
        }
      |

      reduce = %Q|
        function(key, values) {
          return values[0];
        }
      |

      result = collection.where("tf.v.k" => {"$in" => condition.keys}).map_reduce(map, reduce)
        .out(inline: true).scope(condition: condition)

      result = result.sort{|x, y| y["value"] <=> x["value"] }

      result.inject([]) do |ret, t|
        object = collection.find(t["_id"])
        if (object)
          object.similarity = t["value"]
          ret << object 
        end
        ret
      end

    end

  end
end

