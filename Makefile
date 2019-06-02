IN	= dump
OUT	= data
PATCH	= patch

TMPIN	= tmpin
TMPOUT	= tmpout

# Overall scaling
SCALE	= 3

# General text encoding
CHARENC	= SHIFT-JIS
# Character layer txt file encoding
LYRENC	= UTF-16LE

# # of concurrent waifu2x GPU jobs
GPUJOBS	?= 3

# https://github.com/lltcggie/waifu2x-caffe
WAIFU	:= /mnt/c/Programs/Miscellaneous/waifu2x-caffe/waifu2x-caffe-cui.exe
WFARGS	:= -m noise_scale -s $(SCALE) -n 0 -y cunet -c 128 -b 1
WFVARGS	:= -m noise_scale -s $(SCALE) -n 0 -y cunet -c 128 -b 1
# https://github.com/UlyssesWu/FreeMote
PSBDEC	:= /mnt/c/Games/galgame/Tools/FreeMoteToolkit/PsbDecompile.exe
PSBENC	:= /mnt/c/Games/galgame/Tools/FreeMoteToolkit/PsBuild.exe -double
# https://github.com/zhiyb/AlphaMovieDecoder
AMVDEC	:= /mnt/c/Games/galgame/Tools/krkr/AlphaMovieDecoder/AlphaMovieDecoderFake
# https://github.com/zhiyb/AlphaMovieEncoder
AMVENC	:= /mnt/c/Games/galgame/Tools/krkr/alphamovie/AlphaMovieEncoder/amenc.exe --png --zlib --rate 30 --scale 1 --quality 95
# https://github.com/vn-tools/arc_unpacker
AU	:= ~/bin/arc_unpacker
# https://github.com/zhiyb/png2tlg
PNG2TLG	:= ~/bin/png2tlg
# https://stedolan.github.io/jq/manual/v1.6/
JQ	:= ~/bin/jq
#JQRAW	?= | $(JQ) -c .

# Force update certain steps
#UPDIMG	:= Makefile
#UPDVIMG	:= Makefile

# Stages:
# dir, prepare, first, gpu, final

ifeq ($(STAGE), dir)
SRC	:= $(shell find $(IN) -type d)
TRG	:= $(SRC:$(IN)%=$(OUT)%) $(SRC:$(IN)%=$(TMPIN)%) $(SRC:$(IN)%=$(TMPOUT)%)
else ifneq ($(STAGE),)
SRC	:= $(shell find $(IN) -type f)
ifeq ($(STAGE), gpu)
SRC	+= $(shell find $(TMPIN) -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.bmp' \))
endif
TRG	:= $(subst $(TMPIN), $(TMPOUT), $(SRC:$(IN)%=$(OUT)%))
TRG	:= $(TRG:%.txt.txt=%.txt)
endif

include gmsl

.SUFFIXES:
.SECONDARY:
.DELETE_ON_ERROR:

.PHONY: all
ifeq ($(STAGE),)
all: $(TRG)
	$(MAKE) STAGE=dir
	$(MAKE) STAGE=prepare
	./scripts/amv.sh "$(AMVDEC)"
	$(MAKE) STAGE=first
	$(MAKE) STAGE=gpu -j$(GPUJOBS)
	$(MAKE) STAGE=final
else
all: $(TRG)
endif

.PHONY: patch
patch: all
	mkdir -p $(PATCH)
	./scripts/patch.sh "$(IN)" "$(OUT)" "$(PATCH)"

ifeq ($(STAGE), gpu)
$(OUT)/%.PNG: $(IN)/%.PNG $(UPDIMG)
	$(WAIFU) $(WFARGS) -i "$<" -o "$@"
$(OUT)/%.png: $(IN)/%.png $(UPDIMG)
	$(WAIFU) $(WFARGS) -i "$<" -o "$@"
$(OUT)/%.bmp: $(IN)/%.bmp $(UPDIMG)
	$(WAIFU) $(WFARGS) -i "$<" -o "$@"
$(OUT)/%.jpg: $(IN)/%.jpg $(UPDIMG)
	$(WAIFU) $(WFARGS) -i "$<" -o "$@"

$(TMPOUT)/video/%.png: $(TMPIN)/video/%.png $(UPDVIMG)
	$(WAIFU) $(WFVARGS) -i "$<" -o "$@"
	@touch "$(dir $@)"

$(TMPOUT)/%.png: $(TMPIN)/%.png $(UPDIMG)
	$(WAIFU) $(WFARGS) -i "$<" -o "$@"
	@touch "$(dir $@)"
$(TMPOUT)/%.bmp: $(TMPIN)/%.bmp $(UPDIMG)
	$(WAIFU) $(WFARGS) -i "$<" -o "$@"
	@touch "$(dir $@)"
$(TMPOUT)/%.jpg: $(TMPIN)/%.jpg $(UPDIMG)
	$(WAIFU) $(WFARGS) -i "$<" -o "$@"
	@touch "$(dir $@)"
else
$(OUT)/%.PNG: $(IN)/%.PNG
	@
$(OUT)/%.png: $(IN)/%.png
	@
$(OUT)/%.bmp: $(IN)/%.bmp
	@
$(OUT)/%.jpg: $(IN)/%.jpg
	@
endif

ifneq ($(STAGE),)
# PSB encoded scenarios and UI
$(TMPIN)/%.scn: $(IN)/%.scn
	cp "$<" "$@"

$(TMPIN)/%.pimg: $(IN)/%.pimg
	cp "$<" "$@"

$(TMPIN)/%.json: $(TMPIN)/%.scn
	$(PSBDEC) "$<"

$(TMPIN)/%.json: $(TMPIN)/%.pimg
	$(PSBDEC) "$<"

JQSCN	:= 'walk((.|arrays|select(.[0]?|( \
		.=="xpos",.=="ypos",.=="camerax",.=="cameray",.=="originx",.=="originy",.=="leveloffset" \
	))|.[1]) |= \
	if isempty(.|arrays)|not then \
		walk((.value?,.vibration?,.start?,.accel?) |= \
		if isempty(.|strings)|not then \
			gsub("(?<v>\\d+)"; .v|tonumber*$(SCALE)|tostring) \
		elif isempty(.|numbers)|not then \
			.*$(SCALE) \
		elif isempty(.|null)|not then \
			empty \
		else \
			. \
		end) \
	elif isempty(.|strings)|not then \
		gsub("(?<v>\\d+)"; .v|tonumber*$(SCALE)|tostring) \
	else \
		.*$(SCALE) \
	end) | walk((.|arrays|select(.[0]?|(.=="doBoxBlur"))|.[1,2]) |= .*$(SCALE)) | \
	walk((.|arrays|select(.[0]?|(.=="quake")) | ( \
		if .[]=="vmax" then .[index("vmax")+1] else empty end, \
		if .[]=="hmax" then .[index("hmax")+1] else empty end \
	)) |= (.|tonumber*$(SCALE)|tostring)) | \
	walk((.|strings) |= gsub("(?<p>(width|height)\\s*,\\s*)(?<v>-?\\d+)"; (.p)+(.v|tonumber*$(SCALE)|tostring)))'

$(TMPOUT)/scn/%.json: $(TMPIN)/scn/%.json
	$(JQ) $(JQSCN) "$<" $(JQRAW) > "$@"

$(TMPOUT)/%.json: $(TMPIN)/%.json | $(TMPOUT)/%/
	$(JQ) 'walk(((.width?,.height?,.left?,.top?)|numbers)*=$(SCALE))' "$<" $(JQRAW) > "$@"

$(TMPOUT)/%.resx.json: $(TMPIN)/%.resx.json
	cp "$<" "$@"

$(TMPOUT)/%.pure.scn: $(TMPOUT)/%.json $(TMPOUT)/%.resx.json
	cd "$(dir $@)" && $(PSBENC) "$(notdir $*).json"

$(TMPOUT)/%.pure.pimg: $(TMPOUT)/%/ $(TMPOUT)/%.json $(TMPOUT)/%.resx.json
	cd "$(dir $@)" && $(PSBENC) "$(notdir $*).json"

ifneq ($(STAGE), final)
# Ignore repacking for now, wait for GPU process
$(OUT)/%.scn: $(TMPOUT)/%.json
	@

$(OUT)/%.pimg: $(TMPOUT)/%.json
	@
else
$(OUT)/%.scn: $(TMPOUT)/%.pure.scn
	cp "$<" "$@"

$(OUT)/%.pimg: $(TMPOUT)/%.pure.pimg
	cp "$<" "$@"
endif

# TLG images
$(TMPIN)/%.png: $(IN)/%.tlg
	$(AU) -d=kirikiri/tlg -o=$(dir $@) $<

ifneq ($(STAGE), gpu)
$(TMPOUT)/%.png: $(TMPIN)/%.png
	@
endif

ifeq ($(STAGE), final)
$(OUT)/%.tlg: $(TMPOUT)/%.png
	$(PNG2TLG) "$<" "$@"
else
$(OUT)/%.tlg: $(TMPOUT)/%.png
	@
endif

# Character stand
$(OUT)/%.stand: $(IN)/%.stand
	iconv -f $(CHARENC) -t UTF-8 $< | perl -wpe 's/\d+/$$&*$(SCALE)/eg if /xoff|yoff|offset/' | iconv -f UTF-8 -t $(CHARENC) > $@
$(OUT)/fgimage/%.txt: $(IN)/fgimage/%.txt.txt
	iconv -f $(LYRENC) -t UTF-8 $< | ./scripts/charlayer.sh $(SCALE) | iconv -f UTF-8 -t $(LYRENC) > $@
$(OUT)/%.sinfo: $(IN)/%.sinfo
	cp "$<" "$@"

# Character emotion offset
$(OUT)/%/emotion.txt: $(IN)/%/emotion.txt
	iconv -f $(CHARENC) -t UTF-8 $< | perl -wpe 's/\d+/$$&*$(SCALE)/eg' | iconv -f UTF-8 -t $(CHARENC) > $@

# Animation description
$(OUT)/%.asd: $(IN)/%.asd
	iconv -f $(CHARENC) -t UTF-8 $< | perl -wpe 's/\d+/$$&*$(SCALE)/eg if /clip|copy/' | iconv -f UTF-8 -t $(CHARENC) > $@

# Particle effects
$(OUT)/image/particle%.tjs: $(IN)/image/particle%.tjs
	iconv -f $(CHARENC) -t UTF-8 $< | perl -wpe 's/(patsp|speed|x|y|vibsz)([^"]*")(-?\d+)\/(-?\d+)"/$$1.$$2.($$3*$(SCALE))."\/".($$4*$(SCALE))."\""/eg' | perl -wpe 's/(-?\d+)/$$&*$(SCALE)/eg if /term:/' | iconv -f UTF-8 -t $(CHARENC) > $@

# AlphaMovie
ifeq ($(STAGE), prepare)
$(TMPOUT)/%/: $(IN)/%.amv
	cp $< "$(AMVDEC)/data/video/"
else ifeq ($(STAGE), first)
$(TMPIN)/%/: $(IN)/%.amv | $(TMPOUT)/%/
	mkdir -p $@
	mv "$(AMVDEC)/data/video/$(call lc, $(notdir $<))"*.png $@
endif

ifeq ($(STAGE), first)
$(OUT)/%.amv: $(TMPIN)/%/
	@
else ifeq ($(STAGE), final)
$(OUT)/%.amv: $(TMPOUT)/%/
	$(AMVENC) "$<" "$@"
else
$(OUT)/%.amv: $(TMPOUT)/%/
	@
endif

# Scripts
$(OUT)/%/macro.ks: $(IN)/%/macro.ks
	iconv -f $(CHARENC) -t UTF-8 $< | perl -wpe 's/(\bxpos\b|\bypos\b|\bsize\b|\bvague\b|\bwidth\b|\bheight\b|\bblur\b|\bblurx\b|\bblury\b|\bhmax\b|\bvmax\b)(=[^ \d]*)(\d+)/$$1.$$2.$$3*'$(SCALE)'/eg' | iconv -f UTF-8 -t $(CHARENC) > $@

$(OUT)/%/custom.ks: $(IN)/%/custom.ks
	iconv -f $(CHARENC) -t UTF-8 $< | perl -wpe 's/(\bleft\b|\btop\b|\bwidth\b|\bheight\b|\bedgeExtent\b|\bedgeEmphasis\b)(=[^ \d]*)(\d+)/$$1.$$2.$$3*'$(SCALE)'/eg' | iconv -f UTF-8 -t $(CHARENC) > $@

$(OUT)/%/envinit.tjs: $(IN)/%/envinit.tjs
	iconv -f $(CHARENC) -t UTF8 $< | ./scripts/envinit.sh $(SCALE) | iconv -f UTF8 -t $(CHARENC) > $@

endif

# Copy files
ifneq ($(STAGE),)
CPEXT	:= .ogg .ogg.sli .mpg .ttf .otf \
	   .stage .ini .csv .txt \
	   .tjs .func .ks

define CPRULE
$$(OUT)/%$(1): $$(IN)/%$(1)
	cp "$$<" "$$@"
endef

$(foreach ext,$(CPEXT),$(eval $(call CPRULE,$(ext))))
endif

# Extra
ifeq ($(STAGE), touch)
$(OUT)/%: $(IN)/%
	touch "$@"
endif

# Directories
ifeq ($(STAGE),dir)
$(TRG): %:
	mkdir -p "$@"
endif

$(TMPOUT)/%/:
	mkdir -p $@
