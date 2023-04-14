#!/bin/bash

# BEWARE OF COGs/pyramids in input layers while using gdal_calc!!
# Use tiff files without overviews (gdalinfo file.tif|grep -i Overview)

homedir=$(realpath ~)
data_dir="$homedir"'/data/hrea/'
hrea_cogs_dir="$data_dir"'HREA_COGs/'
thr_dir=$data_dir'hrea_data_thr80p/'
tmp_cmd_list='/dev/shm/hrea_tmp_cmd_list'

#write down the (buffered) extent of the Country layers
#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk '{print $1, $2, $5, $4, $3}'> extents.txt

#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk 'BEGIN{buf=10000;}{printf "%s %.0f %.0f %.0f %.0f\n", $1, $2-buf, $5+buf, $4+buf, $3+buf}'> extents.txt

#parallel extraction of buffered per-country per-year tif

#SUBST_YEAR SUBST_SERIES

available_years=(2012 2013 2014 2015 2016 2017 2018 2019 2020)
#available_years=(2014)

mkdir -p "$thr_dir"

function create_commands() {

  echo "" > "$tmp_cmd_list"

  for this_year in "${available_years[@]}"; do

    echo "$this_year"
  #  mkdir -p "$thr_dir/$this_year"

    # list available Countries based on existing folders
    countries=($(ls -1d "$hrea_cogs_dir"/HREA_*_v1|grep "$this_year"|xargs -I{} basename {}|grep '^HREA'|grep '_v1$'|sed 's/^HREA_//g'|sed 's/_v1//g'|sed "s/_$this_year//g"))
    countries_str=$(ls -1d "$hrea_cogs_dir"/HREA_*_v1|grep "$this_year"|xargs -I{} basename {}|grep '^HREA'|grep '_v1$'|sed 's/^HREA_//g'|sed 's/_v1//g'|sed "s/_$this_year//g")

  #echo "$countries_str"|grep '^A'


#    GDAL_CACHEMAX=4096 is important, since RAM seems to be a major bottleneck.
# for eaxmple, data/hrea/HREA_COGs/HREA_Colombia_2017_v1/Colombia_set_lightscore_sy_2017.tif
# has an uncompressed size of about 15.7 GB:
# gdalinfo /home/rafd/data/hrea/HREA_COGs/HREA_Colombia_2017_v1/Colombia_set_lightscore_sy_2017.tif|grep 'Size is'|tr ',' ' ' |tr -s ' '|awk '{print int($3*$4*32/8/1024/1024*1.05'
# 15652
# execution time of gdal_calc with:
# GDAL_CACHEMAX=256  ~ 28'
# GDAL_CACHEMAX=2048 ~ 28'
# GDAL_CACHEMAX=4096 ~ 2' 30"
# GDAL_CACHEMAX=8192 ~ 2' 30"
# GDAL_CACHEMAX=16384 ~ 2' 30"


  # hrea
  echo "$countries_str"|tr ' ' "\n"| awk \
  -v this_year="$this_year" -v hrea_cogs_dir="$hrea_cogs_dir" -v thr_dir="$thr_dir" \
  '{this_country=$1; out_dir=thr_dir""this_country"/"; \
    out_file=out_dir""this_country"_"this_year"_hrea.tif"; \
    in_file=hrea_cogs_dir"HREA_"this_country"_"this_year"_v1/"this_country"_set_lightscore_sy_"this_year".tif"; \
    print "mkdir -p "out_dir"; if [ ! -e "out_file" ]; then " \
    " echo "out_file";"  \
    " export GDAL_CACHEMAX=4096;" \
    " gdal_calc.py --quiet  --co COMPRESS=ZSTD --type=Byte --co NBITS=1 --NoDataValue=0 -A " \
    in_file" --outfile=" \
    out_file" --calc=@A>=0.8@; fi"}'|tr '@' '"' >> $tmp_cmd_list

  # no_hrea
  echo "$countries_str"|tr ' ' "\n"| awk \
  -v this_year="$this_year" -v hrea_cogs_dir="$hrea_cogs_dir" -v thr_dir="$thr_dir" \
  '{this_country=$1; out_dir=thr_dir""this_country"/"; \
    out_file=out_dir""this_country"_"this_year"_no_hrea.tif"; \
    in_file=hrea_cogs_dir"HREA_"this_country"_"this_year"_v1/"this_country"_set_lightscore_sy_"this_year".tif"; \
    print "mkdir -p "out_dir"; if [ ! -e "out_file" ]; then " \
    " echo "out_file";"  \
    " export GDAL_CACHEMAX=4096;" \
    " gdal_calc.py --quiet  --co COMPRESS=ZSTD --type=Byte --co NBITS=1 --NoDataValue=0 -A " \
    in_file" --outfile=" \
    out_file" --calc=@A<0.8@; fi"}'|tr '@' '"' >> $tmp_cmd_list

  done
}

create_commands

echo "executing parallel on " $(wc -l "$tmp_cmd_list" ) " commands"

# sort in order to process country-wise
cat "$tmp_cmd_list" | sort| parallel  --jobs 5 -I{}  {}
