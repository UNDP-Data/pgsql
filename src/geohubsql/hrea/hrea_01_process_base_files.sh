#!/bin/bash

# BEWARE OF COGs/pyramids in input layers while using gdal_calc!!
# Use tiff files without overviews (gdalinfo file.tif|grep -i Overview)

hrea_dir="/home/rafd/Downloads/admin-levels_/HREA/"
hrea_data_dir=$hrea_dir"hrea_data/"
fb_pop_dir=$hrea_dir"facebook_pop_30m/"
thr_dir=$hrea_dir"hrea_data_thr80p/"

#write down the (buffered) extent of the Country layers
#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk '{print $1, $2, $5, $4, $3}'> extents.txt

#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk 'BEGIN{buf=10000;}{printf "%s %.0f %.0f %.0f %.0f\n", $1, $2-buf, $5+buf, $4+buf, $3+buf}'> extents.txt

#parallel extraction of buffered per-country per-year tif

#SUBST_YEAR SUBST_SERIES

#available_years=(2012 2013 2014 2015 2016 2017 2018 2019 2020)
available_years=(2012)
#available_series=(hrea ml)
available_series=(hrea)

#MASK HREA @ 80%

#mkdir -p "$hrea_dir"hrea_data/by_year/
mkdir -p "$thr_dir"

for this_year in "${available_years[@]}"; do

   mkdir -p "$thr_dir/$this_year"

   echo "$this_year"
    for this_series in "${available_series[@]}"; do
      #echo $this_series - $this_year
      echo "$hrea_dir""$this_series"'_data_thr80p/'"$this_year"
      mkdir -p "$hrea_dir""$this_series"'_data_thr80p/'"$this_year"

        cat "$hrea_dir"'extents.txt'|sed 's/GID_0_//g'|awk -v this_series="$this_series" \
        -v this_year="$this_year" -v hrea_dir="$hrea_dir" \
        '{print "gdal_calc.py --quiet --co COMPRESS=ZSTD --type=Byte --co NBITS=1 --NoDataValue=0 --projwin " \
        $2,$3,$4,$5 \
        " -A "hrea_dir""this_series"_data/"this_series"_"this_year"_orig.tif " \
        " --outfile="hrea_dir""this_series"_data_thr80p/"this_year"/"this_series"_"this_year"_"$1"_m80.tif" \
        " --calc=@A>=0.8@"
        }'|tr '@' '"'|parallel -I{} echo {}

#       echo gdal_calc.py  --co="COMPRESS=ZSTD" --type=Byte --co NBITS=1 -A \
#        "$hrea_dir""$this_series"_"$this_year"_orig.tif \
#        --outfile="$thr_dir"/"$this_year"/"$this_series"_"$this_year"_mask80p.tif --calc="A>=0.8"

###split hrea tifs by series/year/country

#       ls -la "$hrea_dir"extents.txt
#       time cat "$hrea_dir"extents.txt|sed 's/GID_0_//g'|awk -v this_series="$this_series" \
#       -v this_year="$this_year" -v hrea_dir="$hrea_dir" \
#       '{print "gdal_translate -projwin "$2,$3,$4,$5 " -of GTiff -co COMPRESS=ZSTD -co BIGTIFF=IF_NEEDED "\
#       hrea_dir""this_series"_data/"this_series"_"this_year"_orig.tif " \
#       hrea_dir""this_series"_data/by_year/"this_year"/"this_series"_"this_year"_"$1".tif"}'|parallel -I{} echo {}

    done
done
