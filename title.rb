#
# title.rb
#

class Title
  FONTNAME = "image/boxfont2.ttf"
  TITLECGNAME = "image/title.bmp"

  COL_HILIGHT = [0,0,255]
  COL_NORMAL  = [100,100,100]

  Menuitem = Struct.new(:name,:ret)

  def initialize(screen)
    @screen = screen
    @font = SDL::TTF.open(FONTNAME,30)
    @titleback = SDL::Surface.loadBMP(TITLECGNAME)
    @menu = []
    @menu << Menuitem.new("START",:game)
    @menu << Menuitem.new("CONFIG",:config)
    @menu << Menuitem.new("EXIT",nil)
    @cursor = 0
    @snd_move = SDL::Mixer::Wave.load("sound/change.wav") unless $OPT_s
  end

  attr_accessor :cursor
  MENU_START = 0    # @cursor takes(?) one of these values
  MENU_CONFIG = 1
  MENU_EXIT = 2
  
  def run
    #check value
    @cursor = 0 if @cursor < 0
    @cursor = @menu.size-1 if @cursor > @menu.size-1

    #main loop
    
    while true
      #event check
      while (event=SDL::Event2.poll)
        case event
        when SDL::Event2::Quit
          return nil
          
        when SDL::Event2::KeyDown
          #key check
          case event.sym
          when SDL::Key::UP, SDL::Key::K
            SDL::Mixer.playChannel(-1,@snd_move,0) if $CONF_SOUND   #0=no loop(play only one time)
            @cursor-=1 
            @cursor = @menu.size-1 if @cursor<0
            
          when SDL::Key::DOWN, SDL::Key::J
            SDL::Mixer.playChannel(-1,@snd_move,0) if $CONF_SOUND
            @cursor+=1 
            @cursor = 0 if @cursor>@menu.size-1

          when SDL::Key::RETURN, SDL::Key::SPACE
            return @menu[@cursor].ret
            
          when SDL::Key::ESCAPE
            return nil
            
          end
        end
      end

      #drawing
      @screen.put(@titleback,0,0)
      
      @menu.each_with_index do |item,i|
        color = (i==@cursor) ? COL_HILIGHT : COL_NORMAL
        s = (i==@cursor) ? "<#{item.name}>" : item.name
        x = (@screen.w - @font.textSize(s)[0])/2
        @font.drawBlendedUTF8(@screen, s, x, 300+i*50, *color)
      end
      
      @screen.flip
    end
  end

end

#test
if __FILE__==$0 then
  require 'sdl'
  SDL.init(SDL::INIT_VIDEO|SDL::INIT_AUDIO)
  screen = SDL::setVideoMode(640,480,16,SDL::SWSURFACE)
  SDL::TTF.init
  SDL::Mixer.open(22050,SDL::Mixer::FORMAT_S8,1)
  #SDL::Mixer.open()
  Title.new(screen).run
end
