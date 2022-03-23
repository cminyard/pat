#!/usr/bin/env bash
set -e

export GO111MODULE=on

if [ -d $GOOS ]; then OS=$(go env GOOS); else OS=$GOOS; fi
if [ -d $CGO_ENABLED ]; then CGO_ENABLED=$(go env CGO_ENABLED); else OS=$CGO_ENABLED; fi

echo "Building for $OS"

GITREV=$(git rev-parse --short HEAD)
GITTAG=$(git tag --contains HEAD)
VERSION=$(grep "Version =" internal/buildinfo/VERSION.go|cut -d '"' -f2)

# Go 1.19 or later is required
GO_POINT_VERSION=$(go version| perl -ne 'm/go1\.(\d+)/; print $1;')
[ "$GO_POINT_VERSION" -lt "19" ] && echo "Go 1.19 or later required" && exit 1;

AX25VERSION="0.0.12-rc4"
AX25DIST="libax25-${AX25VERSION}"
AX25DIST_URL="https://ubuntu.hi.no/ubuntu/pool/universe/liba/libax25/libax25_${AX25VERSION}.orig.tar.gz"
function install_libax25 {
	mkdir -p .build && cd .build
	[[ -f "${AX25DIST}" ]] || curl -LSsf "${AX25DIST_URL}" | tar zx
	cd "${AX25DIST}/" && ./configure --prefix=/ && make && cd ../../
}
function build_web {
	cd web
	if [ -d $NVM_DIR ]; then
	  source $NVM_DIR/nvm.sh
	  nvm install
	  nvm use
	fi
	npm install
	npm run production
}

[[ "$1" == "libax25" ]] && install_libax25 && exit 0;
[[ "$1" == "web" ]] && build_web && exit 0;

# Link against libax25 (statically) on Linux
#LIBAX25_CFLAGS=
#LIBAX25_LDFLAGS=
if [[ "$OS" == "linux"* ]] && [[ "$CGO_ENABLED" == "1" ]]; then
	TAGS="libax25 $TAGS"
	LIB=".build/${AX25DIST}/.libs/libax25.a"
	if [[ -z "$LIBAX25_LDFLAGS" ]] && [[ -f "$LIB" ]]; then
		export LIBAX25_CFLAGS="-I$(pwd)/.build/${AX25DIST}"
		export LIBAX25_LDFLAGS="$(pwd)/${LIB}"
	fi
	if [[ -z "$LIBAX25_LDFLAGS" ]]; then
		echo "WARNING: No static libax25 library available."
		echo "  Linking against shared library instead. To fix"
		echo "  this issue, set LIBAX25_LDFLAGS to the full path of"
		echo "  libax25.a, or run 'make.bash libax25' to download"
		echo "  and compile ${AX25DIST} in .build/"
	else
		TAGS="static $TAGS"
	fi
else
	if [[ "$OS" == "linux"* ]]; then
		echo "WARNING: CGO unavailable. libax25 (ax25+linux) will not be supported with this build."
	fi
fi

GENSIOVERSION="2.8.15"
GENSIODIST="gensio-${GENSIOVERSION}"
GENSIODIST_BASEURL="https://sourceforge.net/projects/ser2net/files/ser2net"
GENSIODIST_URL="${GENSIODIST_BASEURL}/${GENSIODIST}.tar.gz"
GENSIODIST_PATCHES=""
function install_gensio {
	mkdir -p .build && cd .build
	if [ ! -f "${GENSIODIST}" ]; then
		echo "Downloading ${GENSIODIST_URL}"
		curl -LSsf "${GENSIODIST_URL}" | tar zx
		cd "${GENSIODIST}"
		for i in ${GENSIODIST_PATCHES}; do
		    echo "Applying patch $i"
		    curl -LSsf "${GENSIODIST_BASEURL}/$i" | patch -p1
		done
	else
		cd "${GENSIODIST}"
	fi
	./configure --prefix=/ --enable-static --disable-shared --with-go=no --with-sctp=no --with-mdns=no --with-ssl=no --with-certauth=no --with-ipmisol=no && make && cd ../../
}

[[ "$1" == "gensio" ]] && install_gensio && exit 0;

EXTRALIBS=""
EXTRA_CXXFLAGS=""
if [[ "$OS" == "windows"* ]]; then
	bdir=`pwd -W`
	EXTRALIBS="-lws2_32 -liphlpapi -lgdi32 -lbcrypt"
	EXTRALIBS="$EXTRALIBS -lsecur32 -luserenv -lwtsapi32 -lole32 -lwinmm"
	EXTRALIBS="$EXTRALIBS -lhid -lsetupapi"
else
	bdir=`pwd`
	case $OS in
        linux)
		EXTRALIBS="-lasound -ludev"
		;;
	darwin)
		EXTRA_CXXFLAGS="-std=gnu++11"
		EXTRALIBS="-L /opt/homebrew/lib -lportaudio"
		;;
	*)
		;;
	esac
fi

# Uncomment these to link dynamically against gensio on Linux
#GENSIO_CXXFLAGS="-I/usr/local/include"
#GENSIO_LDFLAGS="-L/usr/local/lib -lgensiocpp -lgensiomdnscpp -lgensiooshcpp -lgensioosh -lgensiomdns -lgensio"

# Uncomment these to link dynamically against gensio on Windows MINGW64
#GENSIO_CXXFLAGS="-I/mingw64/include"
#GENSIO_LDFLAGS="-L/mingw64/lib -lgensiocpp -lgensiomdnscpp -lgensiooshcpp -lgensioosh -lgensiomdns -lgensio"

# Uncomment these to link statically against gensio on all platforms
GENSIO_LIBS=""
GENSIO_LIBS="${GENSIO_LIBS} .build/${GENSIODIST}/c++/lib/.libs/libgensiocpp.a"
GENSIO_LIBS="${GENSIO_LIBS} .build/${GENSIODIST}/c++/lib/.libs/libgensiomdnscpp.a"
GENSIO_LIBS="${GENSIO_LIBS} .build/${GENSIODIST}/c++/lib/.libs/libgensiooshcpp.a"
GENSIO_LIBS="${GENSIO_LIBS} .build/${GENSIODIST}/lib/.libs/libgensio.a"
GENSIO_LIBS="${GENSIO_LIBS} .build/${GENSIODIST}/lib/.libs/libgensiomdns.a"
GENSIO_LIBS="${GENSIO_LIBS} .build/${GENSIODIST}/lib/.libs/libgensioosh.a"
if [[ -z "$GENSIO_LDFLAGS" ]] && [[ -n "$GENSIO_LIBS" ]]; then
	export GENSIO_CXXFLAGS="-I${bdir}/.build/${GENSIODIST}/include -I${bdir}/.build/${GENSIODIST}/c++/include -DGENSIO_LINK_STATIC"
	export GENSIO_LDFLAGS="${GENSIO_LIBS} ${EXTRALIBS}"
fi
if [[ -z "$GENSIO_LDFLAGS" ]]; then
	echo "WARNING: No static gensio library available."
	echo "  Linking against shared library instead. To fix"
	echo "  this issue, set GENSIO_LDFLAGS to the full path of"
	echo "  libgensio.a and libgensiocpp.a, or run"
	echo "  'make.bash gensio' to download and compile"
	echo "  ${GENSIODIST} in .build/"
	sleep 3;
fi

export CGO_CFLAGS="${LIBAX25_CFLAGS}"
export CGO_CXXFLAGS="${GENSIO_CXXFLAGS} ${EXTRA_CXXFLAGS}"
export CGO_LDFLAGS="${LIBAX25_LDFLAGS} ${GENSIO_LDFLAGS}"

echo CFLAGS: ${CGO_CFLAGS}
echo CXXFLAGS: ${CGO_CXXFLAGS}
echo LDFLAGS: ${CGO_LDFLAGS}

echo -e "Downloading Go dependencies..."
go mod download

echo "Running tests..."
if [[ "$SKIP_TESTS" == "1" ]]; then
	echo "Skipping."
else
	go test -tags "$TAGS" ./... github.com/la5nta/wl2k-go/...
fi
echo

echo "Building Pat v$VERSION..."
go build -tags "$TAGS" -ldflags "-X \"github.com/la5nta/pat/internal/buildinfo.GitRev=$GITREV $GITTAG\"" $(go list .)

# Build macOS pkg
if [[ "$OS" == "darwin"* ]] && command -v packagesbuild >/dev/null 2>&1; then
	ARCH=$(go env GOARCH)
	echo "Generating macOS installer package..."
	packagesbuild osx/pat.pkgproj
	mv 'Pat :: A Modern Winlink Client.pkg' "pat_${VERSION}_darwin_${ARCH}_unsigned.pkg"
fi

echo -e "Enjoy!"
