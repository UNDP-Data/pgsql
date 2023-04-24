#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/hrea/'
hrea_outputs="$data_dir"'hrea_outputs/'


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

mkdir -p "$hrea_outputs"GeoJSON/
mkdir -p "$hrea_outputs"pbfs/

mkdir -p "$hrea_outputs"pbfs/admin0/
mkdir -p "$hrea_outputs"pbfs/admin1/
mkdir -p "$hrea_outputs"pbfs/admin2/

#create a line-separated GeoJSON
#check the attributes in the gpks are correct
ogr2ogr -f GeoJSONSeq "$hrea_outputs"GeoJSON/adm0_polygons.geojsonl "$hrea_outputs"hrea_gadm_admin0.gpkg
ogr2ogr -f GeoJSONSeq "$hrea_outputs"GeoJSON/adm1_polygons.geojsonl "$hrea_outputs"hrea_gadm_admin1.gpkg
ogr2ogr -f GeoJSONSeq "$hrea_outputs"GeoJSON/adm2_polygons.geojsonl "$hrea_outputs"hrea_gadm_admin2.gpkg


tippecanoe  --layer=adm0_polygons  --maximum-zoom=6 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  \
--no-tile-size-limit  --no-tile-compression  --force  \
--output-to-directory="$hrea_outputs"pbfs/adm0_polygons/  "$hrea_outputs"GeoJSON/adm0_polygons.geojsonl \
--include=adm0_id  --include=adm0_name  --include=pop  \
--include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  \
--include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012

tippecanoe  --layer=adm1_polygons  --maximum-zoom=8 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  \
--no-tile-size-limit  --no-tile-compression  --force  \
--output-to-directory="$hrea_outputs"pbfs/adm1_polygons/  "$hrea_outputs"GeoJSON/adm1_polygons.geojsonl \
--include=adm0_id  --include=adm0_name  --include=adm1_id  --include=adm1_name  --include=pop \
--include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  \
--include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012

tippecanoe  --layer=adm2_polygons  --maximum-zoom=10 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  \
--no-tile-size-limit  --no-tile-compression  --force  \
--output-to-directory="$hrea_outputs"pbfs/adm2_polygons/  "$hrea_outputs"GeoJSON/adm2_polygons.geojsonl \
--include=adm0_id  --include=adm0_name  --include=adm1_id  --include=adm1_name  --include=adm2_id  --include=adm2_name  --include=pop \
--include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  \
--include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012


rm -f "$hrea_outputs"GeoJSON/adm0_polygons.geojsonl
rm -f "$hrea_outputs"GeoJSON/adm1_polygons.geojsonl
rm -f "$hrea_outputs"GeoJSON/adm2_polygons.geojsonl

# lastly, upload the pbf folders into the Cloud Storage