CREATE OR REPLACE FUNCTION admin.hdi_subnat(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    life_expectancy_multiplier numeric default 1,
    expected_years_of_schooling_multiplier numeric default 1,
    mean_years_of_schooling_multiplier numeric default 1,
    gross_national_income_multiplier numeric default 1,
    definition_multiplier float default 1
    )

    RETURNS bytea AS $$
    DECLARE
        layer_name varchar := 'admin.hdi_subnat';

        mvt bytea;
        geom_col varchar;
        featcount integer;
        feat_limit integer := 3000;

        min_extent integer := 256;
        max_extent integer := 4096;
        mvt_extent integer := 1024;
        mvt_buffer integer := 32;


-- PL/PgSQL function to create a dynamic function layer (delivered as Vector Tiles) with a representation of the Human Development Index
-- requires/accepts four input parameters which act as multipliers for the respective HDI formula parameters:
--			life_expectancy_multiplier  multiplies the "Life expectancy" parameter
--			expected_years_of_schooling_multiplier multiplies the "Expected years schooling"  parameter
--			mean_years_of_schooling_multiplier multiplies the "Mean years schooling"  parameter
--			gross_national_income_multiplier multiplies the "Log Gross National Income per capita" parameter
-- input parameters can be passed in the URL
--
-- example URL:
-- http://172.18.0.6:7800/admin.hdi_subnat/{z}/{x}/{y}.pbf?life_expectancy_multiplier=1.0&expected_years_of_schooling_multiplier=1.0&mean_years_of_schooling_multiplier=1.0&gross_national_income_multiplier=1.0

    BEGIN

    -- uncomment to visualize with pg_tileServ's internal viewer:
    --layer_name := 'default';


		DROP TABLE IF EXISTS hdi_tmp_table;

        --let's set St_AsMVT's extent as a function of the zoom level
        --in order to reduce network usage and increase the UX.

        CASE
            WHEN (z<=1) THEN
                mvt_extent := 256*2;
            WHEN (z=2) THEN
                mvt_extent := 256*2;
            WHEN (z=3) THEN
                mvt_extent := 512*2;
            WHEN (z=4) THEN
                mvt_extent := 512*2;
            WHEN (z=5) THEN
                mvt_extent := 512*2;
            WHEN (z>6)AND(z<=10) THEN
                mvt_extent := 1024*2;
            WHEN (z>10)AND(z<=12) THEN
                mvt_extent := 2048*2;
            ELSE
                mvt_extent := 4096;
        END CASE;


        -- comment out after devel phase
        mvt_extent := definition_multiplier*mvt_extent;
        IF (mvt_extent > max_extent) THEN
            mvt_extent := max_extent;
        END IF;
        IF (mvt_extent < min_extent) THEN
            mvt_extent := min_extent;
        END IF;
        --

        --RAISE WARNING 'Zoom Level is: %, definition_multiplier is %, mvt_extent is %', z, definition_multiplier, mvt_extent;

        CREATE TEMPORARY TABLE hdi_tmp_table AS (
            SELECT
			h."GDLCODE" AS gdlcode,
			h."Life expectancy" AS LE,
			h."Mean years schooling" AS MYS,
			h."Expected years schooling" AS EYS,
			h."Log Gross National Income per capita" AS GDI,
			admin.calc_hdi( h."Life expectancy"*life_expectancy_multiplier,
			                h."Expected years schooling"*expected_years_of_schooling_multiplier,
			                h."Mean years schooling"*mean_years_of_schooling_multiplier,
			                h."Log Gross National Income per capita"*1000*gross_national_income_multiplier) hdi
			FROM admin.hdi_input_data h
--			WHERE h."GDLCODE" like 'USA%'
        );

		CREATE INDEX IF NOT EXISTS "hdi_tmp_table_idx1" ON "hdi_tmp_table" (gdlcode);

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
			CAST(h.hdi as FLOAT),
            -- comment out after devel phase
			-- z as z,
			-- comment out after devel phase
			mvt_extent as mvt_extent_px,
			definition_multiplier as ext_multiplier_val
            FROM admin.admin1_3857 a
			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
            JOIN hdi_tmp_table h ON a.gdlcode = h.gdlcode
            ORDER BY a.gdlcode
            --LIMIT feat_limit
            );

        --COMMENT ON COLUMN mvtgeom.hdi is 'Human Development Index';
        --COMMENT ON COLUMN mvtgeom.gdlcode is 'National/Subnational administrative region unique identification code';

		--SELECT COUNT(geom) INTO featcount FROM mvtgeom;
        --RAISE WARNING 'featcount1 %', featcount;


-- use 'default' as a layer name to make it possible to visualize it via pg_tileServ's internal map viewer

        SELECT ST_AsMVT(mvtgeom.*,layer_name, mvt_extent, 'geom', 'fid')
		FROM mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.hdi_subnat IS 'This is hdi_subnat, please insert the desired multiplication values';

