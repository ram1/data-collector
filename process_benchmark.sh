#!/bin/bash
bm=$1
dir=$2
./statistics_by_f.pl $bm $dir 30
./contour.pl ${dir}/summary_${bm}.csv ${dir}/summary_${bm}_reordered.csv
