from geohubsql import util
import asyncio
import logging
from dotenv import dotenv_values
import sys
import os
#sys.path.insert(0, '../')


if __name__ == '__main__':
    logging.basicConfig()
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    logger.name = os.path.split(__file__)[-1]
    evars = dotenv_values('../../.env')
    dsn = evars['POSTGRES_DSN']


    #asyncio.run(run(dsn=dsn))
    asyncio.run(util.deploy_sql_func(   sql_func_name='hdi_subnat.sql',
                                                dsn=dsn,

                                    )
                        )

