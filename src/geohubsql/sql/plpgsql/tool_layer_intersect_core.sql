CREATE OR REPLACE FUNCTION admin.tool_layer_intersect_core (
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
            }',
    temp_table_name text default 'tool_layer_intersection_core_temp_table'
    )

RETURNS VOID AS $$

    DECLARE
        mvt bytea;
        output_layer_name varchar := 'admin.tool_layer_intersect_core';

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

            DROP TABLE IF EXISTS %5$s;

            CREATE TABLE %5$s AS (
            SELECT
            a1.*,
            ST_Intersection(a1.geom, a2.geom) as geom1
                FROM %1$s AS a1, %2$s AS a2
                JOIN bounds AS b ON (a2.geom && b.geom)
                WHERE (a2.geom && a1.geom)
            );

            ALTER TABLE %5$s
            DROP COLUMN geom;

            ALTER TABLE %5$s
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

        RAISE WARNING 'tool_layer_intersect_core params: %', params;

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



        DROP TABLE IF EXISTS temp_table_name;

        sql_stmt = format(q1_string,
            input_layer_name_1,
            input_layer_name_2,
            input_layer_name_1_idx,
            input_layer_name_2_idx,
            temp_table_name
        );


        RAISE WARNING 'tool_layer_intersect_core sql_stmt: %',sql_stmt;

        EXECUTE sql_stmt;

        EXECUTE format('SELECT COUNT(*) FROM %s', temp_table_name) INTO res_counter;
        RAISE WARNING 'elem_output_layer_name has % features.', res_counter;

--        RAISE WARNING '# # # # # # # # # # # # # # # input_layer_name_1: %',sql_stmt;
--        SELECT COUNT(*) FROM temp_table_name INTO res_counter;
--        RAISE WARNING '################# input_layer_name_1: %, input_layer_name_2: %, res_counter:%', input_layer_name_1, input_layer_name_2,  res_counter;

--        no measurable effect
--        CREATE INDEX IF NOT EXISTS temp_geom_idx ON temp_table_name USING GIST (geom);

--        RETURN QUERY
--

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.tool_layer_intersect_core IS 'Intersect two vector layers';

-- EXAMPLES:

--SELECT * FROM admin.tool_layer_intersect_core(0,0,0,'{
--"input_layer_name_1": {"value":"admin_roads2"},
--"buffer_distance":  {"value":1200},
--"filter_attribute": {"value":"type"},
--"filter_value":     {"value":"national road"}
--}');
--
--SELECT * FROM admin.tool_layer_intersect_core(0,0,0,'{
--"input_layer_name_1": {"value":"admin.roads2"},
--"input_layer_name_2": {"value":"admin.rwanda_water_buffer"}
--}');

-- works in QGIS:
-- http://172.18.0.6:7800/admin.tool_layer_intersect_core/{z}/{x}/{y}.pbf?params={"input_layer_name_1": {"value":"admin.roads2"},"input_layer_name_2": {"value":"admin.rwanda_water_buffer"}}