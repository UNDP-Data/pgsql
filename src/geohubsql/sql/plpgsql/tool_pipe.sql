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

        elem_id text;
        elem_label text;
		elem_function_name text;
		elem_input_layer_name text;
		elem_return_type text;
		elem_valid_params JSONB;

		elem_output_layer_name text;
		last_elem_output_layer_name text;

        --temporary_tables text[];

        function_is_valid int;
        function_valid_parameters jsonb;

		res_counter int;
		sql_stmt text;


        _valid_key   text;
        _value text;

        requested_array_element jsonb;

        query_string text;

        query_string_table text =
            $STMT1$
            DROP TABLE IF EXISTS %s;
            CREATE TEMPORARY TABLE %s AS (
                SELECT * FROM admin.%s (%s,%s,%s,'%s')
                );
            $STMT1$;

        query_string_temp_table text =
            $STMT2$
            DROP TABLE IF EXISTS %s;
            SELECT * FROM admin.%s (%s,%s,%s,'%s','%s')
            $STMT2$;

        func_defaults jsonb :=
            '[
   {
      "Buffer around springs":{
         "id":{ "value":"1"},
         "tool_function":{ "value":"tool_layer_buffer_core"},
         "input_layer_name":{ "value":"rwanda.water_facilities"},
         "buffer_distance":{ "value":500}
      }
   },
   {
      "Intersect roads with buffered springs":{
         "id":{"value":"2"},
         "tool_function":{"value":"tool_layer_intersect_core"},
         "input_layer_name_1":{"value":"rwanda.roads"},
         "input_layer_name_2":{"value":"output_from_tool_1"}
      }
   },
   {
      "Calculate road lengths within buffered springs":{
         "id":{"value":"3"},
         "tool_function":{"value":"tool_layer_stats"},
         "input_layer_name":{"value":"output_from_tool_2"}
      }
   }
] ';

-- TODO
-- create & check table of allowed tables (or at least schemas) which can be used as args for the tools, for security reason

    BEGIN

        defaults_json        := func_defaults::jsonb;
        requested_json       := params::jsonb;

        CREATE TABLE IF NOT EXISTS admin.tool_pipe_valid_functions (
            function_name text NOT NULL UNIQUE,
            parameters JSONB,
            return_type text);

        -- Warning: UPSERTing JSON(B) needs to be done one row at a time!
        -- https://github.com/PostgREST/postgrest/issues/1118#issuecomment-391379263

        INSERT INTO admin.tool_pipe_valid_functions (function_name, parameters,return_type)
        VALUES
        ('tool_layer_buffer_core',
            '{"input_layer_name":{"value":""},
            "buffer_distance":{"value":0},
            "filter_attribute":{"value":"type"},
            "filter_value":{"value":""}
            }',
            'temp_table')
        ON CONFLICT (function_name) DO NOTHING;

        INSERT INTO admin.tool_pipe_valid_functions (function_name, parameters,return_type)
        VALUES
        ('tool_layer_intersect_core',
            '{"input_layer_name_1": {"value":"admin.input_layer_1"},
            "input_layer_name_2":{"value":"admin.input_layer_2"}
        }',
            'temp_table')
        ON CONFLICT (function_name) DO NOTHING;



        FOR requested_array_element IN SELECT * FROM jsonb_array_elements(requested_json)
        LOOP
--            RAISE NOTICE '#################################';
            elem_label             := jsonb_object_keys(requested_array_element)::text;
            elem_id                := regexp_replace(LEFT((requested_array_element->elem_label->'id'->>'value')::text,2),'[^0-9.-]+','','g');
            elem_function_name     := requested_array_element->elem_label->'tool_function'->>'value' ;
		    --elem_input_layer_name  := requested_array_element->elem_label->'input_layer_name'->>'value' ;
            -- output_from_tool_1
            elem_output_layer_name := 'output_from_tool_'||elem_id;

			--RAISE WARNING 'requested_array_element LABEL: %', requested_array_element->elem_label;

            SELECT count(*)
                FROM admin.tool_pipe_valid_functions
                WHERE function_name = elem_function_name
            INTO function_is_valid;

            CONTINUE WHEN (function_is_valid = 0);

             --retrieve return_type for the specific tool/function_name

            SELECT return_type
                FROM admin.tool_pipe_valid_functions
                WHERE function_name = elem_function_name
            INTO elem_return_type;

            --retrieve expected parameters for the specific tool/function_name

            SELECT parameters
                FROM admin.tool_pipe_valid_functions
                WHERE function_name = elem_function_name
            INTO function_valid_parameters;

            -- create a jsonb object made with:
            -- - the (possibly nested) keys / arg names from function_valid_parameters
            -- - the corresponding values from requested_json

            elem_valid_params := function_valid_parameters;

            FOR _valid_key, _value IN
               SELECT * FROM jsonb_each_text(elem_valid_params)
            LOOP

--             RAISE NOTICE 'KV %: %', _valid_key, _value;
-- 			   RAISE WARNING 'requested_array_element LABEL KEY: %', requested_array_element->elem_label->>_valid_key;
--             IF (jsonb_path_exists(elem_valid_params, '$[*] ? (@ == "buffer_distance")')) THEN
               IF (requested_array_element->elem_label->>_valid_key IS NOT NULL) THEN
--                   RAISE NOTICE 'KV OK %: %', _valid_key, _value;
                   elem_valid_params = jsonb_set( elem_valid_params, ('{'||_valid_key||'}')::text[], requested_array_element->elem_label->_valid_key );
               ELSE
--                    RAISE NOTICE 'KV NOT OK %: %', _valid_key, _value;
                    -- if the value was not requested, delete the corresponding key
					elem_valid_params = elem_valid_params #- ('{'||_valid_key||'}')::text[];
               END IF;
            END LOOP;

--            RAISE NOTICE 'Array element % - function_name:%, function_is_valid:%, elem_output_layer_name:%',
--                         elem_id, elem_function_name, function_is_valid, elem_output_layer_name;
--            RAISE NOTICE 'elem_valid_params: %', elem_valid_params;
--            RAISE NOTICE 'tool_function: %', JSONB_PATH_QUERY_ARRAY(requested_array_element, '$.*.tool_function.value');



            query_string := format (query_string_temp_table, elem_output_layer_name, elem_function_name, z,x,y,elem_valid_params,elem_output_layer_name);

            IF (elem_return_type = 'table')  THEN
                query_string := format (query_string_table, elem_output_layer_name, elem_output_layer_name, elem_function_name, z,x,y,elem_valid_params);
            END IF;

--            RAISE WARNING 'TOOL_PIPE query_string: %', query_string;
			EXECUTE query_string;
            last_elem_output_layer_name := elem_output_layer_name;


        END LOOP;

        DROP TABLE IF EXISTS bounds;

        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);


       DROP TABLE IF EXISTS mvtgeom;

       EXECUTE format('
       CREATE TEMPORARY TABLE mvtgeom AS (
           SELECT ST_AsMVTGeom(t.geom, bounds.geom, extent => 2048, buffer => 256) AS geom
           FROM %s t
           JOIN bounds ON ST_Intersects(t.geom, bounds.geom)
       )',
       last_elem_output_layer_name);


        SELECT ST_AsMVT(mvtgeom.*, 'admin.tool_pipe', 2048, 'geom')
        FROM mvtgeom AS mvtgeom
		INTO mvt;


        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.tool_pipe IS 'Vector tool pipe';

-- EXAMPLES:
--
--SELECT * FROM admin.tool_pipe(0,0,0,'[
--   {
--      "Buffer around springs":{
--         "id":{
--            "value":"1"
--         },
--         "tool_function":{
--            "value":"tool_layer_buffer_core"
--         },
--         "input_layer_name":{
--            "value":"rwanda.water_facilities"
--         },
--         "buffer_distance":{
--            "value":500
--         }
--      }
--   },
--   {
--      "Intersect roads with buffered springs":{
--         "id":{
--            "value":"2"
--         },
--         "tool_function":{
--            "value":"tool_layer_intersect"
--         },
--         "input_layer_name_1":{
--            "value":"rwanda.roads"
--         },
--         "input_layer_name_2":{
--            "value":"output_from_tool_1"
--         }
--      }
--   },
--   {
--      "Calculate road lengths within buffered springs":{
--         "id":{
--            "value":"3"
--         },
--         "tool_function":{
--            "value":"tool_layer_stats"
--         },
--         "intersect_by_layer_name":{
--            "value":"output_from_tool_2"
--         }
--      }
--   }
--]');

-- http://172.18.0.6:7800/admin.tool_pipe/0/0/0.pbf?params='[ {"Buffer around springs":{ "id":{"value":"1" },"tool_function":{"value":"tool_layer_buffer_core" },"input_layer_name":{"value":"admin.water_facilities" },"buffer_distance":{"value":500 }} }, {"Intersect roads with buffered springs":{ "id":{"value":"2" },"tool_function":{"value":"tool_layer_intersect" },"input_layer_name_1":{"value":"admin.roads2" },"input_layer_name_2":{"value":"output_from_tool_1" }} }, {"Calculate road lengths within buffered springs":{ "id":{"value":"3" },"tool_function":{"value":"tool_layer_stats" },"intersect_by_layer_name":{"value":"output_from_tool_2" }} }]'