#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/drr/'
adm_base_dir="$homedir"'/data/boundaries/'

drr_others_csv_base_dir="$data_dir"'others/others_outputs/others_csv/'

this_pid="$$"

tmp_file='/dev/shm/others_020_combined_'"$this_pid".csv
tmp_file1='/dev/shm/others_020_combined_'"$this_pid"_1.csv
tmp_file2='/dev/shm/others_020_combined_'"$this_pid"_2.csv

mkdir -p ${drr_others_csv_base_dir}

#extract the relevant "TEMP"erature tifs from the zip
echo dir: ${data_dir}

function run_zonal_stats() {
adm_level="$1"
adm_gpkg="$2"
tif_file="$3"
col_name="$4"

csv_out_dir=${drr_others_csv_base_dir}"adm"${adm_level}"/"
mkdir -p ${csv_out_dir}

filename=${tif_file}

out_csv=${csv_out_dir}$(echo ${filename}|xargs -n1 basename|sed 's/_defl//g'|sed "s/tif/csv/g")

  if [ ! -e ${out_csv} ]; then
    echo "processing ${filename}"

    echo time exactextract -r "t:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=mean(t)" --fid "GID_${adm_level}"
#    GADM
#    time exactextract -r "t:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=mean(t)" --fid "GID_${adm_level}"
#    sed -i 's/^GID_/AAAAA_GID_/g' "${out_csv}"

#    GDL:
    export GDAL_CACHEMAX=10000;
    time exactextract -r "t:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=mean(t)" --fid "gdlcode"

    sed -i 's/^gdlcode/AAAAA_Gdlcode_/g' "${out_csv}"

    echo sorting
    sort -t',' -k 1b,1 "${out_csv}" > ${tmp_file}
    mv ${tmp_file} ${out_csv}
    echo "created: ${out_csv}"
    echo
  fi

}

function combine_csvs() {
adm_level="$1"
csv_out_dir=${drr_others_csv_base_dir}"adm"${adm_level}"/"
out_file=${csv_out_dir}'adm'${adm_level}'_combined.csv'

mkdir -p ${csv_out_dir}
file_cnt=0

for filename in "${csv_out_dir}"*.csv; do

  echo ${filename}

  if [ ${filename} == ${out_file} ]; then
    continue
  fi

  if [ ${file_cnt} -eq 0 ]; then
    sort -t','  -k 1b,1 ${filename} > ${tmp_file}
    file_cnt=1
  else
    sort -t','  -k 1b,1 ${filename} > ${tmp_file2}
    join -a 1 -t',' ${tmp_file} ${tmp_file2} > ${tmp_file1}
    mv ${tmp_file1} ${tmp_file}
    rm -f ${tmp_file2}
  fi

  #sort and round all columns from the second onwards, leaving tre header row as it is (the header row starts with `AAAAA_GID`)
  sort -t','  -k 1b,1 ${tmp_file} |tr ',' ' '|awk '{if($1 ~ /AAAAA_G/){print $0}else{ printf $1; for (i = 2; i <= NF; i++){printf " %.2f",$i}; printf "\n"}}' > ${out_file}

done

echo 'wrote: '${out_file}
wc -l ${out_file}

}

#extract_and_deflate_tifs
#run_zonal_stats adm1 ${homedir}'/data/boundaries/gadm_admin1_no_1st_world_4326.gpkg'

#run_zonal_stats 0 ${homedir}'/data/boundaries/gadm_admin0_fixed_ordered_3857.gpkg' ${data_dir}'log_gross_national_income/Log_Gross_National_Income_per_capita_Females_defl.tif' 'LGNI_f'
#run_zonal_stats 0 ${homedir}'/data/boundaries/gadm_admin0_fixed_ordered_3857.gpkg' ${data_dir}'log_gross_national_income/Log_Gross_National_Income_per_capita_Males_defl.tif' 'LGNI_m'
#run_zonal_stats 0 ${homedir}'/data/boundaries/gadm_admin0_fixed_ordered_3857.gpkg' ${data_dir}'relative_wealth_index/Relative_Wealth_Index.tif' 'RWI'
#
#run_zonal_stats 1 ${homedir}'/data/boundaries/gadm_admin1_fixed_ordered_3857.gpkg' ${data_dir}'log_gross_national_income/Log_Gross_National_Income_per_capita_Females_defl.tif' 'LGNI_f'
#run_zonal_stats 1 ${homedir}'/data/boundaries/gadm_admin1_fixed_ordered_3857.gpkg' ${data_dir}'log_gross_national_income/Log_Gross_National_Income_per_capita_Males_defl.tif' 'LGNI_m'
#run_zonal_stats 1 ${homedir}'/data/boundaries/gadm_admin1_fixed_ordered_3857.gpkg' ${data_dir}'relative_wealth_index/Relative_Wealth_Index.tif' 'RWI'
#
#run_zonal_stats 2 ${homedir}'/data/boundaries/gadm_admin2_fixed_ordered_3857.gpkg' ${data_dir}'log_gross_national_income/Log_Gross_National_Income_per_capita_Females_defl.tif' 'LGNI_f'
#run_zonal_stats 2 ${homedir}'/data/boundaries/gadm_admin2_fixed_ordered_3857.gpkg' ${data_dir}'log_gross_national_income/Log_Gross_National_Income_per_capita_Males_defl.tif' 'LGNI_m'
#run_zonal_stats 2 ${homedir}'/data/boundaries/gadm_admin2_fixed_ordered_3857.gpkg' ${data_dir}'relative_wealth_index/Relative_Wealth_Index.tif' 'RWI'
#
#run_zonal_stats 0 ${homedir}'/data/boundaries/gadm_admin0_fixed_ordered_3857.gpkg' ${data_dir}'population_density/2020_Population_density_per_squareKm.tif' 'pop_dens'
#run_zonal_stats 1 ${homedir}'/data/boundaries/gadm_admin1_fixed_ordered_3857.gpkg' ${data_dir}'population_density/2020_Population_density_per_squareKm.tif' 'pop_dens'
#run_zonal_stats 2 ${homedir}'/data/boundaries/gadm_admin2_fixed_ordered_3857.gpkg' ${data_dir}'population_density/2020_Population_density_per_squareKm.tif' 'pop_dens'
#
#combine_csvs 0
#combine_csvs 1
#combine_csvs 2


run_zonal_stats 1 ${homedir}'/data/boundaries/gdl_v61_3857.gpkg' ${data_dir}'log_gross_national_income/Log_Gross_National_Income_per_capita_Females_defl.tif' 'LGNI_f'
run_zonal_stats 1 ${homedir}'/data/boundaries/gdl_v61_3857.gpkg' ${data_dir}'log_gross_national_income/Log_Gross_National_Income_per_capita_Males_defl.tif' 'LGNI_m'

run_zonal_stats 1 ${homedir}'/data/boundaries/gdl_v61_3857.gpkg' ${data_dir}'relative_wealth_index/Relative_Wealth_Index.tif' 'RWI'

run_zonal_stats 1 ${homedir}'/data/boundaries/gdl_v61_3857.gpkg' ${data_dir}'population_density/2020_Population_density_per_squareKm.tif' 'pop_dens'

combine_csvs 1
