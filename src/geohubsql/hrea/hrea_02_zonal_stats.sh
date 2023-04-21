#!/bin/bash

homedir=$(realpath ~)
data_dir="$homedir"'/data/hrea/'
pop_dir="$data_dir"'HREA_COGs/'
adm_base_dir="$homedir"'/data/boundaries/adm'
#base_dir="$homedir""/Downloads/admin-levels_/"
#hrea_dir="$base_dir""HREA/"
#adm2_dir="$data_dir""gadm_adm2_by_country_4326/"

hrea_csv_base_dir="$data_dir"'hrea_outputs/hrea_csv/adm'
thr_dir="$data_dir""hrea_data_thr80p/"
this_pid="$$"
tmp_file='/dev/shm/hrea_02_zonal_stats_'"$this_pid"

#COD,DR_Congo
#COG,Congo_Republic
country_lut="$data_dir"'adm0_names_lut.csv'

this_series='hrea'

#levels_to_extract=(3 4 5)
levels_to_extract=(3)

function prepare_exact_extract_commands(){

for this_level in "${levels_to_extract[@]}"; do

  gadm_per_country_level_dir="$adm_base_dir$this_level"'/'
  hrea_csv_dir="$hrea_csv_base_dir$this_level"'/'

  echo '# '"Outputs from $gadm_per_country_level_dir will be created in $hrea_csv_dir"
  mkdir -p "$hrea_csv_dir"


  #cd admin-levels_/gadm_adm2_by_country
  #ls -1|sed 's/.gpkg//g'|awk '{print "ogrinfo "$1".gpkg -sql @ALTER TABLE "$1" DROP COLUMN nofv@"}'|tr '@' '"'
  #ls -1|sed 's/.gpkg//g'|awk '{print "ogrinfo "$1".gpkg -sql @ALTER TABLE "$1" DROP COLUMN GID_1b@"}'|tr '@' '"'

  #reproject into 4326
  #cd "$homedir"/data/hrea/gadm_adm2_by_country_3857
  #mkdir "$homedir"/data/hrea/gadm_adm2_by_country_4326/
  #ls -1|parallel -I{} ogr2ogr "$homedir"/data/hrea/gadm_adm2_by_country_4326/{} -t_srs "EPSG:4326" {}



  # exactextract seems not to like particularly binary masks (i.e. raster with 1-byte values), like the hrea and no_hrea series,
  # for weighting purposes.
  # for example:
  #    hrea_2020_wsum=weighted_sum(pop,hrea_2020_rst)
  # failes most of the times, producing "nan"
  # while:
  #    hrea_2020_wsum=weighted_sum(hrea_2020_rst,pop)
  # works.
  #
  # also, it might have troubles with polygons containing rings (holes)

  #RWA needs a special processing (see the end of this file)

#~/data/boundaries/adm3/adm3_ZWE.gpkg

cat "$country_lut" |  tr ',' ' ' | grep -v "COG\|GAB\|GNQ\|STP\|MNG\|MUS\|TJK\|FSM\|BRN\|RWA" | awk \
  -v this_series="$this_series" \
  -v gadm_per_country_level_dir="$gadm_per_country_level_dir" \
  -v this_level="$this_level" \
  -v hrea_csv_dir="$hrea_csv_dir" \
  -v thr_dir="$thr_dir" \
  -v gadm_per_country_level_dir="$gadm_per_country_level_dir" \
  -v pop_dir="$pop_dir" \
  '{print \
"printf @%(%m-%d %H:%M:%S)T@; echo @ @"$1" aka "$2";" \
"if [ ! -e " hrea_csv_dir""this_series"_"$1".csv ]; then " \
" exactextract " \
"-p @"gadm_per_country_level_dir"adm"this_level"_"$1".gpkg@ -f @GID_"this_level"@ " \
"-o @"hrea_csv_dir""this_series"_"$1".csv@ " \
"-r @pop:"pop_dir""$2"_pop.tif@ " \
"-r @hrea_2012_rst:"thr_dir""$2"/"$2"_2012_hrea.tif@ " \
"-r @hrea_2013_rst:"thr_dir""$2"/"$2"_2013_hrea.tif@ " \
"-r @hrea_2014_rst:"thr_dir""$2"/"$2"_2014_hrea.tif@ " \
"-r @hrea_2015_rst:"thr_dir""$2"/"$2"_2015_hrea.tif@ " \
"-r @hrea_2016_rst:"thr_dir""$2"/"$2"_2016_hrea.tif@ " \
"-r @hrea_2017_rst:"thr_dir""$2"/"$2"_2017_hrea.tif@ " \
"-r @hrea_2018_rst:"thr_dir""$2"/"$2"_2018_hrea.tif@ " \
"-r @hrea_2019_rst:"thr_dir""$2"/"$2"_2019_hrea.tif@ " \
"-r @hrea_2020_rst:"thr_dir""$2"/"$2"_2020_hrea.tif@ " \
"-r @no_hrea_2012_rst:"thr_dir""$2"/"$2"_2012_no_hrea.tif@ " \
"-r @no_hrea_2013_rst:"thr_dir""$2"/"$2"_2013_no_hrea.tif@ " \
"-r @no_hrea_2014_rst:"thr_dir""$2"/"$2"_2014_no_hrea.tif@ " \
"-r @no_hrea_2015_rst:"thr_dir""$2"/"$2"_2015_no_hrea.tif@ " \
"-r @no_hrea_2016_rst:"thr_dir""$2"/"$2"_2016_no_hrea.tif@ " \
"-r @no_hrea_2017_rst:"thr_dir""$2"/"$2"_2017_no_hrea.tif@ " \
"-r @no_hrea_2018_rst:"thr_dir""$2"/"$2"_2018_no_hrea.tif@ " \
"-r @no_hrea_2019_rst:"thr_dir""$2"/"$2"_2019_no_hrea.tif@ " \
"-r @no_hrea_2020_rst:"thr_dir""$2"/"$2"_2020_no_hrea.tif@ " \
"-s @pop_sum=sum(pop)@ " \
"-s @hrea_2012_wsum=weighted_sum(hrea_2012_rst,pop)@ " \
"-s @hrea_2013_wsum=weighted_sum(hrea_2013_rst,pop)@ " \
"-s @hrea_2014_wsum=weighted_sum(hrea_2014_rst,pop)@ " \
"-s @hrea_2015_wsum=weighted_sum(hrea_2015_rst,pop)@ " \
"-s @hrea_2016_wsum=weighted_sum(hrea_2016_rst,pop)@ " \
"-s @hrea_2017_wsum=weighted_sum(hrea_2017_rst,pop)@ " \
"-s @hrea_2018_wsum=weighted_sum(hrea_2018_rst,pop)@ " \
"-s @hrea_2019_wsum=weighted_sum(hrea_2019_rst,pop)@ " \
"-s @hrea_2020_wsum=weighted_sum(hrea_2020_rst,pop)@ " \
"-s @no_hrea_2012_wsum=weighted_sum(no_hrea_2012_rst,pop)@ " \
"-s @no_hrea_2013_wsum=weighted_sum(no_hrea_2013_rst,pop)@ " \
"-s @no_hrea_2014_wsum=weighted_sum(no_hrea_2014_rst,pop)@ " \
"-s @no_hrea_2015_wsum=weighted_sum(no_hrea_2015_rst,pop)@ " \
"-s @no_hrea_2016_wsum=weighted_sum(no_hrea_2016_rst,pop)@ " \
"-s @no_hrea_2017_wsum=weighted_sum(no_hrea_2017_rst,pop)@ " \
"-s @no_hrea_2018_wsum=weighted_sum(no_hrea_2018_rst,pop)@ " \
"-s @no_hrea_2019_wsum=weighted_sum(no_hrea_2019_rst,pop)@ " \
"-s @no_hrea_2020_wsum=weighted_sum(no_hrea_2020_rst,pop)@ " \
"; fi" \
}' |tr '@' '"'

done

}


function debug_country() {

country="$1"
#year="$2"
#echo 'debug:'
grep "$country" "$tmp_file"|head -1|sed "s/-r/\n-r/g"|sed "s/-s/\n-s/g"

}

function filter_exception() {

country="$1"
year="$2"

country_name=$(grep "$country" "$country_lut"|head -1|cut -d',' -f2)



#echo "filtering $country $country_name $year"

#remove relevant "-r" lines:
sed -i '\#'${country}'#s#-r "hrea_'${year}'_rst:'${thr_dir}${country_name}'/'${country_name}'_'${year}'_hrea.tif"##g' "$tmp_file"
sed -i '\#'${country}'#s#-r "no_hrea_'${year}'_rst:'${thr_dir}${country_name}'/'${country_name}'_'${year}'_no_hrea.tif"##g' "$tmp_file"

#change this:
#hrea_2019_wsum=weighted_sum(hrea_2019_rst,pop)
#into this:
#hrea_2019_wsum=min(pop)
sed -i '/'${country}'/s/hrea_'${year}'_wsum\=weighted_sum(hrea_'${year}'_rst,pop)/hrea_'${year}'_wsum\=min(pop)/g' "$tmp_file"
sed -i '/'${country}'/s/no_hrea_'${year}'_wsum\=weighted_sum(no_hrea_'${year}'_rst,pop)/no_hrea_'${year}'_wsum\=min(pop)/g' "$tmp_file"


}

function filter_all_exceptions() {

# the following Countries do not have hrea 2019.
# using "min(pop)" to force a 0:
# Congo Republic / COG
# Gabon / GAB
# Equatorial Guinea / GNQ
# Sao_Tome_and_Principe / STP

filter_exception 'COG' '2019'
filter_exception 'GAB' '2019'

filter_exception 'GNQ' '2019'
filter_exception 'STP' '2019'

# the following Countries do not have hrea 2012 and 2013.
# using "min(pop)" to force a 0:
#MNG,Mongolia
#TJK,Tajikistan
#BRN,Brunei

filter_exception 'MNG' '2012'
filter_exception 'MNG' '2013'

filter_exception 'TJK' '2012'
filter_exception 'TJK' '2013'

filter_exception 'BRN' '2012'
filter_exception 'BRN' '2013'

# the following Countries do not have hrea 2012, 2013 and 2019.#
# using "min(pop)" to force a 0:
#FSM,Micronesia

filter_exception 'FSM' '2012'
filter_exception 'FSM' '2013'
filter_exception 'FSM' '2019'

# the following Countries only have hrea 2018, 2019, 2020
# using "min(pop)" to force a 0:
#MUS,Mauritius

filter_exception 'MUS' '2018'
filter_exception 'MUS' '2019'
filter_exception 'MUS' '2020'

}

# Rwanda could not be processed like all other Countries, and needed to be pre-processed with gdal_calc.

#available_years=(2012 2013 2014 2015 2016 2017 2018 2019 2020)
#for this_year in "${available_years[@]}"; do
#
#    echo "$this_year"
#    this_country='Rwanda'
#    #mv "$thr_dir"Rwanda_"$this_year"_hrea.tif "$thr_dir"Rwanda_"$this_year"_hrea.tif
#    echo gdal_calc.py -A "$thr_dir""$this_country"'/'"$this_country""_""$this_year""_hrea.tif -B " "$gadm_per_country_level_dir""$this_country"'_pop.tif --calc="A*B"'"  --outfile ""$thr_dir""$this_country"'/'"$this_country""_""$this_year""_hrea_wpop.tif"|parallel -I{} {}
#    #gdal_calc.py -A $thr_dir$this_country'/'$this_country"_"$this_year"_hrea.tif -B "$gadm_per_country_level_dir$this_country'_pop.tif --calc="A*B"  --outfile '$thr_dir$this_country'/'$this_country"_"$this_year"_hrea_wpop.tif"
#    echo gdal_calc.py -A "$thr_dir""$this_country"'/'"$this_country""_""$this_year""_no_hrea.tif -B " "$gadm_per_country_level_dir""$this_country"'_pop.tif --calc="A*B"'"  --outfile ""$thr_dir""$this_country"'/'"$this_country""_""$this_year""_no_hrea_wpop.tif"|parallel -I{} {}
#
#done
#
#exactextract -p "/home/rafd/data/hrea/gadm_adm2_by_country_4326/GID_0_RWA.gpkg" -f "GID_2b" -o "/home/rafd/data/hrea/hrea_outputs/hrea_csv/hrea_RWA.csv"  -r "pop:/home/rafd/data/hrea/HREA_COGs/Rwanda_pop.tif"  -r "hrea_2012_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2012_hrea_wpop.tif"  -r "hrea_2013_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2013_hrea_wpop.tif"  -r "hrea_2014_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2014_hrea_wpop.tif"  -r "hrea_2015_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2015_hrea_wpop.tif"  -r "hrea_2016_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2016_hrea_wpop.tif"  -r "hrea_2017_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2017_hrea_wpop.tif"  -r "hrea_2018_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2018_hrea_wpop.tif"  -r "hrea_2019_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2019_hrea_wpop.tif"  -r "hrea_2020_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2020_hrea_wpop.tif"  -r "no_hrea_2012_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2012_no_hrea_wpop.tif"  -r "no_hrea_2013_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2013_no_hrea_wpop.tif"  -r "no_hrea_2014_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2014_no_hrea_wpop.tif"  -r "no_hrea_2015_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2015_no_hrea_wpop.tif"  -r "no_hrea_2016_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2016_no_hrea_wpop.tif"  -r "no_hrea_2017_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2017_no_hrea_wpop.tif"  -r "no_hrea_2018_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2018_no_hrea_wpop.tif"  -r "no_hrea_2019_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2019_no_hrea_wpop.tif"  -r "no_hrea_2020_wpop:/home/rafd/data/hrea/hrea_data_thr80p/Rwanda/Rwanda_2020_no_hrea_wpop.tif"  -s "pop_sum=sum(pop)"   -s "hrea_2012_wsum=sum(hrea_2012_wpop)"  -s "hrea_2013_wsum=sum(hrea_2013_wpop)"  -s "hrea_2014_wsum=sum(hrea_2014_wpop)"  -s "hrea_2015_wsum=sum(hrea_2015_wpop)"  -s "hrea_2016_wsum=sum(hrea_2016_wpop)"  -s "hrea_2017_wsum=sum(hrea_2017_wpop)"  -s "hrea_2018_wsum=sum(hrea_2018_wpop)"  -s "hrea_2019_wsum=sum(hrea_2019_wpop)"  -s "hrea_2020_wsum=sum(hrea_2020_wpop)"  -s "no_hrea_2012_wsum=sum(no_hrea_2012_wpop)"  -s "no_hrea_2013_wsum=sum(no_hrea_2013_wpop)"  -s "no_hrea_2014_wsum=sum(no_hrea_2014_wpop)"  -s "no_hrea_2015_wsum=sum(no_hrea_2015_wpop)"  -s "no_hrea_2016_wsum=sum(no_hrea_2016_wpop)"  -s "no_hrea_2017_wsum=sum(no_hrea_2017_wpop)"  -s "no_hrea_2018_wsum=sum(no_hrea_2018_wpop)"  -s "no_hrea_2019_wsum=sum(no_hrea_2019_wpop)"  -s "no_hrea_2020_wsum=sum(no_hrea_2020_wpop)"

echo "Writing to: $tmp_file"

prepare_exact_extract_commands > "$tmp_file"

filter_all_exceptions

debug_country 'MUS'

cat "$tmp_file"|parallel --jobs 3 -I{} echo {}

#rm -f "$tmp_file"

date

