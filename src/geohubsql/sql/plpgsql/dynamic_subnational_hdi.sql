CREATE OR REPLACE FUNCTION admin.dynamic_subnational_hdi(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
              "le_incr":
                { "id":"le_incr",
                  "param_name":"life_expectancy_increment",
                  "type":"numeric",
                  "icon":"fa-people-roof",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":100},
                  "value":0,
                  "label":"Increment of life expectancy",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "eys_incr":
                { "id":"eys_incr",
                  "param_name":"expected_years_of_schooling_increment",
                  "type":"numeric",
                  "icon":"fa-graduation-cap",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":30},
                  "value":0,
                  "label":"Increment of expected education",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "mys_incr":
                { "id":"mys_incr",
                  "param_name":"mean_years_of_schooling_increment",
                  "type":"numeric",
                  "icon":"fa-school",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":30},
                  "value":0,
                  "label":"Increment of mean education",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "gni_incr":
                { "id":"gni_incr",
                  "param_name":"gross_national_income_increment",
                  "type":"numeric",
                  "icon":"fa-hand-holding-dollar",
                  "limits":{"min":-30000,"max":30000},
                  "abs_limits":{"min":0,"max":350000},
                  "value":0,
                  "label":"Income increment",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"USD"}
            }'
    )


RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        layer_name varchar := 'admin.hdi_subnat_extarg_simpl';

        simplified_table_name varchar := NULL;

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

        le_min  float default 0;
        eys_min float default 0;
        mys_min float default 0;
        gni_min float default 0;

        le_max  float default 0;
        eys_max float default 0;
        mys_max float default 0;
        gni_max float default 0;

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
                { "id":"le_incr",
                  "param_name":"life_expectancy_increment",
                  "type":"numeric",
                  "icon":"fa-people-roof",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":100},
                  "value":0,
                  "label":"Increment of life expectancy",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "eys_incr":
                { "id":"eys_incr",
                  "param_name":"expected_years_of_schooling_increment",
                  "type":"numeric",
                  "icon":"fa-graduation-cap",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":30},
                  "value":0,
                  "label":"Increment of expected education",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "mys_incr":
                { "id":"mys_incr",
                  "param_name":"mean_years_of_schooling_increment",
                  "type":"numeric",
                  "icon":"fa-school",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":30},
                  "value":0,
                  "label":"Increment of mean education",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"years"},
              "gni_incr":
                { "id":"gni_incr",
                  "param_name":"gross_national_income_increment",
                  "type":"numeric",
                  "icon":"fa-hand-holding-dollar",
                  "limits":{"min":-30000,"max":30000},
                  "abs_limits":{"min":0,"max":350000},
                  "value":0,
                  "label":"Income increment",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"USD"}
            }';

-- PL/PgSQL function to create a dynamic function layer (delivered as Vector Tiles) with a representation of the Human Development Index
-- requires/accepts four input parameters which act as increment/decrement for the respective HDI formula parameters:
--
--			life_expectancy_increment               increments/decrements the "Life expectancy" parameter
--			expected_years_of_schooling_increment   increments/decrements the "Expected years schooling"  parameter
--			mean_years_of_schooling_increment       increments/decrements the "Mean years schooling"  parameter
--			gross_national_income_increment         increments/decrements the "Gross National Income per capita" parameter
--
-- input parameters shall be passed as JSON in the URL


    BEGIN
        defaults_json  := func_defaults::jsonb;
        requested_json := params::jsonb;

        -- sanitize the JSON before proceeding
        sanitized_json:=admin.params_sanity_check(defaults_json, requested_json);

--      RAISE WARNING 'sanitized_json: %', sanitized_json;
--		RAISE WARNING 'sanitized_json -> le_incr: %',  sanitized_json->'le_incr';
--		RAISE WARNING 'sanitized_json -> le_incr -> value: %',  sanitized_json->'le_incr'->'value';

        -- extract the relevant parameters
        le_incr  := sanitized_json->'le_incr'->'value';
        eys_incr := sanitized_json->'eys_incr'->'value';
        mys_incr := sanitized_json->'mys_incr'->'value';
        gni_incr := sanitized_json->'gni_incr'->'value';

        -- recast once to avoid doing that every row
        le_min  := (func_defaults->'le_incr'->'abs_limits'->'min')::float;
        eys_min := (func_defaults->'eys_incr'->'abs_limits'->'min')::float;
        mys_min := (func_defaults->'mys_incr'->'abs_limits'->'min')::float;
        gni_min := (func_defaults->'gni_incr'->'abs_limits'->'min')::float;

        le_max  := (func_defaults->'le_incr'->'abs_limits'->'max')::float;
        eys_max := (func_defaults->'eys_incr'->'abs_limits'->'max')::float;
        mys_max := (func_defaults->'mys_incr'->'abs_limits'->'max')::float;
        gni_max := (func_defaults->'gni_incr'->'abs_limits'->'max')::float;


        --RAISE WARNING 'le_incr: %, eys_incr: %, mys_incr: %, gni_incr %', le_incr, eys_incr, mys_incr, gni_incr;

        -- use 'default' as a layer name to make it possible to visualize it via pg_tileServ's internal map viewer
        --layer_name := 'default';

		DROP TABLE IF EXISTS hdi_extarg_tmp_table_simpl;

        --let's set St_AsMVT's extent as a function of the zoom level
        --in order to reduce network usage and increase the UX.


        EXECUTE format('SELECT * FROM admin.util_lookup_mvt_extent(%s)',z) INTO mvt_extent;

-- TODO benckmark CASEs vs util_lookup_mvt_extent
--        CASE
--            WHEN (z<=1) THEN
--                mvt_extent := 512;
--            WHEN (z=2) THEN
--                mvt_extent := 512;
--            WHEN (z=3) THEN
--                mvt_extent := 512;
--            WHEN (z=4) THEN
--                mvt_extent := 512;
--            WHEN (z=5) THEN
--                mvt_extent := 512;
--            WHEN (z>6)AND(z<=10) THEN
--                mvt_extent := 1024;
--            WHEN (z>10)AND(z<=12) THEN
--                mvt_extent := 2048;
--            ELSE
--                mvt_extent := 4096;
--        END CASE;

        --EXECUTE format('SELECT * FROM admin.util_lookup_simplified_table_name(''admin'',''admin1_3857'',%s)',z) INTO simplified_table_name;

        -- comment out after devel phase
        --mvt_extent := definition_multiplier*mvt_extent;
--        IF (mvt_extent > max_extent) THEN
--            mvt_extent := max_extent;
--        END IF;
--        IF (mvt_extent < min_extent) THEN
--            mvt_extent := min_extent;
--        END IF;
        --

        RAISE WARNING 'Zoom Level is: %, mvt_extent is %', z, mvt_extent;

--			                admin.utils_enforce_limits(h."Life expectancy"+le_incr,                    func_defaults->'le_incr'->'abs_limits'->'min'::float,  func_defaults->'le_incr'->'abs_limits'->'max'::float)::decimal,
--			                admin.utils_enforce_limits(h."Expected years schooling"+eys_incr,          func_defaults->'eys_incr'->'abs_limits'->'min'::float, func_defaults->'eys_incr'->'abs_limits'->'max'::float)::decimal,
--			                admin.utils_enforce_limits(h."Mean years schooling"+mys_incr,              func_defaults->'mys_incr'->'abs_limits'->'min'::float, func_defaults->'mys_incr'->'abs_limits'->'max'::float)::decimal,
--			                admin.utils_enforce_limits(h."Gross National Income per capita"+gni_incr,  func_defaults->'gni_incr'->'abs_limits'->'min'::float, func_defaults->'gni_incr'->'abs_limits'->'max'::float)::decimal


        CREATE TEMPORARY TABLE hdi_extarg_tmp_table_simpl AS (
            SELECT
			h."GDLCODE" AS gdlcode,
			--h."Life expectancy" AS LE,
			--h."Mean years schooling" AS MYS,
			--h."Expected years schooling" AS EYS,
			--h."Gross National Income per capita" AS GDI,
			admin.calc_hdi(
			                admin.utils_enforce_limits(h."Life expectancy"                  + le_incr,  le_min,   le_max)::decimal,
			                admin.utils_enforce_limits(h."Expected years schooling"         + eys_incr, eys_min,  eys_max)::decimal,
			                admin.utils_enforce_limits(h."Mean years schooling"             + mys_incr, mys_min,  mys_max)::decimal,
			                admin.utils_enforce_limits(h."Gross National Income per capita" + gni_incr, gni_min,  gni_max)::decimal
			                ) AS hdi
			FROM admin.hdi_input_data h
			--WHERE h."GDLCODE" like 'USA%'
        );

		CREATE INDEX IF NOT EXISTS "hdi_extarg_tmp_table_simpl_idx1" ON "hdi_extarg_tmp_table_simpl" (gdlcode);

        -- takes about 50 millisecs to create
		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

		DROP TABLE IF EXISTS mvtgeom;

        EXECUTE format('SELECT * FROM admin.util_lookup_simplified_table_name(''admin'',''admin1_3857'',%s)',z) INTO simplified_table_name;

--        RAISE WARNING 'Uding implified table %', simplified_table_name;

        EXECUTE format('CREATE TEMPORARY TABLE mvtgeom AS (

            SELECT ST_AsMVTGeom(a.geom, bounds.geom, extent => %s, buffer => %s) AS geom,
			ROW_NUMBER () OVER (ORDER BY a.gdlcode) AS fid,
			a.gdlcode,
			CAST(h.hdi as FLOAT),
			--h.hdi,
            -- comment out after devel phase
			CAST(%s as INTEGER) as z,
			CAST(%s as INTEGER) as x,
			CAST(%s as INTEGER) as y,
			-- comment out after devel phase
			CAST(%s as INTEGER) as mvt_extent_px,
			''%s'' as table_name
			--definition_multiplier as ext_multiplier_val
            FROM admin."%s" a
			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
            JOIN hdi_extarg_tmp_table_simpl h ON a.gdlcode = h.gdlcode
            ORDER BY a.gdlcode
            --LIMIT feat_limit
            );',
            mvt_extent, mvt_buffer,
            z, x, y,
            mvt_extent, simplified_table_name,
            simplified_table_name
            );


        --COMMENT ON COLUMN mvtgeom.hdi is 'Human Development Index';

        --RAISE WARNING 'SIMPLIFIED into %', simplified_table_name;

        SELECT ST_AsMVT(mvtgeom.*,layer_name, mvt_extent, 'geom', 'fid')
		FROM mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.hdi_subnat_extarg_simpl IS 'This is hdi_subnat_extarg_simpl, please insert the desired increment values';


--
--SELECT * FROM admin.hdi_subnat_extarg_simpl(0,0,0,'{
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
-- wget http://172.18.0.6:7800/admin.hdi_subnat_extarg_simpl/0/0/0.pbf?params='%7B%0A%20%20%22le_incr%22%3A%0A%20%20%20%20%7B%22value%22%3A11%7D%2C%0A%20%20%22eys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A22%7D%2C%0A%20%20%20%20%22mys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A33%7D%2C%0A%20%20%22gni_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A44%7D%0A%7D' -O ext.pbf

-- http://172.18.0.6:7800/admin.hdi_subnat_extarg_simpl/{z}/{x}/{y}.pbf?params='%7B%0A%20%20%22le_incr%22%3A%0A%20%20%20%20%7B%22value%22%3A11%7D%2C%0A%20%20%22eys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A22%7D%2C%0A%20%20%20%20%22mys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A33%7D%2C%0A%20%20%22gni_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A44%7D%0A%7D'

-- works in QGIS:
-- http://172.18.0.6:7800/admin.hdi_subnat_extarg_simpl/{z}/{x}/{y}.pbf?params={"le_incr":{"value":11},"eys_incr":{"value":22},"mys_incr":{"value":33},"gni_incr":{"value":44}}
