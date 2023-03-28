import csv

with open('/home/rafd/Downloads/admin-levels_/HREA/hrea_outputs/all_countries_sp.csv', 'r') as infile:

    reader = csv.reader(infile)

    adm1_sums = {}
    adm1_avgs = {}

    for row in reader:

        # skip the header
        if row[0] == 'iso3cd':
            continue

        # get the adm1 value and columns from the 5th to the last, which are the sums and weighted sums
        adm1 = row[1]
        # print(row)
        cols = [float(x) for x in row[4:]]

        if adm1 not in adm1_sums:
            adm1_sums[adm1] = [0] * len(cols)

        adm1_sums[adm1] = [sum(x) for x in zip(adm1_sums[adm1], cols)]


with open('output.csv', 'w', newline='') as outfile:

    writer = csv.writer(outfile)

    #header
    writer.writerow(['adm1'] + ['sum_pop','mean_pop','min_pop','max_pop'] + ['sum_' + str(i) for i in range(1, len(cols)-3)] + ['perc_' + str(i) for i in range(1, len(cols)-3)] )

    for adm1, sums in adm1_sums.items():
        if adm1 not in adm1_avgs:
            adm1_avgs[adm1] = [0] * (len(adm1_sums[adm1])-4)

        outcol=0
        # print(len(adm1_sums[adm1]))
        # print(adm1_sums[adm1])
        for ncol in range(4, len(adm1_sums[adm1])):
            if(adm1_sums[adm1][0] > 0):
                adm1_avgs[adm1][outcol] = adm1_sums[adm1][ncol] / adm1_sums[adm1][0]
                # print(str(adm1_sums[adm1][ncol])+'/'+str(adm1_sums[adm1][0]))
            else:
                adm1_avgs[adm1][outcol] = 0
            outcol += 1

        writer.writerow([adm1] + sums + adm1_avgs[adm1])
