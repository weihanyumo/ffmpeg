#!/bin/sh

SOURCE="ffmpeg-2.0.2"
FAT="Fat"
SCRATCH="scratch"
THIN=`pwd`/"thin"

ARCHS="arm64 armv7 armv7s x86_64 i386"
# absolute path to x264 library
#X264=`pwd`/fat-x264
#--enable-logging

CONFIGURE_FLAGS="--disable-asm --enable-cross-compile --disable-debug --enable-nonfree --disable-programs \
                 --enable-openssl --disable-doc --enable-pic  \
                 --disable-decoders --enable-decoder=h264 --enable-decoder=mpeg4 --enable-decoder=aac \
                 --disable-encoders --enable-encoder=h264 --enable-encoder=mpeg4 --enable-encoder=aac "



COMPILE="y"
LIPO="y"

DEPLOYMENT_TARGET="6.0"

if [ "$COMPILE" ]
then
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
                        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
				|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi
	if [ ! `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			-o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
	fi

	if [ ! -r $SOURCE ]
	then
		echo 'FFmpeg source not found. Trying to download...'
		curl http://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj \
			|| exit 1
	fi

	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi
		fi

#ssl

        if [ "$ARCH" = "i386" ]
        then
            FF_BUILD_NAME_OPENSSL="openssl-i386"
        elif [ "$ARCH" = "x86_64" ]
        then
            FF_BUILD_NAME_OPENSSL="openssl-x86_64"
        elif [ "$ARCH" = "armv7" ]
        then
            FF_BUILD_NAME_OPENSSL="openssl-armv7"
        elif [ "$ARCH" = "armv7s" ]
        then
            FF_BUILD_NAME_OPENSSL="openssl-armv7s"
        elif [ "$ARCH" = "arm64" ]
        then
            FF_BUILD_NAME_OPENSSL="openssl-arm64"
        else
            echo "unknown architecture $FF_ARCH";
            exit 1
        fi

        FFMPEG_DEP_OPENSSL_INC="$CWD/openssl/$FF_BUILD_NAME_OPENSSL/output/include"
        echo $FFMPEG_DEP_OPENSSL_INC
        FFMPEG_DEP_OPENSSL_LIB="$CWD/openssl/$FF_BUILD_NAME_OPENSSL/output/lib"
#ssl end


		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		CXXFLAGS="$CFLAGS"

        CFLAGS="$CFLAGS -I${FFMPEG_DEP_OPENSSL_INC}"
        FFMPEG_DEP_LIBS="$CFLAGS -L${FFMPEG_DEP_OPENSSL_LIB} -lssl -lcrypto"
		LDFLAGS="$FFMPEG_DEP_LIBS"


		TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
		    --target-os=darwin \
		    --arch=$ARCH \
		    --cc="$CC" \
		    $CONFIGURE_FLAGS \
		    --extra-cflags="$CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH" \
		|| exit 1

		make -j3 install $EXPORT || exit 1
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		echo lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB 1>&2
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB || exit 1
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi

rm -r $THIN
rm -r $SCRATCH

echo Done
