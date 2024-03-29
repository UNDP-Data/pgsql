#!/bin/bash

homedir=$(realpath ~)
boundaries_dir="$homedir"'/data/boundaries/'
adm_base_dir="$homedir"'/data/boundaries/adm'

data_dir="$homedir"'/data/hrea/'
base_dir="$homedir""/Downloads/admin-levels_/"
hrea_dir="$base_dir""HREA/"
hrea_cogs_dir="$data_dir"'HREA_COGs/'
adm2_dir="$data_dir""gadm_adm2_by_country_4326/"

hrea_csv_dir="$data_dir"'hrea_outputs/hrea_csv/'
thr_dir="$data_dir""hrea_data_thr80p/"
country_lut="$data_dir"'adm0_names_lut.csv'

this_pid="$$"

available_pop=/tmp/pop_tif_"${this_pid}".txt
all_countries=/tmp/all_countries_lut.txt
available_pop_with_fullname=/tmp/available_pop_with_fullname.txt

levels_to_extract=(4)

#wget https://geodata.ucdavis.edu/gadm/gadm4.1/gadm_410-levels.zip

#ogr2ogr -f 'GPKG' gadm_410-levels_adm0.gpkg gadm_410-levels.gpkg ADM_0
#ogr2ogr -f 'GPKG' gadm_410-levels_adm1.gpkg gadm_410-levels.gpkg ADM_1
#ogr2ogr -f 'GPKG' gadm_410-levels_adm2.gpkg gadm_410-levels.gpkg ADM_2
#ogr2ogr -f 'GPKG' gadm_410-levels_adm3.gpkg gadm_410-levels.gpkg ADM_3
#ogr2ogr -f 'GPKG' gadm_410-levels_adm4.gpkg gadm_410-levels.gpkg ADM_4

function available_countries() {

  level="$1"
  countries_str=$()

  ls -1 "$hrea_cogs_dir"*_pop.tif |sed 's/_pop.tif//g' | xargs -n 1 basename|sort -k 1b,1 > "$available_pop"
  #head -5 "$available_pop"

  cat "$country_lut" | tr ',-' ' _' |awk '{print $2,$1}' |sort -k 1b,1 > "$all_countries"
  #head -5 "$all_countries"

  join -o 1.1 2.2 "$available_pop" "$all_countries" > "$available_pop_with_fullname"
  list=$(join -o 2.2 "$available_pop" "$all_countries" | tr "\n" ','|sed 's/,$//g'|sed 's/,/","/g')
  list='"'${list}'"'
  echo "$list"

}


#ogrinfo -dialect sqlite -sql 'SELECT DISTINCT (GID_3) as IDs FROM ADM_3 LIMIT 50' gadm_410-levels.gpkg

#list all Countries in adm3
#Layer name: SELECT
#OGRFeature(SELECT):0
#  adm_0_id (String) = AGO
#  adm0_name (String) = Angola
#
#OGRFeature(SELECT):1
#  adm_0_id (String) = ALB
#  adm0_name (String) = Albania
#
# ->
#
#AGO,Angola
#ALB,Albania
function extract_levels() {
for this_level in "${levels_to_extract[@]}"; do

#number of Countries to be extracted:
nof_countries=$(ogrinfo -q -dialect sqlite -sql 'SELECT COUNT(DISTINCT(GID_0)) as adm_0_id FROM ADM_'"$this_level" "$boundaries_dir"gadm_410-levels.gpkg|grep adm_0_id|awk '{print $NF}')

outdir="$adm_base_dir$this_level"'/'
echo 'Extracting '"$nof_countries"' Countries at administrative level '"$this_level"' into '"$outdir"
mkdir -p $outdir

countries_str=$(ogrinfo -q -dialect sqlite -sql 'SELECT DISTINCT(GID_0) as adm_0_id, COUNTRY as adm0_name FROM ADM_'"$this_level" "$boundaries_dir"gadm_410-levels.gpkg| \
grep -v SELECT|tr "=\n" ' @'|sed 's/^@ //g'|tr -s ' '|sed "s/@@/\n/g"|tr '@' ' '|sed 's/  adm0_name (String) /,/g'|sed 's/ adm_0_id (String) //g'|tr ' ' '_')

#echo $countries_str

echo "$countries_str"| tr ',' ' '| \
awk -v this_level=$this_level -v boundaries_dir=$boundaries_dir -v outdir=$outdir \
'{iso3=$1; printf "ogr2ogr -t_srs EPSG:4326 -f GPKG %sadm%s_%s.gpkg -nln %s -dialect sqlite -sql \x27SELECT * FROM ADM_3 WHERE GID_0=\"%s\"\x27 %sgadm_410-levels.gpkg\n", \
outdir,this_level,iso3,iso3,iso3,boundaries_dir}'|parallel --jobs 2 -I{} {}

#ogr2ogr -f GPKG out.gpkg -dialect sqlite -sql 'SELECT * FROM ADM_3 WHERE GID_0="RWA"' "$boundaries_dir"gadm_410-levels.gpkg

done
}


for level in "${levels_to_extract[@]}"; do

  echo "Extracting admin level ${level}: "
  list=$(available_countries "${level}")

  echo -e 'List of available Countries: ' ${list}"\n"
  country_array=($(echo ${list}|tr -d '"'|tr ',' ' '))
#  echo country_array_0 ${country_array[0]}
#  echo country_array_1 ${country_array[1]}

  #extract the 'minimal' gpkg, containing all and only adm${level} Countries
  ogr2ogr -f GPKG ${boundaries_dir}adm${level}_minimal.gpkg -nln adm${level}_polygons -dialect sqlite -sql 'SELECT * FROM ADM_'${level}' WHERE GID_0 IN ('${list}')' "$boundaries_dir"gadm_410-levels.gpkg

  available_in_gadm=$(ogrinfo -dialect sqlite -sql 'SELECT distinct (GID_0) as noff FROM ADM_4' "${boundaries_dir}"gadm_410-levels.gpkg|grep 'noff (String) ='|tr -s ' '|sed 's/ noff (String) = //g'| tr "\n" ' ')
  echo "Countries available_in_gadm: ${available_in_gadm}"

  array_available_in_gadm=($(echo ${available_in_gadm}))

  for this_country in "${country_array[@]}"; do

    if [[ " ${array_available_in_gadm[*]} " =~ "${this_country}" ]]; then
#       echo ogrinfo -dialect sqlite -sql 'SELECT count(*) as noff FROM ADM_4 WHERE GID_0="'${this_country}'";' /home/rafd/data/boundaries/gadm_410-levels.gpkg
       noff=$(ogrinfo -dialect sqlite -sql 'SELECT count(*) as noff FROM ADM_4 WHERE GID_0="'${this_country}'";' /home/rafd/data/boundaries/gadm_410-levels.gpkg|grep noff|grep '='|tr -s ' '|sed 's/ noff (Integer) = //g')

       echo ${this_country} ${noff}

       if [ ${noff} -gt 0 -a ${noff} -lt 52000  ]; then
         echo 'creating: '${boundaries_dir}adm${level}/adm${level}_${this_country}'.gpkg'
         ogr2ogr -f GPKG "${boundaries_dir}"adm"${level}"/adm"${level}"_"${this_country}".gpkg -nln adm"${level}"_polygons -dialect sqlite -sql 'SELECT * FROM ADM_'${level}' WHERE GID_0="'${this_country}'" order by ST_X(ST_Centroid(geom));' "$boundaries_dir"gadm_410-levels.gpkg
       fi

       if [ ${noff} -ge 52000 ]; then
         echo 'splitting: '${boundaries_dir}adm${level}/adm${level}_${this_country}'.gpkg'
         ogr2ogr -f GPKG "${boundaries_dir}"adm"${level}"/adm"${level}"_"${this_country}"1.gpkg -nln adm"${level}"_polygons -dialect sqlite -sql 'SELECT * FROM ADM_'${level}' WHERE GID_0="'${this_country}'" order by ST_X(ST_Centroid(geom)) LIMIT 20000;' "$boundaries_dir"gadm_410-levels.gpkg
         ogr2ogr -f GPKG "${boundaries_dir}"adm"${level}"/adm"${level}"_"${this_country}"2.gpkg -nln adm"${level}"_polygons -dialect sqlite -sql 'SELECT * FROM ADM_'${level}' WHERE GID_0="'${this_country}'" order by ST_X(ST_Centroid(geom)) LIMIT 20000 OFFSET 20000;' "$boundaries_dir"gadm_410-levels.gpkg
         ogr2ogr -f GPKG "${boundaries_dir}"adm"${level}"/adm"${level}"_"${this_country}"3.gpkg -nln adm"${level}"_polygons -dialect sqlite -sql 'SELECT * FROM ADM_'${level}' WHERE GID_0="'${this_country}'" order by ST_X(ST_Centroid(geom)) LIMIT 20000 OFFSET 40000;' "$boundaries_dir"gadm_410-levels.gpkg
         ogr2ogr -f GPKG "${boundaries_dir}"adm"${level}"/adm"${level}"_"${this_country}"4.gpkg -nln adm"${level}"_polygons -dialect sqlite -sql 'SELECT * FROM ADM_'${level}' WHERE GID_0="'${this_country}'" order by ST_X(ST_Centroid(geom)) LIMIT 999999999 OFFSET 60000;' "$boundaries_dir"gadm_410-levels.gpkg

       fi

  fi

  done

done

