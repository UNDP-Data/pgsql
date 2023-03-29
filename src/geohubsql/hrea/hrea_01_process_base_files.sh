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


# remove overviews from hrea files:

#MASK HREA @ 80%

#mkdir -p "$hrea_dir"hrea_data/by_year/
mkdir -p "$thr_dir"

for this_year in "${available_years[@]}"; do

   echo "$this_year"
   mkdir -p "$thr_dir/$this_year"


#-te <xmin ymin xmax ymax>
#   1         2        3       4        5
#GID_0_MOZ 3354012 -1162198 4556211 -3097076

#gdal_translate -ovr NONE -eco -projwin 3354012 -1162198 4556211 -3097076 -of GTiff -co COMPRESS=ZSTD -co BIGTIFF=IF_NEEDED /home/rafd/Downloads/admin-levels_/HREA/_data/_2012_orig.tif /home/rafd/Downloads/admin-levels_/HREA/_data/by_year/2012/_2012_MOZ.tif

#gdalwarp -multi -wo NUM_THREADS=ALL_CPUS -overwrite -tap -ovr NONE -r bilinear -t_srs EPSG:3857 -of GTiff  -co BIGTIFF=IF_NEEDED -co COMPRESS=DEFLATE \
#-tr 41.735973305281412 41.735973305281412 -te_srs EPSG:3857 \
#-te 3354012 -3097076 4556211 -1162198 \
#/home/rafd/Downloads/admin-levels_/HREA/hrea_data/hrea_2012_orig.tif \
#/home/rafd/Downloads/admin-levels_/HREA/hrea_data/by_year/2012/hrea_2012_MOZ_warp.tif

    #create pixel_aligned country-sized hrea/ml geotiffs for each available year
    for this_series in "${available_series[@]}"; do

       ls -la "$hrea_dir"extents.txt

        #       time cat "$hrea_dir"extents.txt|sed 's/GID_0_//g'|awk -v this_series="$this_series" \
        #       -v this_year="$this_year" -v hrea_dir="$hrea_dir" \
        #       '{print "gdal_translate -ovr NONE -eco -projwin "$2,$3,$4,$5 " -of GTiff -co COMPRESS=ZSTD -co BIGTIFF=IF_NEEDED "\
        #       hrea_dir""this_series"_data/"this_series"_"this_year"_orig.tif " \
        #       hrea_dir""this_series"_data/by_year/"this_year"/"this_series"_"this_year"_"$1".tif"}'|parallel -I{} echo {}

        # -multi -wo NUM_THREADS=ALL_CPUS does not have much of an effect

#grep "AFG\|ARE\|ASM\|AZE\|BDI\|BEN\|BFA\|BGD\|BLM\|BRA\|BRN\|CHL\|CHN\|CIV\|CMR\|COG\|DJI\|DOM\|EGY\|ERI\|GAB"
#grep "AGO\|ARG\|BOL\|CAF\|COD\|COL\|DZA\|ECU\|ETH\|FSM\|BTN\|BWA"|
#grep "BDI\|BEN\|BGD\|BFA\|BRN\|CMR\|CIV\|COG"
#grep "DOM\|DJI\|EGY\|ERI\|GAB"
       time cat "$hrea_dir"extents.txt|sed 's/GID_0_//g'|awk \
       -v this_series="$this_series" \
       -v this_year="$this_year" \
       -v hrea_dir="$hrea_dir" \
       '{print "time gdalwarp -overwrite -tap -ovr NONE -r bilinear -t_srs EPSG:3857 -of GTiff  -co BIGTIFF=IF_NEEDED -co COMPRESS=DEFLATE "\
       " -tr 41.735973305281412 41.735973305281412 -te_srs EPSG:3857 -te "\
       $2,$5,$4,$3" " \
       hrea_dir""this_series"_data/"this_series"_"this_year"_orig.tif " \
       hrea_dir""this_series"_data/by_year/"this_year"/"this_series"_"this_year"_"$1".tif"}'|parallel -I{}  {}

    done

    # zonal stats
    for this_series in "${available_series[@]}"; do
      #echo $this_series - $this_year
      echo "$hrea_dir""$this_series"'_data_thr80p/'"$this_year"
      mkdir -p "$hrea_dir""$this_series"'_data_thr80p/'"$this_year"

      #time gdal_calc.py  --co COMPRESS=ZSTD --type=Byte --co NBITS=1 --NoDataValue=0 -A /home/rafd/Downloads/admin-levels_/HREA/hrea_data/by_year/2012/hrea_2012_MOZ_bash.tif  --outfile=/home/rafd/Downloads/admin-levels_/HREA/hrea_data_thr80p/2012/hrea_2012_MOZ_m80.tif --calc="A>=0.8"

      cat "$hrea_dir"'extents.txt'|sed 's/GID_0_//g'|awk -v this_series="$this_series" \
      -v this_year="$this_year" -v hrea_dir="$hrea_dir" \
      '{print "gdal_calc.py --overwrite --quiet --co COMPRESS=ZSTD --type=Byte --co NBITS=1 --NoDataValue=0 -A " \
      hrea_dir""this_series"_data/by_year/"this_year"/"this_series"_"this_year"_"$1".tif" \
      " --outfile="hrea_dir""this_series"_data_thr80p/"this_year"/"this_series"_"this_year"_"$1"_m80.tif" \
      " --calc=@A>=0.8@" \
      }'|tr '@' '"'|parallel -I{}  {}

      #exactextract does not understand NoData
      ls -1 "$thr_dir/$this_year"'/'$this_series''*tif|parallel -I{} gdal_edit.py -unsetnodata {}

    done

done

