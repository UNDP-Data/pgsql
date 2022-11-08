from geohubsql import util
import asyncio
import asyncpg
import logging
from dotenv import dotenv_values



async def run(dsn):
    async with asyncpg.create_pool(dsn=dsn, min_size=1, max_size=2,
                                   command_timeout=60,  ) as pool:
        logging.debug('Connecting to database...')
        async with pool.acquire(timeout=10) as conn_obj:
            logging.debug(f'Conencted to DB ')
            # await util.run_sql_func(sql_func_name='filter.sql', conn_obj=conn_obj)
            # await util.run_sql_func(sql_func_name='filter.sql', conn_obj=conn_obj)
            # await util.run_sql_func(sql_func_name='filter.sql', conn_obj=conn_obj)
            # await util.run_sql_func(sql_func_name='filter.sql', conn_obj=conn_obj)
            # await util.run_sql_func(sql_func_name='filter.sql', conn_obj=conn_obj)
            # await util.run_sql_func(sql_func_name='filter.sql', conn_obj=conn_obj)

if __name__ == '__main__':
    logging.basicConfig()
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    evars = dotenv_values('../../.env')
    dsn = evars['POSTGRES_DSN']


    #asyncio.run(run(dsn=dsn))
    bytes = asyncio.run(util.run_sql_func(sql_func_name='filter_layer.sql',
                                  dsn=dsn,
                                  filter_table='admin.admin0',
                                  filter_column='iso3cd',
                                  filter_value='C')
                )
    util.dump_mvt(bytes)

