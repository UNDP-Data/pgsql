#!/bin/bash

#git clone https://github.com/mapbox/tippecanoe.git
#cd tippecanoe
#make -j
#make install

#create a line-separated GeoJSON:

mkdir -p ~/Downloads/admin-levels_/HREA/hrea_outputs/pbfs/admin0/
mkdir -p ~/Downloads/admin-levels_/HREA/hrea_outputs/pbfs/admin1/
mkdir -p ~/Downloads/admin-levels_/HREA/hrea_outputs/pbfs/admin2/

#check the attributes in the gpks are correct
ogr2ogr -f GeoJSONSeq ~/admin-levels_/HREA/hrea_outputs/GeoJSON/adm0_polygons.geojson ~/Downloads/admin-levels_/HREA/hrea_outputs/hrea_gadm_admin0.gpkg
ogr2ogr -f GeoJSONSeq ~/admin-levels_/HREA/hrea_outputs/GeoJSON/adm1_polygons.geojson ~/Downloads/admin-levels_/HREA/hrea_outputs/hrea_gadm_admin1.gpkg
ogr2ogr -f GeoJSONSeq ~/admin-levels_/HREA/hrea_outputs/GeoJSON/adm2_polygons.geojson ~/Downloads/admin-levels_/HREA/hrea_outputs/hrea_gadm_admin2.gpkg


tippecanoe  --layer=adm0_polygons  --maximum-zoom=10 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  --no-tile-size-limit  --no-tile-compression  --force  --output-to-directory=/home/rafd/Downloads/admin-levels_/HREA/hrea_outputs/pbfs/adm0_polygons/  /home/rafd/Downloads/admin-levels_/HREA/hrea_outputs/GeoJSON/adm0_polygons.geojsonl.json --include=adm0_id  --include=adm0_name  --include=adm0_id  --include=adm0_name  --include=pop  --include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  --include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012

tippecanoe  --layer=adm1_polygons  --maximum-zoom=10 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  --no-tile-size-limit  --no-tile-compression  --force  --output-to-directory=/home/rafd/Downloads/admin-levels_/HREA/hrea_outputs/pbfs/adm1_polygons/  /home/rafd/Downloads/admin-levels_/HREA/hrea_outputs/GeoJSON/adm1_polygons.geojsonl.json --include=adm1_id  --include=adm1_name  --include=adm1_id  --include=adm1_name  --include=pop  --include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  --include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012

tippecanoe  --layer=adm2_polygons  --maximum-zoom=10 --simplify-only-low-zooms  --detect-shared-borders  --read-parallel  --no-tile-size-limit  --no-tile-compression  --force  --output-to-directory=/home/rafd/Downloads/admin-levels_/HREA/hrea_outputs/pbfs/adm2_polygons/  /home/rafd/Downloads/admin-levels_/HREA/hrea_outputs/GeoJSON/adm2_polygons.geojsonl.json --include=adm2_id  --include=adm2_name  --include=adm2_id  --include=adm2_name  --include=pop  --include=hrea_2020  --include=hrea_2019  --include=hrea_2018  --include=hrea_2017  --include=hrea_2016  --include=hrea_2015  --include=hrea_2014  --include=hrea_2013  --include=hrea_2012

