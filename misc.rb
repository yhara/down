#
# misc.rb
#

require 'singleton'

#--------------------------------------------------------------------

Score = Struct.new(:score,:name,:version)
class Score
  VERSION = 2
end

#--------------------------------------------------------------------

module Constants
  CHAR = 16
  SCREEN_W = 640
  SCREEN_H = 480 

  #wait
  module Wait
    #(msec)   1vsync = 1/60sec = 16.66msec
    FALL = ($DEBUG_FASTEST) ? 0 : 40
    FALL_PARA = 60
    FALL_OMORI= 20
    
    WALK = 83
    DAMAGE = 10 #ms/damage (life=100)
    HITOFLASH = 80
    HITOWAVE = 200
    MUTEKIFLASH = 80
    GAUGEFLASH = 60
    HARIBREAK = 140
    
    GAMEOVER = 3400   #ms
    DEMO_TIME = 1000 * 60 * 3 #5min
  end

  #game configuration
  HARI_PER_FLOOR = 30 # 30%
  ITEM_PERCENT = 15
  MUTEKI_TIME = 4000  # 4sec (length of MUTEKI bgm)

  HIGHSCORES = 10
end

#--------------------------------------------------------------------

class Timer
  def reset
    @wait=0
  end

  def initialize(waittime)
    set_wait(waittime)
    reset
  end

  def wait(dt)
    @wait+=dt
    while @wait>=@waittime do
      @wait-=@waittime
      yield
      reset if @wait<@waittime
    end
  end

  def set_wait(t)
    raise ArgumentError,"waittime must be >0" if t<=0
    @waittime = t
  end
end

#--------------------------------------------------------------------

class State
  #a state class which supports multi states
  
  def initialize(*states)
    @state=Hash.new
    
    states.each do |state|
      @state[state.id2name]=false
      
      instance_eval <<-EOD
      def #{state.id2name}?
        @state[\"#{state.id2name}\"]
        end
      EOD
    end
  end

  #no operand check for now..
  def on(state)
    @state[state.id2name]=true
  end
  def off(state)
    @state[state.id2name]=false
  end

  def reset
    #set all the states false
    @state.keys.each do |key|
      @state[key]=false
    end
  end
end

#--------------------------------------------------------------------

class Sound
  include Singleton

  MAX_CHANNELS = 10
  CH_DAMAGE = 4 #channel for damage.wav
  CH_MUTEKI = 3
  CH_BREAK  = 2
  
  def initialize
    return if $OPT_s  #silent mode

    @channels = SDL::Mixer.allocateChannels( MAX_CHANNELS )
    
    @foot     = SDL::Mixer::Wave.load("sound/foot.wav")
    @gameover = SDL::Mixer::Wave.load("sound/gameover.wav")
    @gameover.setVolume(80)
    @muteki   = SDL::Mixer::Wave.load("sound/muteki.wav")
    @muteki.setVolume(60)
    @getpara  = SDL::Mixer::Wave.load("sound/getpara.wav")
    @getomori = SDL::Mixer::Wave.load("sound/getomori.wav")
    @damage   = SDL::Mixer::Wave.load("sound/damage.wav")
    @spank    = SDL::Mixer::Wave.load("sound/spank.wav")
    @break    = SDL::Mixer::Wave.load("sound/break.wav")
    @bgm = SDL::Mixer::Music.load("sound/dark3.it")
  end
  attr_reader :channels
  attr_reader :foot,:gameover,:muteki,:getpara,:getomori,:damage,:spank,:break,:bgm
end

#--------------------------------------------------------------------
module Util
  def self.cut_image(w,h,n,img, ofsx=0, ofsy=0, colkey=nil)
    ret = []
    n.times do |i|
      surf = SDL::Surface.new(SDL::HWSURFACE,w,h,img)
      SDL.blitSurface(img,i*w+ofsx,0+ofsy, w,h, surf,0,0)
      surf.setColorKey(SDL::SRCCOLORKEY, colkey) if colkey!=nil
      ret << surf
    end
    ret
  end
end
