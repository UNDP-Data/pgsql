CREATE OR REPLACE FUNCTION drr.dynamic_subnational_hhr(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
              "max_t_adjustment":
                { "id":"max_t_adjustment",
                  "param_name":"max_temperature_adjustment",
                  "type":"numeric",
                  "icon":"fa-regular fa-temperature-sun",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":250,"max":350},
                  "value":0,
                  "label":"Maximum temperature",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"Kelvin degrees"},
              "hdi_adjustment":
                { "id":"hdi_adjustment",
                  "param_name":"hdi_adjustment",
                  "type":"numeric",
                  "icon":"fa-graduation-cap",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":2},
                  "value":0,
                  "label":"Human Development Index",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"percent"},
              "working_age_pop_adjustment":
                { "id":"working_age_pop_adjustment",
                  "param_name":"working_age_pop_adjustment",
                  "type":"numeric",
                  "icon":"fa-regular fa-user-helmet-safety",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":100},
                  "value":0,
                  "label":"Working age population in percent",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"percent"},
              "gnipc_adjustment":
                { "id":"gnipc_adjustment",
                  "param_name":"gross_national_income_per_capita_adjustment",
                  "type":"numeric",
                  "icon":"fa-hand-holding-dollar",
                  "limits":{"min":-30000,"max":30000},
                  "abs_limits":{"min":0,"max":350000},
                  "value":0,
                  "label":"Gross National Income per Capita adjustment",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"USD"},
            "vhi_adjustment":
                { "id":"vhi_adjustment",
                  "param_name":"vhi_adjustment",
                  "type":"numeric",
                  "icon":"fa-solid fa-seedling",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":1},
                  "value":0,
                  "label":"Vegetation Health Index",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"percent"},
            "pop_density_adjustment":
                { "id":"pop_density_adjustment",
                  "param_name":"pop_density_adjustment",
                  "type":"numeric",
                  "icon":"fa-solid fa-people-group",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":1000000},
                  "value":0,
                  "label":"Population Density",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"percent"}
            }'
    )

-- Notes:
-- working_age_pop = 1 / population(15_64)
-- population(15_64) = 1 / (1 + working_age_pop)

-- do not use commas in the labels of the advertised JSON



RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        layer_name varchar := 'drr.dynamic_subnational_hhr';

        simplified_table_name varchar := NULL;

        defaults_json jsonb;
		requested_json jsonb;
		sanitized_json jsonb;

        geom_col varchar;
        featcount integer;
        feat_limit integer := 3000;

        max_t_adjustment  float default 0;
        hdi_adjustment float default 0;
        working_age_pop_adjustment float default 0;
        gnipc_adjustment float default 0;
        vhi_adjustment float default 0;
        pop_density_adjustment float default 0;

        max_t_min  float default 0;
        hdi_min float default 0;
        working_age_pop_min float default 0;

        vhi_min float default 0;
        pop_density_min float default 0;

        max_t_max  float default 0;
        hdi_max float default 0;
        working_age_pop_max float default 0;

        vhi_max float default 0;
        pop_density_max float default 0;

        max_t_value  float default 0;
        hdi_value float default 0;
        working_age_pop_value float default 0;
        gnipc_value float default 0;
        vhi_value float default 0;
        pop_density_value float default 0;

        min_extent integer := 256;
        max_extent integer := 4096;
        mvt_extent integer := 1024;
        mvt_buffer integer := 32;

        gnipc_min float default 0;
        gnipc_max float default 100;
        log_gnipc_min decimal;
        log_gnipc_max decimal;
        log_gnipc_diff decimal;

        pop_min  decimal;
        pop_max  decimal;
        pop_diff decimal;

        debug_val decimal;
        debug_val_str varchar;

        func_defaults jsonb :=
            '{
              "max_t_adjustment":
                { "id":"max_t_adjustment",
                  "param_name":"max_temperature_adjustment",
                  "type":"numeric",
                  "icon":"fa-regular fa-temperature-sun",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":250,"max":350},
                  "value":0,
                  "label":"Maximum temperature",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"Kelvin degrees"},
              "hdi_adjustment":
                { "id":"hdi_adjustment",
                  "param_name":"hdi_adjustment",
                  "type":"numeric",
                  "icon":"fa-graduation-cap",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":2},
                  "value":0,
                  "label":"Human Development Index",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"percent"},
              "working_age_pop_adjustment":
                { "id":"working_age_pop_adjustment",
                  "param_name":"working_age_pop_adjustment",
                  "type":"numeric",
                  "icon":"fa-regular fa-user-helmet-safety",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":100},
                  "value":0,
                  "label":"Working age population in percent",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"percent"},
              "gnipc_adjustment":
                { "id":"gnipc_adjustment",
                  "param_name":"gross_national_income_per_capita_adjustment",
                  "type":"numeric",
                  "icon":"fa-hand-holding-dollar",
                  "limits":{"min":-30000,"max":30000},
                  "abs_limits":{"min":0,"max":350000},
                  "value":0,
                  "label":"Gross National Income per Capita adjustment",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"USD"},
            "vhi_adjustment":
                { "id":"vhi_adjustment",
                  "param_name":"vhi_adjustment",
                  "type":"numeric",
                  "icon":"fa-solid fa-seedling",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":1},
                  "value":0,
                  "label":"Vegetation Health Index",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"percent"},
            "pop_density_adjustment":
                { "id":"pop_density_adjustment",
                  "param_name":"pop_density_adjustment",
                  "type":"numeric",
                  "icon":"fa-solid fa-people-group",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":0,"max":1000000},
                  "value":0,
                  "label":"Population Density",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"percent"}
            }';

-- PL/PgSQL function to create a dynamic function layer (delivered as Vector Tiles) with a representation of the Heat Health Risk
-- requires/accepts four input parameters which act as increment/decrement for the respective hhr formula parameters.
--
-- input parameters shall be passed as JSON in the URL


    BEGIN
        defaults_json  := func_defaults::jsonb;
        requested_json := params::jsonb;

        -- sanitize the JSON before proceeding
        sanitized_json:=admin.params_sanity_check(defaults_json, requested_json);

--      RAISE WARNING 'sanitized_json: %', sanitized_json;
--		RAISE WARNING 'sanitized_json -> max_t_adjustment: %',  sanitized_json->'max_t_adjustment';
--		RAISE WARNING 'sanitized_json -> max_t_adjustment -> value: %',  sanitized_json->'max_t_adjustment'->'value';

        -- extract the relevant parameters
        max_t_adjustment             := sanitized_json->'max_t_adjustment'->'value';
        hdi_adjustment               := sanitized_json->'hdi_adjustment'->'value';
        working_age_pop_adjustment   := sanitized_json->'working_age_pop_adjustment'->'value';
        gnipc_adjustment             := sanitized_json->'gnipc_adjustment'->'value';
        vhi_adjustment               := sanitized_json->'vhi_adjustment'->'value';
        pop_density_adjustment       := sanitized_json->'pop_density_adjustment'->'value';

        -- recast once to avoid doing that every row
        max_t_min               := (func_defaults->'max_t_adjustment'->'abs_limits'->'min')::float;
        hdi_min                 := (func_defaults->'hdi_adjustment'->'abs_limits'->'min')::float;
        working_age_pop_min     := (func_defaults->'working_age_pop_adjustment'->'abs_limits'->'min')::float;
        gnipc_min               := (func_defaults->'gnipc_adjustment'->'abs_limits'->'min')::float;
        vhi_min                 := (func_defaults->'vhi_adjustment'->'abs_limits'->'min')::float;
        pop_density_min         := (func_defaults->'pop_density_adjustment'->'abs_limits'->'min')::float;

        max_t_max               := (func_defaults->'max_t_adjustment'->'abs_limits'->'max')::float;
        hdi_max                 := (func_defaults->'hdi_adjustment'->'abs_limits'->'max')::float;
        working_age_pop_max     := (func_defaults->'working_age_pop_adjustment'->'abs_limits'->'max')::float;
        gnipc_max               := (func_defaults->'gnipc_adjustment'->'abs_limits'->'max')::float;
        vhi_max                 := (func_defaults->'vhi_adjustment'->'abs_limits'->'max')::float;
        pop_density_max         := (func_defaults->'pop_density_adjustment'->'abs_limits'->'max')::float;


        --RAISE WARNING 'max_t_adjustment: %, hdi_adjustment: %, working_age_pop_adjustment: %, gnipc_adjustment %, vhi_adjustment %, pop_density_adjustment %', max_t_adjustment, hdi_adjustment, working_age_pop_adjustment, gnipc_adjustment, vhi_adjustment, pop_density_adjustment;

        -- use 'default' as a layer name to make it possible to visualize it via pg_tileServ's internal map viewer
        --layer_name := 'default';



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

        --EXECUTE format('SELECT * FROM admin.util_lookup_simplified_table_name(''admin'',''admin1'',%s)',z) INTO simplified_table_name;

        -- comment out after devel phase
        --mvt_extent := definition_multiplier*mvt_extent;
--        IF (mvt_extent > max_extent) THEN
--            mvt_extent := max_extent;
--        END IF;
--        IF (mvt_extent < min_extent) THEN
--            mvt_extent := min_extent;
--        END IF;
        --

--        RAISE WARNING 'Zoom Level is: %, mvt_extent is %', z, mvt_extent;

--			                admin.utils_enforce_limits(h."Life expectancy"+le_incr,                    func_defaults->'le_incr'->'abs_limits'->'min'::float,  func_defaults->'le_incr'->'abs_limits'->'max'::float)::decimal,
--			                admin.utils_enforce_limits(h."Expected years schooling"+eys_incr,          func_defaults->'eys_incr'->'abs_limits'->'min'::float, func_defaults->'eys_incr'->'abs_limits'->'max'::float)::decimal,
--			                admin.utils_enforce_limits(h."Mean years schooling"+mys_incr,              func_defaults->'mys_incr'->'abs_limits'->'min'::float, func_defaults->'mys_incr'->'abs_limits'->'max'::float)::decimal,
--			                admin.utils_enforce_limits(h."Gross National Income per capita"+gni_incr,  func_defaults->'gni_incr'->'abs_limits'->'min'::float, func_defaults->'gni_incr'->'abs_limits'->'max'::float)::decimal

        DROP TABLE IF EXISTS hhr_extarg_tmp_table_simpl;

--max_t_adjustment	°C	-5	5  **normalize
--hdi_adjustment	%	-10	10
--working_age_pop_adjustment	%	-10	10  **recalc dependency ratio
--gnipc_adjustment	$	-10000	10000
--vhi_adjustment	%	-10	10
--pop_density_adjustment	%	-10	10

        SELECT h."gnipc"
		FROM drr.hhr_input_data h
		ORDER BY h."gnipc" ASC LIMIT 1
		INTO gnipc_min;

        SELECT h."gnipc"
		FROM drr.hhr_input_data h
		ORDER BY h."gnipc" DESC LIMIT 1
		INTO gnipc_max;

        log_gnipc_min := LOG(gnipc_min);
        log_gnipc_max := LOG(gnipc_max);
        log_gnipc_diff := log_gnipc_max - log_gnipc_min;

        SELECT h."pop_density"
		FROM drr.hhr_input_data h
		ORDER BY h."pop_density" ASC LIMIT 1
		INTO pop_min;

        SELECT h."pop_density"
		FROM drr.hhr_input_data h
		ORDER BY h."pop_density" DESC LIMIT 1
		INTO pop_max;

		pop_diff := pop_max - pop_min;

        CREATE TEMPORARY TABLE hhr_extarg_tmp_table_simpl AS (
            SELECT
			h."gdlcode" AS gdlcode,
            admin.utils_enforce_limits(h."max_t"                + max_t_adjustment,  max_t_min,   max_t_max)::decimal AS max_t,
            admin.utils_enforce_limits(h."hdi"                  * (1+hdi_adjustment/100),  hdi_min,   hdi_max)::decimal AS hdi,
            admin.utils_enforce_limits(h."working_age_pop"      * (1+working_age_pop_adjustment/100),  working_age_pop_min,   working_age_pop_max)::decimal AS working_age_pop,
            admin.utils_enforce_limits(h."gnipc"                + gnipc_adjustment,  gnipc_min,   gnipc_max)::decimal AS gnipc,
            admin.utils_enforce_limits(h."vhi"                  * (1+vhi_adjustment/100),  vhi_min,   vhi_max)::decimal AS vhi,
            admin.utils_enforce_limits(h."pop_density"          * (1+pop_density_adjustment/100),  pop_density_min,   pop_density_max)::decimal AS pop_density,
			drr.calc_hhr(
			                admin.utils_enforce_limits(h."max_t"                + max_t_adjustment,  max_t_min,   max_t_max)::decimal,
			                admin.utils_enforce_limits(h."hdi"                  * (1+hdi_adjustment/100),  hdi_min,   hdi_max)::decimal,
			                admin.utils_enforce_limits(h."working_age_pop"      * (1+working_age_pop_adjustment/100),  working_age_pop_min,   working_age_pop_max)::decimal,
			                admin.utils_enforce_limits(h."gnipc"                + gnipc_adjustment,  gnipc_min,   gnipc_max)::decimal,
			                admin.utils_enforce_limits(h."vhi"                  * (1+vhi_adjustment/100),  vhi_min,   vhi_max)::decimal,
			                admin.utils_enforce_limits(h."pop_density"          * (1+pop_density_adjustment/100),  pop_density_min,   pop_density_max)::decimal,
			                log_gnipc_min,
			                log_gnipc_diff,
			                pop_min,
			                pop_diff
			                ) AS hhr
			FROM drr.hhr_input_data h
			--WHERE h."GDLCODE" like 'USA%'
        );


        --RAISE WARNING 'TTT % % %', max_t_adjustment, max_t_min, max_t_max;
--        SELECT INTO debug_val count(hhr) FROM hhr_extarg_tmp_table_simpl t LIMIT 1;
--        RAISE WARNING 'hhr_extarg_tmp_table_simpl rows: %',debug_val;
--        SELECT INTO debug_val hdi FROM hhr_extarg_tmp_table_simpl t LIMIT 1;
--        RAISE WARNING 'hhr_extarg_tmp_table_simpl hdi: %',debug_val;


		CREATE INDEX IF NOT EXISTS "hhr_extarg_tmp_table_simpl_idx1" ON "hhr_extarg_tmp_table_simpl" (gdlcode);

        -- takes about 50 millisecs to create
		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

		DROP TABLE IF EXISTS mvtgeom;

        EXECUTE format('SELECT * FROM admin.util_lookup_simplified_table_name(''admin'',''admin1'',%s)',z) INTO simplified_table_name;

--        RAISE WARNING 'Using simplified table %', simplified_table_name;

        EXECUTE format('CREATE TEMPORARY TABLE mvtgeom AS (

            SELECT ST_AsMVTGeom(a.geom, bounds.geom, extent => %s, buffer => %s) AS geom,
			ROW_NUMBER () OVER (ORDER BY a.gdlcode) AS fid,
			a.gdlcode,
			CAST(h.hhr as FLOAT),
			CAST(h.max_t as FLOAT),
			CAST(h.hdi as FLOAT),
			CAST(h.working_age_pop as FLOAT),
			CAST(h.gnipc as FLOAT),
			CAST(h.vhi as FLOAT),
			CAST(h.pop_density as FLOAT)
            FROM admin."%s" a
			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
            JOIN hhr_extarg_tmp_table_simpl h ON a.gdlcode = h.gdlcode
            ORDER BY a.gdlcode
            );',
            mvt_extent, mvt_buffer,
            simplified_table_name
            );

--        SELECT INTO debug_val count(hhr) FROM mvtgeom t LIMIT 1;
--        RAISE WARNING 'mvtgeom rows: %',debug_val;
--
--        SELECT INTO debug_val_str ST_AsEWKT(geom) FROM mvtgeom t LIMIT 1;
--        RAISE WARNING 'geom: %',debug_val_str;

        --COMMENT ON COLUMN mvtgeom.hhr is 'Human Development Index';

        --RAISE WARNING 'SIMPLIFIED into %', simplified_table_name;

        SELECT ST_AsMVT(mvtgeom.*,layer_name, mvt_extent, 'geom', 'fid')
		FROM mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION drr.dynamic_subnational_hhr IS 'This is dynamic subnational hhr, please insert the desired increment values';

--
-- SELECT * FROM drr.dynamic_subnational_hhr(0,0,0,'{
--  "max_t_adjustment":
--    {"value":5},
--  "hdi_adjustment":
--     {"value":3},
--  "working_age_pop_adjustment":
--     {"value":4},
--  "gnipc_adjustment":
--     {"value":5000},
--  "vhi_adjustment":
--     {"value":6},
--  "pop_density_adjustment":
--     {"value":7}
-- }') AS OUTP;

-- example URL:
-- wget http://172.18.0.6:7800/drr.dynamic_subnational_hhr/0/0/0.pbf?params='%7B%0A%20%20%22le_incr%22%3A%0A%20%20%20%20%7B%22value%22%3A11%7D%2C%0A%20%20%22eys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A22%7D%2C%0A%20%20%20%20%22mys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A33%7D%2C%0A%20%20%22gni_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A44%7D%0A%7D' -O ext.pbf

-- works in QGIS:
-- http://172.18.0.6:7800/drr.dynamic_subnational_hhr/{z}/{x}/{y}.pbf?params={ "max_t_adjustment": {"value":5}, "hdi_adjustment": {"value":3}, "working_age_pop_adjustment": {"value":4}, "gnipc_adjustment": {"value":5000}, "vhi_adjustment": {"value":6}, "pop_density_adjustment": {"value":7} }
