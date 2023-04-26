Data pipe for the GeoHub Electricity Access Dashboard
===

This suite of scripts creates csv tables which summarises the percentage of population with access to electricity at different administrative levels (admin0/admin1/admin2, extensible to admin3).

The input files are:

- gpkgs of the administrative boundaries of each Country (for performance reasons: as single parts, geometrically subdivided so that each feature has a maximum of 1000 vertexes. An example can be found in the `example_data` folder)
- global population raster, where the value of each pixel represents the estimated number of people living in the pixel's area (derived from data provided by Facebook/Meta)
- global HREA rasters, showing the probability of electrification of each pixel with a range [0..1]

The scripts are the following, and need to be run in the proposed order:

- `hrea_00_azure_lightscore_downloader.py`
  - (optional) downloads to a local folder/container the `*_set_lightscore_sy_20??_hrea` series of file
- `hrea_01_calculate_thresholds.sh`
  - computes the pixed-aligned threshold, per-year Country files into `data/hrea/hrea_data_thr80p/20??/hrea_20??_???_m80.tif` these are two complementary series of binary mask:
    - the `hrea` series represents the pixels which can be considered as fully electrified (i.e. with an electrification probability >= 80%) 
    - the `no_hrea` series represents the pixels which can be considered as non-electrified (i.e. with an electrification probability < 80%) 
- `hrea_02_zonal_stats.sh`
  - runs the zonal stats on each country, and outputs the respective csv files into: `data/hrea/hrea_outputs/hrea_csv/hrea_???.csv`
  - the zonal stats are run simultaneously for all currently available years (2012-2020) against the `admin 2` level features
  - zonal stats include:
    - the population count (sum of the facebook population within each administrative polygon)
    - the population count weighted/masked by each year's `hrea` (i.e. how many people within each administrative polygon had access to electricity in the specified year)
    - the population count weighted/masked by each year's `no_hrea` (i.e. how many people within each administrative polygon had access to electricity in the specified year)
- `hrea_03_combine_csvs.sh`
  - this simply concatenates all Countries' csvs into one file `data/hrea/hrea_outputs/hrea_per_country/all_countries_sp.csv`
- `hrea_04_summarise_csvs.py`
  - processes `data/hrea/hrea_outputs/hrea_per_country/all_countries_sp.csv` summarising the columns for each administrative level, and calculating the respective percentage of population with access to electricity, per year.
  - outputs are written in the `data/hrea/hrea_outputs/hrea_summaries` directory.
- `hrea_05_create_pbfs.sh`
  - a post-production helper to convert joined adm[012] gpkgs (see note below) into GeoJson and then into a series of pbf 
  - to be backwards compatible with the HREA dashbord, the pbf are written as static files into a hierarchical folder structure, which replicates the ZXY http protocol commonly used to retrieve vector tiles.
  - after the final human check, the output pbf folders shall be uploaded to the Blob Container pointed to by the HREA dashboard interface (currently this means the `admin` container, not the `hrea` one)


```
# example workflow:
> time bash hrea_00_azure_lightscore_downloader.py
> time bash hrea_01_calculate_thresholds.sh
> time bash hrea_02_zonal_stats.sh
> time bash hrea_03_combine_csvs.sh
> time pipenv run python3 hrea_04_summarise_csvs.py
> time bash hrea_05_create_pbfs.sh
```

exacetextract bug workaround
---

Since exacetextract showed some unexpected behaviour while weighting (large?) maps, there are also two variants, which pre-compute the weighted hrea maps, and perform zonal stats on those instead of doing the weighted zonal stats in exactextract.
Namely:
- `hrea_01a_calculate_thresholds.sh`
  - creates weighted hrea maps in ~/data/hrea/hrea_weighted/
- `hrea_02a_zonal_stats.sh`
  - computes zonal stats on the weighted hrea maps, hence only using `sum` instead of `weighted_sum` functions in exactextract.

Once exactextract's bug is fixed, these variants will be considered obsolete.

```
# example workflow:
> time bash hrea_00_azure_lightscore_downloader.py
> time bash hrea_01a_calculate_thresholds.sh
> time bash hrea_02a_zonal_stats.sh
> time bash hrea_03_combine_csvs.sh
> time pipenv run python3 hrea_04_summarise_csvs.py
> time bash hrea_05_create_pbfs.sh
```



Notes:
---

- Some Countries have wrongly formatted columns, these will not appear in the final outputs. Correct them in the original dataset.
  - for example, the original gpkg of Ghana had a different format for the feature labels (`GHA1.1` instead of `GHA.1.1`)


- The conversion sequence from `.gpkg` to `.pbf` can be outlined as follows:
  - join adm0 layer with `example_data/output_adm0.csv` using `adm0` as join field
  - add the `pop` and `hrea_2012`..`hrea_2020` fields
  - make sure the layer name is the same as the published one (`adm0_polygons`, `adm1_polygons`, etc.)
  - export into GeoJSON (newline delimited), either from (Q)GIS or via ogr2ogr 
  - run tippecanoe as suggested in `hrea_05_create_pbfs.sh`
  - check the files are properly working, for example using a Vector Tile layer with an URL like: `file:///home/youruser/UNDP_NY/admin-levels_/HREA/hrea_outputs/pbfs/adm0_polygons/{z}/{x}/{y}.pbf`
  - upload the created directories into the blob container/cloud

Performance notes:
---

Countries with very large extensions / very high number of features can be split up to decrease memory usage.
In that case, the splitting shall create geographically compact gpkg files, so that exactextract can load in memory only the relevant part of the raster(s) (and it does so automatically, no need to split the rasters too)
In `hrea_02_extract_from_gadm.sh` this is performed with:

`'SELECT * FROM ADM_'${level}' WHERE GID_0="'${this_country}'" order by ST_X(ST_Centroid(geom)) LIMIT 20000;'`

Processing the whole Indonesia @adm4 would require more than 64 GB of RAM, while splitting the features into 4 slices (by centroid.x) requires about 4Gb for each of the exactextract instances.
