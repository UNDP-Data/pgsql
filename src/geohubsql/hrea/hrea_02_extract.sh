#!/bin/bash

base_dir="/home/rafd/Downloads/admin-levels_/"
hrea_dir="$base_dir""HREA/"
adm0_dir="$base_dir""admin2_by_region3_subdivided/"
hrea_data_dir=$hrea_dir"hrea_data/"
hrea_csv_dir=$hrea_data_dir"hrea_csv/"
fb_pop_dir=$hrea_dir"facebook_pop_30m/"
thr_dir=$hrea_dir"hrea_data_thr80p/"

this_series='hrea'

mkdir -p "$hrea_csv_dir"

cat "$hrea_dir"'extents.txt'|sed 's/GID_0_//g'|awk \
  -v this_series="$this_series" \
  -v hrea_csv_dir="$hrea_csv_dir" \
  -v thr_dir="$thr_dir" \
  -v fb_pop_dir="$fb_pop_dir" \
  -v adm0_dir="$adm0_dir" \
  '{print "exactextract " \
"-r @pop:"fb_pop_dir""$1"_pop_3857.tif@ " \
"-r @"this_series"_2012:"thr_dir"/2012/"this_series"_2012_"$1"_m80.tif@ " \
"-r @"this_series"_2013:"thr_dir"/2013/"this_series"_2013_"$1"_m80.tif@ " \
"-r @"this_series"_2014:"thr_dir"/2014/"this_series"_2014_"$1"_m80.tif@ " \
"-r @"this_series"_2015:"thr_dir"/2015/"this_series"_2015_"$1"_m80.tif@ " \
"-r @"this_series"_2016:"thr_dir"/2016/"this_series"_2016_"$1"_m80.tif@ " \
"-r @"this_series"_2017:"thr_dir"/2017/"this_series"_2017_"$1"_m80.tif@ " \
"-r @"this_series"_2018:"thr_dir"/2018/"this_series"_2018_"$1"_m80.tif@ " \
"-r @"this_series"_2019:"thr_dir"/2019/"this_series"_2019_"$1"_m80.tif@ " \
"-r @"this_series"_2020:"thr_dir"/2020/"this_series"_2020_"$1"_m80.tif@ " \
"-p @"adm0_dir"GID_0_"$1".gpkg@ -f @GID_2b@ -o @"hrea_csv_dir""this_series"_"$1".csv@ -s @sum(pop)@ -s @mean(pop)@ -s @min(pop)@ -s @max(pop)@ " \
"-s @popw_2012=weighted_sum(pop,"this_series"_2012)@ " \
"-s @popw_2013=weighted_sum(pop,"this_series"_2013)@ " \
"-s @popw_2014=weighted_sum(pop,"this_series"_2014)@ " \
"-s @popw_2015=weighted_sum(pop,"this_series"_2015)@ " \
"-s @popw_2016=weighted_sum(pop,"this_series"_2016)@ " \
"-s @popw_2017=weighted_sum(pop,"this_series"_2017)@ " \
"-s @popw_2018=weighted_sum(pop,"this_series"_2018)@ " \
"-s @popw_2019=weighted_sum(pop,"this_series"_2019)@ " \
"-s @popw_2020=weighted_sum(pop,"this_series"_2020)@ " \
}' |tr '@' '"'|parallel --jobs 80% -I{} {}



#cat SUBST_SERIES_GID_0_*.csv|grep -v 'GID2b,e_count,e_sum,e_mean,e_min,e_max,e_stdev'|awk '{split($1,adm2,":");split(adm2[1],country,".");split($1,adm2,":");print country[1]","country[1]"."country[2]","adm2[1]","$0}'|tr ',' ' ' > all_countries_sp.ssv
#cat all_countries_sp.ssv |awk 'BEGIN{country="";cnt=0;sum=0}{if($1!=country){if(cnt>0){printf "%s %.2f %.2f %.5f\n", country,sum,cnt,sum/cnt}else{printf "%s %.2f %.2f %.5f\n",country,0,0,0};country=$1;cnt=$5;sum=$6}else{cnt=cnt+$5;sum=sum+$6}}'>SUBST_SERIES_adm0_stats_2020.csv
#cat all_countries_sp.ssv |awk 'BEGIN{adm1="";cnt=0;sum=0}{if($2!=adm1){if(cnt>0){printf "%s %.2f %.2f %.5f\n",adm1,sum,cnt,sum/cnt}else{printf "%s %.2f %.2f %.5f\n",adm1,0,0,0};adm1=$2;cnt=$5;sum=$6}else{cnt=cnt+$5;sum=sum+$6}}'>SUBST_SERIES_adm1_stats_2020.csv
#cat all_countries_sp.ssv |awk 'BEGIN{adm2="";cnt=0;sum=0}{\
#if($3!=adm2)\
#{if(cnt>0)\
#    {printf "%s %.2f %.2f %.5f\n",adm2,sum,cnt,sum/cnt}\
#    else {printf "%s %.2f %.2f %.5f\n",adm2,0,0,0}\
#;adm2=$3;cnt=$5;sum=$6}\
#else\
#{cnt=cnt+$5;sum=sum+$6}\
#}'>SUBST_SERIES_adm2_stats_2020.csv

date

#exactextract -r "pop:/home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop1.tif" \
#-r "hrea_2012:/home/rafd/Downloads/admin-levels_/HREA/hrea_data_thr80p//2012/hrea_2012_MOZ_m80.tif" \
#-p "/home/rafd/Downloads/admin-levels_/admin2_by_region3_subdivided/GID_0_MOZ.gpkg" \
#-f "GID_2b" -o "hrea_MOZ.csv" --progress \
#-s "sum(pop)" -s "mean(pop)" -s "min(pop)" -s "max(pop)" -s "popw_2012=weighted_sum(hrea_2012,pop)"


#exactextract \
#-r "pop:/home/rafd/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop_3857.tif" \
#-r "hrea_2017:/home/rafd/Downloads/admin-levels_/HREA/hrea_data_thr80p//2017/hrea_2017_MOZ_m80_dfl.tif" \
#-p "/home/rafd/Downloads/admin-levels_/admin2_by_region3_subdivided/GID_0_MOZ.gpkg" -f "GID_2b" -o "/home/rafd/Downloads/admin-levels_/HREA/hrea_data/hrea_csv/hrea_MOZ_manual_inv.csv" \
#-s "sum(pop)" -s "mean(pop)" -s "min(pop)" -s "max(pop)" \
#-s "sum(hrea_2017)" -s "mean(hrea_2017)" -s "min(hrea_2017)" -s "max(hrea_2017)" \
#-s "hrea_2017m=mean(hrea_2017)" \
#-s "popw_2017=weighted_sum(pop,hrea_2017)"