This repo contains geo-analytical PostgreSQL functions used by UNDP GeoHub.
as well as python tools to help with development/testing. The tools leverage asyncpg
library to connect to Postgres and mapbox_vector_tile library to parse/view the results

# Drivers
There are multiple options to connect to Postgres from python [psycopg2/3](https://www.psycopg.org/)
or [asyncpg](https://github.com/MagicStack/asyncpg). While the former is probably well know the 
later is preferred because it is:

- async
- binary
- faster
- fully integrated with Postgres machinery (logging)

The disadvantage is the users has to adhere to the python [async](https://docs.python.org/3/library/asyncio.html) machinery.

# Usage

## clone
```commandline
git clone https://github.com/UNDP-Data/pgsql.git
cd psql
```

- setup POSTGRES_DSN variable through .env file (see [.env.example](.env.example))
- run the [example](./src/geohubsql/example.py)

In principle, the sql functions need to be located inside [sql](./src/geohubsql/sql) folder.
Once a function is created here it can be executed using [run_sql_func](https://github.com/UNDP-Data/pgsql/blob/main/src/geohubsql/util.py#L144)


```python
import asyncio
from dotenv import dotenv_values
from geohubsql import util
evars = dotenv_values('../../.env')
dsn = evars['POSTGRES_DSN']
bytes = asyncio.run(util.run_sql_func(sql_func_name='filter_layer.sql',
                                      dsn=dsn,
                                      filter_table='admin.admin0',
                                      filter_column='iso3cd',
                                      filter_value='C')
                    )
util.dump_mvt(bytes)

INFO:geohubsql.util:0, {'iso3cd': 'COD'}
INFO:geohubsql.util:0, {'iso3cd': 'CHL'}
INFO:geohubsql.util:0, {'iso3cd': 'CAF'}
INFO:geohubsql.util:0, {'iso3cd': 'COG'}
INFO:geohubsql.util:0, {'iso3cd': 'CZE'}
INFO:geohubsql.util:0, {'iso3cd': 'CYP'}
INFO:geohubsql.util:0, {'iso3cd': 'CPV'}
INFO:geohubsql.util:0, {'iso3cd': 'CYM'}
INFO:geohubsql.util:0, {'iso3cd': 'CAN'}
INFO:geohubsql.util:0, {'iso3cd': 'CUB'}
INFO:geohubsql.util:0, {'iso3cd': 'CHE'}
INFO:geohubsql.util:0, {'iso3cd': 'CHN'}
INFO:geohubsql.util:0, {'iso3cd': 'CRI'}
INFO:geohubsql.util:0, {'iso3cd': 'CMR'}
INFO:geohubsql.util:0, {'iso3cd': 'CUW'}
INFO:geohubsql.util:0, {'iso3cd': 'COK'}
INFO:geohubsql.util:0, {'iso3cd': 'CXR'}
INFO:geohubsql.util:0, {'iso3cd': 'COL'}
INFO:geohubsql.util:0, {'iso3cd': 'COM'}
INFO:geohubsql.util:0, {'iso3cd': 'CIV'}
```

The `run_sql_func` function is able to connect automatically to Postgres, can intercept the Postgres
logs from the SQL function, parses the argumnets used by the **sql_func_name** argument and 
makes sure none of the mandatory args of the SQL function **sql_func_name** are omitted.

All of these happens under the hood using  as decorator  and a series of utility functions










