-- Function that creates a table which is search-optimized in terms of geometry.
-- Autodiscovers the (first) geom column of the schema/table passed as argument.
-- Uses two strategies:
--  - physically rewrites the table ordered by the geom, which makes it possible to access the disk only for the strictly necessary interval
--  - indexes the geom column as a GIST to make faster searches/intersects and generally speaking any ST_* operation way faster.
--
-- If an (optional) column name is passed, then a second (standard, not GIST) index is created.
-- Useful for indexing a column which is used in JOINs and WHEREs
--
-- Invoke as:
-- SELECT * FROM admin.optimize_geom('admin','admin1','iso_code');
-- SELECT * FROM admin.optimize_geom('admin','admin1','MixedCaseColName');
-- or
-- SELECT * FROM admin.optimize_geom('admin','admin1');
--
-- Performance comparison
-- (&& is a PostGIS operator checking the intersection of bounding boxes, which are indexed as a GIST):
-- (thuse && is not affected by the number of vertexes of the actual geometry and creates "unbiased" comparisons)
--
-- SELECT count(tr.id) FROM admin.test_rects_100k tr
-- JOIN admin.admin1 a1
-- ON (a1.geom && tr.geom);
-- takes 527 seconds
--
-- SELECT count(tr.id) FROM admin.test_rects_100k tr
-- JOIN admin.admin1_opt a1
-- ON (a1.geom && tr.geom);
-- takes 1.19 seconds
-- 
-- improvement > 440x


-- dropping is more radical than 'CREATE OR REPLACE'
-- because it makes it possible to change the number & type of the function's arguments
DROP FUNCTION IF EXISTS admin.optimize_geom;

-- 'OR REPLACE' was left just in case the previous 'DROP' gets commented
CREATE OR REPLACE FUNCTION admin.optimize_geom(input_schema_name varchar, input_table_name varchar, opt_additional_col_to_be_indexed varchar default NULL)
RETURNS int AS
$$

DECLARE

	-- exit code
	exit_code int default 1;

    -- the name of the first available geometry column in the table
	geom_col_name text;

	-- the name of the optimized table
	table_name_opt varchar;

	-- the name of the GIST index
	table_name_opt_idx_geom varchar;

	-- var to check if the optional column for which an index is requested does actually exist
	opt_col_exists int;

	-- the name of the generic index for the optional column
	opt_col_index varchar;


BEGIN



-- discover the first available geom column in the requested table
SELECT f_geometry_column FROM geometry_columns
WHERE f_table_name = input_table_name
LIMIT 1
INTO geom_col_name;

RAISE NOTICE 'Geom col name: %',geom_col_name;

-- define the name of the optimized table
table_name_opt = lower(input_table_name) || '_opt';
table_name_opt_idx_geom = lower(input_table_name) || '_opt_idx_geom';

IF (geom_col_name IS NOT NULL) THEN

	-- drop the optimized table, if already existing
	EXECUTE format('DROP TABLE IF EXISTS %I.%I',
						input_schema_name, table_name_opt);

	-- physical storage rewriting of the table, ordered geometry-wise to make it faster to retrieve contiguous features
	EXECUTE format('
	CREATE TABLE %I.%I AS
	SELECT * FROM %I.%I as optimized_table
	ORDER BY optimized_table.geom',
				   input_schema_name, table_name_opt, input_schema_name, input_table_name);

	-- dropping the GIST geometry index, should not be necessary since we just created the table
	-- EXECUTE format('DROP INDEX IF EXISTS %I', table_name_opt_idx_geom);

	-- create an index based on the GIST of the geom tree
	EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %I.%I USING GIST (%I)',
				   table_name_opt_idx_geom, input_schema_name,
				   table_name_opt, geom_col_name
				  );
	exit_code = 0;
ELSE
	-- no geom col found. Exiting the function.
	RAISE WARNING 'WARNING no goem col was found in table %.',input_table_name;
	RETURN exit_code;

END IF;

IF (opt_additional_col_to_be_indexed IS NOT NULL) THEN

	exit_code = 2;

    -- is the column present?
    EXECUTE 'SELECT count(*)
    		FROM information_schema.columns
			WHERE table_name=$1 and column_name=$2'
	USING table_name_opt, opt_additional_col_to_be_indexed
	INTO opt_col_exists;

	--RAISE NOTICE 'The requested column "%.%" has a count of %', table_name_opt, opt_additional_col_to_be_indexed, opt_col_exists;

	IF (opt_col_exists > 0) THEN

		opt_col_index = lower(opt_additional_col_to_be_indexed) || '_idx';

		RAISE NOTICE 'Creating index % for the requested column % (%)', opt_col_index, opt_additional_col_to_be_indexed , opt_col_exists;


		-- creating the index on the optional column
		EXECUTE format('DROP INDEX IF EXISTS %I', opt_col_index);

		EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %I.%I (%I)',
				   opt_col_index, input_schema_name,
				   table_name_opt, opt_additional_col_to_be_indexed
				  );
		exit_code = 0;

	ELSE
		RAISE WARNING 'ERROR: the requested column % was not found.', opt_additional_col_to_be_indexed ;
		exit_code = 4;

	END IF;

ELSE
    RAISE NOTICE 'The optional column is not present';
	exit_code = 3;
END IF;

RETURN exit_code;

END
$$  LANGUAGE plpgsql SECURITY DEFINER