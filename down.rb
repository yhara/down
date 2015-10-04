#!/usr/bin/env ruby
#
# down.rb : Entrypoint for command-line
#
orig_dir = Dir.pwd
Dir.chdir(File.dirname(__FILE__))
$LOAD_PATH.unshift "."
require "main.rb"

require 'optparse'
OptionParser.new{|o|
  o.on("-s", "--silent", "Do not play sound"){
    puts "set to silent mode"
    $OPT_s = true
  }
  o.on("-f", "--fullscreen", "Start in fullscreen"){
    puts "set to fullscreen"
    $OPT_f = true
  }

  $OPT_savefile = "save.dat"
  o.on("--savefile PATH",
       "Path to score data file (default: ./save.dat)"){|s|
    $OPT_savefile = File.expand_path(s, orig_dir)
    puts "Savefile: #{$OPT_savefile}"
  }
}.parse(ARGV)

Main.init
Main.new.start
