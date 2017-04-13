#!/bin/sh

SOURCE="ffmpeg-2.0.2"
FAT="Fat"
SCRATCH="scratch"
THIN=`pwd`/"thin"

ARCHS="arm64 armv7 armv7s x86_64 i386"
#git clone git://git.videolan.org/x264.git

CONFIGURE_FLAGS="--disable-asm --enable-cross-compile --disable-debug --enable-nonfree --disable-doc --enable-pic \
                 --disable-programs --disable-ffmpeg --disable-ffplay --disable-ffprobe --disable-ffserver \
                  --enable-gpl --enable-openssl --enable-nonfree \
                 --disable-decoders --enable-decoder=h264 --enable-decoder=mpeg4 --enable-decoder=aac \
                 --disable-encoders --enable-encoder=h264 --enable-encoder=mpeg4 --enable-encoder=aac --enable-libx264"



COMPILE="y"
LIPO="y"

DEPLOYMENT_TARGET="7.0"

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
        FFMPEG_DEP_OPENSSL_INC="$CWD/build-SSL/ios/build/$ARCH/output/include"
        FFMPEG_DEP_OPENSSL_LIB="$CWD/build-SSL/ios/build/$ARCH/output/lib"
        echo $FFMPEG_DEP_OPENSSL_INC
#x264
        FFMPEG_DEP_X264_INC="$CWD/build_x264/thin-x264/$ARCH/include"
        FFMPEG_DEP_X264_LIB="$CWD/build_x264/thin-x264/$ARCH/lib"
        echo $FFMPEG_DEP_X264_INC
#end
		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		CXXFLAGS="$CFLAGS"

        CFLAGS="$CFLAGS -I$FFMPEG_DEP_OPENSSL_INC -I$FFMPEG_DEP_X264_INC"
        FFMPEG_DEP_LIBS="$CFLAGS -L$FFMPEG_DEP_OPENSSL_LIB -L$FFMPEG_DEP_X264_LIB -lssl -lcrypto -lx264"
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
