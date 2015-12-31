#
# conf.rb : Config menu for Ruby/SDL games
#

=begin

== Example

  # Initialize SDL
  SDL.init(SDL::INIT_VIDEO)
  screen = SDL::setVideoMode(640,480,16,SDL::SWSURFACE)

  SDL::TTF.init
  font = SDL::TTF.open("font.ttf",24)

  # Load config data
  open("savedata.dat","r") do |file|
    configdata = Marshal.load(file)
  end

  # Define menu
  menu = [
    ["Level", ["Easy","Normal","Hard"] ],
    ["Music", [true,false] ],
    ["Sound", [true,false] ],
    [],
    ["#Exit"]
  ]

  # Create Conf
  conf = Conf.new(screen,font,menu,configdata)

  # Run config menu
  # Will define $CONF_Level, $CONF_Music and $CONF_Sound 
  conf.run

  # Save config data
  open("savedata.dat","w") do |file|
    Marshal.dump( conf.data, file )
  end

== Defining menu

Example:

  menu = [
    ["display", ["window","fullscreen"]],
    ["sound", ["on","off","auto"]],
    ["music vol", ["off","10","20","30","40","50","60","70","80","90","100"], false ],
    [],
    ["key config",Proc.new{key_config}]
    ["#exit"]
  ]

Menu item is one of the following.

* Choice
   # Example 1
   ["Level", ["Easy", "Hard"]]

   - "Easy" or "Hard" is set to $CONF_Level

   # Example 2
   ["Music", [true,false], true]

   - true or false is set to $CONF_Music
   - true/false is shown as "ON"/"OFF" in the screen (can be changed
   by Conf#true_string, #false_string)
   - 3rd argument : whether to loop the selection

   # Example 3
   ["MUSIC VOL", [0,10,20,30,40,50,60,70,90,90,100]] 
   
   - A value between 0 and 100 is set to $CONF_MUSIC_VOL
     (Spaces in menu title will be converted to `_`. Only alphabet,
     numbers, space and `_` are allowed in menu title)

* Command  
   ["key config", proc{key_config} ]

  Execute the proc when selected (space or enter is hit)

*Space
   [] or [nil]

  Vertical space

*Exit
   ["#exit"] or ["#EXIT"] or ["#Exit"]

  Quit menu when selected

== Advanced usage

Menus can be nested when Proc is specified as options.

  # Child menu
  menu_sound = [
    ["Music", ["On","Off"] ],
    ["Sound", ["On","Off"] ],
    ["Sampling Rate", [44100,22050,11025] ]  # You can pass numbers, too :)
    [],
    ["#Exit"]
  ]
  conf_sound = Conf.new(screen,font,menu_sound)

  # Parent menu
  menu_main = [
    ["Level", ["Easy","Normal","Hard","Maniac"] ],
    [],
    ["Sound Settings", proc{ conf_sound.run }], # Put proc here
    [],
    ["#Exit"]
  ]
  conf_main = Conf.new(screen,font,menu_main)

  # Run
  conf_main.run

["#Exit"] is equivalent to:

  conf = Conf.new(screen,font)
  conf.add_menuitem( ["Exit",proc{conf.quit}] )

== Control

* Key Up, Down : choose menu item
* Key Right, Left : choose menu option
* Space, Enter : select option
* Esc : quit menu

=end

require "sdl"

class Conf

private
  COL_HILIGHT = [0,255,255]
  COL_NORMAL  = [255,255,255]

  PREFIX = "CONF_"
  
  Choice = Struct.new("Choice",:name,:showname,:items,:loop)
  Command = Struct.new("Command",:name,:proc)
  Space = Struct.new("Space",:enlarge)

  # Convert menu definition to Choice/Command/Space
  # Initialize @selected and $CONF_xx
  def menuitemize(item)
    case item.size
    when 0
      Space.new(false)
    
    when 1
      case item[0]
      when nil
        Space.new(false)
      when "#exit"
        Command.new("exit",proc{quit})
      when "#EXIT"
        Command.new("EXIT",proc{quit})
      when "#Exit"
        Command.new("Exit",proc{quit})
      else 
        raise "invalid menu item:#{item.inspect}"
      end
      
    when 2
      if item[0]==nil then
        Space.new(item[1])
      elsif item[1].is_a? Proc then
        raise ArgumentError,"title of a Command must be String" unless item[0].is_a? String
        Command.new(item[0],item[1])
      else
        ret = Choice.new(quote_space(item[0]), item[0], item[1], true)
        @selected[ret.name] = 0
        instance_eval("$#{PREFIX}#{ret.name} = ret.items[0]") # $CONF_music = ret.items[0]
        ret
      end
    when 3
      ret = Choice.new(quote_space(item[0]), item[0], item[1], item[2])
      @selected[ret.name] = 0
      instance_eval("$#{PREFIX}#{ret.name} = ret.items[0]") # $CONF_music = ret.items[0]
      ret
    end
  end

  # Replace spaces with `_`
  def quote_space(name)
    raise ArgumentError,"title of Choice must be String" unless name.is_a? String
    if name=~/[^A-Za-z0-9_ ]/ then
      raise ArgumentError,"you can use only A-Z,a-z,0-9,`_' and space for a title of Choice."
    end
    name.gsub(/ /,"_")
  end

  def renew_configdata
    @menu.each do |item|
      if item.is_a? Choice then
        # $CONF_music = item.items[@selected['music']]
        instance_eval("$#{PREFIX}#{item.name} = item.items[@selected[item.name]]")
      end
    end
  end
  
  public

  # initialize(screen,font[,menudata])
  #
  # - `screen`: SDL screen
  # - `font`: SDL::TTF
  # 
  # When `menudata` is omitted, you must call Conf#add_menuitem(s) before
  # calling Conf#run.
  def initialize(*args)
    raise ArgumentError,"wrong # of arguments" if args.size<2 || args.size>4
    #screen
    @screen = args[0]

    #font
    @font = args[1]
    
    #view
    @margin_top  = 32
    @margin_left = 32
    @line_height = @font.textSize("jpfM")[1] * 1.5
    @true_string = "ON"
    @false_string= "OFF"
    @ondraw = proc{|screen,dt| screen.fillRect(0,0,@screen.w,@screen.h,[0,0,0]) }

    #model
    @selected = {}
    @configdata = {}
    
    #(menudata)
    @menu = []
    if args.size >= 3 then
      args[2].each do |item|
        @menu << menuitemize(item)
      end
    end
  end

  # Top margin, left margin, line height (px)
  attr_accessor :margin_top,:margin_left,:line_height

  # Add menu item
  def add_menuitem(item)
    raise ArgumentError,"#{item} is not an Array" if !item.is_a? Array
    raise ArgumentError,"wrong # of arguments" if item.size>3
    @menu << menuitemize(item)
  end

  # Add menu items
  def add_menuitems(items)
    items.each do |item|
      add_menuitem(item)
    end
  end

  # Quit running config menu
  def quit
    @running=false
  end

  # Set Proc to draw background
  #
  # Example:
  #      conf.on_draw{|screen,dt|
  #        # dt: time passed since the last call (ms)
  #        screen.fillRect(0,0,screen.w, screen.h,[255,255,255])
  #      }     
  def on_draw(&block)
    @ondraw = block
  end

  # Set a string to show when `true` is passed as menu option
  # default: "ON"
  def true_string(str)
    @true_string = str
  end

  # Set a string to show when `false` is passed as menu option
  # default: "OFF"
  def false_string(str)
    @false_string = str
  end
  
  # Run config menu
  #
  # FIXME: this method calls SDL::Key.disableKeyRepeat
  def run
    #data check
    if @menu.size == 0 then
      raise "no menudata for configuration"
    end
    if @menu.select{|item|item.is_a? Space}.size == @menu.size then
      raise "menudata must not all Space"
    end

    #set cursor
    cursor = 0
    while @menu[cursor].is_a? Space
      cursor+=1
    end

    margin = @font.textSize("< ")[0]      #=> [wid,hei][0] = wid.
    before = now = SDL.getTicks
    SDL::Key::enableKeyRepeat(500,80)
    @running = true
    
    while @running
      
      #event check
      while (event=SDL::Event2.poll)
        case event
        when SDL::Event2::Quit
          return nil
          
        when SDL::Event2::KeyDown
          #key check
          case event.sym
          when SDL::Key::UP
            cursor-=1 
            cursor = @menu.size-1 if cursor<0
            redo if @menu[cursor].is_a? Space
            
          when SDL::Key::DOWN
            cursor+=1 
            cursor = 0 if cursor>@menu.size-1
            redo if @menu[cursor].is_a? Space
            
          when SDL::Key::LEFT
            break if @menu[cursor].is_a? Command
            item = @menu[cursor]
            @selected[item.name]-=1
            if @selected[item.name]<0 then
              @selected[item.name] = (item.loop) ? (item.items.size-1) : (0)
            end
            
          when SDL::Key::RIGHT
            break if @menu[cursor].is_a? Command
            item = @menu[cursor]
            @selected[item.name]+=1
            if @selected[item.name] > item.items.size-1 then
              @selected[item.name] = (item.loop) ? (0) : (item.items.size-1)
            end

          when SDL::Key::RETURN, SDL::Key::SPACE
            @menu[cursor].proc.call if @menu[cursor].is_a? Command
            
          when SDL::Key::ESCAPE
            renew_configdata
            return nil   #exit menu.
            
          end
        end
      end

      #---drawing
      #drawing back
      now = SDL.getTicks
      @ondraw.call(@screen, now-before)
      before = now

      #drawing menu
      @menu.each_with_index do |item,i|
        case item
        when Space
          next
        when Command
          color = (i==cursor) ? COL_HILIGHT : COL_NORMAL
          @font.drawBlendedUTF8(@screen, item.name, @margin_left, @margin_top+i*@line_height, *color)
        when Choice
          choice=""
          if i==cursor then
            choice += "< " if @selected[item.name]>0 || item.loop
            choice += quote_tf(item.items[@selected[item.name]]).to_s
            choice += " >" if @selected[item.name]<item.items.size-1 || item.loop
            color = COL_HILIGHT
            m = (@selected[item.name]>0 || item.loop) ? margin : 0
          else
            choice = quote_tf(item.items[@selected[item.name]]).to_s
            color = COL_NORMAL
            m = 0
          end
          @font.drawBlendedUTF8(@screen, item.showname, @margin_left,    @margin_top+i*@line_height, *color)
          @font.drawBlendedUTF8(@screen, choice,        (@screen.w/2)-m, @margin_top+i*@line_height, *color)
        end
      end
      
      #flip
      @screen.flip
    end

    SDL::Key::disableKeyRepeat
    renew_configdata
  end

  # true/false => @true_string/@false_string
  def quote_tf(a)
    if a==true then
      @true_string
    elsif a==false then
      @false_string
    else
      a
    end
  end

  # Returns save data converted to a Marshalable object (Hash).
  #
  # Do not call this method before setting menu data (with #initialize
  # or #add_menuitems).
  def savedata
    ret = {}
    @menu.each do |item|
      if item.is_a? Choice then
        # ret['music']=$CONF_music
        instance_eval("ret['#{item.name}']=$#{PREFIX}#{item.name}")
      end
    end
    ret
  end

  # Load a save data, which is returned by Conf#savedata
  #
  # Do not call this method before setting menu data (with #initialize
  # or #add_menuitems).
  def loaddata(savedata)
    return if savedata.nil?
      
    #savedata => $CONF_xx
    savedata.each_key do |key|
      quote_space(key) rescue next   #skip if `key' is invalid for a title of a Choice
      # $CONF_music = savedata['music']
      instance_eval("$#{PREFIX}#{key} = savedata['#{key}']")
    end
    
    # $CONF_xx => @selected
    @menu.each do |item|
      if item.is_a? Choice then
        # @selected['music'] = item.items.index( $CONF_music ) || 0 if $CONF_music!=nil
        instance_eval("@selected[item.name] = item.items.index( $#{PREFIX}#{item.name} )||0 if $#{PREFIX}#{item.name}!=nil")
      end
    end
  end
  
end


#test
if __FILE__==$0 then
  #init view
  SDL.init(SDL::INIT_VIDEO)
  screen = SDL::setVideoMode(640,480,16,SDL::SWSURFACE)

  #init font
  SDL::TTF.init
  font = SDL::TTF.open("boxfont2.ttf",24)


  conf1 = Conf.new(screen, font, [
    ["music vol", ["off","10","20",30,"40","50","60","70","80","90","100"], false ],
    ["sound", [true,false]],
    [nil],
    ["#exit"],
  ], {"sound"=>"auto"})

  conf = Conf.new(screen, font, [
    ["display", ["window","fullscreen"], true ],
    [],
    ["sound setting",proc{conf1.run}],
    ["key config",proc{} ],
    [],
    ["#Exit"]
  ], {"display"=>"fullscreen"})  

  #load
  #open("_junk.dat","rb"){|f| conf.loaddata( Marshal.load(f) ) }
  
  conf.on_draw{|screen,dt| screen.fillRect(0,0,640,480,[0,128,0])}
  conf.run

  p $CONF_sound
  p $CONF_music_vol

  #save
  #open("_junk.dat","wb"){|f| f.write(Marshal.dump( conf.savedata )) }
    
end

