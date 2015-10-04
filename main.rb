#
# main.rb
#

class Main
  VERSION = 0.53
end
  
require 'sdl'
require 'title.rb'
require 'conf.rb'
require 'game.rb'
require 'misc.rb'

#---------------------------------------------------------------------
# Save/load game data using Marshal.dump
# (Note: Marshal format may be incompatible between Ruby versions!)
class SavedataManager

  def initialize(fname)
    @fname = fname
  end

  # Load savedata from the file
  # (Return nil if the file does not exist)
  def read
    return nil if FileTest.exist?(@fname)==false

    open(@fname,"rb") do |file|    #Read & Binary mode
      @data = Marshal.load(file)
    end
    @data
  end

  # Set savedata
  # eg.
  #   savedata.set( [highscore,name] )
  #   savedata.set( {"highscore"=>highscore, "name"=>name} )
  def set(data)
    @data = data
  end

  # Write savedata to file
  def write
    open(@fname,"wb") do |file|
      Marshal.dump(@data,file)
    end
  end
end

class MyConfig < Conf
  #constants
  FONT_CONFIG = "image/boxfont2.ttf"
  FONT_CONFIG_SIZE = 24
  WAIT_SCROLL = 50 #ms/move
  
  def initialize(screen,savedata)
    #init Config
    menu = [
      [ "MUSIC", [true, false] ],
      [ "SOUND", [true, false] ],
      #[ "SCREEN", ["WINDOW","FULLSCREEN"] ],
      [],
      [ "#EXIT" ]
    ]
    font = SDL::TTF.open(FONT_CONFIG, FONT_CONFIG_SIZE)
    super(screen,font,menu)
    self.loaddata(savedata)

    #init on_draw function     
    @configback = SDL::Surface.loadBMP("image/confback.bmp")
    @shiftx = 0 ; @shifty = 0 ; @scrolltimer = Timer.new(WAIT_SCROLL)

    self.on_draw do |screen,dt|
      #move
      @scrolltimer.wait(dt) do
        @shiftx += 1 ; @shiftx = -(@configback.w-1) if @shiftx>0
        @shifty += 1 ; @shifty = -(@configback.h-1) if @shifty>0
      end
      #draw
      for y in 0..(screen.h/@configback.h)+1
        for x in 0..(screen.w/@configback.w)+1
          screen.put(@configback, x*@configback.w+@shiftx, y*@configback.h+@shifty)
        end
      end
    end
  end
end

class Main

  #init SDL
  def self.init
    SDL.init(SDL::INIT_VIDEO|SDL::INIT_AUDIO)
    SDL::TTF.init

    unless $OPT_s
      SDL::Mixer.open(22010,SDL::Mixer::FORMAT_S8,1,1024) #22kHz,8bit,monoral
      $sound = Sound.instance
    end
  end

  #init main
  def initialize
    #screen
    if $OPT_f
      @screen = SDL::setVideoMode(640,480,16,SDL::SWSURFACE|SDL::DOUBLEBUF|SDL::FULLSCREEN)
      SDL::Mouse.hide
    else
      @screen = SDL::setVideoMode(640,480,16,SDL::SWSURFACE|SDL::DOUBLEBUF)
    end
    SDL::WM.setCaption("DOWN!!v#{Main::VERSION} on Ruby/SDL","DOWN!!v#{Main::VERSION}")
    
    #load
    @svmanager = SavedataManager.new($OPT_savefile)
    savedata = @svmanager.read
    savedata = {} unless savedata.is_a? Hash
    svversion  = savedata["savedata-version"] || 0
    highscores = savedata["highscores"] || []
    configdata = savedata["configdata"] || nil

    if "savedata-version"==0.1
      highscores = [Score.new(savedata["highscore"].to_i, "", 1)]
    end
    
    #init config
    @config = MyConfig.new(@screen,configdata)
    #begin
    #  @screen.toggleFullScreen if $CONF_SCREEN=="FULLSCREEN"
    #rescue SDL::Error
    #end
    $CONF_SOUND=$CONF_MUSIC=false if $OPT_s   #silent mode
    
    #init game
    @game = Game.instance
    @game.init(@screen,highscores)

    #init title
    @title = Title.new(@screen)
  end

  def start   #main loop
    @state = self.method(:logo)
    
    while true
      ret = @state.call
      break if ret==nil
      @state = self.method(ret)
    end

    #save
    @svmanager.set( {"savedata-version"=>0.2, "highscores"=>@game.highscores, "configdata"=>@config.savedata} )
    @svmanager.write
  end
  
private  

  def logo
    #not yet implemented...
    return :title
  end

  def title
    return @title.run
  end
  
  def game
    @title.cursor = Title::MENU_START
    return @game.run
  end

  def config
    fullscreen = $CONF_SCREEN

    @config.run

    begin
      @screen.toggleFullScreen if $CONF_SCREEN != fullscreen
    rescue SDL::Error
    end
    
    if $OPT_s   #silent mode
      $CONF_SOUND = false
      $CONF_MUSIC = false
    end
    @title.cursor = Title::MENU_CONFIG
    return :title
  end

end
