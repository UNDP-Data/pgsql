CREATE OR REPLACE FUNCTION admin.layer_buffer(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
              "input_layer_name":"provide_layer_name",
              "buffer_distance":0
            }'
    )

--    layer_name text default 'admin.admin0',
--    buffer_distance decimal default 0

RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        output_layer_name varchar := 'admin.layer_buffer';
        --defaults_json jsonb;
		requested_json jsonb;
		input_layer_name text;
		buffer_distance float;
		--sanitized_json jsonb;


    BEGIN
        --mvt:=admin.hdi_subnat_extarg(z,x,y,query_params::text);
        --mvt:=function_name(z,x,y,query_params::text);
-- TODO
-- what if buffer_distance <=0 ?
-- what if geom column name is not 'geom' ?
-- what about the attributes in the original layer? -> drop them, the buffer will be likely used as a binary mask
--                                                  -> add an opt flag to the function parameters to preserve attrs
-- opt buffer distance taken from a field of the original layer?
-- check geom type?


        requested_json := params::jsonb;
        input_layer_name  := requested_json->'input_layer_name';
        buffer_distance  := (requested_json->'buffer_distance')::float;

        --RAISE WARNING 'layer_name: %, buffer_distance: %', input_layer_name, buffer_distance;

        -- takes about 50 millisecs to create
		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);


--SELECT
--       ST_AsMVTGeom(ST_Union(ST_Buffer(a.geom, 1000)), bounds.geom, extent => 2048, buffer => 256)) as geom
--FROM admin.water_facilities a;


--        DROP TABLE IF EXISTS temp_buffer;
--        CREATE TEMPORARY TABLE temp_buffer AS (
--            SELECT ST_Union(ST_Buffer(a.geom, 1000)) AS geom
--            FROM admin.water_facilities a
--        );
--
--        DROP TABLE IF EXISTS mvtgeom;
--        CREATE TEMPORARY TABLE mvtgeom AS (
--            SELECT ST_AsMVTGeom(t.geom, bounds.geom, extent => 2048, buffer => 256) AS geom
--            FROM (
--            SELECT ST_Union(ST_Buffer(a.geom, 1000)) AS geom
--            FROM admin.water_facilities a
--        ) t
--            JOIN bounds ON ST_Intersects(t.geom, bounds.geom)
--        );
--
--        SELECT ST_AsMVT(mvtgeom.*,'default', 2048, 'geom')
--		FROM AS mvtgeom
--		INTO mvt;




        SELECT ST_AsMVT(mvtgeom.*,'default', 2048, 'geom')
		FROM (
            SELECT ST_AsMVTGeom(t.geom, bounds.geom, extent => 2048, buffer => 256) AS geom
            FROM (
            SELECT ST_Union(ST_Buffer(a.geom, 1000)) AS geom
            FROM admin.water_facilities a
        ) t
            JOIN bounds ON ST_Intersects(t.geom, bounds.geom)
        ) AS mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.layer_buffer IS 'Buffer a vector layer by a given distance';

--
--SELECT * FROM admin.layer_buffer('admin.admin0',10000') AS OUTP;
--

--SELECT * FROM admin.layer_buffer(0,0,0,'{
--              "layer_name":"admin.water_facilities",
--              "buffer_distance":1000
--            }') AS OUTP;

-- works in QGIS:
-- http://172.18.0.6:7800/admin.layer_buffer/{z}/{x}/{y}.pbf?params={"input_layer_name":"admin.water_facilities","buffer_distance":10007}