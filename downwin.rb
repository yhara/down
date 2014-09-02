#
# downwin.rb : Show windows form and start game
#

require 'vr/vruby'
require 'vr/vrdialog'
require '_frm_downwin.rb'
require 'main.rb'

module WConst
  VK_RETURN = 0x0D
  VK_SPACE  = 0x20
end

module Frm_form
  def self_created
    @mode = :window
    @exec = true
    @rad_window.check(true)
    @static1.caption = "Down!! on Ruby/SDL\nVer.#{Main::VERSION}"
  end

  def rad_window_clicked
    @mode = :window
  end

  def rad_fullscreen_clicked
    @mode = :fullscreen
  end

  attr_reader :mode

  def btn_execute_clicked
    self.close
  end

  def self_close
    # Close button
    @exec = false
  end
  attr_reader :exec
end

#run form
frm = VRLocalScreen.newform
frm.extend Frm_form
frm.create.show
VRLocalScreen.messageloop

#hoge = VRLocalScreen.modelessform(nil,nil,Frm_form)  
#VRLocalScreen.messageloop

#run game
if frm.exec
  $OPT_f = true if frm.mode==:fullscreen
  Main.init
  Main.new.start
end
