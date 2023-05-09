#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/drr/'
hdf_dir="$data_dir""ndvi/VNP13C2/hdf/"
out_tif_dir="$data_dir""ndvi/VNP13C2/tif/"

mkdir -p ${out_tif_dir}

#VNP13C2.A2022152.001.2022193130955.h5
#gdal_translate -f GTiff -a_srs EPSG:4326 -a_ullr -180 90 180 -90 HDF5:"VNP13C2.A2022335.001.2023013202239.h5"://HDFEOS/GRIDS/NPP_Grid_monthly_VI_CMG/Data_Fields/CMG_0.05_Deg_monthly_NDVI test.tif

function extract_and_convert_from_hdf() {
for filename in "${hdf_dir}"VNP*.h5; do
  echo ${filename}
  out_tif=${out_tif_dir}$(echo ${filename}|xargs -n1 basename |sed 's/h5$/tif/g')

  gdal_translate -f GTiff -co COMPRESS=DEFLATE -a_srs EPSG:4326 -a_ullr -180 90 180 -90 HDF5:"${filename}"://HDFEOS/GRIDS/NPP_Grid_monthly_VI_CMG/Data_Fields/CMG_0.05_Deg_monthly_NDVI ${out_tif}
  #pbzip2 ${filename}

  echo 'Created '${out_tif}
done
}

extract_and_convert_from_hdf


