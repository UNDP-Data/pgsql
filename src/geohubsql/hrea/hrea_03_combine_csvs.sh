#!/bin/bash

base_dir="/home/rafd/Downloads/admin-levels_/"
hrea_dir="$base_dir""HREA/"
adm0_dir="$base_dir""gadm_adm2_by_country/"
hrea_data_dir=$hrea_dir"hrea_data/"
hrea_csv_dir=$hrea_data_dir"hrea_csv/"
hrea_outputs_dir=$hrea_dir"hrea_outputs/"

all_countries_csv="$hrea_outputs_dir"all_countries_sp.csv

mkdir -p "$hrea_outputs_dir"
echo "reading $hrea_csv_dir"
echo "creating $all_countries_csv"

echo -n 'iso3cd,adm1,adm2,adm2_sub,' > "$all_countries_csv"
head -q -n1 "$hrea_csv_dir"hrea_???.csv|head -n1 |grep  'GID_2b'|sed 's/GID_2b,//g' | sed 's/GHA/GHA./g' |sed 's/GHA../GHA../g' >> "$all_countries_csv"
head -n1 "$all_countries_csv"
echo


cat "$hrea_csv_dir"hrea_???.csv|grep -v 'GID_2b'| sed 's/-nan/nan/g'| sed 's/nan/0/g'| sed 's/,,/,0,/g'| sed 's/,,/,0,/g'| sed 's/,,/,0,/g'| sed 's/,$/,0/g' | awk '{split($1,adm2,":");split(adm2[1],country,".");split($1,adm2,":");print country[1]","country[1]"."country[2]","adm2[1]","$0}'  >> "$all_countries_csv"
head "$all_countries_csv"



#fix GHA: GHA1 -> GHA.1 // skip: fixed the original gpkg
sed -i '/GHA/s/GHA\([0-9]\)/GHA\.\1/g'  "$all_countries_csv"
sed -i '/GHA/s/GHA\.\./GHA\./g' "$all_countries_csv"

#fix GHA: admin2  GHA.10.13_2 -> GHA.10.13_1
#sed -i  '/GHA/s/GHA.\([0-9]\+\).\([0-9]\+\)_2,/GHA.\1.\2_1,/g' "$all_countries_csv"

#fix ZWE: admin2  ZWE.10.13_2 -> ZWE.10.13_1
#sed -i  '/ZWE/s/ZWE.\([0-9]\+\).\([0-9]\+\)_2,/ZWE.\1.\2_1,/g' "$all_countries_csv"

#fix ZMB: admin2  ZMB.10.13_2 -> ZMB.10.13_1
#sed -i  '/ZMB/s/ZMB.\([0-9]\+\).\([0-9]\+\)_2,/ZMB.\1.\2_1,/g' "$all_countries_csv"

#fix TGO: admin2  TGO.10.13_2 -> TGO.10.13_1
#sed -i  '/TGO/s/TGO.\([0-9]\+\).\([0-9]\+\)_2,/TGO.\1.\2_1,/g' "$all_countries_csv"


#cat "$all_countries_csv" | sed 's/-nan/nan/g' | sed 's/nan/0/g' |head -2

#cat "$all_countries_csv" | grep -v 'iso3cd' | sed 's/-nan/nan/g' | sed 's/nan/0/g'|tr ',' ' ' | awk 'BEGIN{country="";cnt=0;sum=0}
#{
#if($1!=country){
#  if(cnt>0){
#    printf "%s %.2f %.2f %.5f", country,sum,cnt,sum/cnt;
#    { i = 1 }
#    { while ( i <= NF )
#    { printf " %.5f ", $i ; i++ } };
#    printf "\n"
#
#{ print "\n" }
#  }else{
#    if(length(country)>0){printf "%s %.2f %.2f %.5f\n",country,0,0,0}
#  };
#  country=$1;cnt=$5;sum=$6
#}else{
#  cnt=cnt+$5;sum=sum+$6}
#}'> "$hrea_outputs_dir"adm0_stats_2020.csv

#cat "$all_countries_csv" | grep -v 'iso3cd' | sed 's/-nan/nan/g' | sed 's/nan/0/g' |tr ',' ' '| awk 'BEGIN{adm1="";cnt=0;sum=0}{if($2!=adm1){if(cnt>0){printf "%s %.2f %.2f %.5f\n",adm1,sum,cnt,sum/cnt}else{printf "%s %.2f %.2f %.5f\n",adm1,0,0,0};adm1=$2;cnt=$5;sum=$6}else{cnt=cnt+$5;sum=sum+$6}}'> "$hrea_outputs_dir"adm1_stats_2020.csv

#cat "$all_countries_csv | grep -v 'iso3cd'" | sed 's/-nan/nan/g' | sed 's/nan/0/g' |tr ',' ' '| awk 'BEGIN{adm2="";cnt=0;sum=0}{\
#if($3!=adm2)\
#{if(cnt>0)\
#    {printf "%s %.2f %.2f %.5f\n",adm2,sum,cnt,sum/cnt}\
#    else {printf "%s %.2f %.2f %.5f\n",adm2,0,0,0}\
#;adm2=$3;cnt=$5;sum=$6}\
#else\
#{cnt=cnt+$5;sum=sum+$6}\
#}'> "$hrea_outputs_dir"adm2_stats_2020.csv