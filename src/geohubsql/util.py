import sys
#sys.path.append('src/')
from geohubsql import ROOT_DIR
import os
import mapbox_vector_tile
import asyncpg
from functools import wraps
import logging


logger = logging.getLogger(__name__)


def dump_mvt(mvt_bytes=None):
    """
    Prints the human readable content of a chunk pof bytes representing a MVT tile(tiles)
    :param mvt_bytes: bytes
    :return:
    """
    decoded_data = mapbox_vector_tile.decode(mvt_bytes)
    for lname, l in decoded_data.items():
        for feat in l['features']:
            logger.info(f'{feat["id"]}, {feat["properties"]}')



def print_pg_message(conn_obj, msg):
    logger.info(msg)


def connect(func):
    """
    Decorator function that handles the connection to PostgreSQL DB
    If the decorated function possesses a conn_obj in **kwargs it patches it with
    a listener to log the messages from PG server
    If the dsn is supplied the decorator creates a pool and a connection to the serves specified in DB and
    closes the pool ad the connection after the decorated function is called
    """

    @wraps(func)
    async def wrapper(**kwargs):

        if not 'conn_obj' in kwargs:
            reuse = False
            dsn = kwargs.get('dsn', None)
            if dsn is None:
                raise ValueError(f'dsn argument have to be provided to be able to connect to DB')
            pool = await asyncpg.create_pool(dsn=dsn, min_size=1, max_size=1, command_timeout=60, )
            conn_obj = await pool.acquire(timeout=10)

        else:
            reuse = True
            conn_obj = kwargs['conn_obj']
        # add log listener
        if not print_pg_message in conn_obj._log_listeners:
            conn_obj.add_log_listener(print_pg_message)

        kwargs['conn_obj'] = conn_obj
        result = await func(**kwargs)
        if print_pg_message in conn_obj._log_listeners:
            conn_obj.remove_log_listener(print_pg_message)
        if reuse is False:
            logger.debug(f'going to close the connection')
            conn_obj = kwargs['conn_obj']
            await conn_obj.close()
            if 'pool' in locals():
                await pool.close()
        else:
            logger.debug(f'going to keep the connection')
        return result

    return wrapper




def scantree(path):
    """Recursively yield DirEntry objects for given directory."""
    for entry in os.scandir(path):
        if entry.is_dir(follow_symlinks=False):
            yield from scantree(entry.path)
        else:
            yield entry


def get_sql_file_path(sql_file_name=None):
    """Compute the sql file path for the goven sql_file_name residing in sql folder of this repo"""
    assert sql_file_name is not None, f'Invalid sql_file_name={sql_file_name}'
    for entry in scantree(os.path.join(ROOT_DIR, 'sql')):
        if entry.is_file() and entry.name.endswith('.sql'):
            if entry.name == sql_file_name:
                return entry.path


def get_sqlfile_content(sql_file_path=None):
    """
    Read the content of a SQL file from sql folder
    :param sql_file_name:
    :return: str, the content of the SQL file, as is
    """


    assert sql_file_path is not None, f'No SQL function {sql_file_path} was found'

    with open(sql_file_path) as f:
        return f.read()


def get_sql_func_details(sql_func_content=None):
    """
    Parses an SQL postgres funtion returning various details abouyt the function like
    name, schema, arguments
    :param sql_func_content: str, the text content representing a SQL function
    :return: dict with various properties of the function
    """
    assert sql_func_content.count('$$') == 2, f'sql_func_content={sql_func_content} seems to be malformed '
    header, body, footer = sql_func_content.split('$$')
    start_paranthesis_index = header.index('(')
    end_paranthesis_index = header.index(')')
    fname_section  = header[:start_paranthesis_index].lower()
    args_section  = header[start_paranthesis_index+1:end_paranthesis_index]
    return_section  = header[end_paranthesis_index+1:].lower()
    assert 'FUNCTION'.lower() in fname_section.lower(), f'Could not parse/find the function name from {header}=>{fname_section}'
    fqfn = fname_section.split(' ')[-1]
    assert '.' in fqfn, f'Could not extract fully qualified func name from {fname_section}'
    schema, func_name = fqfn.split('.')
    args = [e.strip().split( ) for e in args_section.split(',')]
    assert 'RETURNS'.lower() in return_section.lower(), f'Could not parse/find return type of the function in {return_section}'
    return_type = return_section.lower().strip().split(' ')[1]
    assert return_type == 'bytea', f'Invalid return type {return_type}. The return type of the SQL function {fqfn} must be "bytea"'
    return dict(name=func_name,schema=schema,args=args, return_type=return_type)

@connect
async def run_jsonargs_sql_func(sql_func_name=None, z=0, x=0, y=0, **kwargs):
    assert 'conn_obj' in kwargs, 'asyncpg.connection instance stored in conn_obj kwd is needed.'
    conn_obj = kwargs.get('conn_obj' or None)
    assert conn_obj is not None, f'ivalid conn_obj={conn_obj}'
    sql_func_content = get_sqlfile_content(sql_file_name=sql_func_name)
    details = get_sql_func_details(sql_func_content=sql_func_content)
    drop_func_query = f'DROP FUNCTION IF EXISTS {details["schema"]}.{details["name"]};'
    #remove function
    await conn_obj.execute(drop_func_query)
    #create
    await conn_obj.execute(sql_func_content)
    # run
    execute_func_query = f'''
        SELECT * FROM public.function_source_query_params({z},{x},{y}, query_params => '{json_args}')
    '''
    mvt = conn_obj.fetch()

@connect
# DEPLOY and RUN
async def deploy_and_run_sql_func(sql_func_name=None, dsn=None, conn_obj=None, z=0, x=0, y=0, cleanup=False, **kwargs):
    """
    Run the SQL function sql_func_name in the database provided by the dsn or conn_obj arguments
    forwarding the arguments through the kwargs
    :param sql_func_name: str, the name of the function to read/execute
    :param dsn: str, Postgres DSN
    :param conn_obj: instance of asyncpg.connection as an alternative to dsn.
    :param z: z level, int
    :param x: x tile coord, int
    :param y: y tile coord, int
    :param cleanup: bool, False, if True the function will be also removed
    :param kwargs: dict, a placeholder for any params the sql_func_name might require
    :return: the result of executing the sql function in postgres with the supplied parameters



    """
    if not dsn:
        assert conn_obj is not None, f'invalid conn_obj={conn_obj}'


    await deploy_sql_func(sql_func_name=sql_func_name, dsn=dsn, conn_obj=conn_obj)

    return await run_sql_func(
        sql_func_name=sql_func_name,
        dsn=dsn,
        conn_obj=conn_obj,
        z=z,
        x=x,
        y=y,
        cleanup=cleanup,
        **kwargs
    )






@connect
#RUN ONLY OPTIONALLY CLEANUP
async def run_sql_func(sql_func_name=None, dsn=None, conn_obj=None, z=0, x=0, y=0, cleanup=False, **kwargs):
    """
    Run the SQL function sql_func_name in the database provided by the dsn or conn_obj arguments
    forwarding the arguments through the kwargs
    :param sql_func_name: str, the name of the function to read/execute
    :param dsn: str, Postgres DSN
    :param conn_obj: instance of asyncpg.connection as an alternative to dsn.
    :param z: z level, int
    :param x: x tile coord, int
    :param y: y tile coord, int
    :param cleanup: bool, False, if True the function will be also removed
    :param kwargs: dict, a placeholder for any params the sql_func_name might require
    :return: the result of executing the sql function in postgres with the supplied parameters



    """
    if not dsn:
        assert conn_obj is not None, f'invalid conn_obj={conn_obj}'
    sql_file_path = get_sql_file_path(sql_file_name=sql_func_name)
    sql_func_content = get_sqlfile_content(sql_file_path=sql_file_path)
    func_details = get_sql_func_details(sql_func_content=sql_func_content)
    func_args = func_details['args']


    fqfn = f'{func_details["schema"]}.{func_details["name"]}'
    mandatory_args = [e[0] for e in func_args if 'default' not in e]
    for marg in mandatory_args:
        logger.debug(f'mandatory argument: {marg}')
        assert marg in kwargs, f'{marg} is a mandatory argument for {fqfn}'

    # run
    func_args = dict(z=z,x=x,y=y)
    func_args.update(kwargs)
    args_as_str = ', '.join({f"{k} => '{v}'" if isinstance(v, str) else f"{k} => {v}" for k, v in func_args.items()})
    execute_func_query = f'''
        SELECT * FROM {fqfn}({args_as_str});
    '''


    mvt_bytes =  await conn_obj.fetchval(execute_func_query)
    if cleanup:
        drop_func_query = f'DROP FUNCTION IF EXISTS {fqfn};'
        logger.debug(f'Dropping function {fqfn}')
        await conn_obj.execute(drop_func_query)
    return  mvt_bytes

@connect
async def deploy_sql_func(sql_func_name=None, dsn=None, conn_obj=None):
    """
    Deploy the SQL function sql_func_name in the database provided by the dsn or conn_obj arguments
    :param sql_func_name: str, the name of the function to read/execute
    :param dsn: str, Postgres DSN
    :param conn_obj: instance of asyncpg.connection as an alternative to dsn.

    """
    if not dsn:
        assert conn_obj is not None, f'invalid conn_obj={conn_obj}'
    sql_file_path = get_sql_file_path(sql_file_name=sql_func_name)
    sql_func_content = get_sqlfile_content(sql_file_path=sql_file_path)
    ###
    func_details = get_sql_func_details(sql_func_content=sql_func_content)
    fqfn = f'{func_details["schema"]}.{func_details["name"]}'

    #remove function
    drop_func_query = f'DROP FUNCTION IF EXISTS {fqfn};'
    logger.debug(f'Dropping function using query {drop_func_query}')

    try:
        await conn_obj.execute(drop_func_query)
    except Exception as e:
        logger.error(f'Failed to drop function {fqfn}')
        raise

    #create
    logger.debug(f'Creating function {fqfn} ')
    try:
        await conn_obj.execute(sql_func_content)
    except Exception as e:
        logger.error(f'Failed to create function {fqfn}')
        raise
    return

