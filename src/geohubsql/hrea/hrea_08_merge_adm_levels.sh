#!/bin/bash

# creates an hrea gpkg which is composed by:
# - proper adm3 Countries where available
# - adm2 Countries where adm3 are not available
homedir=$(realpath ~)
boundaries_dir="$homedir"'/data/boundaries/'
data_dir="$homedir"'/data/hrea/'

adm1_input=${data_dir}hrea_outputs/hrea_gadm_admin1.gpkg
adm2_input=${data_dir}hrea_outputs/hrea_gadm_admin2.gpkg
adm3_input=${boundaries_dir}adm3_minimal_joined.gpkg
adm4_input=${boundaries_dir}adm4_minimal_joined.gpkg

out2_file=${boundaries_dir}hrea_gadm_admin2_filled_with_adm1.gpkg
out3_file=${boundaries_dir}adm3_minimal_joined_filled_with_adm2.gpkg
out4_file=${boundaries_dir}adm4_minimal_joined_filled_with_adm3.gpkg

adm1_filler=${data_dir}hrea_outputs/hrea_gadm_admin1_for2.gpkg
adm2_filler=${data_dir}hrea_outputs/hrea_gadm_admin2_for3.gpkg
adm3_filler=${data_dir}hrea_outputs/hrea_gadm_admin3_for4.gpkg

#ogr2ogr -f GPKG output.gpkg input1.gpkg
#ogr2ogr -update -append output.gpkg input2.gpkg -nln output_layer_name

################################################################
#                                                              #
# # # # # # # # #   ADM 2 filling with ADM 1   # # # # # # # # #
#                                                              #
################################################################
this_level_list=$(ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT DISTINCT adm0_id FROM adm2_polygons' "${adm2_input}"| \
grep 'adm0_id (String)'|awk 'BEGIN{sep="("}{printf "%s@%s@",sep,$(NF);sep=","}END{print ")"}'|tr '@' '"')

echo 'adm2 list: '"${this_level_list}"

#extract from adm1 the Countries missing in adm2:
ogr2ogr -t_srs 'EPSG:4326' -f GPKG -nln adm2_polygons -dialect SQLITE -sql 'SELECT "geom","adm0_id","adm0_name","adm1_id","adm1_name", "hrea_2012","hrea_2013","hrea_2014","hrea_2015","hrea_2016","hrea_2017","hrea_2018","hrea_2019","hrea_2020" FROM adm1_polygons WHERE adm0_id NOT IN '${this_level_list} \
"${adm1_filler}" "${adm1_input}"

extracted_list=$(ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT DISTINCT adm0_id FROM adm2_polygons' "${adm1_filler}"| \
grep 'adm0_id (String)'|awk 'BEGIN{sep="("}{printf "%s@%s@",sep,$(NF);sep=","}END{print ")"}'|tr '@' '"')

echo 'extracted: '"${extracted_list}"

#prepare the recipient file:
ogr2ogr -t_srs 'EPSG:4326' -f GPKG -nln adm2_polygons -dialect SQLITE -sql 'SELECT "geom","adm0_id","adm0_name","adm1_id","adm1_name","adm2_id","adm2_name", "hrea_2012","hrea_2013","hrea_2014","hrea_2015","hrea_2016","hrea_2017","hrea_2018","hrea_2019","hrea_2020" FROM adm2_polygons' \
 "${out2_file}" "${adm2_input}"


#append the adm2 excerpt to the recipient file:
ogr2ogr -t_srs 'EPSG:4326' -f GPKG -update -append -nln adm2_polygons "${out2_file}" "${adm1_filler}"

echo "Created: ${out2_file}"
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm2_polygons' "${adm2_input}"  |grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm2_polygons' "${adm1_filler}" |grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm2_polygons' "${out2_file}"   |grep noff | grep '='

################################################################
#                                                              #
# # # # # # # # #   ADM 3 filling with ADM 2   # # # # # # # # #
#                                                              #
################################################################
this_level_list=$(ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT DISTINCT adm0_id FROM adm3_polygons' "${adm3_input}"| \
grep 'adm0_id (String)'|awk 'BEGIN{sep="("}{printf "%s@%s@",sep,$(NF);sep=","}END{print ")"}'|tr '@' '"')

echo 'adm3 list: '"${this_level_list}"

#extract from adm2 the Countries missing in adm3:
ogr2ogr -t_srs 'EPSG:4326' -f GPKG -nln adm3_polygons -dialect SQLITE -sql 'SELECT "geom","adm0_id","adm0_name","adm1_id","adm1_name","adm2_id","adm2_name", "hrea_2012","hrea_2013","hrea_2014","hrea_2015","hrea_2016","hrea_2017","hrea_2018","hrea_2019","hrea_2020" FROM adm2_polygons WHERE adm0_id NOT IN '${this_level_list} \
"${adm2_filler}" "${out2_file}"

extracted_list=$(ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT DISTINCT adm0_id FROM adm3_polygons' "${adm2_filler}"| \
grep 'adm0_id (String)'|awk 'BEGIN{sep="("}{printf "%s@%s@",sep,$(NF);sep=","}END{print ")"}'|tr '@' '"')

echo 'extracted: '"${extracted_list}"

#prepare the recipient file:
ogr2ogr -t_srs 'EPSG:4326' -f GPKG -nln adm3_polygons -dialect SQLITE -sql 'SELECT "geom","adm0_id","adm0_name","adm1_id","adm1_name","adm2_id","adm2_name","adm3_id","adm3_name", "hrea_2012","hrea_2013","hrea_2014","hrea_2015","hrea_2016","hrea_2017","hrea_2018","hrea_2019","hrea_2020" FROM adm3_polygons' "${out3_file}" "${adm3_input}"

#append the adm2 excerpt to the recipient file:
ogr2ogr -t_srs 'EPSG:4326' -f GPKG -update -append -nln adm3_polygons "${out3_file}" "${adm2_filler}"

echo "Created: ${out3_file}"
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm3_polygons' "${adm3_input}"  | grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm2_polygons' "${out2_file}"   | grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm2_polygons WHERE adm0_id NOT IN '${this_level_list} "${out2_file}" | grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm3_polygons' "${adm2_filler}" | grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm3_polygons' "${out3_file}"   | grep noff | grep '='



################################################################
#                                                              #
# # # # # # # # #   ADM 4 filling with ADM 3   # # # # # # # # #
#                                                              #
################################################################
this_level_list=$(ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT DISTINCT adm0_id FROM adm4_polygons' "${adm4_input}"| \
grep 'adm0_id (String)'|awk 'BEGIN{sep="("}{printf "%s@%s@",sep,$(NF);sep=","}END{print ")"}'|tr '@' '"')

echo 'adm4 list: '"${this_level_list}"

#extract from adm3 the Countries missing in adm4:
ogr2ogr -t_srs 'EPSG:4326' -f GPKG -nln adm4_polygons -dialect SQLITE -sql 'SELECT "geom","adm0_id","adm0_name","adm1_id","adm1_name","adm2_id","adm2_name","adm3_id","adm3_name","hrea_2012","hrea_2013","hrea_2014","hrea_2015","hrea_2016","hrea_2017","hrea_2018","hrea_2019","hrea_2020" FROM adm3_polygons WHERE adm0_id NOT IN '${this_level_list} \
"${adm3_filler}" "${out3_file}"

extracted_list=$(ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT DISTINCT adm0_id FROM adm4_polygons' "${adm3_filler}"| \
grep 'adm0_id (String)'|awk 'BEGIN{sep="("}{printf "%s@%s@",sep,$(NF);sep=","}END{print ")"}'|tr '@' '"')

echo 'extracted: '"${extracted_list}"

#prepare the recipient file:
ogr2ogr -t_srs 'EPSG:4326' -f GPKG -nln adm4_polygons -dialect SQLITE -sql 'SELECT "geom","adm0_id","adm0_name","adm1_id","adm1_name","adm2_id","adm2_name","adm3_id","adm3_name","adm4_id","adm4_name","hrea_2012","hrea_2013","hrea_2014","hrea_2015","hrea_2016","hrea_2017","hrea_2018","hrea_2019","hrea_2020" FROM adm4_polygons' "${out4_file}" "${adm4_input}"

#append the adm3 excerpt to the recipient file:
ogr2ogr -t_srs 'EPSG:4326' -f GPKG -update -append -nln adm4_polygons "${out4_file}" "${adm3_filler}"

echo "Created: ${out4_file}"
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm4_polygons' "${adm4_input}"  | grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm3_polygons' "${out3_file}"   | grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm3_polygons WHERE adm0_id NOT IN '${this_level_list} "${out3_file}" | grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm4_polygons' "${adm3_filler}" | grep noff | grep '='
ogrinfo -geom=NO -dialect SQLITE -sql 'SELECT count(*) as noff FROM adm4_polygons' "${out4_file}"   | grep noff | grep '='