module Misc
  class Image < Magick::Image
    attr_reader :width, :height, :margin
    def initialize(rows, columns, margin)
      super(rows, columns)
      @margin = margin
      @width  = self.columns - @margin * 2
      @height = self.rows    - @margin * 2
    end
    def new_draw
      Draw.new(self)
    end
  end
  class Draw < Magick::Draw
    def initialize(image)
      super()
      @image = image
      @h = @image.margin + @image.height
      @w = @image.margin
      self.font = 'lib/fonts/meiryo.ttc'
      @annotate_info = [
        [Magick::NorthGravity, @image.columns/2, 0],
        [Magick::EastGravity, -@image.width, @image.rows/2],
        [Magick::WestGravity, 0, @image.rows/2],
      ]
    end
    def line(color, x0, y0, x1, y1)
      fill('transparent')
      stroke(color)
      super(@w+x0, @h-y0, @w+x1, @h-y1)
    end
    
    def polyline(color, *p)
      ret = []
      size = p.size
      i = 0
      while (i < size) do
        ret << @w+p[i] << @h-p[i+1]
        i += 2
      end
      fill('transparent')
      stroke(color)
      super(*ret)
    end

    def rectangle(color, x0, y0, x1, y1)
      fill(color)
      stroke(color)
      super(@w+x0, @h-y0, @w+x1, @h-y1)
    end
    def text(x,y,text)
      super(@w+x, @h-y, text)
    end

    def annotate(color, x, y, text, type)
      info = @annotate_info[type]
      super(@image, 0, 0, @w+x-info[1], @h-y-info[2], text) {
        self.gravity = info[0]
        self.fill = color
      }
    end
    
    #          text.annotate(canvas, 0, width/2, -(x+margin), height+margin+4, x.to_s) {
    #        self.fill = '#cc9900'
    #        #self.font_weight = BoldWeight
    #        #self.pointsize = 20
    #      }
      
    #    def annotate(img, width, height, x, y, text)
    #          dr = MyDraw.new(canvas, margin)
    #    dr.gravity=SouthWestGravity
    #    dr.stroke('red')
    #    dr.text(20, 180, "SW (20,180)")
    #    dr.draw(canvas)
    #      super(img, width, height, x, y, text)
    #    end
  end
end


