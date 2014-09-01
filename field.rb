#
# field.rb
#

class Game

  class Field
    include Constants
    WID = 18
    HEI = 30
    LEFT = CHAR*1
    RIGHT = LEFT+(CHAR*WID)-1
    TOP = 0
    BOTTOM =TOP+(CHAR*HEI)
    FLOORWID = 5

    def initialize
      #init imgs
      wallbit = SDL::Surface.loadBMP("image/wall.bmp")
      @wallimg = SDL::Surface.new(SDL::SWSURFACE,CHAR,CHAR*HEI,wallbit)
      HEI.times do |i|
        @wallimg.put(wallbit,0,i*CHAR)
      end
      
      #init variables
      @falltimer = Timer.new(Wait::FALL)
      @floors = Floors.new
      @items = Items.new
      
      reset
    end

    def reset
      #init @data
      @data = Array.new(HEI)
      for i in 0...HEI
        @data[i] = Array.new(WID,Chara::EMPTY)
      end

      for i in 0...FLOORWID
        @data[HEI-1][i+(WID-FLOORWID)/2] = Chara::BLOCK
      end
      
      #init variables
      @isfloor = false
      @falltimer.set_wait(Wait::FALL)
      
      #reset
      @floors.reset
      @falltimer.reset
      @items.reset
    end

    def [](x,y)
      @data[y][x]
    end

    def can_pass?(x,y)
      case @data[y][x]
      when Chara::EMPTY, Chara::STAR, Chara::PARA, Chara::OMORI
        return true
      else
        return false
      end
    end

    def act(hito,dt)
      ret=0
      @falltimer.wait(dt) do
        ret+=1 if scroll(hito,dt)
      end
      ret
    end

    def break(x,y)
      @data[y][x] = Chara::EMPTY
      @floors.break(self, x, y)
      Game.effects.add(:break,x,y)
    end
    
    def consume_item(x,y)
      @items.consume(x,y)
      @data[y][x] = Chara::EMPTY
    end

    def scroll_wait=(t)
      @falltimer.set_wait(t)
    end
    

    def scroll(hito,dt)
      #check collision
      return false if !can_pass?(hito.x, hito.y+1) && !$DEBUG_FASTEST 

      #scroll @data & @floors & @items
      for i in 0...HEI-1
        @data[i] = @data[i+1]
      end
      @data[HEI-1] = Array.new(WID,Chara::EMPTY)

      @floors.scroll
      @items.scroll
      Game.effects.scroll

      #make new floor(if @isfloor) & item(if @isfloor&&rand)
      if @isfloor then
        pos,type = @floors.generate
        for i in 0...FLOORWID
          @data[HEI-1][pos+i] = type
        end
        
        if rand(100) <= ITEM_PERCENT && type!=Chara::HARI then
          case rand(100)
          when 0..33
            type = Chara::STAR
          when 34..66
            type = Chara::PARA
          when 67..99
            type = Chara::OMORI
          end
          x = pos+(FLOORWID/2)
          y = HEI-2

          @items.generate(type,x,y)
          @data[y][x] = type
        end
      end

      #invert @isfloor
      @isfloor = (@isfloor ? false : true)

      #play sound
      if !can_pass?(hito.x,hito.y+1)
        case @data[hito.y+1][hito.x]
        when Chara::BLOCK
          SDL::Mixer.playChannel(-1,$sound.foot,0) if $CONF_SOUND
        end
      end
      return true
    end

    def draw(screen)
      #draw 2 walls
      screen.put(@wallimg,LEFT-CHAR*1,0)
      screen.put(@wallimg,RIGHT+1    ,0)
      #draw floors&items
      @floors.draw(screen)
      @items.draw(screen)
    end

    #---------------------------------------------------------------

    class Items
      include Constants
      Item = Struct.new(:type,:x,:y)
      
      def initialize
        tmp = Util.cut_image( CHAR,CHAR,3, SDL::Surface.loadBMP("image/item.bmp") )
        @imgs = {Chara::STAR=>tmp[0], Chara::PARA=>tmp[1], Chara::OMORI=>tmp[2]}
        reset
      end

      def reset
        @items=[]
      end

      def scroll
        @items.each{|item| item.y-=1 }
        @items.delete_if{|item| item.y<0}
      end
      
      def generate(type,x,y)
        @items << Item.new(type,x,y)
      end

      def consume(x,y)
        @items.delete_if{|item| x==item.x && y==item.y}
      end

      def draw(screen)
        @items.each do |item|
          screen.put(@imgs[item.type], LEFT+item.x*CHAR, item.y*CHAR)
        end
      end
      
    end
    
    #----------------------------------------------------------------
    class Floors
      include Constants
      Floor = Struct.new(:type,:x,:y,:broken)
      
      def initialize
        blockbit,haribit = Util.cut_image( CHAR,CHAR,2, SDL::Surface.loadBMP("image/floor.bmp") )

        blockimg = SDL::Surface.new(SDL::SWSURFACE,CHAR*FLOORWID,CHAR,blockbit)
        WID.times{|i| blockimg.put(blockbit,i*CHAR,0)}
        hariimg = SDL::Surface.new(SDL::SWSURFACE,CHAR*FLOORWID,CHAR,haribit)
        WID.times{|i| hariimg.put(haribit,i*CHAR,0)}

        @img = { Chara::BLOCK => blockimg, Chara::HARI => hariimg }
        self.reset
      end

      def reset
        @floors = []
        @floors << Floor.new(Chara::BLOCK, (WID-FLOORWID)/2, HEI-1, nil)
      end
      
      def scroll
        @floors.each do |item|
          item.y -= 1
        end
        @floors.delete_if {|item| item.y<0} 
      end

      def generate
        pos = rand(WID+FLOORWID) - FLOORWID
        pos = 0 if pos < 0
        pos = (WID-FLOORWID) if pos > (WID-FLOORWID)

        if rand(100) <= HARI_PER_FLOOR then
          type = Chara::HARI
        else
          type = Chara::BLOCK
        end

        @floors << Floor.new(type,pos,HEI-1, nil)
        return [pos,type]
      end

      def break(field,x,y)
        @floors.each do |floor|
          if floor.y == y
            floor.broken = x - floor.x
          end
        end
      end
      
      def draw(screen)
        @floors.each do |floor|
          screen.put(@img[floor.type], LEFT+floor.x*CHAR, TOP+floor.y*CHAR)
          if floor.broken != nil
            screen.fillRect( LEFT+(floor.x+floor.broken)*CHAR, TOP+floor.y*CHAR, CHAR, CHAR, [0,0,0])
          end
        end
      end
    end
    #----------------------------------------------------------------

  end
end
