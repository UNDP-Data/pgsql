#!/bin/bash

# BEWARE OF COGs/pyramids in input layers while using gdal_calc!!
# Use tiff files without overviews (gdalinfo file.tif|grep -i Overview)

homedir=$(realpath ~)
data_dir="$homedir"'/data/hrea/'
hrea_cogs_dir="$data_dir"'HREA_COGs/'
thr_dir=$data_dir'hrea_data_thr80p/'
weighted_dir=$data_dir'hrea_weighted/'
this_pid="$$"
tmp_cmd_list='/dev/shm/hrea_tmp_cmd_list_'${this_pid}

min_cache=1024

compression=ZSTD
#compression=DEFLATE

#write down the (buffered) extent of the Country layers
#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk '{print $1, $2, $5, $4, $3}'> extents.txt
#ls -1 GID*.gpkg|parallel -I{} ogrinfo -so {} {.}|grep "Exte\|Layer name"|sed ':a;N;$!ba;s/\nExten/ Exten/g'|sed 's/Layer name://g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr ',()' '   '|awk 'BEGIN{buf=10000;}{printf "%s %.0f %.0f %.0f %.0f\n", $1, $2-buf, $5+buf, $4+buf, $3+buf}'> extents.txt
#parallel extraction of buffered per-country per-year tif

#SUBST_YEAR SUBST_SERIES

available_years=(2012 2013 2014 2015 2016 2017 2018 2019 2020)
#available_years=(2019)

mkdir -p "$thr_dir"

function create_commands() {

  echo "" > "$tmp_cmd_list"

#  countries_str=$(ls -1 "$hrea_cogs_dir"*_pop.tif| parallel -I{} gdalinfo {}|grep "Files\|Size is"|tr "/," "\n "|grep "_v1\|Size is"|tr "\n" " "|sed 's/HREA_/\nHREA_/g'|sed 's/Size is //g'|sed '/^[[:space:]]*$/d'|\
#  awk '{img_size=int($2*$3*32/8/1024/1024*1.05); cache=img_size; if (cache<4096){cache=4096};print $1,cache,img_size}'|sed 's/HREA_//g'|sed 's/_2020_v1//g')

  #HREA_Uganda_2020_v1/Uganda_set_lightscore_sy_2020.tif   19536   20540   29.5734769      4.2281343       35.0001437      -1.4774213

  countries_str=$(ls -1 "$hrea_cogs_dir"*_pop.tif| parallel -I{} gdalinfo -json  {} | \
  jq -c -r '[ .description, .size[0], .size[1], .cornerCoordinates.upperLeft[0],.cornerCoordinates.upperLeft[1],.cornerCoordinates.lowerRight[0], .cornerCoordinates.lowerRight[1] ]| @tsv' | \
  awk -v min_cache="$min_cache" '{fn=$1;nf=split(fn,afn,"/"); \
  img_size=int($2*$3*32/8/1024/1024*1.05); \
  cache=img_size; if (cache<min_cache){cache=min_cache}; \
  print afn[nf],cache,$4,$5,$6,$7}'| \
  sed 's/_pop.tif//g'|sort|column -t)

  echo "$countries_str"

  for this_year in "${available_years[@]}"; do

    echo "Now processing year $this_year"
  #  mkdir -p "$thr_dir/$this_year"

    # list available Countries based on existing folders
#    countries=($(ls -1d "$hrea_cogs_dir"/HREA_*_v1|grep "$this_year"|xargs -I{} basename {}|grep '^HREA'|grep '_v1$'|sed 's/^HREA_//g'|sed 's/_v1//g'|sed "s/_$this_year//g"))
#    countries_str=$(ls -1d "$hrea_cogs_dir"/HREA_*_v1|grep "$this_year"|xargs -I{} basename {}|grep '^HREA'|grep '_v1$'|sed 's/^HREA_//g'|sed 's/_v1//g'|sed "s/_$this_year//g")



# ogrinfo -so GID_0_RWA.gpkg GID_0_RWA|grep "Open of\|Exten"|sed 's/INFO: Open of `GID_0_//g'|tr -d "'" |sed 's/\.gpkg//g'|sed 's/Extent: (//g'|sed 's/) - (/ /g'|tr -d ')' |tr "\n" ' '| tr '', " "|tr -s ' '


#    GDAL_CACHEMAX=4096 is important, since RAM seems to be a major bottleneck.
# for eaxmple, data/hrea/HREA_COGs/HREA_Colombia_2017_v1/Colombia_set_lightscore_sy_2017.tif
# has an uncompressed size of about 15.7 GB:
# gdalinfo ~/data/hrea/HREA_COGs/HREA_Colombia_2017_v1/Colombia_set_lightscore_sy_2017.tif|grep 'Size is'|tr ',' ' ' |tr -s ' '|awk '{print int($3*$4*32/8/1024/1024*1.05'
# 15652
# execution time of gdal_calc with:
# GDAL_CACHEMAX=256  ~ 28'
# GDAL_CACHEMAX=2048 ~ 28'
# GDAL_CACHEMAX=4096 ~ 2' 30"
# GDAL_CACHEMAX=8192 ~ 2' 30"
# GDAL_CACHEMAX=16384 ~ 2' 30"

#Algeria                   19393  -8.6672825    37.1697089   11.9574399   19.0555421
#Angola                    8803   11.6712513    -4.3776708   24.0820856   -18.0418385
#Argentina                 35385  -73.8281203   -21.7798493  -53.6375646  -55.5415162
#Bangladesh                1426   88.0105667    26.6337662   92.6736226   20.7409879
#Belize                    234    -89.2226181   18.497261    -87.4859513  15.8975386
#Benin                     986    0.7748611     12.4159723   3.8495834    6.2359722
#Bhutan                    271    88.7460403    28.2476788   92.1246517   26.7007342
#Bolivia                   8366   -69.6390228   -9.6693296   -57.4537441  -22.8959974
#Botswana                  4426   19.9998611    -17.7834721  29.3529167   -26.9001389
#Brunei                    65     114.1280518   5.0451441    115.3758296  4.0262551
#Burkina_Faso              2335   -5.5175016    15.0808533   2.4049985    9.4025199
#Burundi                   207    29.001749     -2.3128495   30.8503603   -4.4700719
#Cambodia                  1418   101.9534075   14.6607037   107.6284075  9.8445925
#Cameroon                  4561   8.4994545     13.0773907   16.1911218   1.6523898
#Cape_Verde                337    -25.3615284   17.2051392   -22.656806   14.8018056
#Central_African_Republic  5778   14.4279167    10.9965278   27.4554168   2.4518056
#Chad                      8749   13.4734755    23.4503708   24.0018096   7.4412028
#Colombia                  15652  -81.8412476   15.9124746   -66.870413   -4.2283603
#Comoros                   72     43.2287483    -11.365139   44.5409706   -12.4226391
#Congo_Republic            3377   11.2008581    3.7030821    18.6500254   -5.0305297
#Djibouti                  150    41.7604523    12.7067776   43.4176746   10.952333
#Dominican_Republic        469    -72.0038834   19.9318047   -68.325272   17.4718045
#DR_Congo                  18680  12.2066288    5.3858519    31.305797    -13.4555385
#Ecuador                   5847   -92.0085449   1.681036     -75.1871547  -5.015909
#Egypt                     5961   24.6980991    31.6673603   36.2486556   21.7254151
#El_Salvador               164    -90.1248627   14.450551    -87.6840291  13.1527731
#Equatorial_Guinea         1559   5.6207271     3.7887499    11.3348942   -1.4673616
#Eritrea                   1964   36.4387665    18.0067139   43.1376559   12.357269
#Eswatini                  111    30.7908897    -25.7187595  32.1367232   -27.3176486
#Ethiopia                  8885   33.0015373    14.8454771   47.9582052   3.4015873
#Gabon                     1899   8.699028      2.3156445    14.5009729   -3.9907449
#Gambia                    119    -16.8173618   13.82689     -13.7915283  13.0646677
#Ghana                     1635   -3.5053425    11.1695672   1.3943798    4.7387339
#Grenada                   12     -61.8020821   12.5401382   -61.3781931  11.9843049
#Guatemala                 846    -92.2223611   17.81875     -88.2273611  13.73875
#Guinea                    2107   -15.0754167   12.6695834   -7.6518055   7.2009722
#Guinea-Bissau             290    -16.7148914   12.6842632   -13.6365579  10.8642631
#Guyana                    1873   -61.386898    8.5309219    -56.480231   1.1770325
#Haiti                     375    -74.4806944   20.0918056   -71.0159722  18.0048611
#Honduras                  1598   -89.3497849   17.4179172   -82.4056176  12.9845836
#Hong_Kong                 12     113.8345871   22.5612507   114.440976   22.1531951
#India                     43615  68.1862488    35.5013313   97.41514     6.7552179
#Indonesia                 40728  95.0148611    6.0729168    141.0084726  -10.9859722
#Iraq                      4253   38.7968368    37.3774757   48.5685043   28.9924751
#Ivory_Coast               2193   -8.6997869    10.7766508   -2.1267313   4.3469286
#Jamaica                   187    -78.3690262   18.5248585   -75.9698593  17.0204139
#Jordan                    943    34.9576378    33.3681717   39.3020826   29.1859491
#Kenya                     4072   33.9127825    4.9217454    41.8866715   -4.9176991
#Laos                      3366   100.0867691   22.5002098   107.635103   13.9077091
#Lesotho                   266    27.0133095    -28.5708008  29.4558097   -30.6755232
#Liberia                   889    -11.4681944   8.54125      -7.3756944   4.35625
#Libya                     11170  9.391737      33.1654167   25.1481271   19.5081934
#Madagascar                5574   42.8957414    -11.9507337  50.7599081   -25.6060115
#Malawi                    1298   32.6793148    -9.3686713   35.9032037   -17.1272825
#Malaysia                  6649   99.6412048    7.3805561    119.2673175  0.8536111
#Mali                      12662  -12.2379167   24.9954168   4.2323612    10.1848611
#Marshall_Islands          5993   160.7956238   14.7213879   172.171458   4.5724982
#Mauritania                7923   -17.0634722   27.2243057   -4.8593055   14.7165278
#Mauritius                 3655   56.5898628    -10.3370819  63.50153     -20.5256938
#Mexico                    29115  -117.4139716  32.7184341   -86.6973047  14.458434
#Micronesia                12051  137.4255524   10.0905552   163.0355544  1.0252767
#Mongolia                  17681  87.7500305    52.1542969   119.9236442  41.5676294
#Morocco                   99     -13.9309651   35.9330351   -0.9580484   27.6601184
#Mozambique                9516   30.2229349    -10.1629723  40.8462683   -27.4196391
#Myanmar                   322    88.8612407    28.552675    106.5779074  8.815175
#Namibia                   8427   11.7348623    -16.9598904  25.2537523   -28.9693358
#Nepal                     1675   80.0543056    30.3118056   88.1965278   26.3473611
#Nicaragua                 1274   -87.6868057   15.0259104   -81.9998608  10.7075767
#Niger                     9719   0.16625       23.5250301   15.9956957   11.6969736
#Nigeria                   6298   2.1196575     13.8888131   14.6799354   4.2279797
#Pakistan                  11780  60.899437     37.0970116   77.8430494   23.7028438
#Panama                    745    -83.0498505   9.6473608    -77.1737389  7.2023606
#Papua_New_Guinea          9164   140.8404999   -0.755904    157.0377234  -11.6553493
#Paraguay                  3619   -62.6465187   -19.2913704  -54.2592958  -27.6058155
#Peru                      12050  -81.3287506   -0.03747     -68.6534718  -18.3519159
#Philippines               11019  114.0469946   21.1218149   126.605328   4.2187592
#Puerto_Rico               143    -67.9586655   18.5172547   -64.6875544  17.6700325
#Rwanda                    189    28.8619468    -1.0475001   30.8994469   -2.8400002
#Saint_Lucia               4      -61.0801392   14.1104174   -60.8698614  13.7084729
#Sao_Tome_and_Principe     89     6.4598622     1.701529     7.4626401    -0.0134711
#Senegal                   1407   -17.5284653   16.6920719   -11.3426314  12.3079049
#Seychelles                3410   46.2072906    -3.7126379   56.2947915   -10.2259718
#Sierra_Leone              484    -13.2984722   9.9998611    -10.2676389  6.9209722
#Solomon_Islands           6039   155.3925018   -4.4463458   170.1916697  -12.3074576
#Somalia                   134    40.9508448    11.999594    51.5966782   -1.6524893
#South_Africa              12206  14.4002176    -22.1296933  32.9035511   -34.8374712
#South_Korea               1672   125.0818024   38.6120834   130.9404139  33.112083
#South_Sudan               99     24.0109782    12.2300458   36.3172282   3.4696291
#Sri_Lanka                 494    79.4531387    9.8359761    81.8856387   5.9184761
#Sudan                     239    21.6450225    23.155059    39.5950225   8.667559
#Suriname                  892    -58.0865631   6.0151391    -53.9773961  1.8312499
#Tajikistan                1755   67.3922806    41.0384674   75.1372812   36.6720782
#Tanzania                  6525   29.577687     -0.9828379   41.0362982   -11.9531158
#Thailand                  6686   97.3490415    20.4627177   105.6390415  4.9249398
#Timor-Leste               235    124.0449753   -8.1269445   127.3421978  -9.5030558
#Togo                      509    -0.145851     11.1389809   1.8066492    6.109536
#Trinidad_and_Tobago       98     -61.9287491   11.3595848   -60.4920823  10.0445847
#Tunisia                   1535   7.54375       37.5526389   11.5923611   30.2481944
#Uganda                    1607   29.5734769    4.2281343    35.0001437   -1.4774213
#Uruguay                   1358   -58.4427223   -30.079689   -53.0941108  -34.9741339
#Vanuatu                   1376   166.5413971   -13.0742331  170.2372307  -20.2511781
#Vietnam                   5707   102.1445847   23.3926926   109.4693075  8.3813025
#Zambia                    5952   22.0001389    -8.2531944   33.6793056   -18.0715278
#Zimbabwe                  2763   25.2371769    -15.6093588  33.0549553   -22.4201927



  #(A>0)*B instead of (A*B) to avoid overflows when A=2^32

#echo "$countries_str"|  awk \
#  -v this_year="$this_year" -v hrea_cogs_dir="$hrea_cogs_dir" -v thr_dir="$thr_dir" \
#  -v weighted_dir="$weighted_dir"  -v hrea_cogs_dir="$hrea_cogs_dir" -v compression="$compression" \
#  '{this_country=$1;  thr_dir=thr_dir""this_country"/"; thr_file=thr_dir""this_country"_"this_year"_hrea.tif"; print this_country"_"this_year, thr_file}'

  # hrea
    sub_create_commands 12000 999000 ${tmp_cmd_list}_1
    sub_create_commands 8000 12000 ${tmp_cmd_list}_2
    sub_create_commands 4000 8000 ${tmp_cmd_list}_3
    sub_create_commands 2000 4000 ${tmp_cmd_list}_6
    sub_create_commands 0 2000 ${tmp_cmd_list}_9

  done

  #echo "$countries_str"
}

function sub_create_commands(){

  size_min=$1
  size_max=$2
  outfile=$3

    echo "$countries_str"| awk -v size_min="${size_min}" -v size_max="${size_max}" '{if($2>size_min && $2<=size_max){print $0}}'| awk \
  -v this_year="$this_year" -v hrea_cogs_dir="$hrea_cogs_dir" -v thr_dir="$thr_dir" \
  -v weighted_dir="$weighted_dir"  -v hrea_cogs_dir="$hrea_cogs_dir" -v compression="$compression" \
  '{this_country=$1; unc_file_size=$2; allocated_cache=int(unc_file_size/3*2*2*1.1); \
    out_thr_dir=thr_dir""this_country"/"; thr_file=out_thr_dir""this_country"_"this_year"_hrea.tif"; \
    out_dir=weighted_dir""this_country"/"; weighted_file=out_dir""this_country"_"this_year"_hrea_w.tif";\
    pop_file=hrea_cogs_dir""$1"_pop.tif";\
    in_file=hrea_cogs_dir"HREA_"this_country"_"this_year"_v1/"this_country"_set_lightscore_sy_"this_year".tif"; \
    print "mkdir -p "out_dir"; if [ ! -e "weighted_file" ]; then " \
    " echo "weighted_file";"  \
    " export GDAL_CACHEMAX="allocated_cache";" \
    " gdal_calc.py --quiet --projwin "$3,$4,$5,$6" --co COMPRESS="compression" --type=Float32 --NoDataValue=0 " \
    " -A "thr_file \
    " -B "pop_file \
    " --outfile="weighted_file \
    " --calc=@(A>0)*B@; \
    gdalinfo -hist "weighted_file"; \
    fi"}'|tr '@' '"' >> $outfile

  # no_hrea
    echo "$countries_str"| awk -v size_min=${size_min} -v size_max=${size_max} '{if($2>size_min && $2<=size_max){print $0}}'|  awk \
  -v this_year="$this_year" -v hrea_cogs_dir="$hrea_cogs_dir" -v thr_dir="$thr_dir" \
  -v weighted_dir="$weighted_dir"  -v hrea_cogs_dir="$hrea_cogs_dir" -v compression="$compression" \
  '{this_country=$1; unc_file_size=$2; allocated_cache=int(unc_file_size/3*2*2*1.1); \
    out_thr_dir=thr_dir""this_country"/"; thr_file=out_thr_dir""this_country"_"this_year"_no_hrea.tif"; \
    out_dir=weighted_dir""this_country"/"; weighted_file=out_dir""this_country"_"this_year"_no_hrea_w.tif";\
    pop_file=hrea_cogs_dir""$1"_pop.tif";\
    in_file=hrea_cogs_dir"HREA_"this_country"_"this_year"_v1/"this_country"_set_lightscore_sy_"this_year".tif"; \
    print "mkdir -p "out_dir"; if [ ! -e "weighted_file" ]; then " \
    " echo "weighted_file";"  \
    " export GDAL_CACHEMAX="allocated_cache";" \
    " gdal_calc.py --quiet --projwin "$3,$4,$5,$6" --co COMPRESS="compression" --type=Float32 --NoDataValue=0 " \
    " -A "thr_file \
    " -B "pop_file \
    " --outfile="weighted_file \
    " --calc=@(A>0)*B@; \
    gdalinfo -hist "weighted_file"; \
    fi"}'|tr '@' '"' >> $outfile


}

create_commands

echo "executing parallel on " $(wc -l "$tmp_cmd_list" ) " commands"

# sort in order to process country-wise
#cat "$tmp_cmd_list" | sort |grep -v "India\|Indonesia\|Argentina\|Mexico\|Algeria\|DR_Congo"| parallel  --jobs 5 -I{}  {}


cat ${tmp_cmd_list}_1 | sort | parallel --jobs 1 -I{} echo {}
#cat ${tmp_cmd_list}_2 | sort | parallel --jobs 2 -I{}  {}
#cat ${tmp_cmd_list}_3 | sort | parallel --jobs 3 -I{}  {}
#cat ${tmp_cmd_list}_6 | sort | parallel --jobs 6 -I{}  {}
#cat ${tmp_cmd_list}_9 | sort | parallel --jobs 9 -I{}  {}

#rm -f ${tmp_cmd_list}_1
#rm -f ${tmp_cmd_list}_2
#rm -f ${tmp_cmd_list}_3
#rm -f ${tmp_cmd_list}_6
#rm -f ${tmp_cmd_list}_9

# if the thr80 files of a particular Country needs to be aligned to the pop tif:
#-te <xmin ymin xmax ymax>
#mkdir /home/rafd/data/hrea/hrea_data_thr80p/Rwanda_aligned
#gdalwarp -overwrite -tap -s_srs EPSG:4326 -t_srs EPSG:4326 -te 28.861969 -2.8399016 30.8991914 -1.0476792 -tr 0.000277777799973 -0.000277777800062 /home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2012_hrea.tif /home/rafd/data/hrea/hrea_data_thr80p/Rwanda_aligned/Rwanda_2012_hrea.tif
#ls -1 /home/rafd/data/hrea/hrea_data_thr80p/Rwanda/*tif| xargs -n1 basename | parallel -I {} gdalwarp -co COMPRESS=DEFLATE -overwrite -tap -s_srs EPSG:4326 -t_srs EPSG:4326 -te 28.861969 -2.8399016 30.8991914 -1.0476792 -tr 0.0002777777999727297086 -0.0002777778000619963018 /home/rafd/data/hrea/hrea_data_thr80p/Rwanda/{} /home/rafd/data/hrea/hrea_data_thr80p/Rwanda_aligned/{}
#
#also align the pop file to itself, because the coordinates extracted from gdalwarp are rounded, and not precise enough for exact_extract:
#gdalwarp -co COMPRESS=DEFLATE -overwrite -tap -s_srs EPSG:4326 -t_srs EPSG:4326 -te 28.861969 -2.8399016 30.8991914 -1.0476792 -tr 0.0002777777999727297086 -0.0002777778000619963018 /home/rafd/data/hrea/HREA_COGs/Rwanda_pop.tif /home/rafd/data/hrea/HREA_COGs/Rwanda_pop_aligned.tif

