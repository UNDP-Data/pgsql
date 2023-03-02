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
#    return unicodedata.normalize('NFKD', name).encode('ASCII', 'ignore').decode('utf-8').lower().replace(' ', '_')
    return name

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

def process_value_fields(record, output_record_master, allowed_fields):
    """
    Processes value fields in a record and returns a list of dictionaries
    representing the valid values.
    """
    output_records = []
    for field_name, field_value in record.items():
        if isinstance(field_value, (int, float)) and field_name.startswith('value'):
            if field_value != 0:
                output_record = output_record_master
                output_record['year'] = sanitize_name(field_name)
                output_record['yvalue'] = field_value
                output_records.append(output_record)
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
#        print (os.path.join(file_details['dir'], file_details['file_name']))
        dbf_file = dbfread.DBF(os.path.join(file_details['dir'], file_details['file_name']), encoding='cp852')
        fname=sanitize_name(file_details['file_name'])
        for record in dbf_file:
            output_record_master = {}
            output_record_master['fname'] = fname
            for field_name, field_value in record.items():
                sanitized_field_name = sanitize_name(field_name)
                if sanitized_field_name in allowed_fields:
                    output_record_master[sanitized_field_name] = field_value

            output_records.extend(process_value_fields(record,output_record_master,allowed_fields))

#            output_record['file_name'] = file_details['file_name']
#            output_records.append(output_record)
#            print(output_record_master)

    with open('output_sql.json', 'w') as f:
        json.dump(output_records, f, indent=4)

allowed_fields = ["goal_code", "iso3", "objectid", "target_cod", "indicato_1"]



parser = argparse.ArgumentParser()
parser.add_argument("file_path", type=Path)

p = parser.parse_args()
p.file_path



if p.file_path.exists():
#    root_dir = '....../vector_data/Vector_data/SDG1'
    root_dir = p.file_path
    process_dbf_files(root_dir, allowed_fields)
