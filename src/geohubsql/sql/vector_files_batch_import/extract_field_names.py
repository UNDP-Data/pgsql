import os
import dbfread
import json
import unicodedata
import argparse
from pathlib import Path
import hashlib

processing_options = {
    'each_yearly_value_to_new_record':False,
    'tileserv_user':'tileserver',
    'base_admin0_vector_layer':'admin.admin0',
    'base_admin1_vector_layer': 'admin.admin1',
    'base_admin2_vector_layer': 'admin.admin2',
    'pg_tileserv_base_url': 'https://pgtileserv.undpgeohub.org/',
    'pg_tileserv_suffix': '/{z}/{x}/{y}.pbf',
    'SRID': '4326',
    'created_by_user': 'douglas.tommasi@undp.org'
}


allowed_fields = {}

allowed_fields['admin'] = {
    "goal_code":"goal_code",
    "goal_cod": "goal_code",
    "iso3":"iso3cd",
    "iso3c":"iso3cd",
    "iso3cd":"iso3cd",
    # "objectid":"objectid",
    # "objectid 1": "objectid_1",
    # "objectid_1": "objectid_1",
    "target_cod":"target_code",
    "target_code":"target_code",
    "indicato_1":"indicator",
    "indicator_1": "indicator",
    "Units_desc": "unit",
    "units_desc": "unit",
    "Units_code": "units_code",
    "units_code": "units_code",
    "type": "type",
    "age_code": "age_code",
    "age code": "age_code",
    "sex_code": "sex_code",
    "sex code": "sex_code"
}

#fields useful to gather one-per-file information like tags, descriptions, etc
allowed_fields['lut'] = {
    "indicato_2": "description",
    "indicator_2": "description",
    "series_rel":"series_rel",
    "series_tag":"series_tag",
    "series":"series",
    "seriesDesc":"seriesDesc",
    "Units_code":"unit_code",
    "Units_desc":"units_desc"
}

#used to create a compound primary key, depending on the columns actually created in a specific table
allowed_fields['pk'] = ["file_name_hash","indicator","iso3cd","age_code","sex_code"]

admin_level_lut = {
    "Country":0,
    "Region":1,
    "Province":2
}

def pad_sdg(sdg):
#n -> sdg0n
    return 'sdg'+str(sdg).zfill(2)

def unpad_sdg(sdg_code):
#sdg0n -> n
#import re
#    return re.sub("sdg[01]?", "", sdg_code)
    return sdg_code.removeprefix('sdg0').removeprefix('sdg1')

def sanitize_name(name):
    """
    Sanitizes a field name by removing non-ascii characters, converting
    the name to lowercase, and converting spaces to underscores.
    """
    return unicodedata.normalize('NFKD', name).encode('ASCII', 'ignore').decode('utf-8').lower().replace(' ', '_')
#    return name

def add_tag_in_use(global_tags_in_use,key,value):
    if key not in global_tags_in_use:
        global_tags_in_use[key] = []
    if not value in global_tags_in_use[key]:
        global_tags_in_use[key].append(value)

    return global_tags_in_use
def identify_tags_in_use(indicators_summary, file_path):

    # will be used to update the "tag" table
    #global_tags_in_use['extent'] = ['Global','Asia','China']
    global_tags_in_use = {}

    #will be used as a template for the deeper levels and, ultimately to update the "dataset_tag" table
    proto_tags_in_use = {}

    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'geometrytype','MultiPolygon')
    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'layertype', 'table')
    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'provider', 'United Nations Development Programme (UNDP)')
    proto_tags_in_use = add_tag_in_use(proto_tags_in_use, 'type', 'pgtileserv')

    global_tags_in_use = proto_tags_in_use.copy()

    data = indicators_summary
    for schema_name, schema_data in data.items():
        tags_in_use_schema = proto_tags_in_use.copy()
        #sdg_goal
        global_tags_in_use = add_tag_in_use(global_tags_in_use, 'sdg_goal',unpad_sdg(schema_name))
        tags_in_use_schema = add_tag_in_use(tags_in_use_schema, 'sdg_goal',unpad_sdg(schema_name))

        #schema
        global_tags_in_use = add_tag_in_use(global_tags_in_use, 'schema', schema_name)
        tags_in_use_schema = add_tag_in_use(tags_in_use_schema, 'schema', schema_name)

        for admin_level, admin_data in schema_data.items():
            tags_in_use_admin_level = tags_in_use_schema.copy()

            if admin_level == 'admin0':
                global_tags_in_use = add_tag_in_use(global_tags_in_use, 'extent', 'Global')
                tags_in_use_admin_level = add_tag_in_use(tags_in_use_admin_level, 'extent', 'Global')

            for indicator, indicator_data in admin_data.items():
                tags_in_use_indicator = tags_in_use_admin_level.copy()
                local_tags_in_use = {}
                #units
                unit = indicators_summary[schema_name][admin_level][indicator]['unit']
                global_tags_in_use = add_tag_in_use(global_tags_in_use,'unit',unit)
                tags_in_use_indicator = add_tag_in_use(tags_in_use_indicator, 'unit', unit)

                view_name = indicators_summary[schema_name][admin_level][indicator]['view_name']
                global_tags_in_use = add_tag_in_use(global_tags_in_use, 'table', view_name)
                tags_in_use_indicator = add_tag_in_use(tags_in_use_indicator, 'table', view_name)

                id = schema_name+'.'+view_name
                global_tags_in_use = add_tag_in_use(global_tags_in_use, 'id', id)
                tags_in_use_indicator = add_tag_in_use(tags_in_use_indicator, 'id', id)

                # years
                for this_year in indicators_summary[schema_name][admin_level][indicator]['years']:
                    global_tags_in_use = add_tag_in_use(global_tags_in_use, 'year', this_year)
                    tags_in_use_indicator = add_tag_in_use(tags_in_use_indicator, 'year', this_year)
#                print('TIUI: ')
#                print(tags_in_use_indicator)
                indicators_summary[schema_name][admin_level][indicator]['tags'] = tags_in_use_indicator

    with open(file_path, 'w') as file:
        json.dump(global_tags_in_use, file, indent=4)
    return global_tags_in_use

def insert_into_geohub_tag(global_tags_in_use, sql_file_path):

    with open(sql_file_path, 'w') as sql_file:
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

#    global_tags_in_use['extent'] = ['Global','Asia','China']



def insert_into_geohub_dataset_tag(indicators_summary, sql_file_path):

    data = indicators_summary
    with open(sql_file_path, 'w') as sql_file:
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                for indicator, indicator_data in admin_data.items():
                    indicator_tags = indicators_summary[schema_name][admin_level][indicator]['tags']
                    indicator_id = indicators_summary[schema_name][admin_level][indicator]['id']
                    sql_statement_del = f'''
                        --DELETE FROM geohub.dataset_tag WHERE dataset_id = '{indicator_id}';
                        '''
                    sql_file.write(sql_statement_del)

                    for key, values in indicator_tags.items():
                        for value in values:
                            sql_statement = f'''
    INSERT INTO geohub.dataset_tag (dataset_id, tag_id) VALUES ('{indicator_id}',(SELECT id FROM geohub.tag WHERE key='{key}' AND value='{value}'));
    '''
                            #print (indicator+' '+indicator_id+' '+key+' '+value)

                        # print (sql_statement)
                        sql_file.write(sql_statement)
                    # print('SQL futures:')


def insert_into_geohub_dataset(indicators_summary, sql_file_path):
    # INSERT INTO geohub.dataset(id, url, is_raster, license, bounds, createdat, updatedat, name, description, created_user, updated_user)
    # VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

    with open(sql_file_path, 'w') as sql_file:
        data = indicators_summary
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                bounds = '(SELECT ST_SetSRID(ST_Extent(geom),' + processing_options['SRID'] + ')  AS geom FROM ' + processing_options['base_'+admin_level+'_vector_layer'] + ')'
                for indicator, indicator_data in admin_data.items():
#                    view_name = indicators_summary[schema_name][admin_level][indicator]['view_name']

                    url = indicators_summary[schema_name][admin_level][indicator]['url']
                    id = indicators_summary[schema_name][admin_level][indicator]['id']

                    is_raster = False
                    license = 'Creative Commons BY NonCommercial ShareAlike 4.0'
                    # type:geometry use ST_Bbox / global / subselect?

                    name = indicators_summary[schema_name][admin_level][indicator]['description']
                    description = indicators_summary[schema_name][admin_level][indicator]['description']
                    created_user = processing_options['created_by_user']
                    updated_user = processing_options['created_by_user']

                    sql_statement = f'''
INSERT INTO geohub.dataset(id, url, is_raster, license, bounds, createdat, updatedat, name, description, created_user, updated_user)
VALUES ('{id}', '{url}', {is_raster}, '{license}', {bounds}, current_timestamp, current_timestamp, '{name}', '{description}', '{created_user}', '{updated_user}');
--DELETE FROM geohub.dataset WHERE id ='{id}';
                    '''
                    sql_file.write(sql_statement)


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


def generate_sql_views(json_obj, indicators_summary, sql_file_path):
    with open(sql_file_path, 'w') as sql_file:
        data = indicators_summary
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                for indicator, indicator_data in admin_data.items():
                    indicator_clean = indicator.replace(".", "_")
                    indicator_description = indicators_summary[schema_name][admin_level][indicator]['description']
                    view_name = indicators_summary[schema_name][admin_level][indicator]['view_name']

                    #each feature must be present only once, hence the "DISTINCT ON":
                    sql_statement = f'''
                        DROP VIEW IF EXISTS {schema_name}."{view_name}";
                        CREATE VIEW {schema_name}."{indicator_clean}_view" AS
                        SELECT DISTINCT ON (a.geom) a.id, a.geom, s.* from
                        admin.{admin_level} AS a
                        INNER JOIN {schema_name}.{admin_level} AS s ON (a.iso3cd = s.iso3cd)
                        WHERE s."indicator"='{indicator}';
                        COMMENT ON VIEW {schema_name}."{indicator_clean}_view" IS '{indicator_description}';
                        \n
'''

                    # TODO
                    # add comment on VIEW
                    # add layer_name ?


                    sql_file.write(sql_statement)
                    #processing_options[base_admin0_vector_layer]


def load_json_to_table(json_obj, sql_file_path):

    data = json_obj
    with open(sql_file_path, 'w') as query:
        for schema_name, schema_data in data.items():
            for table_name, table_data in schema_data.items():
                for row_data in table_data:
                    columns = ", ".join(row_data.keys())
                    values = ", ".join(f"'{v}'" for v in row_data.values())
                    query.write(f"INSERT INTO {schema_name}.{table_name} ({columns}) VALUES ({values});\n\n")

        query.write("\n")

def generate_sql_tables(json_obj, sql_file_path):
    with open(sql_file_path, 'w') as sql_file:
        data = json_obj
        for schema_name, schema_data in data.items():
            for table_name, table_data in schema_data.items():
                column_names = set()
                for row in table_data:
                    column_names.update(row.keys())
                sql_file.write(f"CREATE TABLE IF NOT EXISTS {schema_name}.{table_name} (\n")
                col_count=0
                separator=''
                for column_name in sorted(column_names):
                    if col_count > 0:
                        separator=',\n';
                    col_count+=1
                    data_type = 'numeric' if column_name.startswith('value_') else 'text'
                    sql_file.write(f"{separator}    {column_name} {data_type}")
                sql_file.write(");\n\n")

def generate_sql_schemas(json_obj, sql_file_path):
    with open(sql_file_path, 'w') as sql_file:
        data = json_obj
        for schema_name, schema_data in data.items():
            sql_file.write(f"CREATE SCHEMA IF NOT EXISTS {schema_name};\n")
            sql_file.write(f"GRANT SELECT,USAGE ON ALL TABLES IN SCHEMA {schema_name} TO {processing_options['tileserv_user']};\n")
            sql_file.write("\n")

def extract_years(record):

    years_in_use = []

    for field_name, field_value in record.items():
        if isinstance(field_value, (int, float)) and field_name.startswith('value'):
            #extract years from all column names, does not check that at least one row ha non-zero values for each year column
            year = str(field_name).removeprefix('value_').removeprefix('value ')
            years_in_use.append(year)

    return years_in_use

def process_value_fields(record, output_record_template):
    """
    Processes value fields in a record and returns a list of dictionaries
    representing the valid values.
    """
    process_output_records = []
    if (processing_options['each_yearly_value_to_new_record']):
        for field_name, field_value in record.items():
            if isinstance(field_value, (int, float)) and field_name.startswith('value'):
                if field_value != 0:
    #                print("field_name: " + field_name + " field_value: " + str(field_value))

                    output_record = output_record_template.copy()
                    output_record['year'] = str(field_name).removeprefix('value_').removeprefix('value ')
                    output_record['year_value'] = round(field_value,3)
                    process_output_records.append(output_record)

            ## Would create a type mismatch.
            ## Create a SQL views instead with order by desc / limit
            # if isinstance(field_value, (int, float)) and (field_name == ('latest')):
            #     if field_value != 0:
            #         output_record = output_record_template.copy()
            #         output_record['year'] = 'latest'
            #         output_record['year_value'] = round(field_value, 3)
            #         process_output_records.append(output_record)

    else:

        output_record = output_record_template.copy()

        for field_name, field_value in record.items():
            if isinstance(field_value, (int, float)) and field_name.startswith('value'):
                if field_value != 0:
                    year = str(field_name).removeprefix('value_').removeprefix('value ')
                    output_record['value_'+year] = round(field_value,3)
            if isinstance(field_value, (int, float)) and (field_name == ('latest_val')):
                if field_value != 0:
                    output_record['value_latest'] = round(field_value, 3)

        process_output_records.append(output_record)

    return process_output_records


def process_single_dbf_file(file_details, allowed_fields, lut_file_names, output_records, indicators_summary):

    print()
    print(os.path.join(file_details['dir'], file_details['file_name']))

    dbf_file = dbfread.DBF(os.path.join(file_details['dir'], file_details['file_name']), encoding='cp852')
    file_name = sanitize_name(file_details['file_name'])

    sdg_code = 'sdg_others'
    record_count = 0
    admin_level = 'admin0'

    for record in dbf_file:

        record_count += 1
        output_record_template = {}
        lut_temp_values = {}
        output_record_template['file_name'] = file_name

        for field_name, field_value in record.items():
            sanitized_field_name = sanitize_name(field_name)

            if sanitized_field_name in allowed_fields['admin'].keys():
                standardized_field_name = allowed_fields['admin'][sanitized_field_name]
                #print(sanitized_field_name + ' -> '+standardized_field_name)
                output_record_template[standardized_field_name] = field_value

            if sanitized_field_name in allowed_fields['lut'].keys():
                standardized_lut_field_name = allowed_fields['lut'][sanitized_field_name]
                #print(sanitized_field_name + ' -> '+standardized_field_name)
                lut_temp_values[standardized_lut_field_name] = field_value

        if (record_count == 1):
            try:
                admin_level_name = output_record_template['type']
                admin_level = 'admin' + str(admin_level_lut[admin_level_name])

                sdg_code = pad_sdg(output_record_template['goal_code'])
                indicator= output_record_template['indicator']
                admin_level_name = output_record_template['type']
                admin_level = 'admin' + str(admin_level_lut[admin_level_name])
                indicator_clean = indicator.replace(".", "_")
                view_name = indicator_clean+"_view"
                unit = output_record_template['unit'].lower()

                # print('PSDF: '+file_name+' '+sdg_code+' '+admin_level+' '+indicator)
                if sdg_code not in indicators_summary:
                    indicators_summary[sdg_code] = {}
                if admin_level not in indicators_summary[sdg_code]:
                    indicators_summary[sdg_code][admin_level] = {}
                if indicator not in indicators_summary[sdg_code]:
                    indicators_summary[sdg_code][admin_level][indicator] = {}
                if 'file_name' not in indicators_summary[sdg_code][admin_level][indicator]:
                    indicators_summary[sdg_code][admin_level][indicator]['file_name'] = {}
                if file_name not in indicators_summary[sdg_code][admin_level][indicator]:
                    indicators_summary[sdg_code][admin_level][indicator]['file_name'][file_name] = 0
                if 'view_name' not in indicators_summary[sdg_code][admin_level][indicator]:
                    indicators_summary[sdg_code][admin_level][indicator]['view_name'] = view_name

                if 'years' not in indicators_summary[sdg_code][admin_level][indicator]:
                    indicators_summary[sdg_code][admin_level][indicator]['years'] = extract_years(record)

                indicators_summary[sdg_code][admin_level][indicator]['file_name'][file_name]+=1
                url = processing_options['pg_tileserv_base_url'] + sdg_code + '.' + view_name + processing_options['pg_tileserv_suffix']
                id = hashlib.md5(url.encode('utf-8')).hexdigest()  # md5
                indicators_summary[sdg_code][admin_level][indicator]['url'] = url
                indicators_summary[sdg_code][admin_level][indicator]['id'] = id
                indicators_summary[sdg_code][admin_level][indicator]['unit'] = unit

                for lut_field_name, lut_field_value in lut_temp_values.items():
                    if lut_field_name in lut_temp_values:
                        indicators_summary[sdg_code][admin_level][indicator][lut_field_name] = lut_temp_values[lut_field_name]
                # if 'series_tag' in lut_temp_values:
                #     indicators_summary[sdg_code][admin_level][indicator]['series_tag'] = lut_temp_values['series_tag']


            except:
                print('NOK ' + file_name + ' sdg_code: ' + str(sdg_code))
            else:
                print('OK ' + file_name + ' sdg_code: ' + str(sdg_code))

            try:
                if sdg_code not in lut_file_names:
                    lut_file_names[sdg_code] = {}
                if admin_level not in lut_file_names[sdg_code]:
                    lut_file_names[sdg_code][admin_level] = {}

                file_name_hash = hash(sdg_code + '/' + admin_level + '/' + file_name)

                if file_name_hash not in lut_file_names[sdg_code][admin_level]:
                    lut_file_names[sdg_code][admin_level][
                        file_name_hash] = sdg_code + '/' + admin_level + '/' + file_name
                    print('file name was added')
                else:
                    print('file name was already present')
            except:
                print('error on file name hash ')

        output_record_template['file_name_hash'] = file_name_hash

        if sdg_code not in output_records:
            output_records[sdg_code] = {}
        if admin_level not in output_records[sdg_code]:
            output_records[sdg_code][admin_level] = []

        # print (output_record_template)
        output_records[sdg_code][admin_level].extend(process_value_fields(record, output_record_template))




def process_dbf_files(root_dir, allowed_fields):
    """
    Recursively processes all DBF files in a directory and its subdirectories
    and writes the output to a JSON file.
    """
    file_details_list = []
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.dbf'):
                dbf_file_path = os.path.join(root, file)
                file_details = process_dbf_file(dbf_file_path)
                file_details['file_name'] = file
                file_details_list.append(file_details)

    output_records = {}
    lut_file_names = {}
    #the following is mainly to inspect the indicators/file_name relationship:
    indicators_summary = {}

    for file_details in file_details_list:

        process_single_dbf_file(file_details, allowed_fields, lut_file_names, output_records, indicators_summary)

    #            output_record['file_name'] = file_details['file_name']
#            output_records.append(output_record)
#            print(output_record_template)




    generate_sql_schemas(output_records, 'create_schemas.sql')
    generate_sql_tables(output_records, 'create_tables.sql')
    load_json_to_table(output_records, 'populate_tables.sql')
    generate_sql_views(output_records, indicators_summary, 'create_views.sql')
    insert_into_geohub_dataset(indicators_summary, 'insert_into_dataset.sql')
    global_tags_in_use = identify_tags_in_use(indicators_summary,'global_tags_in_use.json')
    insert_into_geohub_tag(global_tags_in_use, 'insert_into_tags.sql')
    insert_into_geohub_dataset_tag(indicators_summary, 'insert_into_dataset_tags.sql')

    with open('output_sql.json', 'w') as f:
        json.dump(output_records, f, indent=4)

    with open('lut_file_names.json', 'w') as f:
        json.dump(lut_file_names, f, indent=4)

    with open('indicators_summary.json', 'w') as f:
        json.dump(indicators_summary, f, indent=4)


parser = argparse.ArgumentParser()
parser.add_argument("file_path", type=Path)

p = parser.parse_args()
p.file_path



if p.file_path.exists():
#    root_dir = '....../vector_data/Vector_data/SDG1'
    root_dir = p.file_path
    process_dbf_files(root_dir, allowed_fields)


#TODO add comment on columns in tables
#TODO add attrs to indicators_summary like:
    #tag
    #attribute
    #description
#TODO add PRIMARY KEY to tables @creation time, depending on the columns actually created