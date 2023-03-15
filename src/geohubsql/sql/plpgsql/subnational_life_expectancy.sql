CREATE OR REPLACE FUNCTION admin.subnational_life_expectancy(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{}'
    )


RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        layer_name varchar := 'admin.subnational_life_expectancy';

        simplified_table_name varchar := NULL;

        geom_col varchar;
        featcount integer;
        feat_limit integer := 3000;


        mvt_extent integer := 1024;
        mvt_buffer integer := 32;


-- PL/PgSQL function to create a dynamic function layer (delivered as Vector Tiles) with a representation of one of the components of the Human Development Index
--
--			life_expectancy               "Life expectancy"
--			expected_years_of_schooling   "Expected years schooling"
--			mean_years_of_schooling       "Mean years schooling"
--			gross_national_income         "Gross National Income per capita"
--


    BEGIN

        -- use 'default' as a layer name to make it possible to visualize it via pg_tileServ's internal map viewer
        --layer_name := 'default';

		DROP TABLE IF EXISTS hdi_component_tmp_table_simpl;

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



        CREATE TEMPORARY TABLE hdi_component_tmp_table_simpl AS (
            SELECT
			h."GDLCODE" AS gdlcode,
			h."Life expectancy"::decimal AS life_expectancy,
			h."Expected years schooling"::decimal AS expected_years_of_schooling,
            h."Mean years schooling"::decimal AS mean_years_of_schooling,
            h."Gross National Income per capita"::decimal AS gross_national_income

			FROM admin.hdi_input_data h
			--WHERE h."GDLCODE" like 'USA%'
        );

		CREATE INDEX IF NOT EXISTS "hdi_component_tmp_table_simpl_idx1" ON "hdi_component_tmp_table_simpl" (gdlcode);


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
			CAST(h.life_expectancy as FLOAT)
            FROM admin."%s" a
			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
            JOIN hdi_component_tmp_table_simpl h ON a.gdlcode = h.gdlcode
            ORDER BY a.gdlcode
            --LIMIT feat_limit
            );',
            mvt_extent, mvt_buffer,
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

COMMENT ON FUNCTION admin.subnational_life_expectancy IS 'This is the subnational HDI component life_expectancy';


--
--SELECT * FROM admin.subnational_life_expectancy(0,0,0) AS OUTP;

-- example URL:
-- wget http://172.18.0.6:7800/admin.subnational_life_expectancy/0/0/0.pbf
-- http://172.18.0.6:7800/admin.subnational_life_expectancy/{z}/{x}/{y}.pbf
-- works in QGIS:
-- http://172.18.0.6:7800/admin.subnational_life_expectancy/{z}/{x}/{y}.pbf
