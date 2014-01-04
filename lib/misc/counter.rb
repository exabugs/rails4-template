# coding: utf-8

module Misc
  class Counter

    def self.graph(coll, min, max, type, dim)

      map = %Q|
        function() {
            var getYMDH = function (d) {
                d.setSeconds(0);
                d.setMilliseconds(0);

                yy = 0
                MM = 0
                dd = 0
                HH = 0
                mm = 0

                switch (type) {
                    case 4 : mm = d.getMinutes();
                    case 3 : HH = d.getHours();
                    case 2 : dd = d.getDate();
                    case 1 : MM = d.getMonth() + 1;
                    case 0 : yy = d.getFullYear();
                }

                MM = ('0' + MM).slice(-2);
                dd = ('0' + dd).slice(-2);
                HH = ('0' + HH).slice(-2);
                mm = ('0' + mm).slice(-2);

                return yy + '-' + MM + '-' + dd + ' ' + HH + ':' + mm + ':00';
            };

            emit({date: getYMDH(this.date)}, {count:1, time:this.time});
        }
      |

      reduce = %Q|
        function(key, values) {
            value = {count: 0, time: 0};
            for (var i = 0; i < values.length; i++) {
              value.count += values[i].count;
              value.time  += values[i].time;
            }
            return value;
        }
      |

      range = range(min, max, type, dim)

      result = coll.unscoped.where(:date.gte => min, :date.lte => max).map_reduce(map, reduce).out(inline: true).scope(type: type)

      prng = Random.new(1234)

      result.each do |log|
        key = log['_id']['date']
        if range.has_key?(key)
          value = log['value']
 #        range[key] = [value['count'], value['time'].to_f/value['count']]
          range[key] = [
            value['count'],
            value['count']*prng.rand,
            value['count']*prng.rand,
            value['time'].to_f/value['count'],
          ]
        end
      end

      range

    end

    def self.range(min, max, type, dim)
      # http://www.namaraii.com/rubytips/?%E6%97%A5%E4%BB%98%E3%81%A8%E6%99%82%E5%88%BB#l18

      format = [
        "%Y-00-00 00:00:00", # 0:年
        "%Y-%m-00 00:00:00", # 1:月
        "%Y-%m-%d 00:00:00", # 2:日
        "%Y-%m-%d %H:00:00", # 3:時
        "%Y-%m-%d %H:%M:00", # 4:分
      ]

      step = [
        60 * 60 * 24, # 0:年
        60 * 60 * 24, # 1:月
        60 * 60 * 24, # 2:日
        60 * 60,      # 3:時
        60,           # 4:分
      ]

      result = {}
      time = min
      while (time <= max) do
        result[time.strftime(format[type])] = Array.new(dim, 0)
        time += step[type]
      end
      result
    end

  end
end
