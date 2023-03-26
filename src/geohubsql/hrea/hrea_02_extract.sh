time cat extents.txt|awk -v this_series=$this_series '{print "exactextract \
-r @SUBST_SERIES_2012:"./tiffs_by_country/SUBST_SERIES_2012_$1".tif@ \
-r @SUBST_SERIES_2013:"./tiffs_by_country/SUBST_SERIES_2013_$1".tif@ \
-r @SUBST_SERIES_2014:"./tiffs_by_country/SUBST_SERIES_2014_$1".tif@ \
-r @SUBST_SERIES_2015:"./tiffs_by_country/SUBST_SERIES_2015_$1".tif@ \
-r @SUBST_SERIES_2016:"./tiffs_by_country/SUBST_SERIES_2016_$1".tif@ \
-r @SUBST_SERIES_2017:"./tiffs_by_country/SUBST_SERIES_2017_$1".tif@ \
-r @SUBST_SERIES_2018:"./tiffs_by_country/SUBST_SERIES_2018_$1".tif@ \
-r @SUBST_SERIES_2019:"./tiffs_by_country/SUBST_SERIES_2019_$1".tif@ \
-r @SUBST_SERIES_2020:"./tiffs_by_country/SUBST_SERIES_2020_$1".tif@ \
-p @"$1".gpkg@ -f @GID_2b@ -o @SUBST_SERIES_"$1".csv@ --progress -s @count(e)@ -s @sum(e)@ -s @mean(e)@ -s @min(e)@ -s @max(e)@ -s @stdev(e)@"}'|tr '@' '"'|parallel -I{} {}

done

cat SUBST_SERIES_GID_0_*.csv|grep -v 'GID2b,e_count,e_sum,e_mean,e_min,e_max,e_stdev'|awk '{split($1,adm2,":");split(adm2[1],country,".");split($1,adm2,":");print country[1]","country[1]"."country[2]","adm2[1]","$0}'|tr ',' ' ' > all_countries_sp.ssv

cat all_countries_sp.ssv |awk 'BEGIN{country="";cnt=0;sum=0}{if($1!=country){if(cnt>0){printf "%s %.2f %.2f %.5f\n", country,sum,cnt,sum/cnt}else{printf "%s %.2f %.2f %.5f\n",country,0,0,0};country=$1;cnt=$5;sum=$6}else{cnt=cnt+$5;sum=sum+$6}}'>SUBST_SERIES_adm0_stats_2020.csv

cat all_countries_sp.ssv |awk 'BEGIN{adm1="";cnt=0;sum=0}{if($2!=adm1){if(cnt>0){printf "%s %.2f %.2f %.5f\n",adm1,sum,cnt,sum/cnt}else{printf "%s %.2f %.2f %.5f\n",adm1,0,0,0};adm1=$2;cnt=$5;sum=$6}else{cnt=cnt+$5;sum=sum+$6}}'>SUBST_SERIES_adm1_stats_2020.csv

cat all_countries_sp.ssv |awk 'BEGIN{adm2="";cnt=0;sum=0}{\
if($3!=adm2)\
{if(cnt>0)\
    {printf "%s %.2f %.2f %.5f\n",adm2,sum,cnt,sum/cnt}\
    else {printf "%s %.2f %.2f %.5f\n",adm2,0,0,0}\
;adm2=$3;cnt=$5;sum=$6}\
else\
{cnt=cnt+$5;sum=sum+$6}\
}'>SUBST_SERIES_adm2_stats_2020.csv

date