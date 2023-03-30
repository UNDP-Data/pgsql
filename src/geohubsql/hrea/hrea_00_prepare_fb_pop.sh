#!/bin/bash


adm0_dir="/home/rafd/Downloads/admin-levels_/gadm_adm2_by_country/"
hrea_dir="/home/rafd/Downloads/admin-levels_/HREA/"
hrea_data_dir=$hrea_dir"hrea_data/"
fb_pop_dir=$hrea_dir"facebook_pop_30m/"
thr_dir=$hrea_dir"hrea_data_thr80p/"
x_res='41.735973305281412'
y_res='41.735973305281412'
#write down the (buffered) extent of the Country layers
### ls -1 "$adm0_dir"GID*.gpkg|parallel -I{} ogrinfo -so {} {/.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk '{print $1, $2, $5, $4, $3}' |sort> adm0_extents.txt

#buffered
ls -1 "$adm0_dir"GID*.gpkg|parallel -I{} ogrinfo -so {} {/.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk 'BEGIN{buf=10000;}{printf "%s %.0f %.0f %.0f %.0f\n", $1, $2-buf, $5+buf, $4+buf, $3+buf}'|sort> adm0_extents.txt
ls -1 "$fb_pop_dir"???_pop_3857.tif|xargs -I{} basename {}|sed 's/_pop_3857.tif//g'|sed 's/^/GID_0_/g' | sort > fb_pop_countries.csv
join fb_pop_countries.csv adm0_extents.txt > "$hrea_dir"'extents.txt'

#reproject fb_pop layers into 3857 with the same pixel size as the hrea files

#gdal_translate -projwin -1278581. 955535. -819880. 485031. -of GTiff -co COMPRESS=NONE -co BIGTIFF=IF_NEEDED ~/Downloads/admin-levels_/admin2_by_region3/e.tif ~/Downloads/admin-levels_/admin2_by_region3_subdivided/LBR.tif

#time gdalwarp -overwrite -s_srs EPSG:4326 -t_srs EPSG:3857 -te 3354012 -3097076 4556211 -1162198 -tr 41.735973305281412 41.735973305281412 /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop.tif /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop_3857_gdal.tif

#gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 -tr 41.73597330528141 41.73597330528141 \
# -r near -te 3354012.0 -3097077.7224 4556216.7111 -1162198.0 -te_srs EPSG:3857
# -multi -ot Float32 -of GTiff -co COMPRESS=DEFLATE -co PREDICTOR=2 -co ZLEVEL=9
# /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop1.tif /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop_3857_gdal_qgis.tif

#gdalwarp -multi -wo NUM_THREADS=ALL_CPUS -overwrite -ovr AUTO -r bilinear -s_srs EPSG:4326 -t_srs EPSG:3857 -of GTiff  -co BIGTIFF=IF_NEEDED -co COMPRESS=DEFLATE  -tr 41.735973305281412 41.735973305281412 -te_srs EPSG:3857 -te 3354012 -3097076 4556211 -1162198 -tap /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop.tif /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop_3587_v2_bilin_auto.tif

cat "$hrea_dir"'extents.txt'|sed 's/GID_0_//g'|awk \
-v fb_pop_dir="$fb_pop_dir" -v hrea_dir="$hrea_dir" \
-v x_res="$x_res" -v y_res="$y_res" \
'{print "time gdalwarp -overwrite -tap -ovr NONE -r nearest -s_srs EPSG:4326 -t_srs EPSG:3857 -of GTiff  -co BIGTIFF=IF_NEEDED -co COMPRESS=ZSTD  -tr 41.735973305281412 41.735973305281412 -te " \
$2,$5,$4,$3 \
" "fb_pop_dir""$1"_pop.tif" \
" "fb_pop_dir""$1"_pop_3857.tif"
}'|parallel -I{} echo {}


#cat "$hrea_dir"'extents.txt'|sed 's/GID_0_//g'|awk \
#-v fb_pop_dir="$fb_pop_dir" -v hrea_dir="$hrea_dir" \
#-v x_res="$x_res" -v y_res="$y_res" \
#'{print "ls -l "fb_pop_dir""$1"_pop.tif" }'|parallel -I{} {}

#cat "$hrea_dir"'extents.txt'|sed 's/GID_0_//g'|grep MOZ|awk \
#-v fb_pop_dir="$fb_pop_dir" -v hrea_dir="$hrea_dir" \
#-v x_res="$x_res" -v y_res="$y_res" \
#'{print "gdal_translate -eco -of GTiff  -co BIGTIFF=IF_NEEDED -co COMPRESS=DEFLATE -projwin_srs EPSG:3857 -projwin " \
#$2,$3,$4,$5 \
#" -outsize "x_res" "y_res \
#" "fb_pop_dir""$1"_pop.tif" \
#" "fb_pop_dir""$1"_pop_3587.tif"
#}'|parallel -I{} echo {}

#Missing In Action from Facebook population:

#AFG
#ARE
#AZE
#ASM
#BLM
#BRA
#CHL
#CHN
#CRI
#CUB
#FJI
#GEO
#GLP
#GUF
#IRN
#KAZ
#KGZ
#JPN
#LBN
#MTQ
#NCL
#PRK
#OMN
#PSE
#REU
#SHN
#SAU
#SYR
#TKM
#TON
#TUR
#TWN
#VEN
#VIR
#WSM
#Z04
#UZB
#Z01
#Z06
#YEM
#Z03
#WLF
#XKO
#Z02
#Z07
#Z05
#Z08
#Z09

