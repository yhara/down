#
# other.rb
#

class Game
  
  #-----------------------------------------------------------------
  class Effects
    include Constants
    Effect = Struct.new(:type, :x, :y, :state, :timer)

    STATES_BREAK = 3
    STATES_PANG  = 3
    STATES_PTS   = 7
    
    def initialize
      src = SDL::Surface.loadBMP("image/effect.bmp")
      @breakimgs = Util.cut_image( 48,24,STATES_BREAK, src, 0,0,  [0,0,0])
      @pangimgs  = Util.cut_image( 48,24,STATES_PANG , src, 0,40, [0,0,0])
      @ptsimgs   = Util.cut_image( 16,16,STATES_PTS  , src, 0,64, [0,0,0])
      reset
    end

    def reset
      @effects = []
    end

    def add(type,x,y)
      case type
      when :break
        @effects<<Effect.new(:break,x,y,0,Timer.new(150))
      when :pang
        @effects<<Effect.new(:pang, x,y,0,Timer.new(150))
      when :pts
        @effects<<Effect.new(:pts,  x,y,0,Timer.new(20))
      end
    end

    def act(dt)
      #animation
      @effects.each do |effect|
        case effect.type
        when :break
          effect.timer.wait(dt){
            effect.state+=1
            effect.type = :dead if effect.state>=STATES_BREAK
          }
        when :pang
          effect.timer.wait(dt){
            effect.state+=1
            effect.type = :dead if effect.state>=STATES_PANG
          }
        when :pts
          effect.timer.wait(dt){
            effect.state+=1
            effect.type = :dead if effect.state>=STATES_PTS
          }
        end
      end
      
      #remove
      @effects.delete_if{|effect| effect.type==:dead}
    end

    def scroll
      @effects.each do |effect|
        effect.y-=1
        case effect.type
        when :break
          effect.type = :dead if effect.y==0
        when :pang
          effect.type = :dead if effect.y==0
        when :pts
          effect.type = :dead if effect.y==0
        end
      end
    end
    
    def draw(screen)
      @effects.each do |effect|
        case effect.type
        when :break
          screen.put(@breakimgs[effect.state], Field::LEFT+effect.x*CHAR-16, Field::TOP+effect.y*CHAR-24)
        when :pang
          screen.put(@pangimgs[effect.state],  Field::LEFT+effect.x*CHAR-16, Field::TOP+effect.y*CHAR-24)
        when :pts
          screen.put(@ptsimgs[effect.state],   Field::LEFT+effect.x*CHAR, Field::TOP+effect.y*CHAR-(effect.state*1))
        end
      end
    end

    end

  #-----------------------------------------------------------------
  class DamageGauge
    include Constants
    
    def reset
      @value=100
      @damaging=false
      @damagetimer.reset
      @state.reset
    end

    def initialize
      @damagetimer = Timer.new(Wait::DAMAGE)
      @flashtimer = Timer.new(Wait::GAUGEFLASH)
      @state=State.new(:flashing,:red)
      ## @color=
      reset
    end

    attr_reader :value

    def act(field,hito,dt)
      if field[hito.x, hito.y+1]==Chara::HARI && !hito.muteki? then
        #damage start
        if @damaging==false
          @damaging=true
          hito.start_flashing
          @state.on(:flashing)
        end
        @damagetimer.wait(dt) do
          SDL::Mixer.playChannel(Sound::CH_DAMAGE,$sound.damage,0) if !hito.gameover? && $CONF_SOUND
          @value-=1 if @value>0
        end
        @flashtimer.wait(dt) do
          if @state.red? then
            @state.off(:red)
          else
            @state.on(:red)
          end
        end
      else
        #damage stop
        if @damaging then
          @damaging=false
          hito.stop_flashing
          @state.off(:flashing)
          @state.off(:red)
          
          @damagetimer.reset
        end
      end
    end

    def draw(screen)
      color = (@state.red? ?  [255,0,0] : [255,255,255])
      screen.fillRect(Field::RIGHT+80, SCREEN_H/10*7, ((SCREEN_W-(CHAR*Field::WID)-108)*@value)/100, 16, color)
    end
  end
  #-----------------------------------------------------------------
  class System
    def initialize
      @time=0
      @count=0
      @fps=0

      @score=0
    end

    attr_reader :fps

    def count_fps(dt)
      @time+=dt
      @count+=1
      if @time>=1000 then
        @fps=@count
        @time-=1000
        @count=0
      end
    end
  end

  #-----------------------------------------------------------------
  module Chara
    include Constants

    # TODO: Use symbols instead
    EMPTY,WALL,BLOCK,HARI,HITO,SAKEBI = [0,1,2,3,4,5]
    STAR,PARA,OMORI,HITOPARA,HITOOMORI = [7,8,9,10,11]
    HITODEAD,HITOWAVE,HITOMUTEKI = [13,14,15]
  end
end
