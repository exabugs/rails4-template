# coding: utf-8
module Misc

  class Graph

    @@line_color = [
      '#ff0000',
      '#00ff00',
      '#00ffff',
      '#0000ff',
    ]
    @@x_axis = ["年", "月", "日", "時", "分"]

    @@annotate_color = '#333333'

    def initialize(width, height, margin)
      @width  = width  - margin * 2
      @height = height - margin * 2
      @margin = margin

      @image = Misc::Image.new(width, height, @margin) do
        self.background_color = '#ffffdd'
      end

    end

    def line(range, dim, bar, type)

      max = Array.new(dim, Float::MIN)
      min = Array.new(dim, Float::MAX)

      range.each do |key, value|
        sum = 0
        0.upto(dim-1) do |i|
          val = value[i]
          max[i] = [max[i], val].max
          min[i] = [min[i], val].min
        end
        0.upto(bar-1) do |i|
          sum += value[i]
          max[i] = [max[i], sum].max
        end
      end

      dr = @image.new_draw

      #dr.translate(0, 0)

      w_ = @width.to_f / range.size
      #w2 = w_ - 5
      #棒グラフの幅。最大5ピクセルの隙間を開ける。
      w2 = w_ - [0, 5 - 12.0 / w_].max

      h = Array.new(dim) # 値:ピクセル の比率
      p = Array.new(dim) # 折れ線グラフの点
      k = Array.new(dim) # 桁
      l = Array.new(dim) # 桁


      # y軸 調整
      0.upto(dim-1) do |i|
        l[i] = Math.log10(max[i]).floor
        k[i] = 10.0 ** l[i]
        max[i] = (max[i] / k[i]).ceil * k[i]

        # 分割数 調整 (分割数を 6〜10 に調整する)
        k[i] /= 5 if (max[i]/k[i] == 2)
        k[i] /= 2 if (max[i]/k[i] <= 5)
      end
      
      max_div = [max[dim-1]/k[dim-1], max[bar-1]/k[bar-1]].max

      0.upto(dim-1) do |i|
        # 分割数を揃える
        div = max[i]/k[i]
        max[i] = k[i] * [div, max_div].max

        h[i] = @height / (max[i] - min[i])
        p[i] = []
      end

      # y軸 メモリ
      0.upto(max_div) do |i|
        lv = i * k[bar-1]
        rv = i * k[dim-1]

        lvf = [0, l[bar-1]-1].min.abs # 小数以下表示桁数
        rvf = [0, l[dim-1]-1].min.abs # 小数以下表示桁数

        y = lv * h[bar-1]
        dr.stroke_dasharray(1,2) if (lv % (10 ** l[bar-1]) != 0)
        dr.line(@@annotate_color, 0, y, @width, y)
        dr.stroke_dasharray()
        dr.annotate(@@annotate_color, 0, 0,        0, y, sprintf("%.*f", lvf, lv), 1)
        dr.annotate(@@annotate_color, 0, 0, @width+2, y, sprintf("%.*f", rvf, rv), 2)
        #  dr.annotate(@@annotate_color, 0, 0,-@width+2, y, rv.to_s, 1)
      end
      
      dr.annotate(@@annotate_color, 0, 0, @width+2,  -12, @@x_axis[type  ], 2)
      dr.annotate(@@annotate_color, 0, 0, @width+2,  -24, @@x_axis[type-1], 2)
      

      # x軸の間引き
      step = to_yakusuu((17.4 / w_).ceil, type)
      prev_label = ""

      range.each.with_index(0) do |(key, value), i|

        x = i * w_

        # 棒グラフ
        prev = 0
        0.upto(bar-1) do |i|
          y = value[i] * h[bar-1]
          dr.rectangle(@@line_color[i], x, prev, x + w2, prev + y)
          prev += y
        end

        # 折れ線グラフ
        bar.upto(dim-1) do |i|
          p[i] << x + w2/2 << value[i] * h[i] if 0 < value[i]
        end

        # x軸 メモリ
        label = x_label(key,type)
        if label.to_i % step == 0 then
          x__ = x + w2/2 + 2
          dr.annotate(@@annotate_color, 0, 0, x__,  -3, label, 0)
          label = x_label(key,type-1)
          dr.annotate(@@annotate_color, 0, 0, x__, -14, label, 0) if label != prev_label
          prev_label = label
        end

      end

      bar.upto(dim-1) do |i|
        dr.polyline(@@line_color[i], *p[i])
      end

      dr.draw(@image)

    end

    def x_label(date, type)
      date = date.to_s
      # 0123456789012345678
      # yyyy/MM/dd hh:mm:ss
      case type
      when 0
        date[0, 4]
      when 1
        date[5, 2]
      when 2
        date[8, 2]
      when 3
        date[11, 2]
      when 4
        date[14, 2]
      end
    end

    def to_yakusuu(n, type)
      max = case type
      when 0
        2000
      when 1
        12
      when 2
        50
      when 3
        24
      when 4
        60
      end
      n.upto(max) do |i|
        return i if max % i == 0
      end
    end
    
    def to_blob
      @image.format = 'PNG'
      @image.to_blob
    end
  end

end


