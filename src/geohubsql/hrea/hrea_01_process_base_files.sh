#!/bin/bash

base_dir="/home/rafd/Downloads/admin-levels_/HREA/"
hrea_dir=$base_dir"hrea_data/"
fb_pop_dir=$base_dir"facebook_pop_30m/"
thr_dir=$base_dir"hrea_data_thr_80p/"

#write down the (buffered) extent of the Country layers
#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk '{print $1, $2, $5, $4, $3}'> extents.txt

#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk 'BEGIN{buf=10000;}{printf "%s %.0f %.0f %.0f %.0f\n", $1, $2-buf, $5+buf, $4+buf, $3+buf}'> extents.txt

#parallel extraction of buffered per-country per-year tif

#SUBST_YEAR SUBST_SERIES

available_years=(2012 2013 2014 2015 2016 2017 2018 2019 2020)
#available_series=(hrea ml)
available_series=(hrea)

#MASK HREA @ 80%

mkdir -p "$base_dir"hrea_data/by_year/
mkdir -p "$thr_dir"

for this_year in "${available_years[@]}"
do

   mkdir -p "$base_dir"hrea_data/by_year/"$this_year"
   mkdir -p $thr_dir"/"$this_year

   echo $this_year
    for this_series in "${available_series[@]}"
    do
       echo $this_series - $this_year



       echo gdal_calc.py  --co="COMPRESS=ZSTD" --type=Byte --co NBITS=1 -A \
        "$hrea_dir""$this_series"_"$this_year"_orig.tif \
        --outfile="$thr_dir"/"$this_year"/"$this_series"_"$this_year"_mask_80p.tif --calc="A>=0.8"

###split hrea tifs by series/year/country

       ls -la "$base_dir"extents.txt
       time cat "$base_dir"extents.txt|sed 's/GID_0_//g'|awk -v this_series=$this_series \
       -v this_year=$this_year -v base_dir=$base_dir \
       '{print "gdal_translate -projwin "$2,$3,$4,$5 " -of GTiff -co COMPRESS=ZSTD -co BIGTIFF=IF_NEEDED "\
       base_dir""this_series"_data/"this_series"_"this_year"_orig.tif " \
       base_dir""this_series"_data/by_year/"this_year"/"this_series"_"this_year"_"$1".tif"}'|parallel -I{} echo {}

    done
done
