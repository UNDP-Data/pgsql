#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/drr/'
adm_base_dir="$homedir"'/data/boundaries/'
lst_dir_zips="$data_dir""eviirs_global_lst_zip/"
lst_dir_zips_processed="$lst_dir_zips""processed/"
lst_dir_tifs="$data_dir""eviirs_global_lst_tif/"
drr_heat_csv_base_dir="$data_dir"'heat_outputs/heat_csv/'

this_pid="$$"
tmp_file='/dev/shm/heat_010_zonal_stats_'"$this_pid"
mkdir -p ${lst_dir_tifs}
mkdir -p ${drr_heat_csv_base_dir}
mkdir -p ${lst_dir_zips_processed}

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
  mv  ${filename} ${lst_dir_zips_processed}
done
}

function run_zonal_stats() {
adm_level="$1"
adm_gpkg="$2"

csv_out_dir=${drr_heat_csv_base_dir}"adm"${adm_level}"/"
mkdir -p ${csv_out_dir}


for filename in "${lst_dir_tifs}"*.tif; do

out_csv=${csv_out_dir}$(echo ${filename}|xargs -n1 basename|sed 's/_defl//g'|sed "s/tif/csv/g")

  if [ ! -e ${out_csv} ]; then
    echo "processing ${filename}"
    #LS_eVSH_TEMP.2023.021-031.1KM.LST_TEMP.001.2023063235103_defl.tif
    col_name=$(echo ${filename}|xargs -n1 basename|tr '.-' ' _'|awk '{print $2"_"$3}')

    #for some regions "max" yields out-of-scale results
    #time exactextract -r "t:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=max(t)" --fid "GID_${adm_level}"

    time exactextract -r "t:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=mean(t)" --fid "GID_${adm_level}"
    sed -i 's/^GID_/AAAAA_GID_/g' "${out_csv}"
    echo sorting
    sort -k 1b,1 "${out_csv}" > ${tmp_file}
    mv ${tmp_file} ${out_csv}
    echo "created: ${out_csv} with col_name ${col_name}"
    echo
  fi
  #test 1 file:
  #exit
done
}

#extract_and_deflate_tifs
#run_zonal_stats adm1 '/home/rafd/data/boundaries/gadm_admin1_no_1st_world_4326.gpkg'

run_zonal_stats 0 '/home/rafd/data/boundaries/gadm_admin0_fixed_ordered.gpkg'
#run_zonal_stats 1 '/home/rafd/data/boundaries/gadm_admin1_fixed_ordered.gpkg'
#run_zonal_stats 2 '/home/rafd/data/boundaries/gadm_admin2_fixed_ordered.gpkg'