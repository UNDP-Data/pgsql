#!/bin/bash

# BEWARE OF COGs/pyramids in input layers while using gdal_calc!!
# Use tiff files without overviews (gdalinfo file.tif|grep -i Overview)

homedir=$(realpath ~)
data_dir="$homedir"'/data/hrea/'
hrea_cogs_dir=$data_dir'HREA_COGs/'
thr_dir=$data_dir'hrea_data_thr80p/'

#write down the (buffered) extent of the Country layers
#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk '{print $1, $2, $5, $4, $3}'> extents.txt

#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk 'BEGIN{buf=10000;}{printf "%s %.0f %.0f %.0f %.0f\n", $1, $2-buf, $5+buf, $4+buf, $3+buf}'> extents.txt

#parallel extraction of buffered per-country per-year tif

#SUBST_YEAR SUBST_SERIES

available_years=(2012 2013 2014 2015 2016 2017 2018 2019 2020)
#available_years=(2012)

mkdir -p "$thr_dir"

for this_year in "${available_years[@]}"; do

  echo "$this_year"
  mkdir -p "$thr_dir/$this_year"

  # list available Countries based on existing folders
  countries=($(ls -1d "$hrea_cogs_dir"/HREA_*_v1|grep "$this_year"|xargs -I{} basename {}|grep '^HREA'|grep '_v1$'|sed 's/^HREA_//g'|sed 's/_v1//g'|sed "s/_$this_year//g"))
  countries_str=$(ls -1d "$hrea_cogs_dir"/HREA_*_v1|grep "$this_year"|xargs -I{} basename {}|grep '^HREA'|grep '_v1$'|sed 's/^HREA_//g'|sed 's/_v1//g'|sed "s/_$this_year//g")


# hrea
echo "$countries_str"|tr ' ' "\n"|awk \
-v this_year="$this_year" -v hrea_cogs_dir="$hrea_cogs_dir" -v thr_dir="$thr_dir" \
'{this_country=$1; out_dir=thr_dir""this_country"/"; \
  out_file=out_dir""this_country"_"this_year"_hrea.tif"; \
  in_file=hrea_cogs_dir"HREA_"this_country"_"this_year"_v1/"this_country"_set_lightscore_sy_"this_year".tif"; \
  print "mkdir -p "out_dir"; if [ ! -e "out_file" ]; then " \
  " gdal_calc.py --quiet  --co COMPRESS=ZSTD --type=Byte --co NBITS=1 --NoDataValue=0 -A " \
  in_file" --outfile=" \
  out_file" --calc=@A>=0.8@; fi"}'|tr '@' '"'|parallel  --jobs 70% -I{}  {}

# no_hrea
echo "$countries_str"|tr ' ' "\n"|awk \
-v this_year="$this_year" -v hrea_cogs_dir="$hrea_cogs_dir" -v thr_dir="$thr_dir" \
'{this_country=$1; out_dir=thr_dir""this_country"/"; \
  out_file=out_dir""this_country"_"this_year"_no_hrea.tif"; \
  in_file=hrea_cogs_dir"HREA_"this_country"_"this_year"_v1/"this_country"_set_lightscore_sy_"this_year".tif"; \
  print "mkdir -p "out_dir"; if [ ! -e "out_file" ]; then " \
  " gdal_calc.py --quiet  --co COMPRESS=ZSTD --type=Byte --co NBITS=1 --NoDataValue=0 -A " \
  in_file" --outfile=" \
  out_file" --calc=@A<0.8@; fi"}'|tr '@' '"'|parallel  --jobs 70% -I{}  {}

done

