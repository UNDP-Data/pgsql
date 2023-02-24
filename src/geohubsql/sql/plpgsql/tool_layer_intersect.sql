CREATE OR REPLACE FUNCTION admin.tool_layer_intersect (
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
                "input_layer_name_1":
                { "id":"input_layer_name_1",
                  "param_name":"input_layer_name_1",
                  "type":"text",
                  "icon":"fa-diamond",
                  "label":"Layer to be intersected, in schema.table format",
                  "widget_type":"search box",
                  "value":"input_layer_1",
                  "hidden":0},
                "input_layer_name_2":
                { "id":"input_layer_name_2",
                  "param_name":"input_layer_name_2",
                  "type":"text",
                  "icon":"fa-diamond",
                  "label":"Layer to be intersected against, in schema.table format",
                  "widget_type":"search box",
                  "value":"input_layer_2",
                  "hidden":0}
            }'
    )

RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        output_layer_name varchar := 'admin.tool_layer_intersect';

        defaults_json jsonb;
		requested_json jsonb;
		input_layer_name_1 text;
		input_layer_name_2 text;
		input_layer_name_1_idx text;
		input_layer_name_2_idx text;

		res_counter int;
		sql_stmt text;

		sanitized_json jsonb;

        q1_string text =

            $STMT1$

            CREATE INDEX IF NOT EXISTS %3$s ON %1$s USING GIST (geom);
            CREATE INDEX IF NOT EXISTS %4$s ON %2$s USING GIST (geom);

            DROP TABLE IF EXISTS temp_intersection;

            CREATE TABLE temp_intersection AS (
            SELECT
            a1.*,
            ST_Intersection(a1.geom, a2.geom) as geom1
                FROM %1$s AS a1, %2$s AS a2
                JOIN bounds AS b ON (a2.geom && b.geom)
                WHERE (a2.geom && a1.geom)
            );

            ALTER TABLE temp_intersection
            DROP COLUMN geom;

            ALTER TABLE temp_intersection
	        RENAME COLUMN geom1 TO geom;

            $STMT1$;

        func_defaults jsonb :=
            '{
                "input_layer_name_1":
                { "id":"input_layer_name_1",
                  "param_name":"input_layer_name_1",
                  "type":"text",
                  "icon":"fa-diamond",
                  "label":"Layer to be intersected, in schema.table format",
                  "widget_type":"search box",
                  "value":"admin.input_layer_1",
                  "hidden":0},
                "input_layer_name_2":
                { "id":"input_layer_name_2",
                  "param_name":"input_layer_name_2",
                  "type":"text",
                  "icon":"fa-diamond",
                  "label":"Layer to be intersected against, in schema.table format",
                  "widget_type":"search box",
                  "value":"admin.input_layer_2",
                  "hidden":0}
            }';

    BEGIN

-- TODO
-- check/create spatial indexes

--        RAISE WARNING 'TOOL_LAYER_INTERSECT params: %', params;

        defaults_json        := func_defaults::jsonb;
        requested_json       := params::jsonb;

        -- sanitize the JSON before proceeding
        sanitized_json       := admin.params_sanity_check(defaults_json, requested_json);

        input_layer_name_1   := trim('"' FROM (sanitized_json->'input_layer_name_1'->'value')::text);
        input_layer_name_2   := trim('"' FROM (sanitized_json->'input_layer_name_2'->'value')::text);

        input_layer_name_1_idx := replace(input_layer_name_1,'.','_')||'_idx';
        input_layer_name_2_idx := replace(input_layer_name_2,'.','_')||'_idx';

		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

        DROP TABLE IF EXISTS temp_intersection;

        sql_stmt = format(q1_string,
            input_layer_name_1,
            input_layer_name_2,
            input_layer_name_1_idx,
            input_layer_name_2_idx
        );


--        RAISE WARNING 'TOOL_LAYER_INTERSECT sql_stmt: %',sql_stmt;

        EXECUTE sql_stmt;

--        RAISE WARNING '# # # # # # # # # # # # # # # input_layer_name_1: %',sql_stmt;
--        SELECT COUNT(*) FROM temp_intersection INTO res_counter;
--        RAISE WARNING '################# input_layer_name_1: %, input_layer_name_2: %, res_counter:%', input_layer_name_1, input_layer_name_2,  res_counter;

--        no measurable effect
--        CREATE INDEX IF NOT EXISTS temp_geom_idx ON temp_intersection USING GIST (geom);

       DROP TABLE IF EXISTS mvtgeom;
       CREATE TEMPORARY TABLE mvtgeom AS (
           SELECT ST_AsMVTGeom(t.geom, bounds.geom, extent => 2048, buffer => 256) AS geom
           FROM temp_intersection t
           JOIN bounds ON ST_Intersects(t.geom, bounds.geom)
       );

        SELECT COUNT(*) FROM mvtgeom INTO res_counter;
--        RAISE WARNING '################# input_layer_name_1: %, input_layer_name_2: %, mvtgeom count:%', input_layer_name_1, input_layer_name_2,  res_counter;

        SELECT ST_AsMVT(mvtgeom.*, 'admin.tool_layer_intersect', 2048, 'geom')
        FROM mvtgeom AS mvtgeom
		INTO mvt;



        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.tool_layer_intersect IS 'Intersect two vector layers';

-- EXAMPLES:

--SELECT * FROM admin.tool_layer_intersect(0,0,0,'{
--"input_layer_name_1": {"value":"admin_roads2"},
--"buffer_distance":  {"value":1200},
--"filter_attribute": {"value":"type"},
--"filter_value":     {"value":"national road"}
--}');
--
--SELECT * FROM admin.tool_layer_intersect(0,0,0,'{
--"input_layer_name_1": {"value":"admin.roads2"},
--"input_layer_name_2": {"value":"admin.rwanda_water_buffer"}
--}');

-- works in QGIS:
-- http://172.18.0.6:7800/admin.tool_layer_intersect/{z}/{x}/{y}.pbf?params={"input_layer_name_1": {"value":"admin.roads2"},"input_layer_name_2": {"value":"admin.rwanda_water_buffer"}}