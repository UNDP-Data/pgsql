CREATE OR REPLACE FUNCTION admin.tool_layer_buffer_core (
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
                "input_layer_name":
                { "id":"input_layer_name",
                  "param_name":"input_layer_name",
                  "type":"text",
                  "icon":"fa-diamond",
                  "label":"Layer to be buffered in schema.table format",
                  "widget_type":"search box",
                  "value":"admin.input_layer",
                  "hidden":0},
                "buffer_distance":
                { "id":"buffer_distance",
                  "param_name":"buffer_distance",
                  "type":"numeric",
                  "icon":"fa-tape",
                  "limits":{"min":0,"max":100000},
                  "abs_limits":{"min":0,"max":100000},
                  "value":0,
                  "label":"Buffer radius/distance in meters",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"meters"},
                "filter_attribute":
                { "id":"filter_attribute",
                  "param_name":"filter_attribute",
                  "type":"text",
                  "icon":"fa-filter",
                  "label":"Layer attribute against which to filter",
                  "widget_type":"search box",
                  "value":"type",
                  "hidden":0},
                "filter_value":
                { "id":"filter_value",
                  "param_name":"filter_value",
                  "type":"text",
                  "icon":"fa-text-height",
                  "label":"Only apply to features with this attribute",
                  "widget_type":"search box",
                  "value":"National roads",
                  "hidden":0}
            }',
    temp_table_name text default 'tool_layer_buffer_core_temp_table'
    --,bounds text default 'bounds'
    )

-- TODO
--RETURNS TABLE (a_name VARCHAR, geom GEOMETRY) AS $$

RETURNS VOID AS $$

    DECLARE
        mvt bytea;
        output_layer_name varchar := 'admin.tool_layer_buffer_core';

        defaults_json jsonb;
		requested_json jsonb;
		input_layer_name text;
		buffer_distance float;
		simplify_distance float;
		res_counter int;
		sql_stmt text;
		filter_attribute text;
		filter_value text;
		sanitized_json jsonb;

        q1_string text =
            $STMT1$

            CREATE TEMPORARY TABLE temp_buffer AS (
                SELECT ST_Buffer(ST_Simplify(a.geom, %s), %s) AS geom
                FROM %s a
                JOIN bounds_buffered AS b
                ON (a.geom && ST_Buffer(b.geom, %s))
                WHERE a.%s = '%s'
                );

            CREATE TEMPORARY TABLE %s AS (
                SELECT ST_Union(a.geom) AS geom
                FROM temp_buffer a
            );

            $STMT1$;

        q2_string text =
            $STMT2$

            CREATE TEMPORARY TABLE temp_buffer AS (
                SELECT ST_Buffer(ST_Simplify(a.geom, %s), %s) AS geom
                FROM %s a
                JOIN bounds_buffered AS b
                ON (a.geom && ST_Buffer(b.geom, %s))
                );

            CREATE TEMPORARY TABLE %s AS (
                SELECT ST_Union(a.geom) AS geom
                FROM temp_buffer a
            );

            $STMT2$;

        q3_string text =
            $STMT2$

            CREATE TEMPORARY TABLE %1$s AS (
                SELECT ST_Buffer(ST_Simplify(a.geom, %s), %s) AS geom
                FROM %s a
                JOIN bounds_buffered AS b
                ON (a.geom && ST_Buffer(b.geom, %s))
                );
            $STMT2$;

        func_defaults jsonb :=
            '{
                "input_layer_name":
                { "id":"input_layer_name",
                  "param_name":"input_layer_name",
                  "type":"text",
                  "icon":"fa-diamond",
                  "label":"Layer to be buffered in schema.table format",
                  "widget_type":"search box",
                  "value":"admin.input_layer",
                  "hidden":0},
                "buffer_distance":
                { "id":"buffer_distance",
                  "param_name":"buffer_distance",
                  "type":"numeric",
                  "icon":"fa-tape",
                  "limits":{"min":0,"max":100000},
                  "abs_limits":{"min":0,"max":100000},
                  "value":0,
                  "label":"Buffer radius/distance in meters",
                  "widget_type":"slider",
                  "hidden":0,
                  "units":"meters"},
                "filter_attribute":
                { "id":"filter_attribute",
                  "param_name":"filter_attribute",
                  "type":"text",
                  "icon":"fa-filter",
                  "label":"Layer attribute against which to filter",
                  "widget_type":"search box",
                  "value":"",
                  "hidden":0},
                "filter_value":
                { "id":"filter_value",
                  "param_name":"filter_value",
                  "type":"text",
                  "icon":"fa-text-height",
                  "label":"Only apply to features with this attribute",
                  "widget_type":"search box",
                  "value":"",
                  "hidden":0}
            }';

    BEGIN

-- TODO
-- make the input params coherent with the structure used in function layers -- DONE
-- add filters -- DONE
-- what if buffer_distance <=0 ?
-- what if geom column name is not 'geom' ?
-- what about the attributes in the original layer? -> drop them, the buffer will be likely used as a binary mask
--                                                  -> add an opt flag to the function parameters to preserve attrs
-- opt buffer distance taken from a field of the original layer?
-- check geom type? -- Not needed

        defaults_json        := func_defaults::jsonb;
        requested_json       := params::jsonb;

        -- sanitize the JSON before proceeding
        sanitized_json       := admin.params_sanity_check(defaults_json, requested_json);

        input_layer_name     := trim('"' FROM (sanitized_json->'input_layer_name'->'value')::text);
        buffer_distance      := (sanitized_json->'buffer_distance'->'value')::float;
   		filter_attribute     := trim('"' FROM (sanitized_json->'filter_attribute'->'value')::text);
		filter_value         := trim('"' FROM (sanitized_json->'filter_value'->'value')::text);

        simplify_distance    := buffer_distance/4;


		DROP TABLE IF EXISTS bounds_tlbc;
        CREATE TEMPORARY TABLE bounds_tlbc AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

		DROP TABLE IF EXISTS bounds_buffered;


        --create a temp table to avoid buffering bounds at every JOIN in the main query
        EXECUTE format('
            CREATE TEMPORARY TABLE bounds_buffered AS (
                SELECT ST_Buffer(b.geom,%s) AS geom
                FROM bounds_tlbc AS b
            );',
            buffer_distance);

        DROP TABLE IF EXISTS temp_buffer;


        -- we need to buffer the tiles of the bounds table to include the buffers of features in neighbouring tiles.


        IF ( (filter_attribute IS NOT NULL) AND (filter_value IS NOT NULL) AND (length(filter_attribute) >0) AND (length(filter_value)>0) AND (filter_attribute != 'null') AND (filter_value != 'null')) THEN

             sql_stmt = format(q1_string,
                simplify_distance,
                buffer_distance,
                input_layer_name,
                buffer_distance,
                filter_attribute, filter_value,
                temp_table_name
            );

        ELSE
            sql_stmt = format(q2_string,
                simplify_distance,
                buffer_distance,
                input_layer_name,
                buffer_distance,
                temp_table_name
            );

        END IF;

        RAISE WARNING 'sql_stmt: %',sql_stmt;

        EXECUTE sql_stmt;


        DROP TABLE IF EXISTS bounds_tlbc;
		DROP TABLE IF EXISTS bounds_buffered;

--        RAISE WARNING '# # # # # # # # # # # # # # # input_layer_name: %',sql_stmt;
--        SELECT COUNT(*) FROM temp_buffer INTO res_counter;
--        RAISE WARNING '################# input_layer_name: %, buffer_distance: %, simplify_distance:%, res_counter:%', input_layer_name, buffer_distance, simplify_distance, res_counter;

-- TODO benchmark for larger tables
--        no measurable effect for small/medium tables
--        CREATE INDEX IF NOT EXISTS temp_geom_idx ON temp_buffer USING GIST (geom);



        -- this is the query which returns the table as the function's "return value"
--        RETURN QUERY
--        SELECT
--            --'abc'::varchar AS a_name,
--            ST_Union(a.geom) AS geom
--        FROM temp_buffer a;


    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.tool_layer_buffer_core IS 'Buffer a vector layer by a given distance';

-- EXAMPLES:
--
--SELECT * FROM admin.tool_layer_buffer_core(0,0,0,'{
--"input_layer_name": {"value":"admin.roads"},
--"buffer_distance":  {"value":100000},
--"filter_attribute": {"value":"type"},
--"filter_value":     {"value":"National road"}
--}')
--
--SELECT * FROM admin.tool_layer_buffer_core(0,0,0,'{
--"input_layer_name": {"value":"rwanda.water_facilities"},
--"buffer_distance":  {"value":1200},
--"filter_attribute": {"value":"wsf_type"},
--"filter_value":     {"value":"Improved Spring"}
--}');

--DROP TABLE IF EXISTS admin.geom_test;
--CREATE TABLE admin.geom_test AS(
--SELECT * FROM admin.tool_layer_buffer_core(0,0,0,'{
--"input_layer_name": {"value":"admin.roads"},
--"buffer_distance":  {"value":1200},
--"filter_attribute": {"value":"type"},
--"filter_value":     {"value":"National road"}
--}'))

-- works in QGIS:
-- http://172.18.0.6:7800/admin.tool_layer_buffer_core/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.water_facilities"},"buffer_distance":{"value":1200}}
-- http://172.18.0.6:7800/admin.tool_layer_buffer_core/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.roads"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"type"},"filter_value":{"value":"National road"}}
-- http://172.18.0.6:7800/admin.tool_layer_buffer_core/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.water_facilities"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"wsf_type"},"filter_value":{"value":"Improved Spring"}}
--
-- https://pgtileserv.undpgeohub.org/admin.tool_layer_buffer_core/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"rwanda.roads"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"type"},"filter_value":{"value":"National road"}}
-- https://pgtileserv.undpgeohub.org/admin.tool_layer_buffer_core/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"rwanda.water_facilities"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"wsf_type"},"filter_value":{"value":"Improved Spring"}}