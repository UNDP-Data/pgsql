vector_batch_import
==

The `vector_batch_import` folder contains the scripts necessary to process the base (shape) SDG vector files,
ingest them into PostgreSQL tables, and make them available as pg_tileserv/PostgreSQL functions.

Running the `extract_field_names.py` script yields a number of sql functions which need to be run in sequence:

- 01_create_schemas.sql
- 02_create_tables.sql
- 03_populate_tables.sql
- 04_create_views.sql
- 05_insert_into_dataset.sql
- 06_insert_into_tags.sql
- 07_insert_into_dataset_tags.sql

Names should be self-explaining.

Additionally, a number of information/debug JSONS are output:

- global_dbf_by_time_series.json
- global_tags_in_use.json
- output_sql.json
- lut_file_names.json
- timeseries_summary.json
- error_files.json
- subsets_summary.json
- field_list.json

Finally, SQL scripts are created in the `batch_function` directory, one per SDG indicator.
Each function needs to be registered and will be exposed as a pg_tileserv function.
These functions are in a lower number then the respective views, since functions expose subset filters through the argument JSON.
Using these subset selectors in the query (SQL questy to the server or http questy through pg_tileserv), 
a user can obtain the representation of the desired subset.

The naming of those functions follows GeoHub's naming convention.
For example, the `f_sdg12_12_4_1.sql` script will `CREATE` the function `f_sdg12_12_4_1` in the `sdg12` schema.

In alternative, the views created by `04_create_views.sql` can be used, but these lack of course the more advanced options of functions.
