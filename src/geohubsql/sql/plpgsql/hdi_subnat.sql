CREATE OR REPLACE FUNCTION admin.hdi_subnat(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    le_mult numeric default 1,
    eys_mult numeric default 1,
    mys_mult numeric default 1,
    gni_mult numeric default 1
    )
    RETURNS bytea AS $$
    DECLARE
        mvt bytea;
        geom_col varchar;
        featcount integer;
        feat_limit integer := 3000;
        extent integer := 1024;

-- PL/PgSQL function to create a dynamic function layer (delivered as Vector Tiles) with a representation of the Human Development Index
-- requires/accepts four input parameters which act as multipliers for the respective HDI formula parameters:
--			le_mult  multiplies the "Life expectancy" parameter
--			eys_mult multiplies the "Expected years schooling"  parameter
--			mys_mult multiplies the "Mean years schooling"  parameter
--			gni_mult multiplies the "Log Gross National Income per capita" parameter
-- input parameters can be passed in the URL
--
-- example URL:
-- http://172.18.0.6:7800/admin.hdi_subnat/{z}/{x}/{y}.pbf?le_mult=1.0&eys_mult=1.0&mys_mult=1.0&gni_mult=1.0

    BEGIN

        CREATE INDEX IF NOT EXISTS "admin1_3857_idx"  ON "admin"."admin1_3857" USING GIST (geom);
		CREATE INDEX IF NOT EXISTS "admin1_3857_idx1" ON "admin"."admin1_3857" (gdlcode);

        RAISE WARNING 'HEY';

		DROP TABLE IF EXISTS hdi_tmp_table;

        CREATE TEMPORARY TABLE hdi_tmp_table AS (
            SELECT
			h."GDLCODE" AS gdlcode,
			h."Life expectancy" AS LE,
			h."Mean years schooling" AS MYS,
			h."Expected years schooling" AS EYS,
			h."Log Gross National Income per capita" AS GDI,
			admin.calc_hdi(h."Life expectancy"*le_mult,h."Expected years schooling"*eys_mult ,h."Mean years schooling"*mys_mult , h."Log Gross National Income per capita"*1000*gni_mult) hdi
			FROM admin.hdi_input_data h
			--WHERE h."GDLCODE" like 'USA%'
        );

		CREATE INDEX IF NOT EXISTS "hdi_tmp_table_idx1" ON "hdi_tmp_table" (gdlcode);

		DROP TABLE IF EXISTS bounds;

        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

		DROP TABLE IF EXISTS mvtgeom;

        CREATE TEMPORARY TABLE mvtgeom AS (

            SELECT ST_AsMVTGeom(a.geom, bounds.geom, extent => extent, buffer => 32) AS geom,
			ROW_NUMBER () OVER (ORDER BY a.gdlcode) AS fid,
			a.gdlcode,
			CAST(h.hdi as FLOAT)
            FROM admin.admin1_3857 a
			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
            JOIN hdi_tmp_table h ON a.gdlcode = h.gdlcode
            ORDER BY a.gdlcode
            LIMIT feat_limit
            );


		--SELECT COUNT(geom) INTO featcount FROM mvtgeom;
        --RAISE WARNING 'featcount1 %', featcount;


-- use 'default' as a layer name to make it possible to visualize it via pg_tileServ's internal map viewer

        SELECT ST_AsMVT(mvtgeom.*,'admin.hdi_subnat', extent, 'geom', 'fid')
		FROM mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.hdi_subnat IS 'This is hdi_subnat, please insert the desired multiplication values';