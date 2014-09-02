#!/usr/bin/env ruby
#
# down.rb : Entrypoint for command-line
#
$LOAD_PATH.unshift "."
require "main.rb"

require 'optparse'
OptionParser.new{|o|
  o.on("-s", "--silent"){
    puts "set to silent mode"
    $OPT_s = true
  }
  o.on("-f", "--fullscreen"){
    puts "set to fullscreen"
    $OPT_f = true
  }
}.parse(ARGV)

Main.init
Main.new.start
