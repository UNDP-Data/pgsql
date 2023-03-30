#!/bin/bash


adm0_dir="/home/rafd/Downloads/admin-levels_/gadm_adm2_by_country/"
hrea_dir="/home/rafd/Downloads/admin-levels_/HREA/"
hrea_data_dir=$hrea_dir"hrea_data/"
fb_pop_dir=$hrea_dir"facebook_pop_30m/"
thr_dir=$hrea_dir"hrea_data_thr80p/"


#processing.run("native:splitvectorlayer", {'INPUT':'/home/rafd/Downloads/admin-levels_/gadm_admin2_no_1stw_singlepolies_fix_1000v_sp_fix.gpkg|layername=gadm_admin2_no_1stw_singlepolies_fix_1000v_sp_fix','FIELD':'GID_0','PREFIX_FIELD':True,'FILE_TYPE':0,'OUTPUT':'/home/rafd/Downloads/admin-levels_/gadm_adm2_by_country'})
#qgis_process run native:splitvectorlayer --distance_units=meters --area_units=m2 --ellipsoid=EPSG:7030 --INPUT='/home/rafd/Downloads/admin-levels_/gadm_admin2_no_1stw_singlepolies_fix_1000v_sp_fix.gpkg|layername=gadm_admin2_no_1stw_singlepolies_fix_1000v_sp_fix' --FIELD=GID_0 --PREFIX_FIELD=true --FILE_TYPE=0 --OUTPUT=/home/rafd/Downloads/admin-levels_/gadm_adm2_by_country


