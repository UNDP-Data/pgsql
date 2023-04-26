#!/bin/bash

homedir=$(realpath ~)
boundaries_dir="$homedir"'/data/boundaries/'
data_dir="$homedir"'/data/hrea/'
hrea_outputs="$data_dir"'hrea_outputs/'
geojson_dir="$hrea_outputs"'GeoJSON/'
pbf_dir="$hrea_outputs"'pbfs/'


#git clone https://github.com/mapbox/tippecanoe.git
#cd tippecanoe
#make -j
#make install

# from GIS export three gpkgs in EPSG::3857 into "$hrea_outputs":
# hrea_gadm_admin0.gpkg
# hrea_gadm_admin1.gpkg
# hrea_gadm_admin2.gpkg
#
# with the layers corresponding named adm[012]_polygons
# and the relevant attributes (hrea_{2012..2020}, adm0_id, adm0_name, adm1_id, adm1_name, adm2_id, adm2_name)

mkdir -p "${geojson_dir}"
mkdir -p "${pbf_dir}"

#mkdir -p "${pbf_dir}"admin0/
#mkdir -p "${pbf_dir}"admin1/
#mkdir -p "${pbf_dir}"admin2/
#mkdir -p "${pbf_dir}"admin3/
#mkdir -p "${pbf_dir}"admin4/

#create a line-separated GeoJSON
#check the attributes in the gpks are correct
#ogr2ogr -f GeoJSONSeq "${geojson_dir}"adm0_polygons.geojsonl "$hrea_outputs"hrea_gadm_admin0.gpkg
#ogr2ogr -f GeoJSONSeq "${geojson_dir}"adm1_polygons.geojsonl "$hrea_outputs"hrea_gadm_admin1.gpkg
#ogr2ogr -f GeoJSONSeq "${geojson_dir}"adm2_polygons.geojsonl "$hrea_outputs"hrea_gadm_admin2.gpkg
#
#ogr2ogr -f GeoJSONSeq "${geojson_dir}"adm3_polygons.geojsonl "${boundaries_dir}"adm3_minimal_joined_filled_with_adm2.gpkg
#ogr2ogr -f GeoJSONSeq "${geojson_dir}"adm4_polygons.geojsonl "${boundaries_dir}"adm4_minimal_joined_filled_with_adm3.gpkg

function export_via_tippecanoe(){

  adm_level="$1"
  fields_to_include=' '

  for this_lvl in $(seq 0 "${adm_level}"); do
    fields_to_include=${fields_to_include}' --include=adm'${this_lvl}'_id  --include=adm'${this_lvl}'_name  '
  done

  echo 'Processing administrative level '"${adm_level}"' with fields: '"${fields_to_include}"

  tippecanoe  --layer=adm"${adm_level}"_polygons  --maximum-zoom=6 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  \
  --no-tile-size-limit  --no-tile-compression  --force  \
  --output-to-directory="${pbf_dir}"adm"${adm_level}"_polygons/  "${geojson_dir}"adm"${adm_level}"_polygons.geojsonl \
  --include=pop  "${fields_to_include}" \
  --include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  \
  --include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012

  rm -f "${geojson_dir}"adm"${adm_level}"_polygons.geojsonl

}

##adm0
#tippecanoe  --layer=adm0_polygons  --maximum-zoom=6 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  \
#--no-tile-size-limit  --no-tile-compression  --force  \
#--output-to-directory="${pbf_dir}"adm0_polygons/  "${geojson_dir}"adm0_polygons.geojsonl \
#--include=adm0_id  --include=adm0_name  --include=pop  \
#--include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  \
#--include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012
#
##adm1
#tippecanoe  --layer=adm1_polygons  --maximum-zoom=8 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  \
#--no-tile-size-limit  --no-tile-compression  --force  \
#--output-to-directory="${pbf_dir}"adm1_polygons/  "${geojson_dir}"adm1_polygons.geojsonl \
#--include=adm0_id  --include=adm0_name  --include=adm1_id  --include=adm1_name  --include=pop \
#--include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  \
#--include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012
#
##adm2
#tippecanoe  --layer=adm2_polygons  --maximum-zoom=10 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  \
#--no-tile-size-limit  --no-tile-compression  --force  \
#--output-to-directory="${pbf_dir}"adm2_polygons/  "${geojson_dir}"adm2_polygons.geojsonl \
#--include=adm0_id  --include=adm0_name  --include=adm1_id  --include=adm1_name  --include=adm2_id  --include=adm2_name  --include=pop \
#--include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  \
#--include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012
#
##adm3
#tippecanoe  --layer=adm3_polygons  --maximum-zoom=10 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  \
#--no-tile-size-limit  --no-tile-compression  --force  \
#--output-to-directory="${pbf_dir}"adm3_polygons/  "${geojson_dir}"adm3_polygons.geojsonl \
#--include=adm0_id  --include=adm0_name  --include=adm1_id  --include=adm1_name  --include=adm2_id  --include=adm2_name   \
#--include=adm3_id  --include=adm3_name  --include=pop \
#--include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  \
#--include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012
#
##adm4
#tippecanoe  --layer=adm4_polygons  --maximum-zoom=10 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  \
#--no-tile-size-limit  --no-tile-compression  --force  \
#--output-to-directory="${pbf_dir}"adm4_polygons/  "${geojson_dir}"adm4_polygons.geojsonl \
#--include=adm0_id  --include=adm0_name  --include=adm1_id  --include=adm1_name  --include=adm2_id  --include=adm2_name   \
#--include=adm3_id  --include=adm3_name  --include=adm4_id  --include=adm4_name  --include=pop \
#--include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  \
#--include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012
#
#rm -f "${geojson_dir}"adm0_polygons.geojsonl
#rm -f "${geojson_dir}"adm1_polygons.geojsonl
#rm -f "${geojson_dir}"adm2_polygons.geojsonl
#rm -f "${geojson_dir}"adm3_polygons.geojsonl
#rm -f "${geojson_dir}"adm4_polygons.geojsonl

export_via_tippecanoe 0
export_via_tippecanoe 1
export_via_tippecanoe 2
export_via_tippecanoe 3
export_via_tippecanoe 4




# lastly, upload the pbf folders into the Cloud Storage