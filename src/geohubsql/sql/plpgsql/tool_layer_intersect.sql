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

--		res_counter int;

		sanitized_json jsonb;

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

        DROP TABLE IF EXISTS temp_intersect_table;
        EXECUTE format('SELECT * FROM admin.tool_layer_intersect_core(%s,%s,%s,''%s'',''temp_intersect_table'')',z,x,y,sanitized_json);

		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

       DROP TABLE IF EXISTS mvtgeom;

       DROP TABLE IF EXISTS mvtgeom;
       CREATE TEMPORARY TABLE mvtgeom AS (
           SELECT ST_AsMVTGeom(t.geom, bounds.geom, extent => 2048, buffer => 256) AS geom
           FROM temp_intersection t
           JOIN bounds ON ST_Intersects(t.geom, bounds.geom)
       );

        SELECT ST_AsMVT(mvtgeom.*, 'admin.tool_layer_intersect', 2048, 'geom')
        FROM mvtgeom AS mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.tool_layer_intersect IS 'Intersect two vector layers';

-- EXAMPLES:

--SELECT * FROM admin.tool_layer_intersect(0,0,0,'{
--"input_layer_name_1": {"value":"admin.roads2"},
--"input_layer_name_2": {"value":"admin.rwanda_water_buffer"}
--}');
--
--SELECT * FROM admin.tool_layer_intersect(0,0,0,'{
--"input_layer_name_1": {"value":"admin.roads2"},
--"input_layer_name_2": {"value":"admin.rwanda_water_buffer"}
--}');

-- works in QGIS:
-- http://172.18.0.6:7800/admin.tool_layer_intersect/{z}/{x}/{y}.pbf?params={"input_layer_name_1": {"value":"admin.roads2"},"input_layer_name_2": {"value":"admin.rwanda_water_buffer"}}