#
# conf.rb
#

=begin
= ruby/SDLなゲーム用 configメニュー 

==概要
configです。自分用に作っただけなんで、まだロクにテストしてません :-P
つーか１年ほどほっといたんで自分でも良くわからなくなってます。

  menu = なんとかかんとか（データ形式 を参照）
  screen = SDL::setVideoMode(...
  font = SDL::TTF.open(...
  conf = Conf.new(screen,font,menu)

で準備完了、あとは conf.run でインタラクティブかつグラフィカルなコンフィグ画面が。

==簡単な使用例

  #SDLの準備
  SDL.init(SDL::INIT_VIDEO)
  screen = SDL::setVideoMode(640,480,16,SDL::SWSURFACE)

  SDL::TTF.init
  font = SDL::TTF.open("font.ttf",24)

  #コンフィグデータのロード
  open("savedata.dat","r") do |file|
    configdata = Marshal.load(file)
  end

  #メニューデータの定義
  menu = [
    ["Level", ["Easy","Normal","Hard"] ],
    ["Music", [true,false] ],
    ["Sound", [true,false] ],
    [],
    ["#Exit"]
  ]

  #コンフィグオブジェクトの生成
  conf = Conf.new(screen,font,menu,configdata)

  #ゲーム本体の実行...
    #コンフィグメニューの実行
    conf.run

  #データセーブ
  open("savedata.dat","w") do |file|
    Marshal.dump( conf.data, file )
  end

==複雑な使用例(応用編)
以下のようなやりかたで、コンフィグメニューを「入れ子」にすることができます。

  #子の定義
  menu_sound = [
    ["Music", ["On","Off"] ],
    ["Sound", ["On","Off"] ],
    ["Sampling Rate", [44100,22050,11025] ]  #数値も渡せるのです :)
    [],
    ["#Exit"]
  ]
  conf_sound = Conf.new(screen,font,menu_sound)

  #親の定義
  menu_main = [
    ["Level", ["Easy","Normal","Hard","Maniac"] ],
    [],
    ["Sound Settings", proc{ conf_sound.run }], #ここがポイント
    [],
    ["#Exit"]
  ]
  conf_main = Conf.new(screen,font,menu_main)

  #実行
  conf_main.run

組み込みの["#Exit"]は、以下と同じです。
  conf = Conf.new(screen,font)
  conf.add_menuitem( ["Exit",proc{conf.quit}] )

==config画面での操作方法
上下で項目の選択、左右で選択肢の選択。SPACEまたはENTERで項目の実行、ESCで終了

==TODO

*(大きい空行) <=いらんか？
*(キー定義を可変に（そこまでするか？）)
* Choiceにブロックを渡すと項目変更時に選択項目を渡して実行してくれる。っての
    ["sound",["on","off], proc{|select| if select=="on" then flag_sound=true end} ]
  とか。
* "#Key Conf"で簡易キーコンフィグ(Conf::KeyConfのオブジェクト)を実行
* 音設定

==内部実装について

*データとして配列@menuとハッシュ@selectedとグローバル変数$CONF_xxを持つ。
*@menuは、クラス(実は構造体)Choice,Command,Spaceのオブジェクトを要素に持つ配列。

以下は古い情報。

*データとして配列@menuと、ハッシュ@selectedと、ハッシュ@configdataの3つを持つ。
 (これらの同期をとるのがめんどくさいっぽい)
*@menuはプログラムに対し静的なので、セーブするときには@configdataだけがあればよい。
*とすると、initializeにはmenudataとconfigdataしか渡されない(@selectedはそれらから生成する)
*またmenudataのみしか渡されない場合もある。

*runにおいては@selectedのみを操作し、runの終了時に@selected => @configdataとする。(Conf#renew_configdata)
 即ちrunする前に、@selectedが@configdataに同期している必要がある。
*$CONF_xxがあれば@configdataはいらない。
 データのセーブ方法を新しく考える必要あり。
*["music"=>$CONF_music,"sound"=>$CONF_sound, ...]みたいなハッシュをセーブ時に作成して

*initializeとloadをわけるとか

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

=begin  
==データ形式
  menu = [
    ["display", ["window","fullscreen"]],
    ["sound", ["on","off","auto"]],
    ["music vol", ["off","10","20","30","40","50","60","70","80","90","100"], false ],
    [],
    ["key config",Proc.new{key_config}]
    ["#exit"]
  ]
とか。

各メニュー項目は、
*Choice
   ["Music", [true,false]]
 選択。第３引数でループするかどうかを指定できます ((-やめるかも-))

 この場合、$CONF_Musicという変数にtrueもしくはfalseがセットされます。
 画面上では、true→"ON", false→"OFF"と表示されます（設定可能）。

 よって、Choiceの項目名には半角英数字と空白、`_'以外の文字は使えません。空白は'_'に変換されます。

 例:
   ["MUSIC VOL",[0,10,20,(省略),90,100 ]]  #=> $CONF_MUSIC_VOL = 0 等
*Command  
   ["key config", proc{key_config} ]
 spaceまたはenterが押されたときにProcを実行
*Space
   []または[nil]
 空行。
*Exit
   ["#exit"]または["#EXIT"]または["#Exit"]
 選択されたときにメニューを終了

のどれかを指定します。

Choiceの選択肢にはStringの他、Fixnum等も使えます（表示時に.to_sしているので）。
Choice,Commandの項目名はStringしか使えません(それ以外のものを渡すとArgumentErrorが発生します)。

Choiceの項目名は重複させるべきではありません（重複するとConf#[]とかConf#dataで困ることになるでしょう）。
=end

  # 上のフォーマットに従った配列を受け取り、
  # 適切なオブジェクト(Choice,Command,Space)を返す。
  # さらに@selected,$CONF_xxを初期化する。
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
      if item[0]==nil then  #大きい空白（未実装）
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

  #空白をスペースに、記号が入ってたらエラー
  def quote_space(name)
    raise ArgumentError,"title of Choice must be String" unless name.is_a? String
    if name=~/[^A-Za-z0-9_ ]/ then
      raise ArgumentError,"you can use only A-Z,a-z,0-9,`_' and space for a title of Choice."
    end
    name.gsub(/ /,"_")
  end

  # @selected -> $CONF_xx
  # (runの終了時に使う)
  def renew_configdata
    @menu.each do |item|
      if item.is_a? Choice then
        # $CONF_music = item.items[@selected['music']]
        instance_eval("$#{PREFIX}#{item.name} = item.items[@selected[item.name]]")
      end
    end
  end
  
public

=begin
==クラスメソッド
--- initialize(screen,font[,menudata])
    Confクラスのオブジェクトを生成して返します。

    screenにはSDLのscreenを、fontにはSDL::TTFオブジェクトを、
    menudataにはコンフィグメニューのメニューデータを指定します（((<データ形式>))を参照）。

    menudataを省略した場合は、Conf#runを呼ぶ前に必ずConf#add_menuitem(s)によりメニューデータを与えなければいけません。
=end
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

  attr_accessor :margin_top,:margin_left,:line_height

=begin   
==メソッド
--- margin_top
--- margin_left
--- line_height
    それぞれ、コンフィグ画面の上の余白、左の余白、１行の高さを表します。代入もできます。デフォルトでは
      margin_top  = 32
      margin_left = 32
      line_height = (文字列"pjfM"を現在のフォントで描画したときの高さ) * 1.5
    となっています。（単位：pixel）

--- add_menuitem(item)
    新しいメニューアイテムitemを追加します。itemはArrayです（((<データ形式>))を参照）。
--- add_menuitems(items)
    複数のメニューアイテムitems(Array)を追加します。（参照：((<データ形式>))）
--- quit
    実行中のコンフィグメニューを終了します。Command形式のメニューアイテムで使います（((<データ形式>))を参照）。
--- on_draw{|screen,dt| ... }
    画面の書き換え時に実行される処理を指定します。この処理はループ毎に実行され、この処理のあとに文字が描画されます。
    dtは前回呼び出し時からの経過時間(ms)です。

    使用例:
      conf.on_draw{|screen,dt|
        screen.fillRect(0,0,screen.w, screen.h,[255,255,255])
      }     
--- true_string(str)
--- false_string(str)
    Choiceの選択肢にtrue/falseを指定したときに表示される文字列を指定します。
    デフォルトではそれぞれ"ON","OFF"です。
=end

  def add_menuitem(item)
    raise ArgumentError,"#{item} is not an Array" if !item.is_a? Array
    raise ArgumentError,"wrong # of arguments" if item.size>3
    @menu << menuitemize(item)
  end

  def add_menuitems(items)
    items.each do |item|
      add_menuitem(item)
    end
  end

  def quit
    @running=false
  end

  def on_draw(&block)
    @ondraw = block
  end

  def true_string(str)
    @true_string = str
  end
  def false_string(str)
    @false_string = str
  end
  
=begin
--- run
    コンフィグメニューを実行します。操作は((<config画面での操作方法>))を参照してください。

    また、現在の仕様では実行するとキーリピートがオフになります。注意してください。
=end

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

=begin
--- savedata
    コンフィグデータをMarshal可能なオブジェクトに変換したものを返します。(現在の実装では、Hashが返されます)

    Conf.initializeやConf#add_menuitems等でメニューデータをセットしてから呼び出してください。
    ((-というのは、$CONF_xxのうち、メニューデータにあるものしかセーブしないからです。-))

--- loaddata(data)
    Conf#savedataが返したオブジェクトを読み込みます。dataが明かに不適切(つまり現在の実装では、Hash以外)な時は
    何もしません。

    Conf.initializeやConf#add_menuitems等でメニューデータをセットしてから呼び出してください。
    ((-というのは、メニューデータをセットする時に「どれを選んだか」という情報がリセットされるからです。
    これは直そうとすれば直せるのですが、コードが少し複雑になるので仕様としています。-))
=end

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

  #savedata => $CONF_xx, @selected
  def loaddata(savedata)
    return unless savedata.is_a? Hash
      
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

