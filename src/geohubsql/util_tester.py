"""
Utility to verify the loading mechanism of SQL scripts into the database.
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


#PYTHONBREAKPOINT=0

async def run(dsn):
    async with asyncpg.create_pool(dsn=dsn, min_size=1, max_size=2,
                                   command_timeout=60,  ) as pool:
        logging.debug('Connecting to database...')
        async with pool.acquire(timeout=10) as conn_obj:
            logging.debug(f'Connected to DB ')
            # await util.run_sql_func(sql_func_name='hdi_subnat.sql', conn_obj=conn_obj)


def test_drop_and_deploy(dsn):
    f_output = asyncio.run(util.drop_and_deploy_sql_func(sql_func_name='hdi_subnat.sql',
                                                        dsn=dsn
                                                        )
                           )
    return


def test_deploy_and_run(dsn):
    f_output = asyncio.run(util.deploy_and_run_sql_func(sql_func_name='hdi_subnat.sql',
                                                        dsn=dsn
                                                        )
                           )
    util.dump_mvt(f_output)
    return


def test_run_only(dsn):
    f_output = asyncio.run(util.run_sql_func(sql_func_name='hdi_subnat.sql',
                                                        dsn=dsn
                                                        )
                           )
    util.dump_mvt(f_output)
    return


if __name__ == '__main__':
    logging.basicConfig()
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    evars = dotenv_values('../../.env')
    dsn = evars['POSTGRES_DSN']
    print(dsn)

    test_drop_and_deploy(dsn)
    test_run_only(dsn)
    test_deploy_and_run(dsn)
