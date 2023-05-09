#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/drr/'
adm_base_dir="$homedir"'/data/boundaries/'
vhi_tif_dir="$data_dir""ndvi/VNP13C2/tif/"
drr_vhi_csv_base_dir="$data_dir"'vhi_outputs/vhi_csv/'

this_pid="$$"
tmp_file='/dev/shm/vhi_010_zonal_stats_'"$this_pid"
mkdir -p ${drr_vhi_csv_base_dir}

function run_zonal_stats() {
adm_level="$1"
adm_gpkg="$2"

csv_out_dir=${drr_vhi_csv_base_dir}"adm"${adm_level}"/"
mkdir -p ${csv_out_dir}


for filename in "${vhi_tif_dir}"*.tif; do

out_csv=${csv_out_dir}$(echo ${filename}|xargs -n1 basename|sed "s/tif/csv/g")

  if [ ! -e ${out_csv} ]; then
    echo "processing ${filename}"

    #echo VNP13C2.A2022152.001.2022193130955.tif|sed 's/VNP13C2\.A//g'|tr '.-' ' _' |awk '{print substr($1,0,4), substr($1,5,3)}'
    #substr($1,4), substr($1,5,3)
    col_name=$(echo ${filename}|xargs -n1 basename|sed 's/VNP13C2\.A//g'|tr '.-' ' _'|awk '{print substr($1,0,4)"_"substr($1,5,3)}')

    #for some regions "max" yields out-of-scale results
    #time exactextract -r "t:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=max(t)" --fid "GID_${adm_level}"

    time exactextract -r "vhi:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=mean(vhi)" --fid "GID_${adm_level}"
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

function combine_csvs() {
adm_level="$1"
csv_out_dir=${drr_vhi_csv_base_dir}"adm"${adm_level}"/"
out_file=${csv_out_dir}'adm'${adm_level}'_combined.csv'

mkdir -p ${csv_out_dir}
file_cnt=0

for filename in "${csv_out_dir}"*.csv; do

  echo ${filename}

  if [ ${file_cnt} -eq 0 ]; then
    cp ${filename} ${tmp_file}
    file_cnt=1
  else
    join -a 1 -t',' ${tmp_file} ${filename} > ${tmp_file1}
    mv ${tmp_file1} ${tmp_file}
  fi

  sort ${tmp_file} > ${out_file}

done

echo 'wrote: '${out_file}
wc -l ${out_file}

}

run_zonal_stats 0 '/home/rafd/data/boundaries/gadm_admin0_fixed_ordered.gpkg'
#run_zonal_stats 1 '/home/rafd/data/boundaries/gadm_admin1_fixed_ordered.gpkg'
#run_zonal_stats 2 '/home/rafd/data/boundaries/gadm_admin2_fixed_ordered.gpkg'


combine_csvs 0
#combine_csvs 1
#combine_csvs 2