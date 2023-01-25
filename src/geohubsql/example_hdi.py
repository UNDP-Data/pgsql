"""
Utility to emulate admin1-level HDI calculation via PL/PgSQL scripts.
Returns a dump of the produced Vector Tiles.
Assumes that the .env file contains the appropriate POSTGRES_DSN string.

"""

import sys
sys.path.insert(0, '../')

from geohubsql import util
import asyncio
import asyncpg
import logging
from dotenv import dotenv_values

#import socket

async def run(dsn):
    async with asyncpg.create_pool(dsn=dsn, min_size=1, max_size=2,
                                   command_timeout=60,  ) as pool:
        logging.debug('Connecting to database...')
        async with pool.acquire(timeout=10) as conn_obj:
            logging.debug(f'Connected to DB ')

if __name__ == '__main__':
    logging.basicConfig()
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    evars = dotenv_values('../../.env')
    dsn = evars['TILESERVER_DSN']
    print(dsn)



    bytes = asyncio.run(util.run_sql_func(sql_func_name='hdi_subnat.sql',
                                    dsn=dsn,
                                    z=0,
                                    x=0,
                                    y=0,
                                    le_mult = 1.0,
                                    eys_mult = 1.0,
                                    mys_mult = 1.0,
                                    gni_mult = 1.0
                                    )
                    )

    util.dump_mvt(bytes)