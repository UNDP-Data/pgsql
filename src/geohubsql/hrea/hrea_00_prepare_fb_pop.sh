#!/bin/bash

hrea_dir="/home/rafd/Downloads/admin-levels_/HREA/"
hrea_data_dir=$hrea_dir"hrea_data/"
fb_pop_dir=$hrea_dir"facebook_pop_30m/"
thr_dir=$hrea_dir"hrea_data_thr80p/"
x_res='41.735973305281412'
y_res='41.735973305281412'
#write down the (buffered) extent of the Country layers
#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk '{print $1, $2, $5, $4, $3}'> extents.txt

#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk 'BEGIN{buf=10000;}{printf "%s %.0f %.0f %.0f %.0f\n", $1, $2-buf, $5+buf, $4+buf, $3+buf}'> extents.txt

#reproject fb_pop layers into 3857 with the same pixel size as the hrea files


#gdal_translate -projwin -1278581. 955535. -819880. 485031. -of GTiff -co COMPRESS=NONE -co BIGTIFF=IF_NEEDED ~/Downloads/admin-levels_/admin2_by_region3/e.tif ~/Downloads/admin-levels_/admin2_by_region3_subdivided/LBR.tif

#time gdalwarp -overwrite -s_srs EPSG:4326 -t_srs EPSG:3857 -te 3354012 -3097076 4556211 -1162198 -tr 41.735973305281412 41.735973305281412 /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop.tif /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop_3857_gdal.tif

#gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 -tr 41.73597330528141 41.73597330528141 \
# -r near -te 3354012.0 -3097077.7224 4556216.7111 -1162198.0 -te_srs EPSG:3857
# -multi -ot Float32 -of GTiff -co COMPRESS=DEFLATE -co PREDICTOR=2 -co ZLEVEL=9
# /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop1.tif /home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop_3857_gdal_qgis.tif

cat "$hrea_dir"'extents.txt'|sed 's/GID_0_//g'|grep MOZ|awk \
-v fb_pop_dir="$fb_pop_dir" -v hrea_dir="$hrea_dir" \
-v x_res="$x_res" -v y_res="$y_res" \
'{print "gdalwarp -overwrite -s_srs EPSG:4326 -t_srs EPSG:3857 -of GTiff  -co BIGTIFF=IF_NEEDED -co COMPRESS=DEFLATE  -tr 41.735973305281412 41.735973305281412 -projwin_srs EPSG:3857 -te " \
$2,$5,$4,$3 \
" "fb_pop_dir""$1"_pop.tif" \
" "fb_pop_dir""$1"_pop_3587.tif"
}'|parallel -I{} echo {}


#cat "$hrea_dir"'extents.txt'|sed 's/GID_0_//g'|grep MOZ|awk \
#-v fb_pop_dir="$fb_pop_dir" -v hrea_dir="$hrea_dir" \
#-v x_res="$x_res" -v y_res="$y_res" \
#'{print "gdal_translate -of GTiff  -co BIGTIFF=IF_NEEDED -co COMPRESS=DEFLATE -projwin_srs EPSG:3857 -projwin " \
#$2,$3,$4,$5 \
#" -outsize "x_res" "y_res \
#" "fb_pop_dir""$1"_pop.tif" \
#" "fb_pop_dir""$1"_pop_3587.tif"
#}'|parallel -I{} echo {}

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
