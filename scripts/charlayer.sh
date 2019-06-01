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
