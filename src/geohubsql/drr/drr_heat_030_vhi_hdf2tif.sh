#!/bin/bash

# processes USGS' VIIRS VNP13C2 HDF5 files and extracts the Vegetation Health Index stats per adm_{0,1,2}

homedir=$(realpath ~)
data_dir=${homedir}'/data/drr/'
hdf_dir="$data_dir""vhi/VNP13C2/hdf/"
vhi_tif_dir="$data_dir""vhi/VNP13C2/tif/"
drr_vhi_csv_base_dir="$data_dir"'vhi/vhi_outputs/vhi_csv/'
fname_prefix='VNP'

mkdir -p ${vhi_tif_dir}

this_pid="$$"
tmp_file='/dev/shm/vhi_010_zonal_stats_'"$this_pid"
tmp_file1='/dev/shm/vhi_010_zonal_stats_'"$this_pid"'_1'
tmp_file2='/dev/shm/vhi_010_zonal_stats_'"$this_pid"'_2'

mkdir -p ${drr_vhi_csv_base_dir}

#VNP13C2.A2022152.001.2022193130955.h5
#gdal_translate -f GTiff -a_srs EPSG:4326 -a_ullr -180 90 180 -90 HDF5:"VNP13C2.A2022335.001.2023013202239.h5"://HDFEOS/GRIDS/NPP_Grid_monthly_VI_CMG/Data_Fields/CMG_0.05_Deg_monthly_vhi test.tif

function extract_and_convert_from_hdf() {
for filename in "${hdf_dir}"${fname_prefix}*.h5; do
  echo ${filename}
  out_tif=${vhi_tif_dir}$(echo ${filename}|xargs -n1 basename |sed 's/h5$/tif/g')

  gdal_translate -f GTiff -co COMPRESS=DEFLATE -a_srs EPSG:4326 -a_ullr -180 90 180 -90 HDF5:"${filename}"://HDFEOS/GRIDS/NPP_Grid_monthly_VI_CMG/Data_Fields/CMG_0.05_Deg_monthly_vhi ${out_tif}
  #pbzip2 ${filename}

  echo 'Created '${out_tif}
done
}

function run_zonal_stats() {
adm_level="$1"
adm_gpkg="$2"

csv_out_dir=${drr_vhi_csv_base_dir}"adm"${adm_level}"/"

mkdir -p ${csv_out_dir}


for filename in "${vhi_tif_dir}"${fname_prefix}*.tif; do

out_csv=${csv_out_dir}$(echo ${filename}|xargs -n1 basename|sed "s/tif/csv/g")

  if [ ! -e ${out_csv} ]; then
    echo "processing ${filename}"

    #echo VNP13C2.A2022152.001.2022193130955.tif|sed 's/VNP13C2\.A//g'|tr '.-' ' _' |awk '{print substr($1,0,4), substr($1,5,3)}'
    #substr($1,4), substr($1,5,3)
    col_name=$(echo ${filename}|xargs -n1 basename|sed 's/VNP13C2\.A//g'|tr '.-' ' _'|awk '{print substr($1,0,4)"_"substr($1,5,3)}')

    #for some regions "max" yields out-of-scale results
    #time exactextract -r "t:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=max(t)" --fid "GID_${adm_level}"

#    GADM:
#    time exactextract -r "vhi:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=mean(vhi)" --fid "GID_${adm_level}"
#    sed -i 's/^GID_/AAAAA_GID_/g' "${out_csv}"

#    GDL:
    time exactextract -r "vhi:${filename}" -p "${adm_gpkg}" -o "${out_csv}" -s "${col_name}=mean(vhi)" --fid "gdlcode"
    cp "${out_csv}" "${out_csv}"'_copy'
    sed -i 's/^gdlcode/AAAAA_Gdlcode_/g' "${out_csv}"

    echo sorting
    sort -t',' -k 1b,1 "${out_csv}" > ${tmp_file}
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

for filename in "${csv_out_dir}"${fname_prefix}*.csv; do

  echo ${filename}

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

#extract_and_convert_from_hdf

#run_zonal_stats 0 ${homedir}'/data/boundaries/gadm_admin0_fixed_ordered.gpkg'
#run_zonal_stats 1 ${homedir}'/data/boundaries/gadm_admin1_fixed_ordered.gpkg'
#run_zonal_stats 2 ${homedir}'/data/boundaries/gadm_admin2_fixed_ordered.gpkg'


#combine_csvs 0
#combine_csvs 1
#combine_csvs 2

run_zonal_stats 1 ${homedir}'/data/boundaries/gdl_v61.gpkg'


combine_csvs 1