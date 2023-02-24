CREATE OR REPLACE FUNCTION admin.zoom_levels (
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{}'
    )

RETURNS bytea AS $$

    DECLARE
        mvt bytea;


    BEGIN

		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom, z,x,y
		);

       DROP TABLE IF EXISTS mvtgeom;
       CREATE TEMPORARY TABLE mvtgeom AS (
           SELECT ST_AsMVTGeom(b.geom, bounds.geom, extent => 2048, buffer => 256) AS geom,
           b.z,b.x,b.y
           FROM bounds b
           JOIN bounds ON ST_Intersects(b.geom, bounds.geom)
       );


        SELECT ST_AsMVT(m.*, 'admin.zoom_levels', 2048, 'geom')
        FROM mvtgeom AS m
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.zoom_levels IS 'Vector zoom levels';


-- works in QGIS:
-- http://172.18.0.6:7800/admin.zoom_levels/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.water_facilities"},"buffer_distance":{"value":1200}}
-- http://172.18.0.6:7800/admin.zoom_levels/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.roads"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"type"},"filter_value":{"value":"National road"}}
-- http://172.18.0.6:7800/admin.zoom_levels/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"admin.water_facilities"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"wsf_type"},"filter_value":{"value":"Improved Spring"}}
--
-- https://pgtileserv.undpgeohub.org/admin.zoom_levels/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"rwanda.roads"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"type"},"filter_value":{"value":"National road"}}
-- https://pgtileserv.undpgeohub.org/admin.zoom_levels/{z}/{x}/{y}.pbf?params={"input_layer_name":{"value":"rwanda.water_facilities"},"buffer_distance":{"value":1200},"filter_attribute":{"value":"wsf_type"},"filter_value":{"value":"Improved Spring"}}