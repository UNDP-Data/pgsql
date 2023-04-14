#!/bin/bash
homedir=$(realpath ~)
data_dir="$homedir"'/data/hrea/'

hrea_csv_dir="$data_dir"'hrea_outputs/hrea_csv/'
hrea_outputs_dir="$data_dir""hrea_outputs/hrea_per_country/"

all_countries_csv="$hrea_outputs_dir"'all_countries_sp.csv'

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
