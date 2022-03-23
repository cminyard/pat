<a href="http://getpat.io"><img src="https://raw.githubusercontent.com/la5nta/pat-website/gh-pages/img/logo.png" width="128" ></a>

[![Build status](https://github.com/la5nta/pat/actions/workflows/go.yaml/badge.svg)](https://github.com/la5nta/pat/actions)
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
* Rig control (using hamlib).
* CRON-like syntax for execution of scheduled commands (e.g. QSY or connect).
* Built in http-server with web interface (mobile friendly).
* Git style command line interface.
* Listen for P2P connections using multiple modes concurrently.
* AX.25, telnet, PACTOR and ARDOP support.
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

### Building

Binaries are available at <https://github.com/cminyard/pat> under
"Releases".  You can build it yourself, though, but unfortunately it's
not an easy process.  On all platforms, to build this, you need out a
version of swig that has some bug fixes in the Go part.  These are in
mainline for swig and recently released, but you might have to check
out swig from it's repository and use it.

You will need git, gcc, g++, and go, flex, bison, and libpcre2-dev
installed, and perhaps a few other things.  You must also make sure
"go" is in your current PATH.  You can get it at https://go.dev/. Then
do:

```
git clone https://github.com/swig/swig
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
./make.bash libax25 #Linux only
./make.bash gensio
./make.bash
```

You should now have a pat executable in the current directory.

### Configuring Pat for ax25+gensio

You have to add a configuration for ax25+gensio.  It won't have it if you
already have a configuration installed.  The default one is:

```
  "gensio": {
    "gensio": "kiss,keepopen(discard-badwrites=yes),tcp,localhost,8001",
  },
```

The "gensio" string tells Pat how to connect to the TNC.  If you are
running direwolf on the local system, the default is correct.
Otherwise replace "localhost" with the proper host and the "8001" with
the port number you need.  If you need to specify kiss parameters, you
would add (parm=a,parm=b) after kiss in the gensio string, like
"kiss(txdelay=100),tcp,...".  See the gensio.5 man page for details on
this.  Added parameters to the ax25 gensio can be added by doing
"(parm=x)" before kiss, no comma.

If you have a Kenwood D710 and want to use the built-in TNC through a
serial port, you can use the following gensio line:

```
"gensio": "kiss(d710),serialdev,/dev/ttyUSB1,9600n81,local,rtscts",
```

If you want to use 9600 baud instead of 1200 baud, use "d710-9600"
instead of "d710".  Note that once you put the D710 in KISS mode, you
have to reset the TNC to get it out of KISS mode.  Turning the radio
off and does this; there may be another way but I don't know how.

If you have another serial TNC, you would use something like the
following for the gensio string:

```
(crc=yes,debug=0x18)kiss,serialdev,/dev/ttyS0,9600n81,local
```

with obvious substitutions where you need them.  If you have hardware
flow control, add ",rtscts" on to the end of this.  This is untested,
except on the D710.  The need for the "(crc=yes)" part depends on if
the TNC does the CRC itself.  The CRC code in the AX25 stack is not
well tested, but I hacked some things in direwolf so it would send the
CRC on and it appeared to work.

The "debug=0x18" thing prints out packets as they are received and
sent.  You can remove that if you don't care, or add it if you do.
These are parameters to the ax25 layer.

If you need some special startup string to talk to your TNC, you can
send that with changing "kiss" to:
```
  kiss(setupstr='<string>')
```
setup string is a normal "C" string, you can use \n for newline, \r
for carraige return, \xnn for the hex value nn, etc.  Any \ needs to
be doubled.  If you specify a setupstr, a 1 second wait is done
for the string to complete.  If you need more, you can add
"setup-delay=n" where "n" is in milliseconds.

You can pass parameters to the ax25 gensio by putting:

```
(parm=asdf,parm=asdf)
```

at the beginning of the gensio string (like the CRC in the previous
example).  By default crc is disabled as direwolf/soundmodem does it
for you, but it might be required for a serial TNC.

To see the man page telling about gensio strings, do the following
from the pat directory after building:

```
nroff -man .build/gensio-2.4.0-rc4/man/gensio.5 | less -r
```

### ax25+gensio and the built-in TNC

ax25+gensio has a built-in TNC, so with it there is no need for an
external TNC like direwolf or soundmodem.  Configuring it is a little
tricky, but once you get it it's not a big deal.

The first thing you must do is find the sound device.  Run:

```
$ gsound -L
```

On Windows, you will see something like:

```
0:Microphone (2- USB Audio CODEC        input,inchans=2
1:Microphone Array (Senary Audio)       input,inchans=2
0:Speakers (2- USB Audio CODEC )        output,outchans=2
```

You can generally just pick part of the name (the part on the left
side).  I'm using the USB Audio CODEC, so "USB" here will work just
fine.

On Linux it's a little messier, you will see a lot of output, but you
are looking for something like:

```
plughw:CARD=Device,DEV=0
    USB PnP Sound Device, USB Audio
    Hardware device with all software conversions
        input,output
```

and you will need the whole "plughw:CARD=Device,DEV=0" for the name.

Then you will set the following in the configuration:

```
  "gensio": {
    "gensio": "afskmdm(debug=0x18),sound(48000-1-float),USB"
  },
```

This would work in the Windows example above.  For Linux you would use:

```
  "gensio": {
    "gensio": "afskmdm(debug=0x18),sound(48000-1-float),plughw:CARD=Device,DEV=0"
  },
```

This will work find with a Signalink or other sound interface that
uses VOX.  If you have something that has a separate key requirement,
it's more complicated.  If it's a serial port keyed with the RTS or
line, you need to find the serial port and tell afskmdm where it is.
On Windows find the COM port (like COM10) and set the keytype (rts or
dtr) and use the "key" string to tell it where to find the comm port.

```
  "gensio": {
    "gensio": "afskmdm(debug=0x18,tx-predelay=500,keytype=rts,key=\"sdev,COM10\"),sound(48000-1-float),USB"
  },
```

On Linux, you need to find the /dev/ttyUSBxxx device associated with
the connection.  Just plug it in and do "ls /dev/ttyUSB*" and see what
appears.  You can use that directly, but it can change when your
system reboots or you add other serial ports.  It's best to find the
path.  do "ls -l /dev/serial/by-path" and find the usb device that
links to the proper /dev/ttyUSBxxx.  It's basically the same as the
Windows one:

```
  "gensio": {
    "gensio": "afskmdm(debug=0x18,tx-predelay=500,keytype=rts,key=\"sdev,/dev/serial/by-path/pci-0000:04:00.3-usb-0:1.3.2.4.1.2:1.0-port0\"),sound(48000-1-float),plughw:CARD=Device,DEV=0"
  },
```

Note that to access serial ports on Linux, you must be a member of the
"dialout" group.

If you have a CM108 based key, then it's a little easier, just do:

```
  "gensio": {
    "gensio": "afskmdm(debug=0x18,key=\"cm108gpio,1\"),sound(48000-1-float),USB"
  },
```

the same on Windows and Linux.  The ",1" in the key string tells which
gpio to use, generally 1.

On Linux, by default the /dev/hidrawN devices that you must use to
access the cm108 GPIO are for root-only.  To fix that, first do
"lsusb" and find the ID of your device.  The output will look
something like:

```
Bus 001 Device 004: ID 0d8c:013a C-Media Electronics, Inc. USB PnP Sound Device
```

On the ID, the number before the ':' is the vendor id, the number after
is the product id.  Now add the following in a file named
`/etc/udev/rules.d/71-cm108.rules`:

```
# A C-Media Electronics USB PnP Sound device, for GPIO
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0d8c", ATTRS{idProduct}=="013a", MODE:="0660", GROUP="dialout"
```

substituting your vendor and product ID with the ones above.  You will
need to be a member of the `dialout` group again, because that's what
the above does.  If you set the mode to `0666` then anyone could use it.

### Using Pat with ax25+gensio

To use this, you basically just put ax25+gensio where you would
normally use ax25, except there's none of the linux setup.  Or you can
just use ax25 and add:
```
"engine": "gensio"
```
to the ax25 config entry.  Once you do "pat configure" you are ready
to go.  For instance, I use:

```
pat connect ax25+gensio:///n5cor-10
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

### Scripting with ax25+gensio

Some gateway connections require you to interact with the gateway
before it connects you to the remote system.  ax25+gensio supports
this by calling an external program and connecting it's stdin/stdout
to ax25.  So anything written to stdout by the external program will
be sent out ax25, and anything received on ax25 will be sent to the
external program's stdin.  This way you can use something like
"expect" (with expect_user and send_user) to do the interaction you
need.  Or you can use any other programming language you would like.
Just be careful that you flush output when writing, or things may not
be sent.

To use scripting, add script= to the url as a standard url item. So,
for instance, I used:

```
   pat connect 'ax25+gensio:///n5cor-10?parms=extended=0&script=./testscr'
```

where "testscr" is the program in the current directory.  Once the
program exits, the connection process will continue normally.

If connecting via the web gui, you can add &script= at the end of the
parms field and it should work.

### Building ax25 gensio on Old Linux OSes

In some cases it's better to build on an old release.  This can be
done with chroot and debootstrap.  This will only work on debian-based
systems.  First make sure debootstrap is installed on your system:

```
  sudo apt install debootstrap
```

For i386, do:

```
  mkdir -p chroot/debian-386-stretch
  sudo debootstrap --arch=i386 stretch chroot/debian-386-stretch/ http://archive.debian.org/debian-archive/debian
  sudo setarch i686 chroot chroot/debian-386-stretch
  apt install debootstrap curl libpcre2-dev
  cd tmp
  wget https://go.dev/dl/go1.25.1.linux-386.tar.gz
```

For amd64, do:

```
  mkdir -p chroot/debian-amd64-stretch
  sudo debootstrap --arch=amd64 stretch chroot/debian-amd64-stretch/ http://archive.debian.org/debian-archive/debian
  sudo chroot chroot/debian-amd64-stretch
  apt install debootstrap curl libpcre2-dev
  cd tmp
  wget https://go.dev/dl/go1.25.1.linux-amd64.tar.gz
```

For arm32, do:

```
  mkdir -p chroot/debian-arm32-stretch
  sudo debootstrap --arch=armhf stretch chroot/debian-arm32-stretch/ http://archive.debian.org/debian-archive/debian
  sudo setarch armh chroot chroot/debian-arm32-stretch
  apt install debootstrap curl libpcre2-dev
  cd tmp
  wget https://go.dev/dl/go1.25.1.linux-armv6l.tar.gz
```

For arm64, do:

```
  mkdir -p chroot/debian-arm64-stretch
  sudo debootstrap --arch=arm64 stretch chroot/debian-arm64-stretch/ http://archive.debian.org/debian-archive/debian
  sudo chroot chroot/debian-arm64-stretch
  apt install debootstrap curl libpcre2-dev
  cd tmp
  wget https://go.dev/dl/go1.25.1.linux-arm64.tar.gz
```

Now the machine-independent portions:

```
  # Do an apt install of the packages required for build described in
  # the gensio BUILD.rst document.
  useradd -m cminyard
  su - cminyard
  exec bash
  tar xzf /tmp/go1.25*
  mv go gobin
  cat <<END >>.profile
  export PATH=$HOME/gobin/bin:$PATH
  export GOROOT=$HOME/gobin
  END
  mkdir git
  cd git
  wget https://ftp.gnu.org/gnu/bison/bison-3.8.tar.gz
  tar xzf bison-3.8.tar.gz
  cd bison-3.8
  ./configure
  make
  exit
  cd /home/cminyard/git/bison-3.8
  make install
  su - cminyard
  exec bash
  cd git
  git clone https://github.com/swig/swig.git
  git clone https://github.com/cminyard/wl2k-go.git
  git clone https://github.com/cminyard/pat.git
  cd swig
  ./autogen.sh
  ./configure --with-python --with-go
  make
  exit
  cd /home/cminyard/git/swig
  make install
  su - cminyard
  exec bash
  cd git/wl2k-go
  git checkout gensio-work
  cd ../pat
  git checkout gensio-work
  ./make.bash libax25
  ./make.bash gensio
  ./make.bash
```

You must also add "-ldl" to the GENSIO\_LIBS environment variable in
the "make.bash" script or it won't link, you'll get an error about
dlopen.

Every time you want to use this, do the setarch+chroot command and such:

```
  sudo setarch i686 chroot chroot/debian386-arm32-stretch
  su - cminyard
  exec bash
```

and you can update things with git and rebuild.

## Copyright/License

Copyright (c) 2020 Martin Hebnes Pedersen LA5NTA

### Contributors (alphabetical)

* AB3E - Justin Overfelt
* DL1THM - Torsten Harenberg
* HB9GPA - Matthias Renner
* K0RET - Ryan Turner
* K0SWE - Chris Keller
* KD8DRX - Will Davidson
* KE8HMG - Andrew Huebner
* KI7RMJ - Rainer Grosskopf
* KM6LBU - Robert Hernandez
* LA3QMA - Kai Günter Brandt
* LA4TTA - Erlend Grimseid
* LA5NTA - Martin Hebnes Pedersen
* N2YGK - Alan Crosswell
* VE7GNU - Doug Collinge
* W6IPA  - JC Martin
* WY2K - Benjamin Seidenberg

## Thanks to

The JNOS developers for the properly maintained lzhuf implementation, as well as the original author Haruyasu Yoshizaki.

The paclink-unix team (Nicholas S. Castellano N2QZ and others) - reference implementation

Amateur Radio Safety Foundation, Inc. - The Winlink 2000 project

F6FBB Jean-Paul ROUBELAT - the FBB forwarding protocol

_Pat/wl2k-go is not affiliated with The Winlink Development Team nor the Winlink 2000 project [http://winlink.org]._
