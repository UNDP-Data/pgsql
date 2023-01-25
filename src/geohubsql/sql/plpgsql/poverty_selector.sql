CREATE OR REPLACE FUNCTION zambia.poverty_selector(
    z integer,
    x integer,
    y integer,
    click_lon double precision DEFAULT 31,
    click_lat double precision DEFAULT -11,
    radius double precision DEFAULT 60000.0)
 RETURNS bytea AS $$
DECLARE
    result bytea;
BEGIN
    WITH
    args AS (
      SELECT
        ST_TileEnvelope(z, x, y) AS bounds,
        ST_Transform(ST_SetSRID(ST_MakePoint(click_lon, click_lat), 4326), 3857) AS click
    ),
    mvtgeom AS (
      SELECT
        ST_AsMVTGeom(ST_Intersection( p.geom, ST_Buffer(args.click, radius)), args.bounds) AS geom,
        p.district
      FROM zambia.poverty p, args
      WHERE ST_Intersects(p.geom, args.bounds)
      AND ST_DWithin(p.geom, args.click, radius)
      LIMIT 10000
    )
    SELECT ST_AsMVT(mvtgeom, 'zambia.poverty_selector')
    INTO result
    FROM mvtgeom;

    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE PARALLEL SAFE

COMMENT ON FUNCTION zambia.poverty_selector IS 'Given the click point (click_lon, click_lat) and radius, returns all the districts in the radius, clipped to the radius circle.'

