#!/usr/bin/env ruby
#
# down.rb : コマンドラインから起動するためのスクリプト
#
$LOAD_PATH.unshift "."
require "main.rb"

#------------------------------------------------------------------------------

#options
require 'getopts'
getopts("sfh","help","silent")
if $OPT_help || $OPT_h then
  puts "DOWN!! v#{Main::VERSION}"
  puts "usage: ruby down.rb [options]"
  puts "options:"
  puts "    -s, --silent"
  puts "    -f, --fullscreen"
  puts "    -h, --help"
  exit
end
$OPT_s=true if $OPT_silent

#execute
Main.init
Main.new.start
