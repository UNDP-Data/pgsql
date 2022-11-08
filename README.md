This repo contains geo-analytical PostgreSQL functions used by UNDP GeoHub
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
ONce a function is cretae here it can be executed using 





