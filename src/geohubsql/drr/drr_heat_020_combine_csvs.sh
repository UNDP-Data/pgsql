#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/drr/'
adm_base_dir="$homedir"'/data/boundaries/'
lst_dir_zips="$data_dir""eviirs_global_lst_zip/"
lst_dir_zips_processed="$lst_dir_zips""processed/"
lst_dir_tifs="$data_dir""eviirs_global_lst_tif/"
drr_heat_csv_base_dir="$data_dir"'heat_outputs/heat_csv/'

this_pid="$$"
tmp_file='/dev/shm/heat_020_combined_'"$this_pid".csv
tmp_file1='/dev/shm/heat_020_combined_'"$this_pid"_1.csv

#join -t',' LS_eVSH_TEMP.2022.001-010.1KM.LST_TEMP.001.2023051171153.csv LS_eVSH_TEMP.2022.011-020.1KM.LST_TEMP.001.2023052230447.csv

function combine_csvs() {
adm_level="$1"
csv_out_dir=${drr_heat_csv_base_dir}"adm"${adm_level}"/"
out_file=${csv_out_dir}'adm'${adm_level}'_combined.csv'

mkdir -p ${csv_out_dir}
file_cnt=0

for filename in "${csv_out_dir}"'LS'*.csv; do

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

combine_csvs 1
combine_csvs 2