import csv
import os

data_dir = os.path.expanduser('~') + '/data/hrea/'
hrea_outputs_csv_dir = os.path.expanduser('~') + '/data/hrea/hrea_outputs/hrea_per_country/'
hrea_outputs_summaries_dir = os.path.expanduser('~') + '/data/hrea/hrea_outputs/hrea_summaries/'
os.chdir(data_dir)

min_year = 2012
max_year = 2020

try:
    # print('Creating ' + hrea_outputs_summaries_dir)
    os.makedirs(hrea_outputs_summaries_dir)
except OSError as error:
    print('Error while creating ' + hrea_outputs_summaries_dir)
    # print(error)


def summarise_by_level(adm_level, adm_number):
    with open(hrea_outputs_csv_dir+'all_countries_sp.csv', 'r') as infile:


# 1       2      3          4                5            6          7            8            9            10           11           12           13           14           15            16            17            18            19            20            21            22            23
# iso3cd  adm1   adm2       adm2_sub         pop_sum      hrea_2012  hrea_2013    hrea_2014    hrea_2015    hrea_2016    hrea_2017    hrea_2018    hrea_2019    hrea_2020    no_hrea_2012  no_hrea_2013  no_hrea_2014  no_hrea_2015  no_hrea_2016  no_hrea_2017  no_hrea_2018  no_hrea_2019  no_hrea_2020
# EGY     EGY.1  EGY.1.1_1  EGY.1.1_1:81821  506750,4375  0          506750,4375  506750,4375  506750,4375  506750,4375  506750,4375  506750,4375  506750,4375  506750,4375  0             0             0             0             0             0             0             0             0


        reader = csv.reader(infile)

        adm_id_sums = {}
        adm_id_avgs = {}
        adm_id_perc = {}

        for row in reader:

            # skip the header
            if row[0] == 'iso3cd':
                continue

            # get the adm_id value and columns from the 5th to the last,
            # which are pup_sum, the "hrea weighted sums", and the "no_hrea weighted sums"
            adm_id = row[adm_number]
            # print(row)
            row_fields = [float(x) for x in row[4:]]

            if adm_id not in adm_id_sums:
                adm_id_sums[adm_id] = [0] * len(row_fields)

            adm_id_sums[adm_id] = [round(sum(x), 2) for x in zip(adm_id_sums[adm_id], row_fields)]

    with open(hrea_outputs_summaries_dir + 'output_adm' + str(adm_number) + '.csv', 'w', newline='') as outfile:

        writer = csv.writer(outfile)

        # header
        writer.writerow([adm_level] + ['pop'] +
                        ['val_hrea_' + str(i) for i in range(min_year, max_year+1)] +
                        ['val_no_hrea_' + str(i) for i in range(min_year, max_year+1)] +
                        ['hrea_' + str(i) for i in range(min_year, max_year + 1)])

        # data
        for adm_id, sums in sorted(adm_id_sums.items()):
            # print(sums)
            # 0          1          2          3          4          5          6          7          8          9          10            11  12  13  14  15  16  17  18
            # pop_sum    hrea_2012                                                                                          no_hrea_2012
            # 233537.61  233537.61  233537.61  233537.61  233537.61  233537.61  233537.61  233537.61  233537.61  233537.61  0             0   0   0   0   0   0   0   0

            nof_available_years = int((len(sums) - 1) / 2)

            if adm_id not in adm_id_perc:
                adm_id_perc[adm_id] = [0] * nof_available_years


            outcol = 0
            for ncol in range(1, nof_available_years + 1):
                hrea_val = adm_id_sums[adm_id][ncol]
                no_hrea_val = adm_id_sums[adm_id][ncol + nof_available_years]
                hrea_no_hrea_val = hrea_val + no_hrea_val
                if hrea_no_hrea_val > 0:
                    adm_id_perc[adm_id][outcol] = round(hrea_val / hrea_no_hrea_val, 4)
                else:
                    adm_id_perc[adm_id][outcol] = 0
                outcol += 1

            writer.writerow([adm_id] + sums + adm_id_perc[adm_id])


summarise_by_level('adm0',0)
summarise_by_level('adm1',1)
summarise_by_level('adm2',2)
# summarise_by_level('adm3',3)
