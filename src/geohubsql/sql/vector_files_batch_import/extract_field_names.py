import os
import dbfread
import json
import unicodedata
import argparse
from pathlib import Path

processing_options = {
    'each_yearly_value_to_new_record':False,
    'tileserv_user':'tileserver',
    'base_admin0_vector_layer':'admin.admin0',
    'base_admin1_vector_layer': 'admin.admin1',
    'base_admin2_vector_layer': 'admin.admin2'
}


def pad_sdg(sdg):

    return 'sdg'+str(sdg).zfill(2)

def sanitize_name(name):
    """
    Sanitizes a field name by removing non-ascii characters, converting
    the name to lowercase, and converting spaces to underscores.
    """
    return unicodedata.normalize('NFKD', name).encode('ASCII', 'ignore').decode('utf-8').lower().replace(' ', '_')
#    return name

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


def generate_sql_views(json_obj, lut_indicators, sql_file_path):
    with open(sql_file_path, 'w') as sql_file:
        data = lut_indicators
        for schema_name, schema_data in data.items():
            for admin_level, admin_data in schema_data.items():
                for indicator, indicator_data in admin_data.items():
                    indicator_clean = indicator.replace(".", "_")
                    indicator_description = lut_indicators[schema_name][admin_level][indicator]['description']

                    #each feature must be present only once, hence the "DISTINCT ON":
                    sql_statement = f'''
                        DROP VIEW IF EXISTS {schema_name}."{indicator_clean}_view";
                        CREATE VIEW {schema_name}."{indicator_clean}_view" AS
                        SELECT DISTINCT ON (a.geom) a.fid, a.geom, s.* from
                        admin.{admin_level} AS a
                        INNER JOIN {schema_name}.{admin_level} AS s ON (a.iso3cd = s.iso3cd)
                        WHERE s."indicator_1"='{indicator}';
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
            sql_file.write(f"GRANT SELECT,EXECUTE,USAGE ON ALL TABLES IN SCHEMA {schema_name} TO {processing_options['tileserv_user']};\n")
            sql_file.write("\n")


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


def process_single_dbf_file(file_details, allowed_fields, lut_file_names, output_records, lut_indicators):

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
                indicator= output_record_template['indicator_1']
                admin_level_name = output_record_template['type']
                admin_level = 'admin' + str(admin_level_lut[admin_level_name])
                # print('PSDF: '+file_name+' '+sdg_code+' '+admin_level+' '+indicator)
                if sdg_code not in lut_indicators:
                    lut_indicators[sdg_code] = {}
                if admin_level not in lut_indicators[sdg_code]:
                    lut_indicators[sdg_code][admin_level] = {}
                if indicator not in lut_indicators[sdg_code]:
                    lut_indicators[sdg_code][admin_level][indicator] = {}
                if 'file_name' not in lut_indicators[sdg_code][admin_level][indicator]:
                    lut_indicators[sdg_code][admin_level][indicator]['file_name'] = {}
                if file_name not in lut_indicators[sdg_code][admin_level][indicator]:
                    lut_indicators[sdg_code][admin_level][indicator]['file_name'][file_name] = 0

                lut_indicators[sdg_code][admin_level][indicator]['file_name'][file_name]+=1

                for lut_field_name, lut_field_value in lut_temp_values.items():
                    if lut_field_name in lut_temp_values:
                        lut_indicators[sdg_code][admin_level][indicator][lut_field_name] = lut_temp_values[lut_field_name]
                # if 'series_tag' in lut_temp_values:
                #     lut_indicators[sdg_code][admin_level][indicator]['series_tag'] = lut_temp_values['series_tag']


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
    lut_indicators = {}

    for file_details in file_details_list:

        process_single_dbf_file(file_details, allowed_fields, lut_file_names, output_records, lut_indicators)

    #            output_record['file_name'] = file_details['file_name']
#            output_records.append(output_record)
#            print(output_record_template)

    with open('output_sql.json', 'w') as f:
        json.dump(output_records, f, indent=4)

    with open('lut_file_names.json', 'w') as f:
        json.dump(lut_file_names, f, indent=4)

    with open('lut_indicators.json', 'w') as f:
        json.dump(lut_indicators, f, indent=4)


    generate_sql_schemas(output_records, 'create_schemas.sql')
    generate_sql_tables(output_records, 'create_tables.sql')
    load_json_to_table(output_records, 'populate_tables.sql')
    generate_sql_views(output_records, lut_indicators, 'create_views.sql')

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
    "indicato_1":"indicator_1",
    "indicator_1": "indicator_1",
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
    "seriesDesc":"seriesDesc"
}

admin_level_lut = {
    "Country":0,
    "Region":1,
    "Province":2
}



parser = argparse.ArgumentParser()
parser.add_argument("file_path", type=Path)

p = parser.parse_args()
p.file_path



if p.file_path.exists():
#    root_dir = '....../vector_data/Vector_data/SDG1'
    root_dir = p.file_path
    process_dbf_files(root_dir, allowed_fields)
