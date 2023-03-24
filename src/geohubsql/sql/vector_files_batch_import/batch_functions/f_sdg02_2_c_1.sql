CREATE OR REPLACE FUNCTION sdg02.f_2_c_1(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
    "subsets":
    {"type_of_pr": {"options": ["CPC2_1_113", "CPC2_1_114", "CPC2_1_118", "CPC2_1_112", "CPC2_1_111"], "value": "CPC2_1_113"}}
    }'
    )
--    "subsets":
--    {
--    "sex_code":{"value":"F","options":["F","M","_T"]},
--    "age_code":{"value":"18-24 years","options":["0-12 years","12-18 years","18-24 years","older than 24 years","total"]},
--    "location":{"value":"urban","options":["urban","rural","total"]},
--    "qualifier":{"value":"F","options":["Literacy","Numeracy"]}
--    }
--    }'

--to be replaced:
--sdg02
--REPLACE_INDICATOR
--2_c_1
--subsets
--REPLACE_DEFAULT_SUBSETS_JSON
--REPLACE_SQL_QUERY_1
--REPLACE_SQL_QUERY_2

RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        layer_name varchar := 'sdg02.f_2_c_1';


        simplified_table_name varchar := NULL;

        defaults_json jsonb;
		requested_json jsonb;
		sanitized_json jsonb;
		sanitized_subset_json jsonb;

        geom_col   varchar;
        featcount  integer;
        my_query   varchar;
        feat_limit integer := 3000;

        type_of_pr   varchar := '';
        

--        series     varchar := '';
--        sex_code   varchar := '';
--        age_code   varchar := '';
--        location   varchar := '';
--        qualifier  varchar := '';

        mvt_extent integer := 1024;
        mvt_buffer integer := 32;

        func_defaults jsonb :=
            '{
            "subsets":
            {"type_of_pr": {"options": ["CPC2_1_113", "CPC2_1_114", "CPC2_1_118", "CPC2_1_112", "CPC2_1_111"], "value": "CPC2_1_113"}}
            }';

-- PL/PgSQL function to create a dynamic function layer (delivered as Vector Tiles) with filters


    BEGIN
        defaults_json  := func_defaults::jsonb;
        requested_json := params::jsonb;

        -- sanitize the JSON before proceeding
        --sanitized_subset_json:=admin.params_sanity_check(defaults_json->'subsets', requested_json->'subsets');

        -- extract the relevant parameters

        type_of_pr   := requested_json->'subsets'->'type_of_pr'->>'value';
        

--        series     := requested_json->'subsets'->'series'->>'value';
--        sex_code   := requested_json->'subsets'->'sex_code'->>'value';
--        age_code   := requested_json->'subsets'->'age_code'->>'value';
--        location   := requested_json->'subsets'->'location'->>'value';
--        qualifier  := requested_json->'subsets'->'qualifier'->>'value';

--        SELECT jsonb_pretty(requested_json) INTO my_query;
--        RAISE WARNING 'JSON: %',my_query;

        --let's set St_AsMVT's extent as a function of the zoom level
        --in order to reduce network usage and increase the UX.
        EXECUTE format('SELECT * FROM admin.util_lookup_mvt_extent(%s)',z) INTO mvt_extent;


		DROP TABLE IF EXISTS sdg_tmp_table;

        SELECT format('CREATE TEMPORARY TABLE sdg_tmp_table AS (
            SELECT
			a."iso3cd" AS iso3cd
			, a.value_2020 , a.value_2017 , a.value_2019 , a.value_2018 , a.value_2015 , a.value_2016 
             , a.value_latest 
			FROM sdg02.admin0 a
			WHERE
    			indicator = ''2.c.1''
			AND a.type_of_pr = ''%s'' 
             AND a.value_latest IS NOT NULL 
        );'
        , type_of_pr 
        ) INTO my_query;

--        SELECT format('CREATE TEMPORARY TABLE sdg_tmp_table AS (
--            SELECT
--			a."iso3cd" AS iso3cd,
--			a.value_2020 AS value_2020,
--			a.value_latest AS value_latest
--			FROM sdg02.admin0 a
--			WHERE
--			indicator = ''%1$s''
--            AND
--            a.sex_code = ''%2$s''
--			AND
--            a.qualifier  = ''%3$s''
--			AND
--			a.value_latest IS NOT NULL
--        );',
--        '4.6.1', sex_code, qualifier
--        ) INTO my_query;

        EXECUTE my_query;

--        RAISE WARNING 'my_query: %', my_query;

--        SELECT COUNT(*) FROM sdg_tmp_table INTO featcount;
--        RAISE WARNING 'featcount %', featcount;

		CREATE INDEX IF NOT EXISTS "sdg_tmp_table_idx1" ON "sdg_tmp_table" (iso3cd);

		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

		DROP TABLE IF EXISTS mvtgeom;

        EXECUTE format('SELECT * FROM admin.util_lookup_simplified_table_name(''admin'',''admin0'',%s)',z) INTO simplified_table_name;

--        RAISE WARNING 'Using simplified table %', simplified_table_name;


        EXECUTE format('CREATE TEMPORARY TABLE mvtgeom AS (

            SELECT ST_AsMVTGeom(a.geom, bounds.geom, extent => %s, buffer => %s) AS geom,
			ROW_NUMBER () OVER (ORDER BY a.iso3cd) AS fid,
			a.iso3cd
            , CAST(h.value_2020 as FLOAT) , CAST(h.value_2017 as FLOAT) , CAST(h.value_2019 as FLOAT) , CAST(h.value_2018 as FLOAT) , CAST(h.value_2015 as FLOAT) , CAST(h.value_2016 as FLOAT) 
             , CAST(h.value_latest as FLOAT)  
			--definition_multiplier as ext_multiplier_val
            FROM admin."%s" a
			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
            JOIN sdg_tmp_table h ON a.iso3cd = h.iso3cd
            ORDER BY a.iso3cd
            --LIMIT feat_limit
            );',
            mvt_extent, mvt_buffer,
            simplified_table_name
            );

--        EXECUTE format('CREATE TEMPORARY TABLE mvtgeom AS (
--
--            SELECT ST_AsMVTGeom(a.geom, bounds.geom, extent => %s, buffer => %s) AS geom,
--			ROW_NUMBER () OVER (ORDER BY a.iso3cd) AS fid,
--			a.iso3cd,
--			CAST(h.value_2020 as FLOAT),
--			CAST(h.value_latest as FLOAT)
--
--			--definition_multiplier as ext_multiplier_val
--            FROM admin."%s" a
--			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
--            JOIN sdg_tmp_table h ON a.iso3cd = h.iso3cd
--            ORDER BY a.iso3cd
--            --LIMIT feat_limit
--            );',
--            mvt_extent, mvt_buffer,
--            simplified_table_name
--            );


        --COMMENT ON COLUMN mvtgeom.hdi is 'Human Development Index';

        --RAISE WARNING 'SIMPLIFIED into %', simplified_table_name;

        -- use 'default' as a layer name to make it possible to visualize it via pg_tileServ's internal map viewer
--        layer_name := 'default';

        SELECT ST_AsMVT(mvtgeom.*,layer_name, mvt_extent, 'geom', 'fid')
		FROM mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION sdg02.f_2_c_1 IS 'This is f_2_c_1
';

--SELECT * FROM "sdg02"."f_2_c_1"(0,0,0,'{"subsets":
--    {"type_of_pr": {"options": ["CPC2_1_113", "CPC2_1_114", "CPC2_1_118", "CPC2_1_112", "CPC2_1_111"], "value": "CPC2_1_113"}}
--    }') AS OUTP;