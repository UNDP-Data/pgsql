#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/drr/'
adm_base_dir="$homedir"'/data/boundaries/'
lst_dir_zips="$data_dir""eviirs_global_lst_zip/"
lst_dir_tifs="$data_dir""eviirs_global_lst_tif/"
drr_heat_csv_base_dir="$data_dir"'heat_outputs/heat_csv/'

adm_gpkg='/home/rafd/data/boundaries/gadm_admin1_no_1st_world_4326.gpkg'


this_pid="$$"
tmp_file='/dev/shm/heat_010_zonal_stats_'"$this_pid"
mkdir -p ${lst_dir_tifs}
mkdir -p ${drr_heat_csv_base_dir}

#extract the relevant "TEMP"erature tifs from the zip
echo dir: ${data_dir}


function extract_and_deflate_tifs() {
for filename in "${lst_dir_zips}"*.zip; do
  echo ${filename}
  lst_temp_file=$(unzip -l ${filename}|grep 'LST_TEMP'|grep "tif$"|awk '{print $(NF)}')
  deflated=$(echo ${lst_temp_file} |sed 's/\.tif/_defl\.tif/g')
  unzip ${filename} ${lst_temp_file} -d ${lst_dir_tifs}
  echo ${deflated}
  gdal_translate -of GTiff -co 'NUM_THREADS=8' -co 'COMPRESS=DEFLATE' ${lst_dir_tifs}${lst_temp_file} ${lst_dir_tifs}${deflated}
  rm -f ${lst_dir_tifs}${lst_temp_file}
done
}

function run_zonal_stats() {
for filename in "${lst_dir_tifs}"*.tif; do
  echo "processing ${filename}"
  out_csv=${drr_heat_csv_base_dir}$(echo ${filename}|xargs -n1 basename|sed 's/_defl//g'|sed 's/tif/csv/g')
  #LS_eVSH_TEMP.2023.021-031.1KM.LST_TEMP.001.2023063235103_defl.tif
  col_name=$(echo ${filename}|xargs -n1 basename|tr '.-' ' _'|awk '{print $2"_"$3}')
  time exactextract -r "t:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=max(t)" --fid "GID_1"
  echo "created: ${out_csv} with col_name ${col_name}"
done
}

#extract_and_deflate_tifs
run_zonal_stats