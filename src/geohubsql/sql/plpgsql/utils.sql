DROP FUNCTION IF EXISTS admin.utils_enforce_limits;

CREATE OR REPLACE FUNCTION admin.utils_enforce_limits(
   input_value float,
   abs_min float,
   abs_max float
   )

RETURNS float AS $utils_enforce_limits$

    DECLARE
        _sanitized_value float = NULL;

    BEGIN

        IF (input_value < abs_min) THEN
            _sanitized_value = abs_min;
            --RAISE WARNING 'WARN LOW  utils_enforce_limits %, %, % -> %', input_value, abs_min, abs_max, _sanitized_value;
        ELSE
            IF (input_value > abs_max) THEN
                _sanitized_value = abs_max;
               --RAISE WARNING 'WARN HIGH utils_enforce_limits %, %, % -> %', input_value, abs_min, abs_max, _sanitized_value;
            ELSE
               _sanitized_value = input_value;
            END IF;
        END IF;

        --RAISE WARNING 'WARN utils_enforce_limits %, %, % -> %', input_value, abs_min, abs_max, _sanitized_value;
        RETURN _sanitized_value;

    END
$utils_enforce_limits$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;


--SELECT * FROM admin.utils_enforce_limits (100.01,0,100);













DROP FUNCTION IF EXISTS admin.utils_simplify_vlayer;

CREATE OR REPLACE FUNCTION admin.utils_simplify_vlayer(
    input_schema_name varchar,
    input_table_name varchar,
    tolerance integer,
    suffix varchar
   )

RETURNS boolean AS $utils_simplify_vlayer$

    DECLARE
        _result boolean = FALSE;
        _output_table_name varchar;

    BEGIN

        _output_table_name := input_table_name||'_'||suffix;
        --RAISE WARNING 'new table name: %s', _output_table_name ;

		EXECUTE format(
			'DROP TABLE IF EXISTS %I.%I ;',
			input_schema_name,_output_table_name);


--      create a copy of the input table, but with a simplified geom column.
--      since the table is then passed to `optimize_geom`,
--      it will then be copied again without leaving gaps in the file

		EXECUTE format('
        CREATE TABLE  %I.%I AS (
            SELECT
            vlr.*,
            ST_SimplifyPreserveTopology( vlr.geom, %s) as geom2
            FROM %I.%I AS vlr

            );',
					input_schema_name,_output_table_name,
					tolerance,
					input_schema_name,input_table_name,
					input_schema_name,_output_table_name);

        EXECUTE format('
        ALTER TABLE  %I.%I DROP COLUMN geom;',
					input_schema_name,_output_table_name);

        EXECUTE format('
        ALTER TABLE  %I.%I RENAME COLUMN geom2 TO geom;',
					input_schema_name,_output_table_name);

		EXECUTE format (
				'SELECT * FROM admin.optimize_geom(''%I'',''%I'');',
					   input_schema_name, _output_table_name
		);

        _result = TRUE;
		RETURN _result;

    END
$utils_simplify_vlayer$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

--SELECT * FROM  admin.utils_simplify_vlayer('admin', 'admin1',10000,'z4') ;



--
CREATE OR REPLACE FUNCTION admin.grant_standard_permissions_on_table(
    input_schema_name varchar,
    input_table_name varchar,
    standard_username varchar default 'tileserver'
   )

RETURNS boolean AS $grant_standard_permissions_on_table$

    DECLARE

        _result boolean = FALSE;


    BEGIN
        RAISE WARNING 'granting read permissions on %.% to % ', input_schema_name,input_table_name, standard_username ;

		EXECUTE format(
			'GRANT SELECT ON %I.%I to %s;',
			input_schema_name, input_table_name, standard_username);

		-- add any other permissions needed
         _result = TRUE;
		RETURN _result;

    END
$grant_standard_permissions_on_table$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

--CREATE USER tileserver WITH PASSWORD 'tileserver';
--SELECT * FROM  admin.grant_standard_permissions_on_table('admin', 'admin1') ;


-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
----------------            util_check_table_exists          ----------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin.util_check_table_exists(
        input_schema_name varchar,
        input_table_name varchar
        )

    RETURNS boolean AS $util_check_table_exists$

    DECLARE
        table_exists boolean default FALSE;

    BEGIN

        EXECUTE format('SELECT EXISTS (
        SELECT FROM
            pg_tables
        WHERE
            schemaname = ''%s'' AND
            tablename  = ''%s''
        );',
        input_schema_name, input_table_name) INTO table_exists;

        RETURN table_exists;
    END
$util_check_table_exists$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

--SELECT * FROM  admin.util_check_table_exists('admin', 'admin1') ;

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
----------------       util_lookup_simplified_table_name     ----------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION admin.util_lookup_simplified_table_name(
        input_schema_name varchar,
        input_table_name varchar,
        zoom_level integer default 0
        )

    RETURNS varchar AS $util_lookup_simplified_table_name$

    DECLARE
        suffix varchar default '';
        simplified_table_name varchar default NULL;
        table_exists BOOLEAN default  FALSE;

    BEGIN

        EXECUTE format(
        'SELECT vsl.table_suffix FROM admin.vector_simplification_level AS vsl
        where vsl.zoom_level = %s
        LIMIT 1;'
        , zoom_level)
        INTO suffix;

	--RAISE NOTICE 'found suffix: %',suffix;

    IF (length (suffix)>0) THEN
        simplified_table_name := input_table_name||'_'||suffix;
    ELSE
        simplified_table_name := input_table_name;
    END IF;

	--RAISE NOTICE 'simplified_table_name: %',simplified_table_name;

     EXECUTE format('SELECT * FROM  admin.util_check_table_exists(''%s'', ''%s'')', input_schema_name, simplified_table_name)
     INTO table_exists;
	--RAISE NOTICE 'table_exists: %',table_exists;

    IF (NOT table_exists) THEN
        RAISE NOTICE 'ERR NOT FOUND simplified_table_name: %',simplified_table_name;
        simplified_table_name:=input_table_name;
    END IF;


    RETURN simplified_table_name;
    END
$util_lookup_simplified_table_name$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

--
--SELECT * FROM admin.util_lookup_simplified_table_name('admin', 'whatever', 7);


-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
----------------            util_lookup_mvt_extent           ----------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------


CREATE OR REPLACE FUNCTION admin.util_lookup_mvt_extent(
        zoom_level integer default 0
        )

    RETURNS integer AS $util_lookup_mvt_extent$

    DECLARE
        _mvt_extent integer default NULL;

    BEGIN

        EXECUTE format(
        'SELECT vzl.mvt_extent_value FROM admin.vector_zoom_level AS vzl
        where vzl.zoom_level = %s
        LIMIT 1;'
        , zoom_level)
        INTO _mvt_extent;

--        SELECT vzl.mvt_extent_value FROM admin.vector_zoom_level AS vzl
--        where vzl.zoom_level = zoom_level
--        LIMIT 1
--        INTO _mvt_extent;

    IF (_mvt_extent IS NULL)OR(_mvt_extent<=0) THEN
        _mvt_extent := 4096;
    END IF;

--	RAISE NOTICE '_mvt_extent: %',_mvt_extent;

    RETURN _mvt_extent;
    END
$util_lookup_mvt_extent$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

--
--SELECT * FROM admin.util_lookup_mvt_extent(7);


-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
----------------        util_create_zoom_lookup_tables       ----------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin.util_create_zoom_lookup_tables()

RETURNS boolean AS $util_create_zoom_lookup_tables$

BEGIN
		DROP TABLE IF EXISTS admin.vector_simplification_level;
        CREATE TABLE admin.vector_simplification_level (
            zoom_level integer PRIMARY KEY,
            table_suffix varchar(10),
            tolerance_m integer NOT NULL default 1000
            );

        INSERT INTO admin.vector_simplification_level
            (zoom_level, table_suffix, tolerance_m)
            values
            (0,'s10000', 10000),
            (1,'s10000', 10000),
            (2,'s10000', 10000),
            (3,'s10000', 10000),
            (4,'s10000', 10000),
            (5,'s5000',   5000),
            (6,'s1000',   1000),
            (7,'s1000',   1000),
            (8,'s500',     500),
            (9,'s100',     100),
            (10,'s100',    100),
            (11,'',          0),
            (12,'',          0),
            (13,'',          0),
            (14,'',          0),
            (15,'',          0),
            (16,'',          0),
            (17,'',          0),
            (18,'',          0),
            (19,'',          0),
            (20,'',          0),
            (21,'',          0),
            (22,'',          0),
            (23,'',          0),
            (24,'',          0),
            (25,'',          0),
            (26,'',          0),
            (27,'',          0),
            (28,'',          0),
            (29,'',          0),
            (30,'',          0)
            ;

        DROP INDEX IF EXISTS vector_simplification_level_idx;
        CREATE INDEX IF NOT EXISTS vector_simplification_level_idx ON admin.vector_simplification_level (zoom_level);

		DROP TABLE IF EXISTS admin.vector_zoom_level;
        CREATE TABLE admin.vector_zoom_level (
           zoom_level integer PRIMARY KEY,
           mvt_extent_value integer NOT NULL default 1024
        );
        INSERT INTO admin.vector_zoom_level
            (zoom_level,  mvt_extent_value)
            values
            (0,  512),
            (1,  512),
            (2,  784),
            (3, 1024),
            (4, 1024),
            (5, 2048),
            (6, 2048),
            (7, 2048),
            (8, 2048),
            (9, 2048),
            (10,4096),
            (11,4096),
            (12,4096),
            (13,4096),
            (14,4096),
            (15,4096),
            (16,4096),
            (17,4096),
            (18,4096),
            (19,4096),
            (20,4096),
            (21,4096),
            (22,4096),
            (23,4096),
            (24,4096),
            (25,4096),
            (26,4096),
            (27,4096),
            (28,4096),
            (29,4096),
            (30,4096)
            ;

            DROP INDEX IF EXISTS vector_zoom_level_idx;
            CREATE INDEX IF NOT EXISTS vector_zoom_level_idx ON admin.vector_zoom_level (zoom_level);

            RETURN TRUE;
END
$util_create_zoom_lookup_tables$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;
-- SELECT * FROM admin.util_create_zoom_lookup_tables();

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
----------------            create_vector_pyramid            ----------------
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION admin.create_vector_pyramid(
    input_schema_name varchar,
    input_table_name varchar
   )

RETURNS boolean AS $create_vector_pyramids$

    DECLARE
            _table_suffix varchar;
            _tolerance_m int;
            _l_schema_name varchar;
            _l_table_name varchar;
            _result boolean = FALSE;
    BEGIN
    -- TODO complete
        RAISE WARNING 'creating vector pyramid for %.% ', input_schema_name,input_table_name;

        FOR _table_suffix, _tolerance_m IN SELECT DISTINCT vsl.table_suffix, vsl.tolerance_m FROM admin.vector_simplification_level AS vsl ORDER BY vsl.tolerance_m
            LOOP
                _l_schema_name := input_schema_name;
                _l_table_name  := input_table_name;
                IF ((_table_suffix IS NOT NULL) AND (_tolerance_m IS NOT NULL) AND (Length(_table_suffix) > 0) AND (_tolerance_m >0 )) THEN
                    --RAISE NOTICE '%.% -> % / %', _l_schema_name, _l_table_name, _table_suffix, _tolerance_m;

                    PERFORM format(
                    'DROP TABLE ''%s''.''%s_%s'';',
                    _l_schema_name, _l_table_name, _table_suffix
                    );
                    EXECUTE format(
                    'SELECT * FROM admin.utils_simplify_vlayer(''%s'', ''%s'',''%s'',''%s'')',
                    _l_schema_name, _l_table_name, _tolerance_m, _table_suffix
                    );
                ELSE

                END IF;
            END LOOP;

		-- add any other permissions needed
         _result = TRUE;
		RETURN _result;

    END
$create_vector_pyramids$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

--CREATE USER tileserver WITH PASSWORD 'tileserver';
--SELECT * FROM  admin.create_vector_pyramid('admin', 'admin1') ;