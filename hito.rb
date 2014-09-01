#
# hito.rb
#

class Game
  class Hito
    include Constants

    def initialize
      @normimgs = Util.cut_image( CHAR,CHAR,7, SDL::Surface.loadBMP("image/hito.bmp") )
      @paraimgs = Util.cut_image( CHAR,CHAR,7, SDL::Surface.loadBMP("image/para.bmp") )
      @omoriimgs = Util.cut_image(CHAR,CHAR,7, SDL::Surface.loadBMP("image/omori.bmp") )
      @sakebiimg = SDL::Surface.loadBMP("image/sakebi.bmp")

      @walktimer = Timer.new(Wait::WALK)
      @flashtimer = Timer.new(Wait::HITOFLASH)
      @wavetimer = Timer.new(Wait::HITOWAVE)
      @mutekiflashtimer = Timer.new(Wait::MUTEKIFLASH)
      @haribreaktimer = Timer.new(Wait::HARIBREAK)
      @state = State.new(:flashing, :muteki, :para, :omori, :gameover)

      self.reset
    end

    def reset
      @x = (Field::WID/2)-1
      @y = Field::HEI/2
      @hitoimgs = @normimgs
      @hitonum  = 0
      
      @walktimer.reset
      @flashtimer.reset
      @wavetimer.reset
      @state.reset
    end
    
    attr_reader :x,:y
    
    #state controllers
    def start_flashing
      @state.on(:flashing)
    end
    def stop_flashing
      @state.off(:flashing)
      @hitonum = 0
    end
    def muteki?
      @state.muteki?
    end
    def omori?
      @state.omori?
    end
    def gameover?
      @state.gameover?
    end
    def gameover
      @state.on(:gameover)
      start_flashing
    end

    def act(field,key,dt)
      ret = 0 #0pts.
      
      #move (if keydown)
      if !(@state.gameover?)
        @walktimer.wait(dt) do
          #move
          return 0 if key.left && key.right
          if key.left then
            @x-=1 if @x>0 && field.can_pass?(@x-1,@y)
          elsif key.right then
            @x+=1 if @x<Field::WID-1 && field.can_pass?(@x+1,@y)
          end
        end
      
        #get item
        case field[@x,@y]
        when Chara::STAR
          field.consume_item(@x,@y)
          @state.on(:muteki)
          @mutekistart = SDL::getTicks
          SDL::Mixer.pauseMusic if $CONF_MUSIC
          SDL::Mixer.halt(Sound::CH_MUTEKI) if $CONF_SOUND
          SDL::Mixer.playChannel(Sound::CH_MUTEKI,$sound.muteki,0) if $CONF_SOUND
        when Chara::PARA
          field.consume_item(@x,@y)
          field.scroll_wait = Wait::FALL_PARA
          @state.on(:para)
          @state.off(:omori)
          @hitoimgs = @paraimgs
          SDL::Mixer.playChannel(-1,$sound.getpara,0) if $CONF_SOUND
        when Chara::OMORI
          field.consume_item(@x,@y)
          field.scroll_wait = Wait::FALL_OMORI
          @state.on(:omori)
          @state.off(:para)
          @hitoimgs = @omoriimgs
          SDL::Mixer.playChannel(-1,$sound.getomori,0) if $CONF_SOUND
        end

        #stop omori
        if @state.omori? && @state.muteki? && (SDL::getTicks - @mutekistart >= (MUTEKI_TIME*0.8))
          @state.off(:omori)
          @hitoimgs = @normimgs
          field.scroll_wait = Wait::FALL
        end
        #stop muteki
        if @state.muteki? && (SDL::getTicks - @mutekistart >= MUTEKI_TIME)
          @state.off(:muteki)
          @hitonum = 0
          SDL::Mixer.resumeMusic if $CONF_MUSIC
        end
        #stop para
        if @state.para? && field[@x,@y+1]==Chara::HARI && !@state.muteki?
          @state.off(:para)
          @hitoimgs = @normimgs
          field.scroll_wait = Wait::FALL
          SDL::Mixer.playChannel(-1,$sound.spank,0) if $CONF_SOUND
          Game.effects.add(:pang,@x,@y)
        end

        #break!
        if @state.omori? && @state.muteki?
          if field[@x,@y+1]==Chara::BLOCK
            field.break(@x, @y+1)
            SDL::Mixer.playChannel(Sound::CH_BREAK,$sound.break,0) if $CONF_SOUND
            #Game.effects.add(:pts,@x,@y)
            #ret = 10 # 10pts.
          elsif field[@x,@y+1]==Chara::HARI
            @haribreaktimer.wait(dt) do
              field.break(@x,@y+1)
              SDL::Mixer.playChannel(Sound::CH_BREAK,$sound.break,0) if $CONF_SOUND
            end
          end
        end
        
      end
      
      #decide which img to show
      if @state.flashing? then
        @flashtimer.wait(dt) { @hitonum = (1 - @hitonum) } #0:white 1:red
      end
      if @state.muteki? then
        @mutekiflashtimer.wait(dt) { @hitonum+=1; @hitonum=0 if @hitonum>6 }
        #newwait = (Wait::MUTEKIFLASH * (MUTEKI_TIME-(SDL::getTicks-@mutekistart)) / MUTEKI_TIME )+1
        # @mutekiflashtimer.set_wait(newwait)
      end

      return ret
    end

    def draw(screen)
      screen.put(@hitoimgs[@hitonum], Field::LEFT+@x*CHAR, Field::TOP+@y*CHAR)

      if @state.gameover? then
        if @x<(Field::WID/2)
          screen.put(@sakebiimg, Field::LEFT+(@x+1)*CHAR, Field::TOP+@y*CHAR)
        else
          screen.put(@sakebiimg, Field::LEFT+(@x-2)*CHAR, Field::TOP+@y*CHAR)
        end
      end
    end
  end
end
