CREATE OR REPLACE FUNCTION public.function_source_query_params(
    z integer,
    x integer,
    y integer,
    query_params json
    ) RETURNS bytea AS $$
    DECLARE
        geom_col varchar;
        mvt bytea;
        sql_stmt text;
        srids integer ARRAY;
        table_name varchar;
        column_name varchar;
        filter_value varchar;
        schemas text ARRAY;
        schema_q text;
        /*
            query string which creates and filters a vector tile according to specified function parameters
            called in the function body when necessary to transform geometry to Web Map Mercator (EPSG 3857)
        */

        q1_string text =
                    $STMT1$
                    WITH
                        bounds AS (
                          SELECT ST_TileEnvelope(%s, %s, %s) AS geom
                        ),
                    mvtgeom AS (
                      SELECT ST_AsMVTGeom(ST_Transform(t.%I, 3857), bounds.geom) AS geom,
                      t.%I
                      FROM public.%I t, bounds
                      WHERE ST_Intersects(ST_Transform(t.%I, 3857),  bounds.geom)
                      AND upper(t.%I) LIKE (upper(%L) || '%%')
                    )
                    SELECT ST_AsMVT(mvtgeom, 'default')
                    FROM mvtgeom;
                    $STMT1$;
        /*
            query string which creates and filters a vector tile according to specified function parameters
            called in the function body when the dataset possesses a geometry column with coordinates in Web Map Mercator (EPSG 3857)
        */

        q2_string text =
                    $STMT2$
                    WITH
                    bounds AS (
                      SELECT ST_TileEnvelope(%s, %s, %s) AS geom
                    ),
                    mvtgeom AS (
                      SELECT ST_AsMVTGeom(t.%s, bounds.geom) AS geom,
                      t.%I
                      FROM public.%I t, bounds
                      WHERE ST_Intersects(t.%s, bounds.geom)
                      AND upper(t.%I) LIKE (upper(%L) || '%%')
                    )
                    SELECT ST_AsMVT(mvtgeom, 'default')
                    FROM mvtgeom;
                    $STMT2$;

    BEGIN
        RAISE INFO 'query_params are: %', query_params;
        IF (query_params->>'table_name')::varchar IS NULL THEN
            RAISE EXCEPTION 'the `table_name` json parameter does not exist in `query_params`';
        END IF;
        table_name = query_params->>'table_name'::varchar;
        IF (query_params->>'column_name')::varchar IS NULL THEN
            RAISE EXCEPTION 'the `column_name` json parameter does not exist in `query_params`';
        END IF;
        column_name = query_params->>'column_name'::varchar;
        IF (query_params->>'filter_value')::varchar IS NULL THEN
            filter_value := 'A';
        ELSE
            filter_value = query_params->>'filter_value'::varchar;
        END IF;

        WITH sch AS (SELECT array_agg(schema_name:: TEXT) as schms
            FROM information_schema.schemata
            WHERE schema_name NOT LIKE 'information_schema' AND
            schema_name NOT LIKE 'pg_catalog'
        )
        SELECT schms from sch INTO schemas;
        --SET search_path TO schemas;
        --SHOW search_path INTO filter_value;
        schema_q = array_to_string(schemas, ',');
        RAISE NOTICE '"%"', schemas;


        WITH sr AS (
            SELECT array_agg(srid:: INT) AS tsrids
            FROM geometry_columns
            WHERE f_table_name LIKE table_name
            GROUP BY f_table_name
        )



        SELECT tsrids  FROM sr INTO srids;

        srids = ARRAY[4326];

        RAISE NOTICE 'Table % has SRIDS % with schemas %', table_name, srids, filter_value;

        IF (SELECT 3857 = ANY(srids)) THEN
            RAISE NOTICE 'WE HAVE GWM';
            /*
                select geometry column with coordinates in the Web Map Mercator projection
                construct the geom_path (table_name.geometry_column)
                execute query string #2 into results
            */
            WITH g AS (
                SELECT f_geometry_column AS the_geom
                FROM geometry_columns
                WHERE f_table_name LIKE table_name AND srid = 3857
            )
            SELECT the_geom  FROM g INTO geom_col;
            sql_stmt = format(q2_string, z, x, y, geom_col, column_name, table_name, geom_col, column_name, filter_value);

        ELSE
            /*
                select the first available geometry column
                construct the geom_path
                execute query string #1 into results
            */
            WITH g AS (
                SELECT array_agg(f_geometry_column:: TEXT) AS geoms
                FROM geometry_columns
                WHERE f_table_name LIKE table_name
            )
            SELECT geoms[1]  FROM g INTO geom_col;
            RAISE INFO 'THE G COL IS %s', geom_col;
            sql_stmt = format(q1_string, z, x, y, geom_col, column_name, table_name, geom_col, column_name, filter_value);
        END IF;
        RAISE INFO '%',sql_stmt;
        EXECUTE sql_stmt INTO mvt;
        RETURN mvt;
    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;