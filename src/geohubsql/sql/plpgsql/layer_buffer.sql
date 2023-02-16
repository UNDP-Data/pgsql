CREATE OR REPLACE FUNCTION admin.layer_buffer (
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
                "input_layer_name":
                { "id":"input_layer_name",
                  "param_name":"input_layer_name",
                  "type":"text",
                  "icon":"fa-people-roof",
                  "label":"Layer to be buffered in schema.table format",
                  "widget_type":"search box",
                  "value":"admin.input_layer",
                  "hidden":0},
                "buffer_distance":
                { "id":"buffer_distance",
                  "param_name":"buffer_distance",
                  "type":"numeric",
                  "icon":"fa-graduation-cap",
                  "limits":{"min":0,"max":100000},
                  "abs_limits":{"min":0,"max":100000},
                  "value":0,
                  "label":"Buffer radius/distance in meters",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"meters"}
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
		simplify_distance float;
		--tile_buffer_distance float;
		res_counter int;
		sql_stmt text;
		--sanitized_json jsonb;


    BEGIN
        --mvt:=admin.hdi_subnat_extarg(z,x,y,query_params::text);
        --mvt:=function_name(z,x,y,query_params::text);
-- TODO
-- make the input params coherent with the structure used in function layers -- DONE
-- what if buffer_distance <=0 ?
-- what if geom column name is not 'geom' ?
-- what about the attributes in the original layer? -> drop them, the buffer will be likely used as a binary mask
--                                                  -> add an opt flag to the function parameters to preserve attrs
-- opt buffer distance taken from a field of the original layer?
-- check geom type?

        requested_json       := params::jsonb;
        input_layer_name     := trim('"' FROM (requested_json->'input_layer_name'->'value')::text);
        buffer_distance      := (requested_json->'buffer_distance'->'value')::float;
        simplify_distance    := buffer_distance/4;
        --tile_buffer_distance := buffer_distance/2;



		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

        DROP TABLE IF EXISTS temp_buffer;

        -- we need to buffer the tiles of the bounds table to include the buffers of features in neighbouring tiles.
        sql_stmt = format('
            CREATE TEMPORARY TABLE temp_buffer AS (
                SELECT ST_Buffer(ST_Simplify(a.geom, %s), %s) AS geom
                FROM %s a
                JOIN bounds AS b
                ON ST_Intersects(a.geom, ST_Buffer(b.geom, %s))
                )',
            simplify_distance,
            buffer_distance,
            input_layer_name,
            buffer_distance
        );

        EXECUTE sql_stmt;

--        RAISE WARNING '# # # # # # # # # # # # # # # input_layer_name: %',sql_stmt;
--        SELECT COUNT(*) FROM temp_buffer INTO res_counter;
--        RAISE WARNING '################# input_layer_name: %, buffer_distance: %, simplify_distance:%, res_counter:%', input_layer_name, buffer_distance, simplify_distance, res_counter;

--        no measurable effect
--        CREATE INDEX IF NOT EXISTS temp_geom_idx ON temp_buffer USING GIST (geom);

        DROP TABLE IF EXISTS temp_buffer_union;
        CREATE TEMPORARY TABLE temp_buffer_union AS (
            SELECT ST_Union(a.geom) AS geom
            FROM temp_buffer a
            );


       DROP TABLE IF EXISTS mvtgeom;
       CREATE TEMPORARY TABLE mvtgeom AS (
           SELECT ST_AsMVTGeom(t.geom, bounds.geom, extent => 2048, buffer => 256) AS geom
           FROM temp_buffer_union t
           JOIN bounds ON ST_Intersects(t.geom, bounds.geom)
       );

        SELECT ST_AsMVT(mvtgeom.*, 'admin.layer_buffer', 2048, 'geom')
        FROM mvtgeom AS mvtgeom
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

--SELECT * FROM admin.layer_buffer(0,0,0,'{
-- "input_layer_name":
--   {"value":"admin.water_facilities"},
-- "buffer_distance":
--    {"value":1200}
--           }') AS OUTP;

--SELECT * FROM admin.layer_buffer(0,0,0,'{
--  "input_layer_name":"admin.water_facilities",
--  "buffer_distance":500}') AS OUTP;

-- works in QGIS:
-- http://172.18.0.6:7800/admin.layer_buffer/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.water_facilities"},"buffer_distance":{"value":1200}}
-- http://172.18.0.6:7800/admin.layer_buffer/{z}/{x}/{y}.pbf
