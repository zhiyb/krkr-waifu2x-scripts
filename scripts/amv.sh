#!/bin/bash -ex
amvdec="$1"

# Check AMV file exists
(( $(cd "$amvdec/data/video"; ls -1 *.amv | wc -l) != 0 )) || exit 0

# Convert filename to lower case
(cd "$amvdec/data/video"; for f in *.amv; do
	ff="${f,,}"	# Convert to lower case
	[ x"$f" == x"$ff" ] || { mv "$f" "$f".tmp && mv "$f".tmp "$ff"; }
done)

cat - <<DOC | iconv -f UTF-8 -t Shift_JIS > "$amvdec/data/scenario/first.ks"
[wait time=200]
[iscript]
System.setArgument("-contfreq", 480);
[endscript]
[call storage="alphamovie.ks"]

[amovopt slot=0 visible=true]
$(cd "$amvdec/data/video"; for f in *.amv; do cat - <<AMV
$f, 
[playamov slot=0 storage="$f" loop=false]
[wam slot=0]
AMV
done)
[iscript]
System.exit();
[endscript]
DOC

#$amvdec/AlphaMovieDecoderFake.exe
"/mnt/c/Programs/Locale Emulator/LEProc.exe" -run 'C:\Games\galgame\Tools\krkr\AlphaMovieDecoder\AlphaMovieDecoderFake\AlphaMovieDecoderFake.exe' -readencoding=Shift_JIS -contfreq=0

echo "Press enter when AMV finished..."
read

rm -f "$amvdec/data/video/"*.amv
