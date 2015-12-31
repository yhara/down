Down!!
======

A game written in [Ruby/SDL](http://ohai.github.io/rubysdl/).

![](image/screenshot.png)

How to run
==========

Windows (binary)
----------------

Execute down.exe (This is compiled version of Down v0.52)

Mac (source)
------------

    $ brew install sdl sdl_ttf
    $ brew install sdl_mixer --with-libmikmod
    $ gem install rubysdl rsdl
    $ rsdl down.rb

Linux (source)
--------------

* Install SDL 1.3.x, SDL_TTF, SDL_Mixer(with mod support)
* `gem install rubysdl`
* `ruby down.rb`

Command-line options
--------------------

* `-h` : Show help
* `-s`, `--silent` : Silent mode (disable sound)
* `-f`, `--fullscreen` : Start in fullscreen
* `--savefile PATH` : Path to savefile  (default: "./save.dat")

License
=======

MIT

History
=======

* (v1.0.0)
  - Added --savefile option
* 2014-05-19 v0.53
  - Support Ruby >= 1.9, etc.
* 2013 Upload to github
* 2003-2004 (v0.52) Remake with Ruby/SDL
* 1997 First version was written in C for NEC 9801Fs

Contact
=======

https://github.com/yhara/down

Yutaka HARA (yhara)
