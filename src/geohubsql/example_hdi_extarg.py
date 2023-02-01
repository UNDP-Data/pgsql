"""
Utility to emulate admin1-level HDI calculation via PL/PgSQL scripts.
Returns a dump of the produced Vector Tiles.
Assumes that the .env file contains the appropriate POSTGRES_DSN string.

"""

import sys
sys.path.insert(0, '../')

from geohubsql import util
import asyncio
import logging
from dotenv import dotenv_values

#import socket


if __name__ == '__main__':
    logging.basicConfig()
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    evars = dotenv_values('../../.env')
    dsn = evars['TILESERVER_DSN']



    bytes = asyncio.run(util.run_sql_func(sql_func_name='hdi_subnat_extarg.sql',
                                    dsn=dsn,
                                    z=0,
                                    x=0,
                                    y=0,
                                    le_incr=dict(value=5)
                                    )
                    )

    util.dump_mvt(bytes)