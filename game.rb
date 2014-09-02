#
# game.rb
#

require 'misc.rb'
require 'field.rb'
require 'hito.rb'
require 'other.rb'
require 'singleton'

#debug flags
# $DEBUG_FASTEST = true
# $DEBUG_SHOW_FIELDDATA = true

class Game
  include Constants
  include Singleton
  
  FONT_GAME = "image/boxfont2.ttf"
  FONT_GAME_SIZE = 20

  def init(screen,highscores)
    @screen = screen

    @font=SDL::TTF.open(FONT_GAME, FONT_GAME_SIZE)
    @font.style=SDL::TTF::STYLE_NORMAL

    #init objects
    @field = Field.new
    @hito  = Hito.new
    @gauge = DamageGauge.new
    @system= System.new
    @effects=Effects.new
    
    @highscores=highscores
    @score=0
    @state=State.new(:gameover)
    @demo=false
  end
  attr_reader :highscores
  attr_reader :effects
  
  Keydata = Struct.new("Keydata",:left,:right)

  def self.effects
    self.instance.effects
  end
  
  def run_demo
    @demo=true
    run
    @demo=false
  end
  
  def reset #restart game
    @field.reset
    @hito.reset
    @gauge.reset
    @effects.reset
    @score=0
    @state.reset 
    @demo_time = 0
    SDL::Mixer.playMusic($sound.bgm, -1) if $CONF_MUSIC && !@demo
    halt_waves if $CONF_SOUND
  end

  def run(demo=false)
    @gameovertimer = Timer.new(Wait::GAMEOVER)
    before=now=SDL.getTicks
    key = Keydata.new
    #demo
    @flashtimer = Timer.new(600)
    @flashing   = true
    @demo=demo
    reset

    #main loop
    while true
      draw
      @screen.flip

      before=now; now=SDL::getTicks; dt=now-before
      act(key,dt)

      key = check_events
      break if key==nil
    end

    #exit game
    SDL::Mixer.haltMusic if $CONF_MUSIC
    halt_waves           if $CONF_SOUND

    return :title
  end

  def halt_waves
    $sound.channels.times do |i|
      SDL::Mixer.halt(i) if SDL::Mixer.play?(i)
    end
  end
  private :halt_waves

  #-------------------------------------------------------------------
  def check_events
    key = Keydata.new
    key.left = key.right = false
    
    while (event=SDL::Event2.poll)
      case event
      when SDL::Event2::Quit
        return nil
      when SDL::Event2::KeyDown
        @demo_time = 0
        case event.sym
        when SDL::Key::ESCAPE
          return nil #exit
        when SDL::Key::RETURN, SDL::Key::SPACE
          if @demo
            @demo=false
            reset             #start game
          end
        when SDL::Key::LEFT, SDL::Key::H
          key.left=true
        when SDL::Key::RIGHT,SDL::Key::L
          key.right=true
        when SDL::Key::D
          @demo=true
          reset
        end
      end
    end
    
    SDL::Key.scan
    key.left = true if SDL::Key.press?(SDL::Key::LEFT) || SDL::Key.press?(SDL::Key::H)
    key.right =true if SDL::Key.press?(SDL::Key::RIGHT)|| SDL::Key.press?(SDL::Key::L)
    
    if @demo
      #automatic move
      key.left = key.right = false
      key = auto_decide(@field,@hito)
    end

    key
  end
  #-----------------------------------------------------------------
  def act(key,dt)
    @system.count_fps(dt)
    @score += @hito.act(@field,key,dt)
    @score += @field.act(@hito,dt)
    @gauge.act(@field,@hito,dt)
    @effects.act(dt)

    if @demo
      @flashtimer.wait(dt) do
        @flashing = (@flashing ? false : true)
      end
    else
      @demo_time+=dt
      if @demo_time > Wait::DEMO_TIME
        @demo=true
        reset                 #start demo
      end
    end
    
    #check gameover
    unless @state.gameover?
      if @gauge.value<=0 then
        @state.on(:gameover)
        @hito.gameover

        SDL::Mixer.haltMusic if $CONF_MUSIC
        $sound.channels.times{|i| SDL::Mixer.halt(i)} if $CONF_SOUND
        SDL::Mixer.playChannel(-1,$sound.gameover,0) if $CONF_SOUND
      end
    else
      # Restart game after a while
      @gameovertimer.wait(dt) do
        unless @demo
          if @highscores.size<HIGHSCORES || @highscores[-1].score<@score
            name = nameentry()
            @highscores<<Score.new(@score, name, Score::VERSION)
            @highscores.sort!{|a,b| b.score<=>a.score}
            @highscores = @highscores[0,HIGHSCORES]
          end
=begin
          name = nameentry()
            @highscores.size.times do |i|
            if @highscores[i].score < @score || @highscores[i].version < Score::VERSION
              @highscores[i,0]= Score.new(@score, name, Score::VERSION)
              break
            end
          end
=end
        end
        @state.off(:gameover)
        reset  
      end
    end
  end
  #------------------------------------------------------------------
  def draw
    #draw
    @screen.fillRect(0,0,640,480,0)

    #DEBUG----
    if $DEBUG_SHOW_FIELDDATA then
      #show Field::@data
      for i in 0...(Field::HEI)
        for j in 0...(Field::WID)
          @font.drawSolidUTF8(@screen,@field[j,i].inspect, Field::RIGHT+32+j*14, 85+i*14, 255,255,255)
        end
      end
    end
    #DEBUG----

    @font.drawBlendedUTF8(@screen,"FPS:#{@system.fps}",      640-80, 0, 127,127,127)
    @font.drawBlendedUTF8(@screen,"SCORE RANKING",           Field::RIGHT+32, 2, 255,255,255)
    @highscores[0,HIGHSCORES].each_with_index do |score,i|
      color = (score.version<Score::VERSION) ? [127,127,127] : [200,255,255]  # Use gray for old score
      @font.drawBlendedUTF8(@screen,sprintf("%2d: %6d %s",i+1, score.score, score.name), Field::RIGHT+32, 25*(i+1), *color)
    end
    @font.drawBlendedUTF8(@screen,"SCORE:#{@score}",         Field::RIGHT+32, 300 , 255,255,255)
    @font.drawBlendedUTF8(@screen,"LIFE",                    Field::RIGHT+32, 330 , 255,255,255)
    @font.drawBlendedUTF8(@screen,"Ver.#{Main::VERSION}",     640-86, 460 , 127,127,127)
    
    @field.draw(@screen)
    @hito.draw(@screen)
    @gauge.draw(@screen)
    @effects.draw(@screen)
    
    if @demo
      @font.drawBlendedUTF8(@screen,"HIT SPACE KEY",       160, 200, 230,230,230) if @flashing
    end
  end

  #----------------------------------------------------------------
  
  SHIFT_SYMBOLS = {
    "1"=>"!", "2"=>'"', "3"=>"#", "4"=>"$", "5"=>"%", "6"=>"&", "7"=>"'", "8"=>"(", "9"=>")",
    "-"=>"=", "^"=>"~", "\\"=>"|","@"=>"`", "["=>"{", ";"=>"+", ":"=>"*", "]"=>"}",
    ","=>"<", "."=>">", "/"=>"?" 
  }
  def nameentry
    name = ""
    cursor = 0
    cont = true
    SDL::Key.enableKeyRepeat(500,40)
    @flashtimer = Timer.new(500)
    flashing = true
    before=now=SDL.getTicks

    # ^->'  @->` |->\ ;->= (:->: *=>+)
    while cont
      #key
      while (event=SDL::Event2.poll)
        case event
        when SDL::Event2::Quit
          cont =  nil
        when SDL::Event2::KeyDown
          case event.sym
          when SDL::Key::RETURN, SDL::Key::ESCAPE
            cont = false
          when SDL::Key::BACKSPACE
            name.chop!
            cursor-=1 if cursor>0
          when SDL::Key::A .. SDL::Key::Z
            if (event.sym==SDL::Key::H) && (event.mod&SDL::Key::MOD_LCTRL!=0)
              #C-h
              name.chop!
              cursor-=1 if cursor>0
              break
            elsif (event.sym==SDL::Key::U) && (event.mod&SDL::Key::MOD_CTRL!=0)
              #C-u
              name=""
              cursor=0
              break
            end
            
            if event.mod&SDL::Key::MOD_SHIFT != 0
              #A-Z
              name << ("A".ord + event.sym-SDL::Key::A).chr
              cursor+=1
            else
              #a-z
              name << ("a".ord + event.sym-SDL::Key::A).chr
              cursor+=1
            end
          else
            if event.mod&SDL::Key::MOD_SHIFT != 0
              val = SHIFT_SYMBOLS[SDL::Key::getKeyName(event.sym)]
              unless val==nil
                name<<val
                cursor+=1
              end
            else
              tmp = SDL::Key::getKeyName(event.sym)
              if tmp.size==1
                name<<tmp
                cursor+=1
              end
            end
          end
        end
      end

      before=now
      now=SDL::getTicks
      dt=now-before

      #draw
      @screen.fillRect(0,0,640,480,0)
      @font.drawBlendedUTF8(@screen,"SCORE RANKING",           Field::RIGHT+32, 2, 255,255,255)
      @highscores[0,HIGHSCORES].each_with_index do |score,i|
        color = (score.version<Score::VERSION) ? [127,127,127] : [200,255,255]  # Use gray for old score
        @font.drawBlendedUTF8(@screen,sprintf("%2d: %6d %s",i+1, score.score, score.name), Field::RIGHT+32, 25*(i+1), *color)
      end
      @font.drawBlendedUTF8(@screen,"SCORE:#{@score}",         Field::RIGHT+32, 300 , 255,255,255)
        @font.drawBlendedUTF8(@screen,"LIFE",                  Field::RIGHT+32, 330 , 255,255,255)
      @flashtimer.wait(dt){
        flashing = (flashing ? false : true)
      }
      if flashing
        @font.drawBlendedUTF8(@screen,"_",                     Field::RIGHT+82+cursor*10, 360 , 255,255,255)
      end
      @font.drawBlendedUTF8(@screen,"NAME:#{name}",            Field::RIGHT+32, 360 , 255,255,255)

      @field.draw(@screen)
      @screen.flip
    end

    SDL::Key.disableKeyRepeat
    
    if cont==nil
      return nil
    else
      return name
    end
    
  end
  private :nameentry

  #-------------------------------------------------------------------
  # AI (for demo mode)
  #-------------------------------------------------------------------
  def auto_decide(field,hito)
    key = Keydata.new
    key.left = key.right = false

    # Do not move when floating
    if @field.can_pass?(@hito.x, @hito.y+1)
      return key
    end
    
    # Go left when on the right end
    x = @hito.x
    until @field.can_pass?(x, @hito.y+1)
      x+=1; break if x>=Field::WID
    end
    if x>=Field::WID then
      key.left=true
      return key
    end
    r=x
    # Go right when on the left end
    x = @hito.x
    until @field.can_pass?(x, @hito.y+1)
      x-=1; break if x<0
    end
    if x<0 then
      key.right=true
      return key
    end
    l=x
    # Otherwise:

    # Check what happens falling from the right end
    y = @hito.y
    until @field[r,y] != Chara::EMPTY
      y+=1; break if y>=Field::HEI
    end
    if y==Field::HEI
      rstat = Chara::EMPTY
    else
      rstat = @field[r,y]
    end
    yr=y

    # Check what happens falling from the left end
    y = @hito.y
    until @field[l,y] != Chara::EMPTY
      y+=1; break if y>=Field::HEI
    end
    if y==Field::HEI
      lstat = Chara::EMPTY
    else
      lstat = @field[l,y]
    end
    yl=y

    if @field[@hito.x, @hito.y+1]==Chara::HARI
      # Go nearer end when on a needle
      if (r-@hito.x) < (@hito.x-l)
        key.right=true
      else
        key.left=true
      end
    else
      # Go opposite side from needle
      if lstat==Chara::HARI
        key.right=true
      elsif rstat==Chara::HARI
        key.left=true
      else
        # Go nearer end when both sides are safe
        if (r-@hito.x) < (@hito.x-l)
          key.right=true
        elsif (r-@hito.x) > (@hito.x-l)
          key.left=true
        else
          if rand(2)==0
            key.right=true
          else
            key.left=true
          end
        end
      end
    end
    
    key
  end
  #----------------------------------------------------------------
end


#test
if __FILE__ == $0 then
  require 'sdl'
  VER="??"
  
  #init view
  SDL.init(SDL::INIT_VIDEO)
  screen = SDL::setVideoMode(640,480,16,SDL::SWSURFACE)
  SDL::WM.setCaption("DOWN!!v#{VER} on Ruby/SDL","DOWN!!v#{VER}")

  #init font
  SDL::TTF.init
  font=SDL::TTF.open('font.ttf',20)
  font.style=SDL::TTF::STYLE_NORMAL

  #execute
  Game.new(screen,font).run
end
