<a href="http://getpat.io"><img src="https://raw.githubusercontent.com/la5nta/pat-website/gh-pages/img/logo.png" width="128" ></a>

[![Build Status](https://app.travis-ci.com/la5nta/pat.svg?branch=master)](https://app.travis-ci.com/la5nta/pat)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/tstq4suxfdmudl5l/branch/master?svg=true)](https://ci.appveyor.com/project/martinhpedersen/pat)
[![Go Report Card](https://goreportcard.com/badge/github.com/la5nta/pat)](https://goreportcard.com/report/github.com/la5nta/pat)
[![Liberapay Patreons](http://img.shields.io/liberapay/patrons/la5nta.svg?logo=liberapay)](https://liberapay.com/la5nta)

## Overview

Pat is a cross platform Winlink client with basic messaging capabilities.

It is the primary sandbox/prototype application for the [wl2k-go](https://github.com/la5nta/wl2k-go) project, and provides both a command line interface and a responsive (mobile-friendly) web interface.

It is mainly developed for Linux, but is also known to run on OS X, Windows and Android.

#### Features
* Message composer/reader (basic mailbox functionality).
* Auto-shrink image attachments.
* Post position reports with location from local GPS, browser location or manual entry.
* Rig control (using hamlib) for winmor PTT and QSY.
* CRON-like syntax for execution of scheduled commands (e.g. QSY or connect).
* Built in http-server with web interface (mobile friendly).
* Git style command line interface.
* Listen for P2P connections using multiple modes concurrently.
* AX.25, telnet, WINMOR and ARDOP support.
* Experimental gzip message compression (See "Gzip experiment" below).

##### Example
```
martinhpedersen@duo:~$ pat interactive
> listen winmor,telnet-p2p,ax25
2015/02/03 10:33:10 Listening for incoming traffic (winmor,telnet-p2p,ax25)...
> connect winmor:///LA3F
2015/02/03 10:34:28 Connecting to winmor:LA3F...
2015/02/03 10:34:33 Connected to WINMOR:LA3F
RMS Trimode 1.3.3.0 Follo.SE Oslo. Pactor & Winmor Hybrid Gateway
LA5NTA has 117 minutes remaining with LA3F
[WL2K-2.8.4.8-B2FWIHJM$]
Wien CMS via LA3F >
>FF
FC EM FOYNU8AKXX59 260 221 0
F> 68
1 proposal(s) received
Accepting FOYNU8AKXX59
Receiving [//WL2K test til linux] [offset 0]
>FF
FQ
Waiting for remote node to close the connection...
> _
```

### Gzip experiment

Gzip message compression has been added as an experimental B2F extension. The extension is implemented as a backwards compatible alternative to the ancient LZHUF compression.

This experiment is enabled by default and sessions between two Pat nodes (or other software supporting this B2F extension) will use gzip compression when transferring messages.

For more information, see <https://github.com/la5nta/wl2k-go#gzip-experiment>.

## Pat with native AX.25

This version of Pat supports a native AX.25 interface.  This is
obviously experimental and may have issues, but it should ease the use
of Pat and allow it to do AX.25 on non-Linux hosts.

This uses the AX.25 layer of the gensio library, see
<https://github.com/cminyard/gensio>

You need to build this to get it working, and unfortunately, it's not
an easy process.  On Linux, to build this, you must first check out a
version of swig that has some bug fixes in the Go part.  These are
submitted, but not yet in mainline for swig.

You will need gcc, g++, and go, flex, bison, and libpcre2-dev
installed, and perhaps a few other things.  You must also make sure
"go" is in your current PATH.  You can get it at https://go.dev/. Then
do:

```
git clone -b add-goin-newline https://github.com/cminyard/swig
cd swig
./autogen.sh
./configure --prefix $HOME/tmpswig
make
make install
export PATH=$HOME/tmpswig/bin:$PATH
```

There may be more things to install than I have said, the configure
script should tell you if it needs something else, but that's broken
for bison.

Now check out Pat and build it:

```
cd ..
git clone -b gensio-work https://github.com/cminyard/wl2k-go
git clone -b gensio-work https://github.com/cminyard/pat
cd pat
./make.bash libax25
./make.bash gensio
./make.bash
```

You should now have a pat executable in the current directory.

You have to add a configuration for gax25.  It won't have it if you
already have a configuration installed.  The default one is:

```
  "gax25": {
    "gensio": "kiss,tcp,localhost,8001",
    "beacon": {
      "every": 3600,
      "message": "Winlink P2P",
      "destination": "IDENT"
    },
    "rig": ""
  },
```

The "gensio" string tells Pat how to connect to the TNC.  If you are
running direwolf on the local system, the default is correct.
Otherwise replace "localhost" with the proper host and the "8001" with
the port number you need.  If you need to specify kiss parameters, you
would add (parm=a,parm=b) after kiss in the gensio string, like
"kiss(txdelay=100),tcp,...".  See the gensio.5 man page for details on
this.

If you have a serial TNC, you would use something like the following
for the gensio string:

```
(crc=yes)kiss,serialdev,/dev/ttyS0,9600n81
```

with obvious substitutions where you need them.  This is untested.
You can pass parameters to the ax25 gensio by putting:

```
(parm=asdf,parm=asdf)
```

at the beginning of the gensio string.  In the above example, it
enables crc checking in the ax25 layer.  By default this is disabled
as direwolf does it for you, but it might be required for a serial
TNC.

To see the man page telling about gensio strings, do the following
from the pat directory after building:

```
nroff -man .build/gensio-2.4.0-rc4/man/gensio.5 | less -r
```

To use this, you basically just put gax25 where you would normally use
ax25, except there's none of the linux setup.  Once you do "pat
configure" you are ready to go.  For instance, I use:

```
pat connect gax25:///n5cor-10
```

The gensio library is pretty flexible, you can use UDP as well.
That's too big a discussion for here, see the gensio man page and
gensio README for details.

Note that I have compiled and tried this under Windows using mingw64
(you still have to compile swig and such, you have to compile gensio
yourself, and you have to build with go in a native Windows
environment).  It works, but it's fairly complicated.  If you know
what you are doing it's not too hard.  If you don't know what you are
doing the learning curve is pretty steep.

So to compile under Windows, you basically follow the steps above in
the mingw64 environment, except you don't do the "./make.bash libax25"
step since that's for Linux only.  You will end up with a binary that
has some DLL dependencies to mingw64 stuff, but that is unavoidable,
as far as I can tell.

## Copyright/License

Copyright (c) 2020 Martin Hebnes Pedersen LA5NTA

### Contributors (alphabetical)

* DL1THM - Torsten Harenberg
* HB9GPA - Matthias Renner
* K0SWE - Chris Keller
* KD8DRX - Will Davidson
* KE8HMG - Andrew Huebner
* KI7RMJ - Rainer Grosskopf
* LA3QMA - Kai Günter Brandt
* LA4TTA - Erlend Grimseid
* LA5NTA - Martin Hebnes Pedersen
* W6IPA  - JC Martin
* WY2K - Benjamin Seidenberg
* VE7GNU - Doug Collinge

## Thanks to

The JNOS developers for the properly maintained lzhuf implementation, as well as the original author Haruyasu Yoshizaki.

The paclink-unix team (Nicholas S. Castellano N2QZ and others) - reference implementation

Amateur Radio Safety Foundation, Inc. - The Winlink 2000 project

F6FBB Jean-Paul ROUBELAT - the FBB forwarding protocol

_Pat/wl2k-go is not affiliated with The Winlink Development Team nor the Winlink 2000 project [http://winlink.org]._
