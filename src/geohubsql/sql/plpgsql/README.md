This directory contains PL/PgSQL and PostgreSQL functions meant to be deployed 
onto a server or cloud infrastructure underpinning an instance of [UNDP's GeoHub](https://undpgeohub.org/).
Currently, those scripts mainly address the management of Vector Data. 
Specifically, some functions are those required to generate on-the-fly and dynamic tables and tables
which are subsequently served as Vector Tiles by [pg_tileServ](https://github.com/CrunchyData/pg_tileserv) of [martin](https://github.com/maplibre/martin) to the end user browser through GeoHub. 

# Rationale


There are three series of scripts:

1. generic scripts and functions to be used while pre-processing incoming data
2. generic ancillary and utility functions
3. vector tile generating functions

## Vector tile generating functions


These functions create on-the-fly, geometry-based tables which are then processed by a specialized PostGIS function set to deliver vector tile objects as MVT ([Mapbox Vector Tile](https://docs.mapbox.com/data/tilesets/guides/vector-tiles-standards/)).

These functions are invoked, with optional parameters, by vector tile servers like pg_tileServ or martin, which upon retrieval of the MVT take care of delivering them to the end user's browser or GIS app through the [protobuf format](https://developers.google.com/protocol-buffers) over http.
The  files received by the enduser are hence `.pbf` files.

# Notes


- While conceptually any [SRID](https://en.wikipedia.org/wiki/Spatial_reference_system) is supported both as an input and as an output, MVT files are typically produced in EPSG::3857 (WGS 84 / Pseudo-Mercator), which is the _de-facto_ standard for web mapping applications. In order to avoid unnecessary on-the-fly reprojections every time a function is invoked, it is recommended to convert the input/base vectors into said SRID. The `geom_optimizer.sql` takes care of that.   
- As the name hopefully suggests, `geom_optimizer.sql` also provides other optimizations which widely enhance the performances of functions which process vector tiles. In particular:
  - it creates a GIST-based index on the first `geom` column
  - it "physically" re-writes the file in a geom-ordered sequence
  - it creates an additional and optional standard index for a column passed as an argument to enhance future `JOIN` operations and `WHERE` filters. It is recommended to create said index (and possibly others, as well) for all columns which are used for `JOIN`s and `WHERE`s.
- MVT-generating functions are optimized for pg_tileServ, however, a convenience wrapper for martin (`martin.sql`) is also provided, and can be invoked as the pg_tileServ function, with the additional argument `function_name`.
- in order to use pg_tileServe's internal map viewer, the first layer needs to be named `default`, otherwise it will not show up on pg_tileServ preview (it will however correctly work on UNDP's GeoHub, maplibre, leaflet, QGIS, etc.)

# Usage


Before using those scripts, PostGIS spatial extension need to be enabled on the PostgreSQL:

```
-- run against the PostgreSQL server 
-- on psql console or via any GUI-based tool (like PgAdmin)
-- 
-- Enable PostGIS
CREATE EXTENSION postgis;
-- enable raster support (currenlty not needed)
-- CREATE EXTENSION postgis_raster;
-- Enable Topology
CREATE EXTENSION postgis_topology;
-- Enable PostGIS Advanced 3D
-- and other geoprocessing algorithms
-- sfcgal not available with all distributions
CREATE EXTENSION postgis_sfcgal;
```