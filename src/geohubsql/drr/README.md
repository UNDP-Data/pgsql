DRR - HEAT HEALTH RISK INDEX 
====

Suite of scripts to:

1. Create a (csv) table with all data required to compute the heat risk, at several administrative levels. (`*.sh` scripts)
2. Create on the PostgreSQL server the needed functions to serve the corresponding function layer. (`*.sql` scripts)

Input data:

- LST raster maps, one per decadal. 
- VHI raster maps, one per month. 
- Population raster map
- HDI vector map
- Working Age Population
- administrative boundaries adm_{0,1,2}

By-products:

- adm_{0,1,2} vector maps of the temperature in the hottest decadal (for each decadal, the average temperature across the adm feature is computed)
- adm_{0,1,2} vector maps of the number/DOY of the hottest decadal (for each decadal, the average temperature across the adm feature is computed)


Data sources:
====

**VHI** 

The VHI used in calculating the HHR is actually a "time-composite", where each adm1 area has the average VHI[^1] of the month with the hottest Land Surface Temperature. 
The Land Surface Temperature for each adm1 level sa calculated starting from the LST raster[^2]

[^1]: Data source: https://earthexplorer.usgs.gov/ - search for `VIIRS VNP13C2`, filenames like `VNP13C2.A2022001.001.2022046162120.h5`
[^2]: Data source: https://earthexplorer.usgs.gov/ - search for `eVIIRS Global LST`, filenames like `EVGLSTS20230111202301201`


**Population density**

https://geohub.data.undp.org/?operator=and&limit=15&breadcrumbs=Home&queryoperator=and&sortby=name%2Casc&query=population+density#0.84/41.4/0
static map:
https://undpngddlsgeohubdev01.blob.core.windows.net/end-poverty/Population_Density/2020_Population_density_per_squareKm.tif


**HDI vector map**

https://geohub.data.undp.org/?operator=and&limit=15&breadcrumbs=Home&queryoperator=and&sortby=name%2Casc&query=dynamic#0.29/0/0


**Gross National Income per Capita**

From the input data used to calculate the HDI index: table `admin.hdi_input` on the production database server


**Maximum Temperature**

https://earthexplorer.usgs.gov/ - search for `eVIIRS Global LST`, filenames like `EVGLSTS20230111202301201`

One map/tif file per month.


**Working age population**

https://globaldatalab.org/areadata/table/depratio/?levels=4
under indicator, select "% population aged 15-65"


****

Notes:
---

- pentadal := period of five days
- decadal := period of ten days
- DOY := Day Of Year [000...366]
- LST := Land Surface Temperature
- VHI := Vegetation Health Index

To load the output into PostgreSQL, use the provided `ddr_hhr_input_data.csv` csv or the provided `drr_hhr_input_data.sql` sql backup file:
```
psql -U postgres -p 5432 -h {URL} -d geodata < data/drr_hhr_input_data.sql
```
_Version 230517_