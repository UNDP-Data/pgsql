HREA / ML
===

This suite of scripts creates csv tables which summarises the percentage of population with access to electricity at different administrative levels (admin0/admin1/admin2, extensible to admin3).

The input files are:

- gpkgs of the administrative boundaries of each Country (for performance reasons: as single parts, geometrically subdivided so that each feature has a maximum of 1000 vertexes. An example can be found in the `example_data` folder)
- global facebook population raster, where the value of each pixel represents the estimated number of people living in the pixel's area 
- global HREA rasters, showing the probability of electrification of each pixel with a range [0..1]

The scripts are the following, and need to be run in the proposed order:

- `hrea_00_prepare_fb_pop.sh` 
  - extracts the extents of each Country from the respective gpkg, writing `extents.csv` 
  - subdivides the global facabook population file into country-level data, creating the pixed-aligned files: `HREA/facebook_pop_30m/???_pop_3857.tif`
- `hrea_01_process_base_files.sh`
  - extracts from the hrea/ml global geotiffs the pixed-aligned, per-year Country files into `HREA/hrea_data/by_year/20??/hrea_20??_???.tif`
  - computes the threshold pixed-aligned, per-year Country files into `HREA/hrea_data_thr80p/20??/hrea_20??_???_m80.tif` which are binary mask representing the pixels which can be considered as fully electrified (i.e. with an electrification probability > 80%)
- `hrea_02_extract.sh`
  - runs the zonal stats on each country, and outputs the respective csv files into: `HREA/hrea_data/hrea_csv/hrea_???.csv`
  - the zonal stats are run simultaneously for all currenlty availabe years (2012-2020)
  - zonal stats include:
    - the population count (sum of the facebook population within each administrative polygon)
    - the population count weighted by each year's threshold electrification (i.e. how many people within each administrative polygon had access to electricity in the specified year)
- `hrea_03_combine_csvs.sh`
  - this simply concatenates all Countries' csvs into one file `/HREA/hrea_outputs/all_countries_sp.csv`
- `hrea_04_summarise_csvs.py`
  - processes `/HREA/hrea_outputs/all_countries_sp.csv` summarising the columns for each administrative level, and calculating the respective percentage of population with access to electricity, per year.



```
# example workflow:
>bash hrea_00_prepare_fb_pop.sh
>bash hrea_01_process_base_files.sh
>bash hrea_02_extract.sh
>bash hrea_03_combine_csvs.sh
>pipenv run python3 hrea_04_summarise_csvs.py
```

Notes:

- some Countries have wrongly formatted columns, these will not appear in the final outputs. Correct them in the original dataset.
  - for example, the original gpkg of Ghana had a different format for the feature labels (`GHA1.1` instead of `GHA.1.1`)

