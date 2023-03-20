import os
import dbfread
import json
import unicodedata
import argparse
from pathlib import Path
import hashlib
from collections import OrderedDict

# ! pipenv install jinja2
from jinja2 import Environment, FileSystemLoader

# to load the longest files (03_populate_tables.sql in particular) use pgAdmin, loading the file from the disk,
# as psql -1 -f echos back each INSERT, thus taking a very long time.

template_name = 'subset_function_prototype.sql'

processing_options = {
    'each_yearly_value_to_new_record': False,
    'tileserv_user': 'tileserver',
    'base_admin0_vector_layer': 'admin.admin0',
    'base_admin1_vector_layer': 'admin.admin1',
    'base_admin2_vector_layer': 'admin.admin2',
    'pg_tileserv_base_url': 'https://pgtileserv.undpgeohub.org/',
    'pg_tileserv_suffix': '/{z}/{x}/{y}.pbf',
    'SRID': '4326',
    'created_by_user': 'douglas.tommasi@undp.org'
}

allowed_fields = {}

allowed_fields['admin'] = {
    "goal_code": "goal_code",
    "goal_cod": "goal_code",
    "iso3": "iso3cd",
    "iso3c": "iso3cd",
    "iso3cd": "iso3cd",
    # "objectid":"objectid",
    # "objectid 1": "objectid_1",
    # "objectid_1": "objectid_1",
    # "target_cod": "sdg_target",
    # "target_code": "sdg_target",
    "indicato_1": "indicator",
    "indicator_1": "indicator",
    "series": "series",
    "timeseries": "timeseries",
    "timeSeries": "timeseries",
    "type_of": "qualifier",
    "type_of_": "qualifier",
    "type_of__": "qualifier",
    "type_of_sk": "type_of_skill",
    # "Units_desc": "unit",
    # "units_desc": "unit",
    # "Units_code": "units_code",
    # "units_code": "units_code",
    "type": "type",
    "age_code": "age_code",
    "age code": "age_code",
    "sex_code": "sex_code",
    "sex code": "sex_code",
    "location": "location",
    "location_c": "location",
    "education": "education",
    "education_": "education",
    "disabili_1": "disability",
    "migrator_1":"migrator_1",
    "mode_of__1":"mode_of__1",
    "reportin_1":"reportin_1",
    "type_of_oc": "type_of_oc",
    "type_of_pr": "type_of_pr",
    "type_of_sp": "type_of_sp",
    "name_of__1":"name_of__1",
    "policy_d_1":"policy_d_1",
    "activity_c":"activity_c"
}

# fields useful to gather one-per-file information like tags, descriptions, etc
allowed_fields['lut'] = {
    "indicato_2": "description2",
    "indicator_2": "description2",
    "target_cod": "sdg_target",
    "target_code": "sdg_target",
    "series_rel": "create_date",
    "series_tag": "series_tag",
    "seriesdesc": "description",
    "seriesDesc": "description",
    "name_of_in": "name_of_in",
    "Units_desc": "unit",
    "units_desc": "unit",
    "Units_code": "units_code",
    "units_code": "units_code"
}

# fields used as subset identifiers.
# these will become the arguments of pg_tilserv query params.

allowed_fields['subsets'] = {
#    "series": "series",
    "type_of": "qualifier",
    "type_of_": "qualifier",
    "type_of__": "qualifier",
    "age_code": "age_code",
    "age code": "age_code",
    "sex_code": "sex_code",
    "sex code": "sex_code",
    "location": "location",
    "location_c": "location",
    "education": "education",
    "education_": "education",
    "disabili_1": "disability",
    "migrator_1":"migrator_1",
    "mode_of__1":"mode_of__1",
    "reportin_1":"reportin_1",
    "type_of_oc": "type_of_oc",
    "type_of_pr": "type_of_pr",
    "type_of_sk": "type_of_skill",
    "type_of_sp": "type_of_sp",
    "name_of__1":"name_of__1",
    "policy_d_1":"policy_d_1",
    "activity_c":"activity_c"
}

allowed_fields['column_comment'] = {
    "file_name": "Name of the original file",
    "goal_code": "SDG Goal code",
    "indicator": "SDG indicator",
    "iso3cd": "Standard ISO Country Code (3 le)",
    "age_code": "Age Group code",
    "sex_code": "Gender code"
}

allowed_fields['unicode'] = {
    '\u00d4\u00c7\u00f4': "-",
    'ÔÇô': "-"
}


global_dbf_by_time_series = {}


#
# "sdg_goal": [
#     "1"
# ],
# "sdg_indicator": [
#     "1.5.2"
# ],
# "sdg_target": [
#     "1.5"
# ],

# used to create a compound primary key, depending on the columns actually created in a specific table
allowed_fields['pk'] = ["view_name_hash", "indicator", "timeseries", "iso3cd", "age_code", "sex_code"]

admin_level_lut = {
    "Country": 0,
    "Region": 1,
    "Province": 2
}


def pad_sdg(sdg):
    # n -> sdg0n
    return 'sdg' + str(sdg).zfill(2)


def unpad_sdg(sdg_code):
    # sdg0n -> n
    # import re
    #    return re.sub("sdg[01]?", "", sdg_code)
    return sdg_code.removeprefix('sdg0').removeprefix('sdg')


def sanitize_name(name):
    """
    Sanitizes a field name by removing non-ascii characters, converting
    the name to lowercase, and converting spaces to underscores.
    """
    return unicodedata.normalize('NFKD', name).encode('ASCII', 'ignore').decode('utf-8').lower().replace(' ', '_')


#    return name

def add_tag_in_use(local_tags_in_use, key, value):
    if key not in local_tags_in_use:
        local_tags_in_use[key] = []
    if value not in local_tags_in_use[key]:
        local_tags_in_use[key].append(value)

    return local_tags_in_use


def parse_template_subset_function(subsets_summary, template_name_in):
    file_loader = FileSystemLoader('./')
    env = Environment(loader=file_loader)
    template = env.get_template(template_name_in)

    if not os.path.exists("./batch_functions"):
        os.makedirs("./batch_functions")

    for schema_name, schema_data in subsets_summary.items():

        for admin_level, admin_data in schema_data.items():
            for indicator, indicator_data in admin_data.items():

                parsing_strings = {}
                parsing_strings['schema_name'] = schema_name
                parsing_strings['admin_level'] = admin_level
                parsing_strings['indicator'] = indicator
                indicator_clean = indicator.replace(".", "_")
                parsing_strings['indicator_clean'] = indicator_clean


                url = 'https://pgtileserv.undpgeohub.org/' + schema_name + '.f_' + indicator_clean + '/{z}/{x}/{y}.pbf'


                parsing_strings['url'] = url
                parsing_strings['md5'] = hashlib.md5(url.encode('utf-8')).hexdigest()

                parsing_strings['subsets_json'] = {}
                parsing_strings['json_request'] = {}
                parsing_strings['years'] = []

                parsing_strings['value_latest'] = 0
                if 'value_latest' in parsing_strings:
                    parsing_strings['value_latest'] = 1


                if 'subsets' in indicator_data:
                    available_subsets = indicator_data['subsets']
                    for subset_name, subset_data in available_subsets.items():
                        parsing_strings['subsets_json'][subset_name] = {}
                        parsing_strings['subsets_json'][subset_name]['options'] = subset_data
                        parsing_strings['subsets_json'][subset_name]['value'] = subset_data[0]

                        parsing_strings['json_request'][subset_name] = {}
                        parsing_strings['json_request'][subset_name]['value'] = subset_data[0]

                        if 'years' in indicator_data:
                            parsing_strings['years'] = indicator_data['years']

                    #print(str(parsing_strings))

                subsets_json_double_quoted = parsing_strings['subsets_json']
                parsing_strings['subsets_json_double_quoted'] = str(subsets_json_double_quoted).replace("'", '"')

                json_request_double_quote = parsing_strings['json_request']
                parsing_strings['json_json_request_double_quoterequest'] = str(json_request_double_quote).replace("'", '"')

                parsed_output = template.render(parsing_strings=parsing_strings)

                template.stream(parsing_strings=parsing_strings).dump('./batch_functions/f_' + schema_name + '_' + indicator_clean + '.sql')
                #print(parsed_output)



def identify_tags_in_use(timeseries_summary, file_path):
    # will be used to update the "tag" table
    # global_tags_in_use['extent'] = ['Global','Asia','China']

    # will be used as a template for the deeper levels and, ultimately to update the "dataset_tag" table
    proto_tags_in_use = {}

    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'geometrytype', 'MultiPolygon')
    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'layertype', 'table')
    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'provider', 'United Nations Development Programme (UNDP)')
    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'type', 'pgtileserv')
    #    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'attribution', 'pgtileserv')
    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'multi_year_format', 'value_{yyyy}')

    global_tags_in_use = proto_tags_in_use.copy()

    data = timeseries_summary
    for schema_name, schema_data in data.items():
        tags_in_use_schema = proto_tags_in_use.copy()
        # sdg_goal
        global_tags_in_use = add_tag_in_use(global_tags_in_use, 'sdg_goal', unpad_sdg(schema_name))
        tags_in_use_schema = add_tag_in_use(tags_in_use_schema, 'sdg_goal', unpad_sdg(schema_name))

        # schema
        global_tags_in_use = add_tag_in_use(global_tags_in_use, 'schema', schema_name)
        tags_in_use_schema = add_tag_in_use(tags_in_use_schema, 'schema', schema_name)

        for admin_level, admin_data in schema_data.items():
            tags_in_use_admin_level = tags_in_use_schema.copy()

            if admin_level == 'admin0':
                global_tags_in_use = add_tag_in_use(global_tags_in_use, 'extent', 'Global')
                tags_in_use_admin_level = add_tag_in_use(tags_in_use_admin_level, 'extent', 'Global')

            for indicator, indicator_data in admin_data.items():
                for timeseries, timeseries_data in indicator_data.items():

                    tags_in_use_series = tags_in_use_admin_level.copy()

                    # sdg_target
                    sdg_target = timeseries_summary[schema_name][admin_level][indicator][timeseries]['sdg_target']
                    global_tags_in_use = add_tag_in_use(global_tags_in_use, 'sdg_target', sdg_target)
                    tags_in_use_series = add_tag_in_use(tags_in_use_series, 'sdg_target', sdg_target)

                    # units
                    unit = timeseries_summary[schema_name][admin_level][indicator][timeseries]['unit']
                    global_tags_in_use = add_tag_in_use(global_tags_in_use, 'unit', unit)
                    tags_in_use_series = add_tag_in_use(tags_in_use_series, 'unit', unit)

                    #view
                    view_name = timeseries_summary[schema_name][admin_level][indicator][timeseries]['view_name']
                    global_tags_in_use = add_tag_in_use(global_tags_in_use, 'table', view_name)
                    tags_in_use_series = add_tag_in_use(tags_in_use_series, 'table', view_name)

                    # id (schema + view name)
                    schema_view_id = schema_name + '.' + view_name
                    global_tags_in_use = add_tag_in_use(global_tags_in_use, 'id', schema_view_id)
                    tags_in_use_series = add_tag_in_use(tags_in_use_series, 'id', schema_view_id)

                    # years
                    min_year = 9999
                    max_year = -9999
                    for this_year in timeseries_summary[schema_name][admin_level][indicator][timeseries]['years']:
                        global_tags_in_use = add_tag_in_use(global_tags_in_use, 'year', this_year)
                        tags_in_use_series = add_tag_in_use(tags_in_use_series, 'year', this_year)
                        if int(this_year) < min_year:
                            min_year = int(this_year)
                        if int(this_year) > max_year:
                            max_year = int(this_year)
                    #   print(tags_in_use_series)


                    if (min_year < 9999) and ( max_year > 0):
                        global_tags_in_use = add_tag_in_use(global_tags_in_use, 'multi_year_from', min_year)
                        tags_in_use_series = add_tag_in_use(tags_in_use_series, 'multi_year_from', min_year)
                        global_tags_in_use = add_tag_in_use(global_tags_in_use, 'multi_year_to', max_year)
                        tags_in_use_series = add_tag_in_use(tags_in_use_series, 'multi_year_to', max_year)
                    else:
                        tags_in_use_series.pop('multi_year_format')

                    series_string = timeseries_summary[schema_name][admin_level][indicator][timeseries]['series_tag']
                    series_string = series_string.replace("'", '"')
                    #print('series_string:'+series_string)

                    series_tags = []
                    series_tags.append(json.loads(series_string))

                    # needs fixing
                    # for series_tag in series_tags:
                    #     global_tags_in_use = add_tag_in_use(global_tags_in_use, 'theme', series_tag)
                    #     tags_in_use_series = add_tag_in_use(tags_in_use_series, 'theme', series_tag)

                    timeseries_summary[schema_name][admin_level][indicator][timeseries]['tags'] = tags_in_use_series

    with open(file_path, 'w') as file:
        json.dump(global_tags_in_use, file, indent=4)
    return global_tags_in_use


def insert_into_geohub_tag(global_tags_in_use, sql_file_path):
    with open(sql_file_path, 'w') as sql_file:
        sql_file.write("BEGIN TRANSACTION;")
        for key, values in global_tags_in_use.items():
            for value in values:
                sql_statement = f'''
                INSERT INTO geohub.tag (key, value)
                SELECT '{key}', '{value}'
                WHERE
                    NOT EXISTS (
                        SELECT key,value FROM geohub.tag WHERE key='{key}' AND value='{value}'
                    );
                --DELETE FROM geohub.tag WHERE key='{key}' AND value='{value}';
                '''
                sql_file.write(sql_statement)
        sql_file.write("\nCOMMIT;")

#    global_tags_in_use['extent'] = ['Global','Asia','China']


def insert_into_geohub_dataset_tag(timeseries_summary, sql_file_path):
    data = timeseries_summary
    with open(sql_file_path, 'w') as sql_file:
        sql_file.write("BEGIN TRANSACTION;")
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                for indicator, indicator_data in admin_data.items():
                    for timeseries, timeseries_data in indicator_data.items():
                        series_tags = timeseries_summary[schema_name][admin_level][indicator][timeseries]['tags']
                        timeseries_id = timeseries_summary[schema_name][admin_level][indicator][timeseries]['id']
                        sql_statement_del = f'''
                            --DELETE FROM geohub.dataset_tag WHERE dataset_id = '{timeseries_id}';
                            '''
                        sql_file.write(sql_statement_del)

                        for key, values in series_tags.items():
                            for value in values:
                                sql_statement = f'''
        -- -- -- series:{timeseries} timeseries_id: {timeseries_id} tag: {value}
        INSERT INTO geohub.dataset_tag (dataset_id, tag_id) VALUES ('{timeseries_id}',(SELECT id FROM geohub.tag WHERE key='{key}' AND value='{value}'))  ON CONFLICT DO NOTHING;
        --DELETE FROM geohub.dataset_tag WHERE dataset_id='{timeseries_id}';
        '''
                                # print (timeseries+' '+timeseries_id+' '+key+' '+value)

                            # print (sql_statement)
                            sql_file.write(sql_statement)
                        # print('SQL futures:')
        sql_file.write("\nCOMMIT;")

def insert_into_geohub_dataset(timeseries_summary, sql_file_path):
    # INSERT INTO geohub.dataset(id, url, is_raster, license, bounds, createdat, updatedat, name, description, created_user, updated_user)
    # VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

    with open(sql_file_path, 'w') as sql_file:
        sql_file.write("BEGIN TRANSACTION;")
        data = timeseries_summary
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                bounds = '(SELECT ST_SetSRID(ST_Extent(geom),' + processing_options['SRID'] + ')  AS geom FROM ' + \
                         processing_options['base_' + admin_level + '_vector_layer'] + ')'
                for indicator, indicator_data in admin_data.items():
                    for timeseries, timeseries_data in indicator_data.items():
                        #view_name = timeseries_summary[schema_name][admin_level][indicator][timeseries]['view_name']

                        url = timeseries_summary[schema_name][admin_level][indicator][timeseries]['url']
                        timeseries_id = timeseries_summary[schema_name][admin_level][indicator][timeseries]['id']

                        is_raster = False
                        layer_license = 'Creative Commons BY NonCommercial ShareAlike 4.0'
                        name = timeseries_summary[schema_name][admin_level][indicator][timeseries]['description']
                        name = name.replace("'", "''")
                        timeseries_description = timeseries_summary[schema_name][admin_level][indicator][timeseries]['description']
                        timeseries_description = timeseries_description.replace("'", "''")
                        created_user = processing_options['created_by_user']
                        updated_user = processing_options['created_by_user']

                        sql_statement = f'''
    INSERT INTO geohub.dataset(id, url, is_raster, license, bounds, createdat, updatedat, name, description, created_user, updated_user)
    VALUES ('{timeseries_id}', '{url}', {is_raster}, '{layer_license}', {bounds}, current_timestamp, current_timestamp, '{name}', '{timeseries_description}', '{created_user}', '{updated_user}');
    --DELETE FROM geohub.dataset WHERE id ='{timeseries_id}';
                        '''
                        sql_file.write(sql_statement)
        sql_file.write("\nCOMMIT;")

def process_dbf_file(dbf_file_path):
    """
    Extracts information from a DBF file and returns a dictionary
    containing the field names, directory path, and number of records.
    """
    dbf_file = dbfread.DBF(dbf_file_path, encoding='cp852')
    field_names = [sanitize_name(field.name) for field in dbf_file.fields]
    file_details = {
        'fields': field_names,
        'dir': os.path.dirname(dbf_file_path),
        'nof_recs': len(dbf_file),
    }
    return file_details


def generate_sql_views(json_obj, timeseries_summary, sql_file_path):
    with open(sql_file_path, 'w') as sql_file:
        data = timeseries_summary
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                for indicator, indicator_data in admin_data.items():
                    indicator_clean = indicator.replace(".", "_")
                    for timeseries, timeseries_data in indicator_data.items():
                        timeseries_description = timeseries_summary[schema_name][admin_level][indicator][timeseries]['description']
                        timeseries_description = timeseries_description.replace("'", "''")
                        view_name = timeseries_summary[schema_name][admin_level][indicator][timeseries]['view_name']

                        # each feature must be present only once, hence the "DISTINCT ON":
                        sql_statement = f'''
                            DROP VIEW IF EXISTS {schema_name}."{view_name}";
                            CREATE VIEW {schema_name}."{view_name}" AS
                            SELECT DISTINCT ON (a.geom) a.id, a.geom, s.* from
                            admin.{admin_level} AS a
                            INNER JOIN {schema_name}.{admin_level} AS s ON (a.iso3cd = s.iso3cd)
                            WHERE s."indicator"='{indicator}' AND s."series" ='{timeseries}';
                            COMMENT ON VIEW {schema_name}."{view_name}" IS '{timeseries_description}';
                            \n
    '''

                        # TODO
                        # add comment on VIEW
                        # add layer_name ?

                        sql_file.write(sql_statement)
                    # processing_options[base_admin0_vector_layer]


def load_json_to_table(json_obj, sql_file_path):
    data = json_obj
    with open(sql_file_path, 'w') as query:

        for schema_name, schema_data in sorted(data.items()):
            query.write("BEGIN TRANSACTION;\n")
            for table_name, table_data in schema_data.items():
                for row_data in table_data:
                    columns = ", ".join(row_data.keys())
                    values = ", ".join(f"'{v}'" for v in row_data.values())
                    query.write(f"INSERT INTO {schema_name}.{table_name} ({columns}) VALUES ({values});\n\n")
            query.write("\nCOMMIT;")

        query.write("\n")


def generate_sql_tables(json_obj, sql_file_path):
    with open(sql_file_path, 'w') as sql_file:
        data = json_obj
        for schema_name, schema_data in data.items():
            for table_name, table_data in schema_data.items():
                column_names = set()
                for row in table_data:
                    column_names.update(row.keys())
                sql_file.write(f"--DROP TABLE IF EXISTS {schema_name}.{table_name};\n")
                sql_file.write(f"CREATE TABLE IF NOT EXISTS {schema_name}.{table_name} (\n")
                col_count = 0
                separator = ''
                for column_name in sorted(column_names):
                    if col_count > 0:
                        separator = ',\n'
                    col_count += 1
                    # use double precision, not numeric or decimal,
                    # otherwise maplibre/pg_tileserv will not recognize those columns as numeric,
                    # and they will not be able to apply colormaps !
                    data_type = 'double precision' if column_name.startswith('value_') else 'text'
                    # one off to convert exisiting tables (after dropping all views)
                    # views need to be re-created after the ALTERing.
                    # sql_file.write(f"\n--ALTER TABLE {schema_name}.{table_name} ALTER COLUMN {column_name} TYPE double precision ;\n")
                    sql_file.write(f"{separator}    {column_name} {data_type}")
                sql_file.write(");\n\n")

                for column_name in sorted(column_names):
                    if column_name in allowed_fields['column_comment'].keys():
                        col_comment = allowed_fields['column_comment'][column_name]
                        sql_file.write(f"COMMENT ON COLUMN {schema_name}.{table_name}.{column_name} IS '{col_comment}';\n")
                        sql_file.write("\n")


def generate_sql_schemas(json_obj, sql_file_path):
    with open(sql_file_path, 'w') as sql_file:
        data = json_obj
        for schema_name, schema_data in data.items():
            sql_file.write(f"CREATE SCHEMA IF NOT EXISTS {schema_name};\n")
            sql_file.write(f"GRANT SELECT,USAGE ON ALL TABLES IN SCHEMA {schema_name} TO {processing_options['tileserv_user']};\n")
            sql_file.write(f"GRANT CREATE,USAGE ON SCHEMA {schema_name} TO {processing_options['tileserv_user']};\n")
            # sql_file.write(f"ALTER DEFAULT PRIVILEGES IN SCHEMA {schema_name} GRANT READ ON TABLES  TO {processing_options['tileserv_user']} WITH GRANT OPTION;\n")
            sql_file.write(f"ALTER DEFAULT PRIVILEGES IN SCHEMA {schema_name} GRANT SELECT ON TABLES  TO {processing_options['tileserv_user']};\n")

            sql_file.write("\n")


def extract_years(record):
    years_in_use = []

    for field_name, field_value in record.items():
        if isinstance(field_value, (int, float)) and field_name.startswith('value'):
            # extract years from all column names,
            # does not check that at least one row ha non-zero values for each year column
            year = str(field_name).removeprefix('value_').removeprefix('value ')
            years_in_use.append(year)

    return years_in_use


def process_value_fields(record, processed_record_template):
    """
    Processes value fields in a record and returns a list of dictionaries
    representing the valid values.
    """
    process_processed_records = []
    if processing_options['each_yearly_value_to_new_record']:
        for field_name, field_value in record.items():
            if isinstance(field_value, (int, float)) and field_name.startswith('value'):
                if field_value != 0:
                    #                print("field_name: " + field_name + " field_value: " + str(field_value))

                    output_record = processed_record_template.copy()
                    output_record['year'] = str(field_name).removeprefix('value_').removeprefix('value ')
                    output_record['year_value'] = round(field_value, 3)
                    process_processed_records.append(output_record)

            # Would create a type mismatch.
            # Create a SQL views instead with order by desc / limit
            # if isinstance(field_value, (int, float)) and (field_name == ('latest')):
            #     if field_value != 0:
            #         output_record = processed_record_template.copy()
            #         output_record['year'] = 'latest'
            #         output_record['year_value'] = round(field_value, 3)
            #         process_processed_records.append(output_record)

    else:

        output_record = processed_record_template.copy()

        for field_name, field_value in record.items():
            if isinstance(field_value, (int, float)) and field_name.startswith('value'):
                if field_value != 0:
                    year = str(field_name).removeprefix('value_').removeprefix('value ')
                    output_record['value_' + year] = round(field_value, 3)
            if isinstance(field_value, (int, float)) and (field_name == 'latest_val'):
                if field_value != 0:
                    output_record['value_latest'] = round(field_value, 3)

        process_processed_records.append(output_record)

    return process_processed_records


def process_single_dbf_file(file_details, allowed_fields_in, lut_file_names, processed_records,
                            timeseries_summary, subsets_summary, field_list, error_files):
    print()
    print(os.path.join(file_details['dir'], file_details['file_name']))

    dbf_file = dbfread.DBF(os.path.join(file_details['dir'], file_details['file_name']), encoding='cp852')
    file_name = sanitize_name(file_details['file_name'])

    #defaults
    sdg_code = 'sdg_others'
    admin_level = 'admin0'
    indicator = ''
    record_count = {}

    dbf_by_time_series = {}

    record = split_dbf_by_timeseries(allowed_fields_in, dbf_by_time_series, dbf_file, file_name, record_count)

    global_dbf_by_time_series.update(dbf_by_time_series)




    for splitter, split_records in dbf_by_time_series.items():

        for rec_count, split_record in split_records.items():

            processed_record_template = {}
            lut_temp_values = {}
            subset_temp_values = {}
            record_count[splitter] += 1
            processed_record_template['record'] = record_count[splitter]
            processed_record_template['file_name'] = file_name
            #print("\n")
            # print('HHH ########## ' + splitter + ' ' +str(split_record))

            extract_processed_record_template(allowed_fields_in, processed_record_template, split_record)

            extract_lut_temp_values(allowed_fields_in, lut_temp_values, split_record)



            # files like 4.7.1 have some incomplete rows:
            if ('goal_code' not in processed_record_template) or ('indicator' not in processed_record_template) or (len(processed_record_template['goal_code'])<1) or (len(processed_record_template['indicator'])<1):
                err_str = 'CONTINUE on ' + sdg_code + ' ' + file_name + ' RECORD: ' + str(processed_record_template)
                print(err_str)
                error_files.append(err_str)
                continue

            # print(processed_record_template)

            if record_count[splitter] == 1:
                # print(all_rec_fields)


                try:

                    extract_field_names(field_list,split_record)

                    admin_level_name = processed_record_template['type']
                    admin_level = 'admin' + str(admin_level_lut[admin_level_name])
                    sdg_code = pad_sdg(processed_record_template['goal_code'])

                    if 'indicator' in processed_record_template:
                        indicator = processed_record_template['indicator']
                    indicator_clean = indicator.replace(".", "_")

                    timeseries = splitter
                    view_name = indicator_clean + "_" + timeseries + "_view"
                    unit = lut_temp_values['unit'].lower()

                    populate_timeseries_summary(admin_level, file_name, indicator, record, sdg_code, timeseries,
                                                timeseries_summary, unit, view_name)


                    for lut_field_name, lut_field_value in lut_temp_values.items():
                        if lut_field_name in lut_temp_values:
                            timeseries_summary[sdg_code][admin_level][indicator][timeseries][lut_field_name] = lut_temp_values[lut_field_name]

                    populate_subsets_summary(admin_level, file_name, indicator, record, lut_temp_values, sdg_code, timeseries,
                                                 subsets_summary, view_name)


                except:
                    print('NOK ' + file_name + ' sdg_code: ' + str(sdg_code))
                    print(processed_record_template)
                    if 'indicator' not in processed_record_template:
                        # do not process a file without indicator
                        err_str = 'ERROR: ' + sdg_code + ' ' + file_details['file_name'] + ' does not have a valid indicator field'
                        print(err_str)
                        error_files.append(err_str)
                        return
                else:
                    print('OK ' + file_name + ' sdg_code: ' + str(sdg_code))

                view_name_md5 = calculate_view_name_md5(admin_level, file_name, lut_file_names, sdg_code, split_record,
                                                        splitter, view_name)

            # print('AA1: ' + splitter + ' record_counter: ' + str(record_count[splitter]))
            # print(timeseries_summary)
            # print('AA2: ' + splitter + ' view_name: ' + view_name)

            extract_subsets_values(allowed_fields_in, subset_temp_values, split_record)

            if len(str(view_name_md5)) == 32:
                processed_record_template['view_name_hash'] = view_name_md5
            else:
                #print('ERROR - no HASH created for file '+ file_name + ' hash:' + str(view_name_hash) + ' len:'+str(len(str(view_name_hash))))
                print('ERROR - no HASH created for file ' + file_name)



            if sdg_code not in processed_records:
                processed_records[sdg_code] = {}
            if admin_level not in processed_records[sdg_code]:
                processed_records[sdg_code][admin_level] = []

            #print('RRR record_counter: ' + str(record_count))
            # print (processed_record_template)
            processed_records[sdg_code][admin_level].extend(process_value_fields(split_record, processed_record_template))

        # some files do not have an indicator at all: skip them
        if len(indicator) > 0:
            merge_subsets_summary(subsets_summary, sdg_code, admin_level, indicator, subset_temp_values)

def calculate_view_name_md5(admin_level, file_name, lut_file_names, sdg_code, split_record, splitter, view_name):
    try:
        if sdg_code not in lut_file_names:
            lut_file_names[sdg_code] = {}
        if admin_level not in lut_file_names[sdg_code]:
            lut_file_names[sdg_code][admin_level] = {}

        view_name_path = sdg_code + '/' + admin_level + '/' + view_name
        view_name_md5 = hashlib.md5(view_name_path.encode('utf-8')).hexdigest()  # md5

        if view_name_md5 not in lut_file_names[sdg_code][admin_level]:
            lut_file_names[sdg_code][admin_level][
                view_name_md5] = sdg_code + '/' + admin_level + '/' + file_name + ':' + view_name_path
            print('OK file name was added')
        else:
            print(
                "\n" + '####file name was already present: ' + sdg_code + '/' + admin_level + '/' + file_name + ' as: ' + view_name_md5 + ' spliiter: ' + splitter)
            print(split_record)
    except:
        print('error on file name hash ')
    return view_name_md5


def populate_timeseries_summary(admin_level, file_name, indicator, record, sdg_code, timeseries, timeseries_summary,
                                unit, view_name):
    # print('PSDF: '+file_name+' '+sdg_code+' '+admin_level+' '+indicator_clean+' '+timeseries+' '+view_name)
    if sdg_code not in timeseries_summary:
        timeseries_summary[sdg_code] = {}
    if admin_level not in timeseries_summary[sdg_code]:
        timeseries_summary[sdg_code][admin_level] = {}
    if indicator not in timeseries_summary[sdg_code][admin_level]:
        timeseries_summary[sdg_code][admin_level][indicator] = {}
    if timeseries not in timeseries_summary[sdg_code][admin_level][indicator]:
        timeseries_summary[sdg_code][admin_level][indicator][timeseries] = {}
    if 'file_name' not in timeseries_summary[sdg_code][admin_level][indicator][timeseries]:
        timeseries_summary[sdg_code][admin_level][indicator][timeseries]['file_name'] = {}
    if file_name not in timeseries_summary[sdg_code][admin_level][indicator][timeseries]:
        timeseries_summary[sdg_code][admin_level][indicator][timeseries]['file_name'][file_name] = 0
    if 'view_name' not in timeseries_summary[sdg_code][admin_level][indicator][timeseries]:
        timeseries_summary[sdg_code][admin_level][indicator][timeseries]['view_name'] = view_name
    if 'sdg_indicator' not in timeseries_summary[sdg_code][admin_level][indicator][timeseries]:
        timeseries_summary[sdg_code][admin_level][indicator][timeseries]['sdg_indicator'] = indicator
    if 'years' not in timeseries_summary[sdg_code][admin_level][indicator][timeseries]:
        timeseries_summary[sdg_code][admin_level][indicator][timeseries]['years'] = extract_years(record)
    timeseries_summary[sdg_code][admin_level][indicator][timeseries]['file_name'][file_name] += 1
    url = processing_options['pg_tileserv_base_url'] + sdg_code + '.' + view_name + processing_options[
        'pg_tileserv_suffix']
    md5_id = hashlib.md5(url.encode('utf-8')).hexdigest()  # md5
    timeseries_summary[sdg_code][admin_level][indicator][timeseries]['url'] = url
    timeseries_summary[sdg_code][admin_level][indicator][timeseries]['id'] = md5_id
    timeseries_summary[sdg_code][admin_level][indicator][timeseries]['unit'] = unit

def populate_subsets_summary(admin_level, file_name, indicator, record, lut_temp_values, sdg_code, timeseries, subsets_summary,
                                view_name):
    # print('PSDF: '+file_name+' '+sdg_code+' '+admin_level+' '+indicator_clean+' '+timeseries+' '+view_name)
    if sdg_code not in subsets_summary:
        subsets_summary[sdg_code] = {}
    if admin_level not in subsets_summary[sdg_code]:
        subsets_summary[sdg_code][admin_level] = {}
    if indicator not in subsets_summary[sdg_code][admin_level]:
        subsets_summary[sdg_code][admin_level][indicator] = {}

    if 'timeseries' not in subsets_summary[sdg_code][admin_level][indicator]:
        subsets_summary[sdg_code][admin_level][indicator]['timeseries'] = []

    if timeseries not in subsets_summary[sdg_code][admin_level][indicator]['timeseries']:
        subsets_summary[sdg_code][admin_level][indicator]['timeseries'].append(timeseries)

    if 'file_name' not in subsets_summary[sdg_code][admin_level][indicator]:
        subsets_summary[sdg_code][admin_level][indicator]['file_name'] = []
    if file_name not in subsets_summary[sdg_code][admin_level][indicator]['file_name']:
        subsets_summary[sdg_code][admin_level][indicator]['file_name'].append(file_name)

    #subsets_summary[sdg_code][admin_level][indicator]['description'] = ''
    if 'description' in lut_temp_values:
        subsets_summary[sdg_code][admin_level][indicator]['description'] = lut_temp_values['description']

    if 'years' not in subsets_summary[sdg_code][admin_level][indicator]:
        subsets_summary[sdg_code][admin_level][indicator]['years'] = []

    temp_list = subsets_summary[sdg_code][admin_level][indicator]['years']
    temp_list.extend(extract_years(record))
    temp_list = list(set(temp_list))
    subsets_summary[sdg_code][admin_level][indicator]['years'] = temp_list

    url = processing_options['pg_tileserv_base_url'] + sdg_code + '.' + view_name + processing_options[
        'pg_tileserv_suffix']
    subsets_summary[sdg_code][admin_level][indicator]['url'] = url


def extract_field_names(field_list,split_record):
    # loop on record's fields to extract field_list
    for field_name, field_value in split_record.items():

        if field_name not in field_list:
            field_list[field_name] = 0
        field_list[field_name] += 1


def extract_lut_temp_values(allowed_fields_in, lut_temp_values, split_record):
    # loop on record's fields to extract lut_temp_values
    for field_name, field_value in split_record.items():
        sanitized_field_name = sanitize_name(field_name)
        # all_rec_fields.append(sanitized_field_name)

        if sanitized_field_name in allowed_fields_in['lut'].keys():
            standardized_lut_field_name = allowed_fields_in['lut'][sanitized_field_name]
            # print(sanitized_field_name + ' -> '+standardized_field_name)
            lut_temp_values[standardized_lut_field_name] = field_value

def extract_subsets_values(allowed_fields_in, subset_temp_values, split_record):
    # loop on record's fields to extract subset_temp_values
    for field_name, field_value in split_record.items():
        sanitized_field_name = sanitize_name(field_name)
        # all_rec_fields.append(sanitized_field_name)

        if sanitized_field_name in allowed_fields_in['subsets'].keys():
            standardized_lut_field_name = allowed_fields_in['subsets'][sanitized_field_name]
            # print(sanitized_field_name + ' -> '+standardized_field_name)
            if standardized_lut_field_name not in subset_temp_values:
                subset_temp_values[standardized_lut_field_name] = []

            temp_array = subset_temp_values[standardized_lut_field_name]
            temp_array.append(field_value)
            temp_array = list(set(temp_array))
            subset_temp_values[standardized_lut_field_name] = temp_array
def merge_subsets_summary (subsets_summary, sdg_code, admin_level, indicator ,subset_temp_values):

    for subset_name, subset_array in subset_temp_values.items():
        if sdg_code not in subsets_summary:
            subsets_summary[sdg_code] = {}
        if admin_level not in subsets_summary[sdg_code]:
            subsets_summary[sdg_code][admin_level] = {}
        if indicator not in subsets_summary[sdg_code][admin_level]:
            subsets_summary[sdg_code][admin_level][indicator] = {}

        if 'subsets' not in subsets_summary[sdg_code][admin_level][indicator]:
            subsets_summary[sdg_code][admin_level][indicator]['subsets'] = {}

        if subset_name not in subsets_summary[sdg_code][admin_level][indicator]['subsets']:
            subsets_summary[sdg_code][admin_level][indicator]['subsets'][subset_name] = []

        # print( subsets_summary[sdg_code][admin_level][indicator]['subsets'][subset_name])
        # print(subset_array)

        temp_list = subsets_summary[sdg_code][admin_level][indicator]['subsets'][subset_name]
        temp_list.extend(subset_array)
        temp_list = list(set(temp_list))
        subsets_summary[sdg_code][admin_level][indicator]['subsets'][subset_name] = temp_list


def extract_processed_record_template(allowed_fields_in, processed_record_template, split_record):
    # loop on record's fields to extract processed_record_template
    for field_name, field_value in split_record.items():
        sanitized_field_name = sanitize_name(field_name)
        # all_rec_fields.append(sanitized_field_name)

        if sanitized_field_name in allowed_fields_in['admin'].keys():
            standardized_field_name = allowed_fields_in['admin'][sanitized_field_name]
            # print(sanitized_field_name + ' -> '+standardized_field_name)
            processed_record_template[standardized_field_name] = field_value

    # print('JJJ processed_record_template: ' + str(processed_record_template))
    # print('COUNT: ' + splitter + ': '+ str(record_count[splitter]) + '/' + str(nof_records))


def split_dbf_by_timeseries(allowed_fields_in, dbf_by_time_series, dbf_file, file_name, record_count):
    # subdivide the dbf file into subfiles by timeseries/series
    max_record_count = {}
    nof_records = 0
    for record in dbf_file:
        nof_records += 1
        curr_record_temp = {}

        # field name sanitization
        for field_name, field_value in record.items():
            sanitized_field_name = sanitize_name(field_name)
            if sanitized_field_name in allowed_fields_in['admin'].keys():
                standardized_field_name = allowed_fields_in['admin'][sanitized_field_name]
                curr_record_temp[standardized_field_name] = field_value

        split_by = ''

        if 'goal_code' in curr_record_temp and len(curr_record_temp['goal_code']) > 0:
            split_by = str(curr_record_temp['goal_code']) + '_'

        if 'indicator' in curr_record_temp and len(curr_record_temp['indicator']) > 0:
            split_by = split_by + str(curr_record_temp['indicator']) + '_'

        if 'timeseries' in curr_record_temp and len(curr_record_temp['timeseries']) > 0:
            split_by = split_by + curr_record_temp['timeseries']
        elif 'series' in curr_record_temp and len(curr_record_temp['series']) > 0:
            split_by = split_by + curr_record_temp['series']
        else:
            split_by = split_by + 'none'

        #print('split_by: ' + split_by)

        if len(split_by) < 1:
            print('Short splitter: ' + split_by + ' for: ' + file_name)

        if split_by not in record_count:
            record_count[split_by] = 0
        if split_by not in max_record_count:
            max_record_count[split_by] = 0

        max_record_count[split_by] += 1
        current_split_rec_count = max_record_count[split_by]

        if split_by not in dbf_by_time_series:
            dbf_by_time_series[split_by] = {}

        dbf_by_time_series[split_by][current_split_rec_count] = record
    return record


def process_dbf_files(root_dir_in, allowed_fields_in):
    """
    Recursively processes all DBF files in a directory and its subdirectories
    and writes the output to a JSON file.
    """
    file_details_list = []
    for root, dirs, files in os.walk(root_dir_in):
        for file in files:
            if file.endswith('.dbf'):
                dbf_file_path = os.path.join(root, file)
                file_details = process_dbf_file(dbf_file_path)
                file_details['file_name'] = file
                file_details_list.append(file_details)

    processed_records = {}
    lut_file_names = {}
    # the following is mainly to inspect the timeseries/file_name relationship:
    timeseries_summary = {}
    subsets_summary = {}
    field_list = {}

    error_files = []
    #
    # sorted_file_details_list = file_details_list.sort()

    for file_details in file_details_list:
        process_single_dbf_file(file_details, allowed_fields_in, lut_file_names, processed_records, timeseries_summary, subsets_summary, field_list, error_files)

    #            output_record['file_name'] = file_details['file_name']
    #            processed_records.append(output_record)
    #            print(processed_record_template)

    generate_sql_schemas(processed_records, '01_create_schemas.sql')
    generate_sql_tables(processed_records, '02_create_tables.sql')
    load_json_to_table(processed_records, '03_populate_tables.sql')
    generate_sql_views(processed_records, timeseries_summary, '04_create_views.sql')
    insert_into_geohub_dataset(timeseries_summary, '05_insert_into_dataset.sql')
    global_tags_in_use = identify_tags_in_use(timeseries_summary, 'global_tags_in_use.json')
    insert_into_geohub_tag(global_tags_in_use, '06_insert_into_tags.sql')
    insert_into_geohub_dataset_tag(timeseries_summary, '07_insert_into_dataset_tags.sql')

    parse_template_subset_function(subsets_summary, template_name)

    with open('output_sql.json', 'w') as f:
        json.dump(processed_records, f, indent=4)

    with open('lut_file_names.json', 'w') as f:
        json.dump(lut_file_names, f, indent=4, sort_keys=True)

    with open('timeseries_summary.json', 'w') as f:
        json.dump(timeseries_summary, f, indent=4, sort_keys=True)

    with open('error_files.json', 'w') as f:
        json.dump(error_files, f, indent=4, sort_keys=True)

    with open('subsets_summary.json', 'w') as f:
        json.dump(subsets_summary, f, indent=4, sort_keys=True)

    with open('field_list.json', 'w') as f:
        json.dump(field_list, f, indent=4, sort_keys=True)




    # with open('global_dbf_by_time_series.json', 'w') as f:
    #     json.dump(global_dbf_by_time_series, f, indent=4)

    # count individual views if dif
    # for splitter in global_dbf_by_time_series.keys():
    #     print('SPLITTER: ' + splitter)

####################################################################################

parser = argparse.ArgumentParser()
parser.add_argument("file_path", type=Path)

p = parser.parse_args()
p.file_path

if p.file_path.exists():
    #    root_dir = '....../vector_data/Vector_data/SDG1'
    root_dir = p.file_path
    process_dbf_files(root_dir, allowed_fields)

# TODO add comment on columns in tables
# TODO add PRIMARY KEY to tables @creation time, depending on the columns actually created
# TODO add indexes as a last step