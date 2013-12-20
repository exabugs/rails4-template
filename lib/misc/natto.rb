# coding: utf-8
require 'nkf'  
module Misc
  class Natto

    def self.tf(text, nbest)

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

    def self.tfidf(coll, text, nbest)
      tf = tf(text, nbest)

      cond = tf.inject({}) do |ret, a|
        ret[a[:k]] = a[:w]
        ret
      end

      name = coll.collection_name.to_s + "_idf"
      idf = IDF.with(collection: name).find(cond.keys).inject({}) do |ret, obj|
        ret[obj._id] = obj.value
        ret
      end

      l = 0
      n = Math.log(coll.count())
      tf.each do |obj|
        obj[:w] = obj[:v] * (idf[obj[:k]] ? idf[obj[:k]] : n)
        l += obj[:w] ** 2
      end

      {:v => tf, :l => Math.sqrt(l)}

    end

    class IDF
      include Mongoid::Document
      field :value, type: Float
    end
    
    def self.to_array(tf)
      tf[:v].inject([]) do |ret, obj|
        ret << obj[:k]
        ret
      end
    end

    def self.to_hash(tf)
      tf[:v].inject({}) do |ret, obj|
        ret[obj[:k]] = obj[:w]
        ret
      end
    end

    def self.search(coll, text)
      tf = tfidf(coll, text, 1)
      coll.where("tf.v.k" => { "$all" => to_array(tf)})
    end

    def self.similar_search(coll, text)

      tf = tfidf(coll, text, 1)
      tf[:w] = to_hash(tf)

      map = %Q|
        function() {
          var sum = 0;
          var a = this.tf.v;
          for (var i = 0; i < a.length; i++) {
            var info = a[i];
            if (tf.w[info.k]) {
              sum += info.w * tf.w[info.k];
            }
          }
          if (0 < sum) emit(this._id, sum / this.tf.l / tf.l);
        }
      |

      reduce = %Q|
        function(key, values) {
          return values[0];
        }
      |

      result = coll.where("tf.v.k" => {"$in" => to_array(tf)}).map_reduce(map, reduce)
      .out(inline: true).scope(tf: tf)

      result = result.sort{|x, y| y["value"] <=> x["value"] }

      result.inject([]) do |ret, t|
        object = coll.find(t["_id"])
        if (object)
          object.similarity = t["value"]
          ret << object 
        end
        ret
      end

    end

  end
end
