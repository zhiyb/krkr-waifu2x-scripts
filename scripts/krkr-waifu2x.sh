#!/bin/bash -ex
# Deprecated by the top-level Makefile

# Scaling factor
scale=3
# General text encoding
encoding=SHIFT-JIS
# Character layer txt file encoding
layer_encoding=UTF-16LE

make_cpu_args="-j10 --no-builtin-rules"
make_gpu_args="-j3 --no-builtin-rules"

# https://github.com/lltcggie/waifu2x-caffe
waifu2x=/mnt/c/Programs/Miscellaneous/waifu2x-caffe/waifu2x-caffe-cui.exe
waifu2x_def_args="-m auto_scale -s $scale -n 1 -y cunet -c 128 -b 1"
waifu2x_amv_args="-m noise_scale -s $scale -n 3 -y cunet -c 128 -b 1"
# https://github.com/UlyssesWu/FreeMote
psbdec=/mnt/c/Games/galgame/Tools/FreeMoteToolkit/PsbDecompile.exe
psbenc=/mnt/c/Games/galgame/Tools/FreeMoteToolkit/PsBuild.exe
# https://github.com/xmoeproject/AlphaMovieDecoder
amvdec=/mnt/c/Games/galgame/Tools/krkr/AlphaMovieDecoderFake

jq=~/bin/jq

# Split to specific directories
mkdir -p original-data
find data.xp3 -iname '*.png' -exec mv {} original-data/ \;
mkdir -p original-uipsd
find data.xp3 -iname '*.pimg' -exec mv {} original-uipsd/ \;
mkdir -p original-evimage
find evimage.xp3 -iname '*.png' -exec mv {} original-evimage/ \;
mkdir -p original-fgimage
find fgimage.xp3 -iname '*.bmp' -exec mv {} original-fgimage/ \;
find original-fgimage -type f -iname '*.tlg.*' | while read f; do mv "$f" "${f:0:-8}${f:(-4)}"; done
mkdir -p original-video
find video.xp3 -iname '*.png' -exec mv {} original-video/ \;
mkdir -p original-video-amv
find video.xp3 -iname '*.amv' -exec mv {} original-video-amv/ \;
mkdir -p original-scn
find data.xp3 -iname '*.scn' -exec mv {} original-scn/ \;
mkdir -p original-fgimage-txt
find fgimage.xp3 \( -iname '*.stand' -o -iname '*.txt.txt' -o -iname 'emotion.txt' \) -exec mv {} original-fgimage-txt/ \;

# Dump AlphaMovie videos by playback
cat - > original-video-amv/amvdec.sh <<SCRIPT
#!/bin/bash -ex
amvdec=$amvdec

SCRIPT

cat - >> original-video-amv/amvdec.sh <<\SCRIPT
cat - > "$amvdec/data/scenario/first.ks" <<DOC
[wait time=200]
[iscript]
System.setArgument("-contfreq", 480);
[endscript]
[call storage="alphamovie.ks"]

[amovopt slot=0 visible=true]
$(for f in *.amv; do [ -d "${f:0:(-4)}" ] || (cp "$f" "$amvdec/data/video/" && cat - <<AMV
$f, 
[playamov slot=0 storage="$f" loop=false]
[wam slot=0]
AMV
); done)
[iscript]
System.exit();
[endscript]
DOC
$amvdec/AlphaMovieDecoderFake.exe

for f in *.amv; do
	f="${f,,}"	# Convert to lower case
	dir="${f:0:(-4)}"
	[ -d "${f:0:(-4)}" ] && continue
	mkdir -p "$dir"
	mv "$amvdec/data/video/$f"*.png "$dir/"
	rm "$amvdec/data/video/$f"
done
SCRIPT

(cd original-video-amv && chmod a+x amvdec.sh && ./amvdec.sh) &
AMVDEC_PID=$!

# Generate necessary makefiles
function makefile_header() {
	cat - <<-MAKEFILE
	SCALE	= $scale
	CHARENC	= $encoding
	LYRENC	= $layer_encoding
	DEC	= $psbdec
	ENC	= $psbenc
	WAIFU	= $waifu2x
	ifeq (\$(TYPE), amv)
		WFARGS	= $waifu2x_amv_args
	else
		WFARGS	= $waifu2x_def_args
	endif
	JQ	= $jq

	.DELETE_ON_ERROR:
	.SECONDARY:
	.SUFFIXES:

	MAKEFILE
}

# Scenario scripts
makefile_header > original-scn/Makefile

cat - >> original-scn/Makefile <<\MAKEFILE
SRC	= $(wildcard *.scn)
OUT	= $(SRC:%=out/%)

.PHONY: all
all: $(OUT)

decomp patch out: %:
	mkdir -p $@

decomp/%.scn: %.scn | decomp
	cp "$<" "$@"

decomp/%.json: decomp/%.scn
	$(DEC) "$<"

patch/%.json: decomp/%.json | patch
	$(JQ) 'walk((.|arrays|select(.[0]?|(.=="xpos",.=="ypos",.=="camerax",.=="cameray",.=="originx",.=="originy"))|.[1]) |= (if isempty(.|arrays) then .*$(SCALE) else walk((.value?,.vibration?,.start?) |= (if isempty(.|strings) then if isempty(.|numbers) then . else .*$(SCALE) end else gsub("(?<v>\\d+)"; .v|tonumber*$(SCALE)|tostring) end)) end))' "$<" | perl -wpe 's/(width|height),(\d+)/$$1.",".$$2*$(SCALE)/eg' | $(JQ) -c . > "$@"

patch/%.resx.json: decomp/%.json | patch
	cp "decomp/$*.resx.json" "$@"

patch/%.pure.scn: patch/%.json patch/%.resx.json
	cd patch && $(ENC) "$*.json"

out/%.scn: patch/%.pure.scn | out
	cp "$<" "$@"
MAKEFILE

# UI layouts
makefile_header > original-uipsd/Makefile

cat - >> original-uipsd/Makefile <<\MAKEFILE
SRC	= $(wildcard *.pimg)
OUT	= $(SRC:%=out/%)

.PHONY: all
all: $(OUT)

decomp patch out: %:
	mkdir -p $@

decomp/%.json: decomp/%.pimg
	$(DEC) "$<"

decomp/%.pimg: %.pimg | decomp
	cp "$<" "$@"

out/%.pimg: patch/%.pure.pimg | out
	cp "$<" "$@"

patch/%.pure.pimg: patch/%/ patch/%.json patch/%.resx.json
	cd patch && $(ENC) "$*.json"

patch/%.resx.json: decomp/%.json | patch
	cp "decomp/$*.resx.json" "$@"

patch/%.json: decomp/%.json | patch
	$(JQ) 'walk(((.width?,.height?,.left?,.top?)|numbers)*=$(SCALE))' "decomp/$*.json" | $(JQ) -c . > "$@"

patch/%/: decomp/%.json | patch
	mkdir -p $@
	$(WAIFU) $(WFARGS) -i "decomp/$*/" -o "$@"
MAKEFILE

# Foreground images (characters)
cat - > original-fgimage-txt/scaling.sh <<\DOC
#!/bin/bash -e
# Script for scaling character stand info txt
scaling="$1"
while IFS='' read line; do
        if [ "${line:0:1}" == "#" ]; then
                echo "$line"
                continue
        fi
        # layer_type, name
        # left top width height
        # type opacity visible layer_id group_layer_id base images
        echo "$line" | awk -F$'\t' '{out=$1"\t"$2;
                for(i=3;i<=6;i++) {out=out"\t"($i+0!=$i?$i:$i*'$scaling')};
                for(;i<=NF;i++) {out=out"\t"$i};
                print out}'
done | unix2dos
DOC

makefile_header > original-fgimage-txt/Makefile

cat - >> original-fgimage-txt/Makefile <<\MAKEFILE
SRC	= $(wildcard *.txt) $(wildcard *.stand)
OUT	= $(SRC:emotion.txt=out/emotion.txt) $(SRC:%.txt.txt=out/%.txt) $(SRC:%.stand=out/%.stand)

.PHONY: all
all: $(OUT)

out: %:
	mkdir -p $@

# Scale all numbers
out/emotion.txt: emotion.txt | out
	iconv -f $(CHARENC) -t UTF-8 $< | perl -wpe 's/\d+/$$&*$(SCALE)/eg' | iconv -f UTF-8 -t $(CHARENC) > $@

# Scale numbers on lines with xoff/yoff
out/%.stand: %.stand | out
	iconv -f $(CHARENC) -t UTF-8 $< | perl -wpe 's/\d+/$$&*$(SCALE)/eg if /xoff|yoff|offset/' | iconv -f UTF-8 -t $(CHARENC) > $@

# Scale specific columns of numbers
out/%.txt: %.txt.txt | out
	iconv -f $(LYRENC) -t UTF-8 $< | ./scaling.sh $(SCALE) | iconv -f UTF-8 -t $(LYRENC) > $@
MAKEFILE

# waifu2x images
makefile_header > Makefile

cat - >> Makefile <<\MAKEFILE
.PHONY: force-build
force-build:

.DELETE_ON_ERROR:
.SECONDARY:

$(OUT)-%: $(IN)-% force-build
	mkdir -p $@
	@$(MAKE) DIR=$* $(subst $(IN), $(OUT), $(wildcard $</*))

$(OUT)-$(DIR)/%.png: $(IN)-$(DIR)/%.png
	"$(WAIFU)" $(WFARGS) -i $< -o $@

$(OUT)-$(DIR)/%.PNG: $(IN)-$(DIR)/%.PNG
	"$(WAIFU)" $(WFARGS) -i $< -o $@

$(OUT)-$(DIR)/%.bmp: $(IN)-$(DIR)/%.bmp
	"$(WAIFU)" $(WFARGS) -i $< -o $@

$(OUT)-$(DIR)/%.jpg: $(IN)-$(DIR)/%.jpg
	"$(WAIFU)" $(WFARGS) -i $< -o $@
MAKEFILE

# Process makefiles
(cd original-scn && make $make_cpu_args)
(cd original-uipsd && make $make_gpu_args)
(cd original-fgimage-txt && chmod a+x scaling.sh && make $make_cpu_args)
make IN=original OUT=patch $make_gpu_args patch-data patch-evimage patch-video
make IN=original OUT=waifu2x $make_gpu_args waifu2x-fgimage

# Process AlphaMovie video frames
wait $AMVDEC_PID
mkdir -p original-video-frames
find original-video-amv -iname '*.png' -exec mv {} original-video-frames/ \;
make IN=original OUT=waifu2x TYPE=amv $make_gpu_args waifu2x-video-frames
set +x
(cd original-video-amv; for f in *.amv; do
	f="${f,,}"	# Convert to lower case
	f="${f:0:(-4)}"
	(cd ../waifu2x-video-frames; [ -d "$f" ] || { mkdir -p "$f"; cp "$f.amv"*.png "$f/"; })
done)
(cd waifu2x-video-frames; max_n="$(find . -maxdepth 1 -type f | wc -l)"
for d in $(find . -mindepth 1 -maxdepth 1 -type d); do
	d="$(basename "$d")"
	num="$(find "$d" -type f | wc -l)"
	n="${#num}"
	idx=0
	echo "AMV frames: Renaming $d to $n digits"
	for ((i = 0; i < max_n; i++)); do
		from="$d/$d.amv$i.png"
		to="$d/$d.amv.$(printf "%0${n}d" $idx).png"
		if [ -e "$to" ]; then
			((idx++)) || true
			continue
		elif [ -e "$from" ]; then
			mv "$from" "$to"
			((idx++)) || true
			continue
		elif ((idx >= num)); then
			break
		fi
	done &
done; wait)
set -x

# Copy files to patch directories
cp original-uipsd/out/*.pimg patch-data/
cp original-scn/out/*.scn patch-data/
mkdir -p patch-fgimage
cp original-fgimage-txt/out/* patch-fgimage/

# Scripts
mkdir -p patch-scripts
iconv -f $encoding -t UTF8 data.xp3/main/Config.tjs | perl -wpe 's/\d+/$&*'$scale'/eg if /;scWidth|;scHeight|;thumbnailWidth|;aboutWidth|;aboutHeight|\bmarginL\b|\bmarginT\b|\bmarginR\b|\bmarginB\b|;mw\b|;mh\b|;mt\b|;defaultFontSize|;defaultLineSpacing|;defaultPitch|;defaultRubySize|;defaultRubyOffset|;glyphFixedLeft|;glyphFixedTop|;shadowOffsetX|;shadowOffsetY|;shadowWidth|;edgeExtent|;edgeEmphasis|nameLayerFontSize|;fontHeight|;lineHeight|\bactionIndent\b|\bnameIndent\b/' | iconv -f UTF8 -t $encoding > patch-scripts/Config.tjs
iconv -f $encoding -t UTF8 data.xp3/main/envinit.tjs | perl -wpe 's/(\bxpos\b|\bypos\b|\bvibration\b|\bvague\b|\bwidth\b|\bheight\b|"emotionX"|"emotionY")([^,]*?)(\d+)/$1.$2.$3*'$scale'/eg' | perl -wpe 's/("originx"|"originy"|"width"|"height"|"noise")([^,]*?,[^,]*?)(\d+)/$1.$2.$3*'$scale'/eg' | perl -wpe 's/(\bstart\b|\bvalue\b|\bmax\b)([^,]*?)(\d+)/$1.$2.$3*'$scale'/eg if /(\bleft\b|\btop\b|\bright\b|\bbottom\b|\btilex\b|\btiley\b).*("MoveAction"|"LoopMoveAction")/' | perl -wpe 's/\d+/$&*'$scale'/eg if /\bleft[^,]*?PathAction\b/' | perl -wpe 's/(\()(-?\d+)([^\)]+?)(-?\d+)([^\)]+?\))/$1.($2*'$scale').$3.($4*'$scale').$5/eg if /"path"/' | iconv -f UTF8 -t $encoding > patch-scripts/envinit.tjs
