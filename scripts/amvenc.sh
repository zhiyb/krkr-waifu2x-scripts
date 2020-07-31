#!/bin/bash -ex

/mnt/c/Games/galgame/Tools/krkr/alphamovie/AlphaMovieEncoder/amenc.exe $@ #"$dir" "$file"
#"/mnt/c/Programs/Locale Emulator/LEProc.exe" -run 'C:\Games\galgame\Tools\krkr\alphamovie\AlphaMovieEncoder\amenc.exe' $@
exit

iconv="iconv -f UTF-8 -t SHIFT_JIS"

dir="$(echo "$1" | $iconv)"
shift
file="$(echo "$1" | $iconv)"
shift

#set -- $(echo "$@" | iconv -f UTF-8 -t SHIFT_JIS | xargs)
#"/mnt/c/Programs/Locale Emulator/LEProc.exe" -run 'C:\Games\galgame\Tools\krkr\alphamovie\AlphaMovieEncoder\amenc.exe' $@ "$dir" "$file"
#/mnt/c/Games/galgame/Tools/krkr/alphamovie/AlphaMovieEncoder/amenc.exe $@ "$dir" "$file"
