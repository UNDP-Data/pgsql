import os
import dbfread
import json
import unicodedata
import argparse
from pathlib import Path
import hashlib

# to load the longest files (03_populate_tables.sql in particular) use pgAdmin, loading the file from the disk,
# as psql -1 -f echos back each INSERT, thus taking a very long time.

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
    "series": "series1",
    "timeseries": "series",
    "timeSeries": "series",
    # "Units_desc": "unit",
    # "units_desc": "unit",
    # "Units_code": "units_code",
    # "units_code": "units_code",
    "type": "type",
    "age_code": "age_code",
    "age code": "age_code",
    "sex_code": "sex_code",
    "sex code": "sex_code"
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

allowed_fields['column_comment'] = {
    "file_name": "Name of the original file",
    "goal_code": "SDG Goal code",
    "indicator": "SDG indicator",
    "iso3cd": "Standard ISO Country Code (3 letters)",
    "age_code": "Age Group code",
    "sex_code": "Gender code"
}

allowed_fields['unicode'] = {
    '\u00d4\u00c7\u00f4': "-",
    'ÔÇô': "-"
}



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
allowed_fields['pk'] = ["file_name_hash", "indicator", "series", "iso3cd", "age_code", "sex_code"]

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


def identify_tags_in_use(series_summary, file_path):
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

    data = series_summary
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
                for series, seies_data in indicator_data.items():

                    tags_in_use_series = tags_in_use_admin_level.copy()

                    # sdg_target
                    sdg_target = series_summary[schema_name][admin_level][indicator][series]['sdg_target']
                    global_tags_in_use = add_tag_in_use(global_tags_in_use, 'sdg_target', sdg_target)
                    tags_in_use_series = add_tag_in_use(tags_in_use_series, 'sdg_target', sdg_target)

                    # units
                    unit = series_summary[schema_name][admin_level][indicator][series]['unit']
                    global_tags_in_use = add_tag_in_use(global_tags_in_use, 'unit', unit)
                    tags_in_use_series = add_tag_in_use(tags_in_use_series, 'unit', unit)

                    #view
                    view_name = series_summary[schema_name][admin_level][indicator][series]['view_name']
                    global_tags_in_use = add_tag_in_use(global_tags_in_use, 'table', view_name)
                    tags_in_use_series = add_tag_in_use(tags_in_use_series, 'table', view_name)

                    # id (schema + view name)
                    schema_view_id = schema_name + '.' + view_name
                    global_tags_in_use = add_tag_in_use(global_tags_in_use, 'id', schema_view_id)
                    tags_in_use_series = add_tag_in_use(tags_in_use_series, 'id', schema_view_id)

                    # years
                    min_year = 9999
                    max_year = -9999
                    for this_year in series_summary[schema_name][admin_level][indicator][series]['years']:
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

                    series_string = series_summary[schema_name][admin_level][indicator][series]['series_tag']
                    series_string = series_string.replace("'", '"')
                    #print('series_string:'+series_string)

                    series_tags = []
                    series_tags.append(json.loads(series_string))

                    # needs fixing
                    # for series_tag in series_tags:
                    #     global_tags_in_use = add_tag_in_use(global_tags_in_use, 'theme', series_tag)
                    #     tags_in_use_series = add_tag_in_use(tags_in_use_series, 'theme', series_tag)

                    series_summary[schema_name][admin_level][indicator][series]['tags'] = tags_in_use_series

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


def insert_into_geohub_dataset_tag(series_summary, sql_file_path):
    data = series_summary
    with open(sql_file_path, 'w') as sql_file:
        sql_file.write("BEGIN TRANSACTION;")
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                for indicator, indicator_data in admin_data.items():
                    for series, series_data in indicator_data.items():
                        series_tags = series_summary[schema_name][admin_level][indicator][series]['tags']
                        series_id = series_summary[schema_name][admin_level][indicator][series]['id']
                        sql_statement_del = f'''
                            --DELETE FROM geohub.dataset_tag WHERE dataset_id = '{series_id}';
                            '''
                        sql_file.write(sql_statement_del)

                        for key, values in series_tags.items():
                            for value in values:
                                sql_statement = f'''
        -- -- -- series:{series} series_id: {series_id} tag: {value}
        INSERT INTO geohub.dataset_tag (dataset_id, tag_id) VALUES ('{series_id}',(SELECT id FROM geohub.tag WHERE key='{key}' AND value='{value}'))  ON CONFLICT DO NOTHING;
        --DELETE FROM geohub.dataset_tag WHERE dataset_id='{series_id}';
        '''
                                # print (series+' '+series_id+' '+key+' '+value)

                            # print (sql_statement)
                            sql_file.write(sql_statement)
                        # print('SQL futures:')
        sql_file.write("\nCOMMIT;")

def insert_into_geohub_dataset(series_summary, sql_file_path):
    # INSERT INTO geohub.dataset(id, url, is_raster, license, bounds, createdat, updatedat, name, description, created_user, updated_user)
    # VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

    with open(sql_file_path, 'w') as sql_file:
        sql_file.write("BEGIN TRANSACTION;")
        data = series_summary
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                bounds = '(SELECT ST_SetSRID(ST_Extent(geom),' + processing_options['SRID'] + ')  AS geom FROM ' + \
                         processing_options['base_' + admin_level + '_vector_layer'] + ')'
                for indicator, indicator_data in admin_data.items():
                    for series, series_data in indicator_data.items():
                        #view_name = series_summary[schema_name][admin_level][indicator][series]['view_name']

                        url = series_summary[schema_name][admin_level][indicator][series]['url']
                        series_id = series_summary[schema_name][admin_level][indicator][series]['id']

                        is_raster = False
                        layer_license = 'Creative Commons BY NonCommercial ShareAlike 4.0'
                        name = series_summary[schema_name][admin_level][indicator][series]['description']
                        name = name.replace("'", "''")
                        series_description = series_summary[schema_name][admin_level][indicator][series]['description']
                        series_description = series_description.replace("'", "''")
                        created_user = processing_options['created_by_user']
                        updated_user = processing_options['created_by_user']

                        sql_statement = f'''
    INSERT INTO geohub.dataset(id, url, is_raster, license, bounds, createdat, updatedat, name, description, created_user, updated_user)
    VALUES ('{series_id}', '{url}', {is_raster}, '{layer_license}', {bounds}, current_timestamp, current_timestamp, '{name}', '{series_description}', '{created_user}', '{updated_user}');
    --DELETE FROM geohub.dataset WHERE id ='{series_id}';
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


def generate_sql_views(json_obj, series_summary, sql_file_path):
    with open(sql_file_path, 'w') as sql_file:
        data = series_summary
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                for indicator, indicator_data in admin_data.items():
                    indicator_clean = indicator.replace(".", "_")
                    for series, series_data in indicator_data.items():
                        series_description = series_summary[schema_name][admin_level][indicator][series]['description']
                        series_description = series_description.replace("'","''")
                        view_name = series_summary[schema_name][admin_level][indicator][series]['view_name']

                        # each feature must be present only once, hence the "DISTINCT ON":
                        sql_statement = f'''
                            DROP VIEW IF EXISTS {schema_name}."{view_name}";
                            CREATE VIEW {schema_name}."{view_name}" AS
                            SELECT DISTINCT ON (a.geom) a.id, a.geom, s.* from
                            admin.{admin_level} AS a
                            INNER JOIN {schema_name}.{admin_level} AS s ON (a.iso3cd = s.iso3cd)
                            WHERE s."indicator"='{indicator}' AND s."series" ='{series}';
                            COMMENT ON VIEW {schema_name}."{view_name}" IS '{series_description}';
                            --  DROP VIEW {schema_name}."{view_name}";
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


def process_single_dbf_file(file_details, allowed_fields_in, lut_file_names, processed_records, series_summary):
    print()
    print(os.path.join(file_details['dir'], file_details['file_name']))

    dbf_file = dbfread.DBF(os.path.join(file_details['dir'], file_details['file_name']), encoding='cp852')
    file_name = sanitize_name(file_details['file_name'])

    sdg_code = 'sdg_others'
    record_count = 0
    admin_level = 'admin0'

    for record in dbf_file:

        record_count += 1
        processed_record_template = {}
        lut_temp_values = {}
        processed_record_template['file_name'] = file_name
        # all_rec_fields = []

        for field_name, field_value in record.items():
            sanitized_field_name = sanitize_name(field_name)
            # all_rec_fields.append(sanitized_field_name)

            if sanitized_field_name in allowed_fields_in['admin'].keys():
                standardized_field_name = allowed_fields_in['admin'][sanitized_field_name]
                # print(sanitized_field_name + ' -> '+standardized_field_name)
                processed_record_template[standardized_field_name] = field_value

            if sanitized_field_name in allowed_fields_in['lut'].keys():
                standardized_lut_field_name = allowed_fields_in['lut'][sanitized_field_name]
                # print(sanitized_field_name + ' -> '+standardized_field_name)
                lut_temp_values[standardized_lut_field_name] = field_value

        if record_count == 1:
            # print(all_rec_fields)
            try:
                admin_level_name = processed_record_template['type']
                admin_level = 'admin' + str(admin_level_lut[admin_level_name])

                sdg_code = pad_sdg(processed_record_template['goal_code'])
                indicator = processed_record_template['indicator']
                series = processed_record_template['series']

                admin_level_name = processed_record_template['type']
                admin_level = 'admin' + str(admin_level_lut[admin_level_name])
                indicator_clean = indicator.replace(".", "_")
                view_name = indicator_clean + "_" + series + "_view"
                unit = lut_temp_values['unit'].lower()

                #print('PSDF: '+file_name+' '+sdg_code+' '+admin_level+' '+indicator_clean+' '+series+' '+view_name)
                if sdg_code not in series_summary:
                    series_summary[sdg_code] = {}
                if admin_level not in series_summary[sdg_code]:
                    series_summary[sdg_code][admin_level] = {}
                if indicator not in series_summary[sdg_code][admin_level]:
                    series_summary[sdg_code][admin_level][indicator] = {}

                if series not in series_summary[sdg_code][admin_level][indicator]:
                    series_summary[sdg_code][admin_level][indicator][series] = {}

                if 'file_name' not in series_summary[sdg_code][admin_level][indicator][series]:
                    series_summary[sdg_code][admin_level][indicator][series]['file_name'] = {}

                if file_name not in series_summary[sdg_code][admin_level][indicator][series]:
                    series_summary[sdg_code][admin_level][indicator][series]['file_name'][file_name] = 0
                if 'view_name' not in series_summary[sdg_code][admin_level][indicator][series]:
                    series_summary[sdg_code][admin_level][indicator][series]['view_name'] = view_name
                if 'sdg_indicator' not in series_summary[sdg_code][admin_level][indicator][series]:
                    series_summary[sdg_code][admin_level][indicator][series]['sdg_indicator'] = indicator

                if 'years' not in series_summary[sdg_code][admin_level][indicator][series]:
                    series_summary[sdg_code][admin_level][indicator][series]['years'] = extract_years(record)

                series_summary[sdg_code][admin_level][indicator][series]['file_name'][file_name] += 1
                url = processing_options['pg_tileserv_base_url'] + sdg_code + '.' + view_name + processing_options[
                    'pg_tileserv_suffix']
                md5_id = hashlib.md5(url.encode('utf-8')).hexdigest()  # md5
                series_summary[sdg_code][admin_level][indicator][series]['url'] = url
                series_summary[sdg_code][admin_level][indicator][series]['id'] = md5_id
                series_summary[sdg_code][admin_level][indicator][series]['unit'] = unit

                for lut_field_name, lut_field_value in lut_temp_values.items():
                    if lut_field_name in lut_temp_values:
                        series_summary[sdg_code][admin_level][indicator][series][lut_field_name] = lut_temp_values[lut_field_name]
                # if 'series_tag' in lut_temp_values:
                #     series_summary[sdg_code][admin_level][indicator][series]['series_tag'] = lut_temp_values['series_tag']

            except:
                print('NOK ' + file_name + ' sdg_code: ' + str(sdg_code))
            else:
                print('OK ' + file_name + ' sdg_code: ' + str(sdg_code))

            try:
                if sdg_code not in lut_file_names:
                    lut_file_names[sdg_code] = {}
                if admin_level not in lut_file_names[sdg_code]:
                    lut_file_names[sdg_code][admin_level] = {}

                file_name_path = sdg_code + '/' + admin_level + '/' + file_name
                file_name_md5 = hashlib.md5(file_name_path.encode('utf-8')).hexdigest()  # md5

                if file_name_md5 not in lut_file_names[sdg_code][admin_level]:
                    lut_file_names[sdg_code][admin_level][file_name_md5] = sdg_code + '/' + admin_level + '/' + file_name
                    print('OK file name was added')
                else:
                    print("\n"+'####file name was already present: '+ sdg_code + '/' + admin_level + '/' + file_name)
            except:
                print('error on file name hash ')

        if len(str(file_name_md5)) == 32:
            processed_record_template['file_name_hash'] = file_name_md5
        else:
            #print('ERROR - no HASH created for file '+ file_name + ' hash:' + str(file_name_hash) + ' len:'+str(len(str(file_name_hash))))
            print('ERROR - no HASH created for file ' + file_name)


        if sdg_code not in processed_records:
            processed_records[sdg_code] = {}
        if admin_level not in processed_records[sdg_code]:
            processed_records[sdg_code][admin_level] = []

        # print (processed_record_template)
        processed_records[sdg_code][admin_level].extend(process_value_fields(record, processed_record_template))


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
    # the following is mainly to inspect the series/file_name relationship:
    series_summary = {}

    for file_details in file_details_list:
        process_single_dbf_file(file_details, allowed_fields_in, lut_file_names, processed_records, series_summary)

    #            output_record['file_name'] = file_details['file_name']
    #            processed_records.append(output_record)
    #            print(processed_record_template)

    generate_sql_schemas(processed_records, '01_create_schemas.sql')
    generate_sql_tables(processed_records, '02_create_tables.sql')
    load_json_to_table(processed_records, '03_populate_tables.sql')
    generate_sql_views(processed_records, series_summary, '04_create_views.sql')
    insert_into_geohub_dataset(series_summary, '05_insert_into_dataset.sql')
    global_tags_in_use = identify_tags_in_use(series_summary, 'global_tags_in_use.json')
    insert_into_geohub_tag(global_tags_in_use, '06_insert_into_tags.sql')
    insert_into_geohub_dataset_tag(series_summary, '07_insert_into_dataset_tags.sql')

    with open('output_sql.json', 'w') as f:
        json.dump(processed_records, f, indent=4)

    with open('lut_file_names.json', 'w') as f:
        json.dump(lut_file_names, f, indent=4)

    with open('series_summary.json', 'w') as f:
        json.dump(series_summary, f, indent=4)

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
