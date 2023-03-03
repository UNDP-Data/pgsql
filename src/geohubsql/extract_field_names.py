import os
import dbfread
import json
import unicodedata
import argparse
from pathlib import Path

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

def process_value_fields(record, output_record_template):
    """
    Processes value fields in a record and returns a list of dictionaries
    representing the valid values.
    """
    output_records = []
    for field_name, field_value in record.items():
        if isinstance(field_value, (int, float)) and field_name.startswith('value'):
            if field_value != 0:
                print("field_name: " + field_name + " field_value: " + str(field_value))
                output_record = output_record_template
                output_record['year'] = field_name
                output_record['year_value'] = field_value
                print(output_record)
                output_records.append(output_record)
                print(output_records)
                print()
    return output_records

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

    output_records = []
    for file_details in file_details_list:
        print()
        print (os.path.join(file_details['dir'], file_details['file_name']))
        dbf_file = dbfread.DBF(os.path.join(file_details['dir'], file_details['file_name']), encoding='cp852')
        file_name=sanitize_name(file_details['file_name'])
        sdg_code = 99
        record_count = 0
        for record in dbf_file:
            record_count+=1
            output_record_template = {}
            output_record_template['file_name'] = file_name
            for field_name, field_value in record.items():
                sanitized_field_name = sanitize_name(field_name)

                if sanitized_field_name in allowed_fields.keys():
                    standardized_field_name = allowed_fields[sanitized_field_name]
                    # print(sanitized_field_name + ' -> '+standardized_field_name)
                    output_record_template[standardized_field_name] = field_value
            if (record_count==1):
                try:
                    sdg_code = output_record_template['goal_code']
                except:
                    print (file_name+' sdg_code: '+ str(sdg_code))
                else:
                    print (file_name+' sdg_code: '+ str(sdg_code))

            output_records.extend(process_value_fields(record,output_record_template))

#            output_record['file_name'] = file_details['file_name']
#            output_records.append(output_record)
#            print(output_record_template)

    with open('output_sql.json', 'w') as f:
        json.dump(output_records, f, indent=4)

#allowed_fields = ["goal_code", "iso3", "objectid", "target_cod", "indicato_1"]

allowed_fields = {
    "goal_code":"goal_code",
    "goal_cod": "goal_code",
    "iso3":"iso3cd",
    "iso3c":"iso3cd",
    "iso3cd":"iso3cd",
    "objectid":"objectid",
    "objectid 1": "objectid_1",
    "objectid_1": "objectid_1",
    "target_cod":"target_code",
    "target_code":"target_code",
    "indicato_1":"indicator_1",
    "indicator_1": "indicator_1",
    "units_code": "units_code",
    "age_code": "age_code",
    "age code": "age_code",
    "sex_code": "sex_code",
    "sex code": "sex_code"
}


parser = argparse.ArgumentParser()
parser.add_argument("file_path", type=Path)

p = parser.parse_args()
p.file_path



if p.file_path.exists():
#    root_dir = '....../vector_data/Vector_data/SDG1'
    root_dir = p.file_path
    process_dbf_files(root_dir, allowed_fields)
