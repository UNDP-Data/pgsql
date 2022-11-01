This repo contains geo-analytical PostgreSQL functions used by UNDP GeoHub
# Drivers
There are multiple options to connect to Postgres from python [psycopg2/3](https://www.psycopg.org/)
or [asyncpg](https://github.com/MagicStack/asyncpg). While the former is probably well know the 
later is preferred because it is:

- async
- binary
- faster

The disadvantage is the users has to adhere to the python [async](https://docs.python.org/3/library/asyncio.html) machinery.


