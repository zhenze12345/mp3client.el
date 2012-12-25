mp3client.el
============

An emacs client to control my simple mp3 server in
https://github.com/zhenze12345/mp3server.

Usage:
Add (require 'mp3client) to your .emacs file.

All the function of mp3client with a prefix of "mp3-client-".

Start connect:
(mp3-client-start)

Stop connect:
(mp3-client-stop)

Refresh music list:
(mp3-client-fetch-music-list)

Next music:
(mp3-client-next-music)

Restart this music:
(mp3-client-restart-music)

Play music:
(mp3-client-play-music)

Pause music:
(mp3-client-pause-music)

Stop music:
(mp3-client-stop-music)

Go ahead three seconds:
(mp3-client-seek-+3)

Go back three seconds:
(mp3-client-seek--3)

And this is my first program which written in emacs lisp.
