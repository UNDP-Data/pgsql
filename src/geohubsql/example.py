"""
Utility to emulate filtering of Countries via PL/PgSQL scripts.
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



async def run(dsn, **kwargs):
    async with asyncpg.create_pool(dsn=dsn, min_size=1, max_size=2,
                                   command_timeout=60,  ) as pool:
        logging.debug('Connecting to database...')
        async with pool.acquire(timeout=10) as conn_obj:
            #patch kwargs so the connection is reused
            kwargs['conn_obj'] = conn_obj
            bytes = await util.deploy_and_run_sql_func(**kwargs)
            util.dump_mvt(bytes)

        logging.debug(f'Connection was closed automatically')


if __name__ == '__main__':
    logging.basicConfig()
    sthandler = logging.StreamHandler()
    sthandler.setFormatter(
        logging.Formatter('%(asctime)s-%(filename)s:%(funcName)s:%(lineno)d:%(levelname)s:%(message)s',
                          "%Y-%m-%d %H:%M:%S"))
    logger = logging.getLogger()
    logger.handlers.clear()
    logger.addHandler(sthandler)
    logger.setLevel(logging.DEBUG)
    evars = dotenv_values('../../.env')
    dsn = evars['POSTGRES_DSN']


    asyncio.run(
        run(
            dsn=dsn,
            sql_func_name='filter_layer.sql',
            filter_table='admin.admin0',
            filter_column='iso3cd',
            filter_value='C',
            cleanup=True
        )
    )


