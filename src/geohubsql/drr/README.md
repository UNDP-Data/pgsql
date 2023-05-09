DRR HEAT RISK 
====

Creates a (csv) table with all data required to compute the heat risk, at several administrative levels.

Input data:

- LST raster maps, one per decadal
- VHI raster maps, one per month
- population raster map
- HDI vector map
- ...
- administrative boundaries adm_{0,1,2}

By-products:

- adm_{0,1,2} vector maps of the temperature in the hottest decadal (for each decadal, the average temperature across the adm feature is computed)
- adm_{0,1,2} vector maps of the number/DOY of the hottest decadal (for each decadal, the average temperature across the adm feature is computed)

Notes:
---

- pentadal := period of five days
- decadal := period of ten days
- DOY := Day Of Year [000...366]
- LST := Land Surface Temperature
- VHI := Vegetation Health Index

_Version 230509_