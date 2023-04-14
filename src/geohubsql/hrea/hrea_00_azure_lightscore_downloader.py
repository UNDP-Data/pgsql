from azure.storage.blob import ContainerClient
from urllib.parse import urlparse
from re import search
import time
from pathlib import Path
import os

sas_url_sig = os.environ['sas_url_sig']
# cwd = os.getcwd() + '/'
# home_dir = os.path.expanduser('~') + '/'
data_dir = os.path.expanduser('~') + '/data/hrea/'
os.chdir(data_dir)

import os

def download_from_container():
    sas_url = "https://undpngddlsgeohubdev01.blob.core.windows.net/?sv=2021-12-02&ss=bfqt&srt=sco&sp=rwdlacupiytfx&se=2023-06-01T21:38:17Z&st=2023-03-24T14:38:17Z&spr=https&sig="+sas_url_sig
    print(sas_url)

    container = 'hrea'
    sasUrlParts = urlparse(sas_url)
    accountEndpoint = sasUrlParts.scheme + '://' + sasUrlParts.netloc
    sasToken = sasUrlParts.query

    blobSasUrl = accountEndpoint + '/' + container + '?' + sasToken
    # print('### blobSasUrl: '+blobSasUrl)

    container_client = ContainerClient.from_container_url(blobSasUrl)
    # print('### container_client: '+str(container_client))

    tot_size = 0

    # Egypt_set_lightscore_sy_2020_hrea.tif
    blobs_list = container_client.list_blobs(name_starts_with='HREA_COGs')

    # download_by(blobs_list, container_client, tot_size, 'HREA_COGs/HREA_', 'Egypt_set_lightscore_sy_', '.tif$')
    # download_by(blobs_list, container_client, tot_size, 'HREA_COGs/HREA_', 'Algeria_set_lightscore_sy_', '.tif$')

    # download hrea files
    tot_size = download_by(blobs_list, container_client, tot_size, 'HREA_COGs/HREA_', '_set_lightscore_sy_', '.tif$', False)
    # download population files
    tot_size = download_by(blobs_list, container_client, tot_size, 'HREA_COGs/', '[A-Fa-f\-]+', '_pop.tif$', False)

    print(str(tot_size) + ' bytes or ' + str(round(tot_size / 1024 / 1024)) + ' Mb')



def download_by(blobs_list, container_client, tot_size, match_1, match_2, match_3, calc_size_only):

    for blob in blobs_list:
        blob_name = blob['name']
        # print('### blob name:' + str(blob['name']))
        if search(match_1, blob_name) and search(match_2, blob_name) and search(match_3, blob_name):

            print("\n" + '### blob OK: ' + str(blob['name']) + ' ' + str(blob['size']) + ' bytes or ' + str(round(blob['size'] / 1024 / 1024)) + ' Mb')
            tot_size = tot_size + blob['size']
            start_time = time.time()

            if not calc_size_only:

                abs_path = os.path.dirname(data_dir + blob_name)
                print('abs_path: ' + abs_path)

                try:
                    # print('Creating ' + abs_path)
                    os.makedirs(abs_path)
                except OSError as error:
                    print('Error while creating ' + abs_path)
                    #print(error)

                path = Path(blob.name)
                if not path.is_file():

                    with open(blob.name, "wb") as my_blob:

                        print('downloading ' + blob_name)
                        local_blob = container_client.download_blob(blob.name)
                        blob_data = local_blob.readall()
                        my_blob.write(blob_data)

                        print("done")
                        end_time = time.time()
                        elapsed_time = end_time - start_time
                        dl_speed = round(blob['size'] / elapsed_time, 2)
                        dl_speed_mb = round(dl_speed / 1024 / 1024, 2)
                        print(blob['size'], "kb in: ", elapsed_time, ' speed:', dl_speed, ' bps (', dl_speed_mb, ' Mb/s)')
                else:
                    print('file ', blob.name, ' exists already')

    return tot_size





download_from_container()