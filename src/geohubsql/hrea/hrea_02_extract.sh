#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/hrea/'
base_dir="$homedir""/Downloads/admin-levels_/"
hrea_dir="$base_dir""HREA/"
hrea_cogs_dir="$data_dir"'HREA_COGs/'
adm2_dir="$data_dir""gadm_adm2_by_country_4326/"

hrea_csv_dir="$data_dir""hrea_csv/"
thr_dir="$data_dir""hrea_data_thr80p/"

#COD,DR_Congo
#COG,Congo_Republic
country_lut="$data_dir"'adm0_names_lut.csv'

this_series='hrea'

mkdir -p "$hrea_csv_dir"

#cd admin-levels_/gadm_adm2_by_country
#ls -1|sed 's/.gpkg//g'|awk '{print "ogrinfo "$1".gpkg -sql @ALTER TABLE "$1" DROP COLUMN nofv@"}'|tr '@' '"'
#ls -1|sed 's/.gpkg//g'|awk '{print "ogrinfo "$1".gpkg -sql @ALTER TABLE "$1" DROP COLUMN GID_1b@"}'|tr '@' '"'

#reproject into 4326
#cd "$homedir"/data/hrea/gadm_adm2_by_country_3857
#mkdir "$homedir"/data/hrea/gadm_adm2_by_country_4326/
#ls -1|parallel -I{} ogr2ogr "$homedir"/data/hrea/gadm_adm2_by_country_4326/{} -t_srs "EPSG:4326" {}

countries_str=$(ls -1d "$hrea_cogs_dir"/HREA_*_v1|grep "$this_year"|xargs -I{} basename {}|grep '^HREA'|grep '_v1$'|sed 's/^HREA_//g'|sed 's/_v1//g'|sed "s/_$this_year//g")

mkdir -p "$hrea_csv_dir"

cat "$country_lut" | tr ',' ' ' | awk \
  -v this_series="$this_series" \
  -v hrea_csv_dir="$hrea_csv_dir" \
  -v thr_dir="$thr_dir" \
  -v hrea_cogs_dir="$hrea_cogs_dir" \
  -v adm2_dir="$adm2_dir" \
  '{print "echo "$1" aka "$2"; exactextract " \
"-p @"adm2_dir"GID_0_"$1".gpkg@ -f @GID_2b@ -o @"hrea_csv_dir""this_series"_"$1".csv@ " \
"-r @pop:"hrea_cogs_dir""$2"_pop.tif@ " \
"-r @hrea_2012:"thr_dir""$2"/"$2"_2012_hrea.tif@ " \
"-r @hrea_2013:"thr_dir""$2"/"$2"_2013_hrea.tif@ " \
"-r @hrea_2014:"thr_dir""$2"/"$2"_2014_hrea.tif@ " \
"-r @hrea_2015:"thr_dir""$2"/"$2"_2015_hrea.tif@ " \
"-r @hrea_2016:"thr_dir""$2"/"$2"_2016_hrea.tif@ " \
"-r @hrea_2017:"thr_dir""$2"/"$2"_2017_hrea.tif@ " \
"-r @hrea_2018:"thr_dir""$2"/"$2"_2018_hrea.tif@ " \
"-r @hrea_2019:"thr_dir""$2"/"$2"_2019_hrea.tif@ " \
"-r @hrea_2020:"thr_dir""$2"/"$2"_2020_hrea.tif@ " \
"-r @no_hrea_2012:"thr_dir""$2"/"$2"_2012_no_hrea.tif@ " \
"-r @no_hrea_2013:"thr_dir""$2"/"$2"_2013_no_hrea.tif@ " \
"-r @no_hrea_2014:"thr_dir""$2"/"$2"_2014_no_hrea.tif@ " \
"-r @no_hrea_2015:"thr_dir""$2"/"$2"_2015_no_hrea.tif@ " \
"-r @no_hrea_2016:"thr_dir""$2"/"$2"_2016_no_hrea.tif@ " \
"-r @no_hrea_2017:"thr_dir""$2"/"$2"_2017_no_hrea.tif@ " \
"-r @no_hrea_2018:"thr_dir""$2"/"$2"_2018_no_hrea.tif@ " \
"-r @no_hrea_2019:"thr_dir""$2"/"$2"_2019_no_hrea.tif@ " \
"-r @no_hrea_2020:"thr_dir""$2"/"$2"_2020_no_hrea.tif@ " \
"-s @sum(pop)@ " \
"-s @hrea_2012=weighted_sum(pop,hrea_2012)@ " \
"-s @hrea_2013=weighted_sum(pop,hrea_2013)@ " \
"-s @hrea_2014=weighted_sum(pop,hrea_2014)@ " \
"-s @hrea_2015=weighted_sum(pop,hrea_2015)@ " \
"-s @hrea_2016=weighted_sum(pop,hrea_2016)@ " \
"-s @hrea_2017=weighted_sum(pop,hrea_2017)@ " \
"-s @hrea_2018=weighted_sum(pop,hrea_2018)@ " \
"-s @hrea_2019=weighted_sum(pop,hrea_2019)@ " \
"-s @hrea_2020=weighted_sum(pop,hrea_2020)@ " \
"-s @no_hrea_2012=weighted_sum(pop,no_hrea_2012)@ " \
"-s @no_hrea_2013=weighted_sum(pop,no_hrea_2013)@ " \
"-s @no_hrea_2014=weighted_sum(pop,no_hrea_2014)@ " \
"-s @no_hrea_2015=weighted_sum(pop,no_hrea_2015)@ " \
"-s @no_hrea_2016=weighted_sum(pop,no_hrea_2016)@ " \
"-s @no_hrea_2017=weighted_sum(pop,no_hrea_2017)@ " \
"-s @no_hrea_2018=weighted_sum(pop,no_hrea_2018)@ " \
"-s @no_hrea_2019=weighted_sum(pop,no_hrea_2019)@ " \
"-s @no_hrea_2020=weighted_sum(pop,no_hrea_2020)@ " \
}' |tr '@' '"'|parallel --jobs 50% -I{}  {}



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

#exactextract -r "pop:"$homedir"/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop1_hrea.tif" \
#-r "hrea_2012:"$homedir"/Downloads/admin-levels_/HREA/hrea_data_thr80p//2012/hrea_2012_MOZ_m80_hrea.tif" \
#-p ""$homedir"/Downloads/admin-levels_/admin2_by_region3_subdivided/GID_0_MOZ.gpkg" \
#-f "GID_2b" -o "hrea_MOZ.csv" --progress \
#-s "sum(pop)" -s "mean(pop)" -s "min(pop)" -s "max(pop)" -s "hrea_2012=weighted_sum(hrea_2012,pop)"


#exactextract \
#-r "pop:"$homedir"/Downloads/admin-levels_/HREA/facebook_pop_30m/MOZ_pop_3857_hrea.tif" \
#-r "hrea_2017:"$homedir"/Downloads/admin-levels_/HREA/hrea_data_thr80p//2017/hrea_2017_MOZ_m80_dfl_hrea.tif" \
#-p ""$homedir"/Downloads/admin-levels_/admin2_by_region3_subdivided/GID_0_MOZ.gpkg" -f "GID_2b" -o ""$homedir"/Downloads/admin-levels_/HREA/hrea_data/hrea_csv/hrea_MOZ_manual_inv.csv" \
#-s "sum(pop)" -s "mean(pop)" -s "min(pop)" -s "max(pop)" \
#-s "sum(hrea_2017)" -s "mean(hrea_2017)" -s "min(hrea_2017)" -s "max(hrea_2017)" \
#-s "hrea_2017m=mean(hrea_2017)" \
#-s "hrea_2017=weighted_sum(pop,hrea_2017)"