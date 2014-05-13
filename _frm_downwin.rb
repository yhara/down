## CAUTION!! ## This code was automagically ;-) created by FormDesigner.
# NEVER modify manualy -- otherwise, you'll have a terrible experience.

require 'vr/vruby'
require 'vr/vrcontrol'
require 'vr/vrhandler'

module Frm_form
  include VRClosingSensitive

  def _form_init
    self.sizebox=false
    self.maximizebox=false
    self.caption = 'Down!!'
    self.move(146,160,170,168)
    addControl(VRStatic,'static1','Down!! on Ruby/SDL Ver.0.83',8,8,136,40,1342177280)
    @static1.setFont(@screen.factory.newfont(
      "MS UI Gothic",-13,0,0,0,0,0,50,128,100,0))
    addControl(VRRadiobutton,'rad_window','Window',8,56,136,24,1342177289)
    @rad_window.setFont(@screen.factory.newfont(
      "MS UI Gothic",-13,0,0,0,0,0,50,128,100,0))
    addControl(VRRadiobutton,'rad_fullscreen','Fullscreen',8,80,136,16,1342177289)
    @rad_fullscreen.setFont(@screen.factory.newfont(
      "MS UI Gothic",-13,0,0,0,0,0,50,128,100,0))
    addControl(VRButton,'btn_execute','run',93,104,59,24,1342242816)
    @btn_execute.setFont(@screen.factory.newfont(
      "MS UI Gothic",-13,0,0,0,0,0,50,128,100,0))
  end 

  def construct
    _form_init
  end 

end 

#VRLocalScreen.start Frm_form
