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

hrea_outputs_dir="$data_dir""hrea_outputs/hrea_csv/"
hrea_summaries_dir="$data_dir""hrea_outputs/hrea_summaries/"

this_pid="$$"



#levels_to_extract=(0 1 2 3 4)

levels_to_extract=(3)

for level in "${levels_to_extract[@]}"; do

  all_countries_csv="$hrea_summaries_dir"'output_adm'${level}'.csv'
  echo $all_countries_csv

  echo "Joining admin level ${level} - ${boundaries_dir}adm${level}_minimal.gpkg "

  dbname="/tmp/hrea_adm${level}_${this_pid}.sqlite"

  sqlite3 ${dbname} "create table hrea(adm${level} text, \
  pop real, \
  val_hrea_2012 real, val_hrea_2013 real, val_hrea_2014 real, val_hrea_2015 real, val_hrea_2016 real, val_hrea_2017 real, val_hrea_2018 real, val_hrea_2019 real, val_hrea_2020 real, \
  val_no_hrea_2012 real, val_no_hrea_2013 real, val_no_hrea_2014 real, val_no_hrea_2015 real, val_no_hrea_2016 real, val_no_hrea_2017 real, val_no_hrea_2018 real, val_no_hrea_2019 real, val_no_hrea_2020 real, \
  hrea_2012 real, hrea_2013 real, hrea_2014 real, hrea_2015 real, hrea_2016 real, hrea_2017 real, hrea_2018 real, hrea_2019 real, hrea_2020 real \
  )"

  echo 'Pragma:'
  echo sqlite3 ${dbname} --cmd "'.header on' '.mode column' 'pragma table_info('hrea')'"

#  sqlite3 ${boundaries_dir}adm${level}_minimal.gpkg --cmd '.mode csv' '.import '${all_countries_csv}' hrea'
  sqlite3 ${dbname} --cmd  '.mode csv' '.import '${all_countries_csv}' hrea'

  sqlite3 ${boundaries_dir}adm${level}_minimal.gpkg 'DROP TABLE IF EXISTS hrea'
  sqlite3 ${boundaries_dir}adm${level}_minimal.gpkg 'DROP TABLE IF EXISTS hrea2'
  
  sqlite3 "${dbname}" ".dump hrea" | sqlite3 "${boundaries_dir}adm${level}_minimal.gpkg"
#echo  sqlite3 ${boundaries_dir}adm${level}_minimal.gpkg --cmd '.import '${dbname}' hrea'

  echo ${boundaries_dir}adm${level}_minimal_joined.gpkg

  ogr2ogr -f GPKG ${boundaries_dir}adm${level}_minimal_joined.gpkg ${boundaries_dir}adm${level}_minimal.gpkg -nln adm${level}_polygons -dialect sqlite -sql "SELECT vectors.geom, vectors.GID_0, vectors.COUNTRY, vectors.GID_1, vectors.NAME_1, vectors.GID_2, vectors.NAME_1, vectors.GID_3, vectors.NAME_3, csv.* FROM adm${level}_polygons AS vectors JOIN hrea AS csv ON vectors.GID_${level} = csv.adm${level} "

#  "SELECT vectors.geom, vectors.GID_0, vectors.COUNTRY, vectors.GID_1, vectors.NAME_1, vectors.GID_2, vectors.NAME_1, vectors.GID_3, vectors.NAME_3, csv.* FROM adm${level}_polygons AS vectors JOIN hrea AS csv ON vectors.GID_${level} = csv.adm${level} WHERE vectors.GID_0=\"ZWE\""

done

