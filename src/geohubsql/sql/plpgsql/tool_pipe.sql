CREATE OR REPLACE FUNCTION admin.tool_pipe (
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '[]'
    )

RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        output_layer_name varchar := 'admin.tool_pipe';

        defaults_json jsonb;
		requested_json jsonb;

        elem_id integer;
        elem_label text;
		elem_function_name text;
		elem_input_layer_name text;

        function_is_valid int;

		res_counter int;
		sql_stmt text;

		sanitized_json jsonb;

        _key   text;
        _value text;

        array_element jsonb;

        q1_string text =
            $STMT1$

            CREATE TEMPORARY TABLE temp_buffer AS (
                SELECT ST_Buffer(ST_Simplify(a.geom, %s), %s) AS geom
                FROM %s a
                JOIN bounds_buffered AS b
                ON (a.geom && ST_Buffer(b.geom, %s))
                WHERE a.%s = '%s'
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
            $STMT2$;

        func_defaults jsonb :=
            '[
   {
      "Buffer around springs":{
         "id":{ "value":"1"},
         "tool_function":{ "value":"tool_layer_buffer"},
         "input_layer_name":{ "value":"rwanda.water_facilities"},
         "buffer_distance":{ "value":500}
      }
   },
   {
      "Intersect roads with buffered springs":{
         "id":{
            "value":"2"
         },
         "tool_function":{
            "value":"tool_layer_intersect"
         },
         "input_layer_name":{
            "value":"rwanda.roads"
         },
         "Intersect_by_layer_name":{
            "value":"output_from_tool_1"
         }
      }
   },
   {
      "Calculate road lengths within buffered springs":{
         "id":{
            "value":"3"
         },
         "tool_function":{
            "value":"tool_layer_stats"
         },
         "Intersect_by_layer_name":{
            "value":"output_from_tool_2"
         }
      }
   }
] ';

    BEGIN

        defaults_json        := func_defaults::jsonb;
        requested_json       := params::jsonb;

        CREATE TABLE IF NOT EXISTS admin.tool_pipe_valid_functions (
            function_name text NOT NULL UNIQUE,
            parameters JSONB);

        -- Warning: UPSERTing JSON(B) needs to be done one row at a time!
        -- https://github.com/PostgREST/postgrest/issues/1118#issuecomment-391379263

        INSERT INTO admin.tool_pipe_valid_functions (function_name, parameters)
        VALUES
        ('tool_layer_buffer',   '{"input_layer_name": { "id":"input_layer_name","param_name":"input_layer_name","type":"text","icon":"fa-diamond","label":"Layer to be buffered in schema.table format","widget_type":"search box","value":"admin.input_layer","hidden":0}, "buffer_distance": { "id":"buffer_distance","param_name":"buffer_distance","type":"numeric","icon":"fa-tape","limits":{"min":0,"max":100000}, "abs_limits":{"min":0,"max":100000}, "value":0, "label":"Buffer radius/distance in meters","widget_type":"slider","hidden":0, "units":"meters"}, "filter_attribute": { "id":"filter_attribute","param_name":"filter_attribute","type":"text","icon":"fa-filter","label":"Layer attribute against which to filter","widget_type":"search box","value":"type","hidden":0}, "filter_value": { "id":"filter_value","param_name":"filter_value","type":"text","icon":"fa-text-height","label":"Only apply to features with this attribute","widget_type":"search box","value":"National roads","hidden":0} }')
        ON CONFLICT (function_name) DO NOTHING;

        INSERT INTO admin.tool_pipe_valid_functions (function_name, parameters)
        VALUES
        ('tool_layer_intersect','{"input_layer_name_1": { "id":"input_layer_name_1","param_name":"input_layer_name_1","type":"text","icon":"fa-diamond","label":"Layer to be intersected, in schema.table format","widget_type":"search box","value":"admin.input_layer_1","hidden":0}, "input_layer_name_2": { "id":"input_layer_name_2","param_name":"input_layer_name_2","type":"text","icon":"fa-diamond","label":"Layer to be intersected against, in schema.table format","widget_type":"search box","value":"admin.input_layer_2","hidden":0} }')
        ON CONFLICT (function_name) DO NOTHING;


        -- sanitize the JSON before proceeding
--        sanitized_json       := admin.params_sanity_check(defaults_json, requested_json);
--        input_layer_name     := trim('"' FROM (sanitized_json->'input_layer_name'->'value')::text);

		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);


        FOR array_element IN SELECT * FROM jsonb_array_elements(requested_json)
        LOOP

            elem_label := jsonb_object_keys(array_element)::text;
            elem_id               := (array_element->elem_label->'id'->>'value')::integer;
            elem_function_name    := array_element->elem_label->'tool_function'->>'value' ;
		    elem_input_layer_name := array_element->elem_label->'input_layer_name'->>'value' ;

            SELECT count(*)
            FROM admin.tool_pipe_valid_functions
            WHERE function_name = elem_function_name
            INTO function_is_valid
            ;


            RAISE NOTICE 'Array element % - function_name:%, input_layer_name: %, function_is_valid:%',elem_id, elem_function_name, elem_input_layer_name, function_is_valid;


        END LOOP;


        -- dummy output
        SELECT ST_AsMVT(mvtgeom.*, 'admin.tool_pipe', 2048, 'geom')
        FROM bounds AS mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.tool_pipe IS 'Vector tool pipe';

-- EXAMPLES:

--SELECT * FROM admin.tool_pipe(0,0,0,'{
--"input_layer_name": {"value":"rwanda.roads"},
--"buffer_distance":  {"value":1200},
--"filter_attribute": {"value":"type"},
--"filter_value":     {"value":"national road"}
--}');
--
--SELECT * FROM admin.tool_pipe(0,0,0,'{
--"input_layer_name": {"value":"rwanda.water_facilities"},
--"buffer_distance":  {"value":1200},
--"filter_attribute": {"value":"wsf_type"},
--"filter_value":     {"value":"Improved Spring"}
--}');

-- works in QGIS:
-- http://172.18.0.6:7800/admin.tool_pipe/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.water_facilities"},"buffer_distance":{"value":1200}}
-- http://172.18.0.6:7800/admin.tool_pipe/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.roads"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"type"},"filter_value":{"value":"National road"}}
-- http://172.18.0.6:7800/admin.tool_pipe/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.water_facilities"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"wsf_type"},"filter_value":{"value":"Improved Spring"}}
--
-- https://pgtileserv.undpgeohub.org/admin.tool_pipe/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"rwanda.roads"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"type"},"filter_value":{"value":"National road"}}
-- https://pgtileserv.undpgeohub.org/admin.tool_pipe/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"rwanda.water_facilities"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"wsf_type"},"filter_value":{"value":"Improved Spring"}}