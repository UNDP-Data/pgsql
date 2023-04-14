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

  countries_str=$(ls -1 "$hrea_cogs_dir"/HREA_*_2020_v1/*tif| parallel -I{} gdalinfo {}|grep "Files\|Size is"|tr "/," "\n "|grep "_v1\|Size is"|tr "\n" " "|sed 's/HREA_/\nHREA_/g'|sed 's/Size is //g'|sed '/^[[:space:]]*$/d'|\
  awk '{img_size=int($2*$3*32/8/1024/1024*1.05); cache=img_size; if (cache<4096){cache=4096};print $1,cache,img_size}'|sed 's/HREA_//g'|sed 's/_2020_v1//g')

  for this_year in "${available_years[@]}"; do

    echo "$this_year"
  #  mkdir -p "$thr_dir/$this_year"

    # list available Countries based on existing folders
#    countries=($(ls -1d "$hrea_cogs_dir"/HREA_*_v1|grep "$this_year"|xargs -I{} basename {}|grep '^HREA'|grep '_v1$'|sed 's/^HREA_//g'|sed 's/_v1//g'|sed "s/_$this_year//g"))
#    countries_str=$(ls -1d "$hrea_cogs_dir"/HREA_*_v1|grep "$this_year"|xargs -I{} basename {}|grep '^HREA'|grep '_v1$'|sed 's/^HREA_//g'|sed 's/_v1//g'|sed "s/_$this_year//g")



  #echo "$countries_str"|grep '^A'


#    GDAL_CACHEMAX=4096 is important, since RAM seems to be a major bottleneck.
# for eaxmple, data/hrea/HREA_COGs/HREA_Colombia_2017_v1/Colombia_set_lightscore_sy_2017.tif
# has an uncompressed size of about 15.7 GB:
# gdalinfo ~/data/hrea/HREA_COGs/HREA_Colombia_2017_v1/Colombia_set_lightscore_sy_2017.tif|grep 'Size is'|tr ',' ' ' |tr -s ' '|awk '{print int($3*$4*32/8/1024/1024*1.05'
# 15652
# execution time of gdal_calc with:
# GDAL_CACHEMAX=256  ~ 28'
# GDAL_CACHEMAX=2048 ~ 28'
# GDAL_CACHEMAX=4096 ~ 2' 30"
# GDAL_CACHEMAX=8192 ~ 2' 30"
# GDAL_CACHEMAX=16384 ~ 2' 30"

#ls -1 ~/data/hrea/HREA_COGs/HREA_*_2012_v1/*tif| parallel -I{} gdalinfo {}|grep "Files\|Size is"|tr "/," "\n "|grep "_v1\|Size is"|tr "\n" " "|sed 's/HREA_/\nHREA_/g'|sed 's/Size is //g'|awk '{print int($2*$3*32/8/1024/1024*1.05),$1}'|sort -n
#
#4 HREA_Saint_Lucia_2012_v1
#12 HREA_Grenada_2012_v1
#12 HREA_Hong_Kong_2012_v1
#72 HREA_Comoros_2012_v1
#89 HREA_Sao_Tome_and_Principe_2012_v1
#98 HREA_Trinidad_and_Tobago_2012_v1
#99 HREA_Morocco_2012_v1
#99 HREA_South_Sudan_2012_v1
#111 HREA_Eswatini_2012_v1
#119 HREA_Gambia_2012_v1
#134 HREA_Somalia_2012_v1
#143 HREA_Puerto_Rico_2012_v1
#150 HREA_Djibouti_2012_v1
#164 HREA_El_Salvador_2012_v1
#187 HREA_Jamaica_2012_v1
#207 HREA_Burundi_2012_v1
#234 HREA_Belize_2012_v1
#235 HREA_Timor-Leste_2012_v1
#239 HREA_Sudan_2012_v1
#266 HREA_Lesotho_2012_v1
#271 HREA_Bhutan_2012_v1
#290 HREA_Guinea-Bissau_2012_v1
#307 HREA_Rwanda_2012_v1
#322 HREA_Myanmar_2012_v1
#337 HREA_Cape_Verde_2012_v1
#375 HREA_Haiti_2012_v1
#469 HREA_Dominican_Republic_2012_v1
#484 HREA_Sierra_Leone_2012_v1
#494 HREA_Sri_Lanka_2012_v1
#509 HREA_Togo_2012_v1
#745 HREA_Panama_2012_v1
#846 HREA_Guatemala_2012_v1
#889 HREA_Liberia_2012_v1
#892 HREA_Suriname_2012_v1
#943 HREA_Jordan_2012_v1
#986 HREA_Benin_2012_v1
#1274 HREA_Nicaragua_2012_v1
#1298 HREA_Malawi_2012_v1
#1358 HREA_Uruguay_2012_v1
#1376 HREA_Vanuatu_2012_v1
#1407 HREA_Senegal_2012_v1
#1418 HREA_Cambodia_2012_v1
#1426 HREA_Bangladesh_2012_v1
#1535 HREA_Tunisia_2012_v1
#1559 HREA_Equatorial_Guinea_2012_v1
#1598 HREA_Honduras_2012_v1
#1607 HREA_Uganda_2012_v1
#1635 HREA_Ghana_2012_v1
#1672 HREA_South_Korea_2012_v1
#1675 HREA_Nepal_2012_v1
#1873 HREA_Guyana_2012_v1
#1899 HREA_Gabon_2012_v1
#1964 HREA_Eritrea_2012_v1
#2107 HREA_Guinea_2012_v1
#2193 HREA_Ivory_Coast_2012_v1
#2335 HREA_Burkina_Faso_2012_v1
#2763 HREA_Zimbabwe_2012_v1
#3366 HREA_Laos_2012_v1
#3377 HREA_Congo_Republic_2012_v1
#3410 HREA_Seychelles_2012_v1
#3619 HREA_Paraguay_2012_v1
#4072 HREA_Kenya_2012_v1
#4253 HREA_Iraq_2012_v1
#4426 HREA_Botswana_2012_v1
#4561 HREA_Cameroon_2012_v1
#5574 HREA_Madagascar_2012_v1
#5707 HREA_Vietnam_2012_v1
#5778 HREA_Central_African_Republic_2012_v1
#5847 HREA_Ecuador_2012_v1
#5952 HREA_Zambia_2012_v1
#5961 HREA_Egypt_2012_v1
#5993 HREA_Marshall_Islands_2012_v1
#6039 HREA_Solomon_Islands_2012_v1
#6298 HREA_Nigeria_2012_v1
#6525 HREA_Tanzania_2012_v1
#6649 HREA_Malaysia_2012_v1
#6686 HREA_Thailand_2012_v1
#7923 HREA_Mauritania_2012_v1
#8366 HREA_Bolivia_2012_v1
#8427 HREA_Namibia_2012_v1
#8749 HREA_Chad_2012_v1
#8803 HREA_Angola_2012_v1
#8885 HREA_Ethiopia_2012_v1
#9164 HREA_Papua_New_Guinea_2012_v1
#9516 HREA_Mozambique_2012_v1
#9719 HREA_Niger_2012_v1
#11019 HREA_Philippines_2012_v1
#11170 HREA_Libya_2012_v1
#11780 HREA_Pakistan_2012_v1
#12050 HREA_Peru_2012_v1
#12206 HREA_South_Africa_2012_v1
#12662 HREA_Mali_2012_v1
#15652 HREA_Colombia_2012_v1
#18680 HREA_DR_Congo_2012_v1
#19393 HREA_Algeria_2012_v1
#29115 HREA_Mexico_2012_v1
#35385 HREA_Argentina_2012_v1
#40728 HREA_Indonesia_2012_v1
#43615 HREA_India_2012_v1

echo "$countries_str"

  # hrea
  echo "$countries_str"| awk \
  -v this_year="$this_year" -v hrea_cogs_dir="$hrea_cogs_dir" -v thr_dir="$thr_dir" \
  '{this_country=$1; unc_file_size=$2; allocated_cache=int(unc_file_size/3); out_dir=thr_dir""this_country"/"; \
    out_file=out_dir""this_country"_"this_year"_hrea.tif"; \
    in_file=hrea_cogs_dir"HREA_"this_country"_"this_year"_v1/"this_country"_set_lightscore_sy_"this_year".tif"; \
    print "mkdir -p "out_dir"; if [ ! -e "out_file" ]; then " \
    " echo "out_file";"  \
    " export GDAL_CACHEMAX="allocated_cache";" \
    " gdal_calc.py --quiet  --co COMPRESS=ZSTD --type=Byte --co NBITS=1 --NoDataValue=0 -A " \
    in_file" --outfile=" \
    out_file" --calc=@A>=0.8@; fi"}'|tr '@' '"' >> $tmp_cmd_list

  # no_hrea
  echo "$countries_str"| awk \
  -v this_year="$this_year" -v hrea_cogs_dir="$hrea_cogs_dir" -v thr_dir="$thr_dir" \
  '{this_country=$1; unc_file_size=$2; allocated_cache=int(unc_file_size/3); out_dir=thr_dir""this_country"/"; \
    out_file=out_dir""this_country"_"this_year"_no_hrea.tif"; \
    in_file=hrea_cogs_dir"HREA_"this_country"_"this_year"_v1/"this_country"_set_lightscore_sy_"this_year".tif"; \
    print "mkdir -p "out_dir"; if [ ! -e "out_file" ]; then " \
    " echo "out_file";"  \
    " export GDAL_CACHEMAX="allocated_cache";" \
    " gdal_calc.py --quiet  --co COMPRESS=ZSTD --type=Byte --co NBITS=1 --NoDataValue=0 -A " \
    in_file" --outfile=" \
    out_file" --calc=@A<0.8@; fi"}'|tr '@' '"' >> $tmp_cmd_list

  done
}

create_commands

echo "executing parallel on " $(wc -l "$tmp_cmd_list" ) " commands"

# sort in order to process country-wise
#cat "$tmp_cmd_list" | sort |grep -v "India\|Indonesia\|Argentina\|Mexico\|Algeria\|DR_Congo"| parallel  --jobs 5 -I{}  {}

cat "$tmp_cmd_list" | sort | parallel  --jobs 2 -I{}  {}