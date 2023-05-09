#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/drr/'
adm_base_dir="$homedir"'/data/boundaries/'
lst_dir_zips="$data_dir""eviirs_global_lst_zip/"
lst_dir_zips_processed="$lst_dir_zips""processed/"
lst_dir_tifs="$data_dir""eviirs_global_lst_tif/"
drr_heat_csv_base_dir="$data_dir"'heat_outputs/heat_csv/'



gdal_translate -f GTiff -a_srs EPSG:4326 -a_ullr -180 90 180 -90 HDF5:"VNP13C2.A2022335.001.2023013202239.h5"://HDFEOS/GRIDS/NPP_Grid_monthly_VI_CMG/Data_Fields/CMG_0.05_Deg_monthly_NDVI test.tif