#!/bin/bash -e
in="$1"
out="$2"
patch="$3"
dirs="data evimage fgimage video voice script crack"

(cd $patch; rm -rf $dirs; mkdir -p $dirs)
diff -qr "$in" "$out" | grep -v "^Only in $in" | while read line; do
	set $line
	file=$4
	if [ x"$1" == x"Only" ]; then
		file=$out/$file
	fi
	type=${file#*/}
	type=${type%%/*}
	case "$type" in
	evimage | fgimage | video | voice ) ;;
	* ) type=data;;
	esac
	if [ x"$type" == x"data" ]; then
		case "${file##*.}" in
			tjs | ks | scn ) type=script;;
		esac
		case "$(basename "$file")" in
			pkeycheck.tjs ) type=crack;;
		esac
	fi
	echo "$file => $patch/$type/"
	cp $file $patch/$type/
done
