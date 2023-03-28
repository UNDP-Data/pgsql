#!/bin/bash

base_dir="/home/rafd/Downloads/admin-levels_/"
hrea_dir="$base_dir""HREA/"
adm0_dir="$base_dir""admin2_by_region3_subdivided/"
hrea_data_dir=$hrea_dir"hrea_data/"
hrea_csv_dir=$hrea_data_dir"hrea_csv/"
hrea_outputs_dir=$hrea_dir"hrea_outputs/"

all_countries_csv="$hrea_outputs_dir"all_countries_sp.csv

mkdir -p "$hrea_outputs_dir"
echo "reading $all_countries_csv"
echo "creating outputs in: $hrea_outputs_dir"

echo -n 'iso3cd,adm1,adm2,adm2_sub,' > "$all_countries_csv"
head -q -n1 "$hrea_csv_dir"hrea_???.csv|head -n1 |grep  'GID_2b'|sed 's/GID_2b,//g' >> "$all_countries_csv"

cat "$hrea_csv_dir"hrea_???.csv|grep -v 'GID_2b'| sed 's/-nan/nan/g'| sed 's/nan/0/g'| sed 's/,,/,0,/g'| sed 's/,,/,0,/g'| sed 's/,,/,0,/g'| sed 's/,$/,0/g' | awk '{split($1,adm2,":");split(adm2[1],country,".");split($1,adm2,":");print country[1]","country[1]"."country[2]","adm2[1]","$0}' >> "$all_countries_csv"
head "$all_countries_csv"

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