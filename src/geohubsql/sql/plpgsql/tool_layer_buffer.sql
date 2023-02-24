CREATE OR REPLACE FUNCTION admin.tool_layer_buffer (
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
            }'
    )

RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        output_layer_name varchar := 'admin.tool_layer_buffer';

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
        geom_text text;

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
            }';

    BEGIN

        defaults_json        := func_defaults::jsonb;
        requested_json       := params::jsonb;

        -- sanitize the JSON before proceeding
         sanitized_json       := admin.params_sanity_check(defaults_json, requested_json);

        DROP TABLE IF EXISTS temp_buffer_union;
        EXECUTE format('SELECT * FROM admin.tool_layer_buffer_core(%s,%s,%s,''%s'',''temp_buffer_union'')',z,x,y,sanitized_json);

		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

       DROP TABLE IF EXISTS mvtgeom;

       CREATE TEMPORARY TABLE mvtgeom AS (
           SELECT ST_AsMVTGeom(t.geom, bounds.geom, extent => 2048, buffer => 256) AS geom
           FROM temp_buffer_union t
           JOIN bounds ON ST_Intersects(t.geom, bounds.geom));

        SELECT ST_AsMVT(mvtgeom.*, 'admin.tool_layer_buffer', 2048, 'geom')
        FROM mvtgeom AS mvtgeom
		INTO mvt;

       SELECT ST_AsText(geom) from mvtgeom INTO geom_text;
       RAISE WARNING 'GEOM: %', geom_text;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.tool_layer_buffer IS 'Buffer a vector layer by a given distance';

-- EXAMPLES:

--SELECT * FROM admin.tool_layer_buffer(0,0,0,'{
--"input_layer_name": {"value":"rwanda.roads"},
--"buffer_distance":  {"value":1200},
--"filter_attribute": {"value":"type"},
--"filter_value":     {"value":"National road"}
--}');
--
--SELECT * FROM admin.tool_layer_buffer(0,0,0,'{
--"input_layer_name": {"value":"rwanda.water_facilities"},
--"buffer_distance":  {"value":1200},
--"filter_attribute": {"value":"wsf_type"},
--"filter_value":     {"value":"Improved Spring"}
--}');

-- works in QGIS:
-- http://172.18.0.6:7800/admin.tool_layer_buffer/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.water_facilities"},"buffer_distance":{"value":1200}}
-- http://172.18.0.6:7800/admin.tool_layer_buffer/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.roads"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"type"},"filter_value":{"value":"National road"}}
-- http://172.18.0.6:7800/admin.tool_layer_buffer/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.water_facilities"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"wsf_type"},"filter_value":{"value":"Improved Spring"}}
--
-- https://pgtileserv.undpgeohub.org/admin.tool_layer_buffer/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"rwanda.roads"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"type"},"filter_value":{"value":"National road"}}
-- https://pgtileserv.undpgeohub.org/admin.tool_layer_buffer/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"rwanda.water_facilities"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"wsf_type"},"filter_value":{"value":"Improved Spring"}}
