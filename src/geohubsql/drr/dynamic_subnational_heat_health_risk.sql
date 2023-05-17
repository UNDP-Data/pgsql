CREATE OR REPLACE FUNCTION drr.dynamic_subnational_hhr(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
  "max_t_adjustment":
    { "id":"max_t_adjustment",
      "param_name":"max_temperature_adjustment",
      "type":"numeric",
      "icon":"fa-regular fa-temperature-arrow-up",
      "limits":{"min":-10,"max":10},
      "abs_limits":{"min":250,"max":350},
      "value":0,
      "label":"Maximum temperature",
      "widget_type":"slider",
      "hidden":0,
      "units":"Celsius degrees"},
  "hdi_adjustment":
    { "id":"hdi_adjustment",
      "param_name":"hdi_adjustment",
      "type":"numeric",
      "icon":"fa-graduation-cap",
      "limits":{"min":-10,"max":10},
      "abs_limits":{"min":0,"max":1},
      "value":0,
      "label":"Human Development Index",
      "widget_type":"slider",
      "hidden":0,
      "units":"percent"},
  "working_age_pop_adjustment":
    { "id":"working_age_pop_adjustment",
      "param_name":"working_age_pop_adjustment",
      "type":"numeric",
      "icon":"fa-regular fa-user-tie",
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
      "limits":{"min":-10,"max":10},
      "abs_limits":{"min":0,"max":350000},
      "value":0,
      "label":"Gross National Income per Capita",
      "widget_type":"slider",
      "hidden":0,
      "units":"percent"},
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

        defaults_jsonb jsonb;
		requested_jsonb jsonb;
		sanitized_jsonb jsonb;

        geom_col varchar;
        featcount integer;
        feat_limit integer := 3000;

        min_extent integer := 256;
        max_extent integer := 4096;
        mvt_extent integer := 1024;
        mvt_buffer integer := 32;



        debug_val decimal;
        debug_val_str varchar;

        func_defaults jsonb :=
            '{
              "max_t_adjustment":
                { "id":"max_t_adjustment",
                  "param_name":"max_temperature_adjustment",
                  "type":"numeric",
                  "icon":"fa-regular fa-temperature-arrow-up",
                  "limits":{"min":-10,"max":10},
                  "abs_limits":{"min":250,"max":350},
                  "value":0,
                  "label":"Maximum temperature",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"Celsius degrees"},
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
                  "icon":"fa-regular fa-user-tie",
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
                  "label":"Gross National Income per Capita",
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
        defaults_jsonb  := func_defaults::jsonb;
        requested_jsonb := params::jsonb;

        -- sanitize the JSON before proceeding
        sanitized_jsonb:=admin.params_sanity_check(defaults_jsonb, requested_jsonb);

--      RAISE WARNING 'sanitized_jsonb: %', sanitized_jsonb;
--		RAISE WARNING 'sanitized_jsonb -> max_t_adjustment: %',  sanitized_jsonb->'max_t_adjustment';
--		RAISE WARNING 'sanitized_jsonb -> max_t_adjustment -> value: %',  sanitized_jsonb->'max_t_adjustment'->'value';

        --let's set St_AsMVT's extent as a function of the zoom level
        --in order to reduce network usage and increase the UX.


        EXECUTE format('SELECT * FROM admin.util_lookup_mvt_extent(%s)',z) INTO mvt_extent;


        DROP TABLE IF EXISTS hhr_extarg_tmp_table_simpl;


        CREATE TEMPORARY TABLE hhr_extarg_tmp_table_simpl AS (
            SELECT * FROM drr.calc_hhr_table(
                func_defaults, sanitized_jsonb
                )
            );


		CREATE INDEX IF NOT EXISTS "hhr_extarg_tmp_table_simpl_idx1" ON "hhr_extarg_tmp_table_simpl" (gdlcode);

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
			CAST(h.heat_health_risk_index as FLOAT) AS "heat_health_risk_index",
			CAST(h.hazard_index as FLOAT),
            CAST(h.vulnerability_index as FLOAT),
            CAST(h.exposure_index as FLOAT)
            FROM admin."%s" a
			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
            JOIN hhr_extarg_tmp_table_simpl h ON a.gdlcode = h.gdlcode
            ORDER BY a.gdlcode
            );',
            mvt_extent, mvt_buffer,
            simplified_table_name
            );

--        SELECT INTO debug_val count(heat_health_risk_index) FROM mvtgeom t LIMIT 1;
--        RAISE WARNING 'mvtgeom rows: %',debug_val;
----
--
--        SELECT INTO debug_val_str gdlcode FROM mvtgeom t ORDER BY gdlcode desc LIMIT 1;
--        RAISE WARNING 'geom: %',debug_val_str;
--        SELECT INTO debug_val_str ST_AsEWKT(geom) FROM mvtgeom t ORDER BY gdlcode desc LIMIT 1;
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
