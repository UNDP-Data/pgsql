CREATE OR REPLACE FUNCTION admin.hdi_subnat_extarg_martin(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    query_params json default '{
              "le_incr":
                {"param_name":"life_expectancy_increment",
                  "type":"numeric",
                  "icon":"fa-people-roof",
                  "limits":{"min":-10,"max":10},
                  "value":0,
                  "label":"Increment of life expectancy",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "eys_incr":
                {"param_name":"expected_years_of_schooling_increment",
                  "type":"numeric",
                  "icon":"fa-graduation-cap",
                  "limits":{"min":-10,"max":10},
                  "value":0,
                  "label":"Increment of expected education",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "mys_incr":
                {"param_name":"mean_years_of_schooling_increment",
                  "type":"numeric",
                  "icon":"fa-school",
                  "limits":{"min":-10,"max":10},
                  "value":0,
                  "label":"Increment of mean education",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "gni_incr":
                {"param_name":"gross_national_income_increment",
                  "type":"numeric",
                  "icon":"fa-hand-holding-dollar",
                  "limits":{"min":-30000,"max":30000},
                  "value":0,
                  "label":"Income increment",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"USD"}
            }'::json
    )


RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        layer_name varchar := 'admin.hdi_subnat_extarg_martin';

        defaults_json jsonb;
		requested_json jsonb;
		sanitized_json jsonb;

        geom_col varchar;
        featcount integer;
        feat_limit integer := 3000;

        le_incr  float default 0;
        eys_incr float default 0;
        mys_incr float default 0;
        gni_incr float default 0;

        le_value  float default 0;
        eys_value float default 0;
        mys_value float default 0;
        gni_value float default 0;

        min_extent integer := 256;
        max_extent integer := 4096;
        mvt_extent integer := 1024;
        mvt_buffer integer := 32;

        --param_names varchar ARRAY  DEFAULT  ARRAY['le_incr','eys_incr','mys_incr','gni_incr'];

        func_defaults jsonb :=
            '{
              "le_incr":
                {"param_name":"life_expectancy_increment",
                  "type":"numeric",
                  "icon":"fa-people-roof",
                  "limits":{"min":-10,"max":10},
                  "value":0,
                  "label":"Increment of life expectancy",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "eys_incr":
                {"param_name":"expected_years_of_schooling_increment",
                  "type":"numeric",
                  "icon":"fa-graduation-cap",
                  "limits":{"min":-10,"max":10},
                  "value":0,
                  "label":"Increment of expected education",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "mys_incr":
                {"param_name":"mean_years_of_schooling_increment",
                  "type":"numeric",
                  "icon":"fa-school",
                  "limits":{"min":-10,"max":10},
                  "value":0,
                  "label":"Increment of mean education",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "gni_incr":
                {"param_name":"gross_national_income_increment",
                  "type":"numeric",
                  "icon":"fa-hand-holding-dollar",
                  "limits":{"min":-30000,"max":30000},
                  "value":0,
                  "label":"Income increment",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"USD"}
            }';

-- PL/PgSQL function to create a dynamic function layer (delivered as Vector Tiles) with a representation of the Human Development Index
-- requires/accepts four input parameters which act as multipliers for the respective HDI formula parameters:
--			life_expectancy_multiplier  multiplies the "Life expectancy" parameter
--			expected_years_of_schooling_multiplier multiplies the "Expected years schooling"  parameter
--			mean_years_of_schooling_multiplier multiplies the "Mean years schooling"  parameter
--			gross_national_income_multiplier multiplies the "Log Gross National Income per capita" parameter
-- input parameters can be passed as JSON in the URL


    BEGIN
        defaults_json  := func_defaults::jsonb;
        requested_json := query_params::jsonb;

        --sanitized_json:=requested_json::json;
        -- sanitize the JSON before proceeding
        sanitized_json:=admin.params_sanity_check(defaults_json, requested_json);


        --param_names:=json_object_keys ( sanitized_json );

--      RAISE WARNING 'arr_par: %', sanitized_json;
--      RAISE WARNING 'sanitized_json: %', sanitized_json;
--		RAISE WARNING 'sanitized_json / le_incr: %',  sanitized_json->'le_incr';
--		RAISE WARNING 'sanitized_json / le_incr / value: %',  sanitized_json->'le_incr'->'value';

        -- extract the relevant parameters
        le_incr  := sanitized_json->'le_incr'->'value';
        eys_incr := sanitized_json->'eys_incr'->'value';
        mys_incr := sanitized_json->'mys_incr'->'value';
        gni_incr := sanitized_json->'gni_incr'->'value';


        --RAISE WARNING 'le_incr: %, eys_incr: %, mys_incr: %, gni_incr %', le_incr, eys_incr, mys_incr, gni_incr;

        -- use 'default' as a layer name to make it possible to visualize it via pg_tileServ's internal map viewer
        --layer_name := 'default';

		DROP TABLE IF EXISTS hdi_extarg_tmp_table;

        --let's set St_AsMVT's extent as a function of the zoom level
        --in order to reduce network usage and increase the UX.

        CASE
            WHEN (z<=1) THEN
                mvt_extent := 256;
            WHEN (z=2) THEN
                mvt_extent := 256;
            WHEN (z=3) THEN
                mvt_extent := 512;
            WHEN (z=4) THEN
                mvt_extent := 512;
            WHEN (z=5) THEN
                mvt_extent := 512;
            WHEN (z>6)AND(z<=10) THEN
                mvt_extent := 1024;
            WHEN (z>10)AND(z<=12) THEN
                mvt_extent := 2048;
            ELSE
                mvt_extent := 4096;
        END CASE;


        -- comment out after devel phase
        --mvt_extent := definition_multiplier*mvt_extent;
        IF (mvt_extent > max_extent) THEN
            mvt_extent := max_extent;
        END IF;
        IF (mvt_extent < min_extent) THEN
            mvt_extent := min_extent;
        END IF;
        --

        --RAISE WARNING 'Zoom Level is: %, definition_multiplier is %, mvt_extent is %', z, definition_multiplier, mvt_extent;



        CREATE TEMPORARY TABLE hdi_extarg_tmp_table AS (
            SELECT
			h."GDLCODE" AS gdlcode,
			h."Life expectancy" AS LE,
			h."Mean years schooling" AS MYS,
			h."Expected years schooling" AS EYS,
			h."Log Gross National Income per capita" AS GDI,
			admin.calc_hdi( GREATEST((h."Life expectancy"+le_incr)::decimal,0.0)::decimal,
			                (h."Expected years schooling"+eys_incr)::decimal,
			                (h."Mean years schooling"+mys_incr)::decimal,
			                (h."Log Gross National Income per capita"*1000+gni_incr)::decimal) AS hdi
			FROM admin.hdi_input_data h
			WHERE h."GDLCODE" like 'USA%'
        );

		CREATE INDEX IF NOT EXISTS "hdi_extarg_tmp_table_idx1" ON "hdi_extarg_tmp_table" (gdlcode);

		DROP TABLE IF EXISTS bounds;

        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

		DROP TABLE IF EXISTS mvtgeom;

        CREATE TEMPORARY TABLE mvtgeom AS (

            SELECT ST_AsMVTGeom(a.geom, bounds.geom, extent => mvt_extent, buffer => mvt_buffer) AS geom,
			ROW_NUMBER () OVER (ORDER BY a.gdlcode) AS fid,
			a.gdlcode,
			--CAST(h.hdi as FLOAT)
			h.hdi,
            -- comment out after devel phase
			z as z,
			-- comment out after devel phase
			mvt_extent as mvt_extent_px
			--definition_multiplier as ext_multiplier_val
            FROM admin.admin1_3857 a
			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
            JOIN hdi_extarg_tmp_table h ON a.gdlcode = h.gdlcode
            ORDER BY a.gdlcode
            --LIMIT feat_limit
            );

        --COMMENT ON COLUMN mvtgeom.hdi is 'Human Development Index';
        --COMMENT ON COLUMN mvtgeom.gdlcode is 'National/Subnational administrative region unique identification code';

		--SELECT COUNT(geom) INTO featcount FROM mvtgeom;
        --RAISE WARNING 'featcount %', featcount;




        SELECT ST_AsMVT(mvtgeom.*,layer_name, mvt_extent, 'geom', 'fid')
		FROM mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.hdi_subnat_extarg_martin IS 'This is hdi_subnat_extarg_martin, please insert the desired multiplication values';



--SELECT * FROM admin.hdi_subnat_extarg_martin(0,0,0,'{"p1":"p1_NEW_data", "p2":"p4_data"}') AS OUTP;
--
--SELECT * FROM admin.hdi_subnat_extarg_martin(0,0,0,'{
--  "le_incr":
--    {"value":11},
--  "eys_incr":
--     {"value":22},
--    "mys_incr":
--     {"value":33},
--  "gni_incr":
--     {"value":44}
--}') AS OUTP;

-- example URL:

-- works in QGIS:
-- http://172.18.0.5:3000/rpc/admin.hdi_subnat_extarg_martin/{z}/{x}/{y}.pbf?query_params={"le_incr":{"value":11},"eys_incr":{"value":22},"mys_incr":{"value":33},"gni_incr":{"value":44}}http://172.18.0.6:7800/admin.hdi_subnat_extarg_martin/{z}/{x}/{y}.pbf?params={"le_incr":{"value":11},"eys_incr":{"value":22},"mys_incr":{"value":33},"gni_incr":{"value":44}}
