CREATE OR REPLACE FUNCTION sdg10.f_10_5_1_fi_fsi_fskrtc(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
    "subsets":
    {
    "series":{"value":"FI_FSI_FSKRTC","options":["FI_FSI_FSKRTC","FI_FSI_FSERA","FI_FSI_FSLS","FI_FSI_FSSNO"]},
    "sex_code":{"value":"F","options":["F","M","_T"]},
    "age_group":{"value":"18-24 years","options":["0-12 years","12-18 years","18-24 years","older than 24 years","total"]},
    "location":{"value":"urban","options":["urban","rural","total"]}
    }
    }'
    )


RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        layer_name varchar := 'sdg10.f_10_5_1_fi_fsi_fskrtc';


        simplified_table_name varchar := NULL;

        defaults_json jsonb;
		requested_json jsonb;
		sanitized_json jsonb;
		sanitized_subset_json jsonb;

        geom_col   varchar;
        featcount  integer;
        feat_limit integer := 3000;

        series     varchar := 'FI_FSI_FSERA';
        sex_code   varchar := 'F';
        age_group  varchar := '18-24 years';
        location   varchar := 'urban';

        min_extent integer := 256;
        max_extent integer := 4096;
        mvt_extent integer := 1024;
        mvt_buffer integer := 32;

        func_defaults jsonb :=
            '{
            "subsets":
                {
                "sex_code":{"value":"F","options":["F","M","_T"]},
                "age_group":{"value":"18-24 years","options":["0-12 years","12-18 years","18-24 years","older than 24 years","total"]},
                "location":{"value":"urban","options":["urban","rural","total"]}
            }
            }';

-- PL/PgSQL function to create a dynamic function layer (delivered as Vector Tiles) with filters


    BEGIN
        defaults_json  := func_defaults::jsonb;
        requested_json := params::jsonb;

        -- sanitize the JSON before proceeding
        --sanitized_subset_json:=admin.params_sanity_check(defaults_json->'subsets', requested_json->'subsets');

--      RAISE WARNING 'sanitized_json: %', sanitized_json;
--		RAISE WARNING 'sanitized_json -> le_incr: %',  sanitized_json->'le_incr';
--		RAISE WARNING 'sanitized_json -> le_incr -> value: %',  sanitized_json->'le_incr'->'value';

        -- extract the relevant parameters
        series     := requested_json->'subsets'->'series'->'value';
        sex_code   := requested_json->'subsets'->'sex_code'->'value';
        age_group  := requested_json->'subsets'->'age_group'->'value';
        location   := requested_json->'subsets'->'location'->'value';




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

--        RAISE WARNING 'Zoom Level is: %, mvt_extent is %', z, mvt_extent;

--			                admin.utils_enforce_limits(h."Life expectancy"+le_incr,                    func_defaults->'le_incr'->'abs_limits'->'min'::float,  func_defaults->'le_incr'->'abs_limits'->'max'::float)::decimal,
--			                admin.utils_enforce_limits(h."Expected years schooling"+eys_incr,          func_defaults->'eys_incr'->'abs_limits'->'min'::float, func_defaults->'eys_incr'->'abs_limits'->'max'::float)::decimal,
--			                admin.utils_enforce_limits(h."Mean years schooling"+mys_incr,              func_defaults->'mys_incr'->'abs_limits'->'min'::float, func_defaults->'mys_incr'->'abs_limits'->'max'::float)::decimal,
--			                admin.utils_enforce_limits(h."Gross National Income per capita"+gni_incr,  func_defaults->'gni_incr'->'abs_limits'->'min'::float, func_defaults->'gni_incr'->'abs_limits'->'max'::float)::decimal

		DROP TABLE IF EXISTS sdg_tmp_table;

		--sdg10.f_10_5_1_fi_fsi_fskrtc


		--TODO use EXECUTE FORMAT
        CREATE TEMPORARY TABLE sdg_tmp_table AS (
            SELECT
			a."iso3cd" AS iso3cd,
			a.value_2020 AS value_2020,
			a.value_latest AS value_latest
			FROM sdg10.admin0 a
			WHERE
			indicator = '10.5.1'
			AND
			a."series" = 'FI_FSI_FSSNO'
			AND
			a.value_latest IS NOT NULL
--            AND
--            a.age_group = age_group
--            AND
--            a.location = location
        );

        SELECT COUNT(*) FROM sdg_tmp_table INTO featcount;

        RAISE WARNING 'featcount %', featcount;

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
			a.iso3cd,
			CAST(h.value_2020 as FLOAT),
			CAST(h.value_latest as FLOAT)

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


        --COMMENT ON COLUMN mvtgeom.hdi is 'Human Development Index';

        --RAISE WARNING 'SIMPLIFIED into %', simplified_table_name;

        -- use 'default' as a layer name to make it possible to visualize it via pg_tileServ's internal map viewer
        layer_name := 'default';

        SELECT ST_AsMVT(mvtgeom.*,layer_name, mvt_extent, 'geom', 'fid')
		FROM mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION sdg10.f_10_5_1_fi_fsi_fskrtc IS 'This is dynamic subnational HDI, please insert the desired increment values';


--
--SELECT * FROM sdg10.f_10_5_1_fi_fsi_fskrtc(0,0,0,'{
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
-- wget http://172.18.0.6:7800/sdg10.f_10_5_1_fi_fsi_fskrtc/0/0/0.pbf?params='%7B%0A%20%20%22le_incr%22%3A%0A%20%20%20%20%7B%22value%22%3A11%7D%2C%0A%20%20%22eys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A22%7D%2C%0A%20%20%20%20%22mys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A33%7D%2C%0A%20%20%22gni_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A44%7D%0A%7D' -O ext.pbf

-- http://172.18.0.6:7800/sdg10.f_10_5_1_fi_fsi_fskrtc/{z}/{x}/{y}.pbf?params='%7B%0A%20%20%22le_incr%22%3A%0A%20%20%20%20%7B%22value%22%3A11%7D%2C%0A%20%20%22eys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A22%7D%2C%0A%20%20%20%20%22mys_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A33%7D%2C%0A%20%20%22gni_incr%22%3A%0A%20%20%20%20%20%7B%22value%22%3A44%7D%0A%7D'

-- works in QGIS:
-- http://172.18.0.6:7800/sdg10.f_10_5_1_fi_fsi_fskrtc/{z}/{x}/{y}.pbf?params={"le_incr":{"value":11},"eys_incr":{"value":22},"mys_incr":{"value":33},"gni_incr":{"value":44}}




--DROP VIEW IF EXISTS sdg10."f_10_5_1_fi_fsi_fskrtc";
--
--CREATE VIEW sdg10."f_10_5_1_fi_fsi_fskrtc" AS
--SELECT DISTINCT ON (a.geom) a.id, a.geom, s.*
--FROM admin.admin0 AS a
--INNER JOIN sdg10.admin0 AS s
--ON (a.iso3cd = s.iso3cd)
--WHERE
--s."indicator"='10.5.1' AND
--s."series" ='10_10.5.1_FI_FSI_FSKRTC';
--
--COMMENT ON VIEW sdg10."f_10_5_1_fi_fsi_fskrtc" IS 'Regulatory Tier 1 capital to risk-weighted assets (%)';

--
--SELECT * FROM sdg10.f_10_5_1_fi_fsi_fskrtc(0,0,0,'{
--    "subsets":
--    {
--    "sex_code":{"value":"F","options":["Female","Male","Total"]},
--    "age_group":{"value":"18-24 years","options":["0-12 years","12-18 years","18-24 years","older than 24 years","total"]},
--    "location":{"value":"urban","options":["urban","rural","total"]}
--    }
--    }') AS OUTP;

--SELECT * FROM "sdg10"."f_10_5_1_fi_fsi_fskrtc"(0,0,0,'{"subsets":{"series":"FI_FSI_FSSNO"}}') AS OUTP;
