CREATE OR REPLACE FUNCTION {{ parsing_strings.schema_name }}.f_{{ parsing_strings.indicator_clean }}(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    params varchar default '{
    "subsets":
    {{ parsing_strings.subsets_json_double_quoted }}
    }'
    )

RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        layer_name varchar := '{{ parsing_strings.schema_name }}.f_{{ parsing_strings.indicator_clean }}';


        simplified_table_name varchar := NULL;

        defaults_json jsonb;
		requested_json jsonb;
		sanitized_json jsonb;
		sanitized_subset_json jsonb;

        geom_col   varchar;
        featcount  integer;
        my_query   varchar;
        feat_limit integer := 3000;

        {% for subset_name in parsing_strings.subsets_json -%}
            {{ subset_name }}   varchar := '';
        {% endfor %}

        mvt_extent integer := 1024;
        mvt_buffer integer := 32;

        func_defaults jsonb :=
            '{
            "subsets":
            {{ parsing_strings.subsets_json_double_quoted }}
            }';

-- PL/PgSQL function to create a dynamic function layer (delivered as Vector Tiles) with filters


    BEGIN
        defaults_json  := func_defaults::jsonb;
        requested_json := params::jsonb;

        -- sanitize the JSON before proceeding
        --sanitized_subset_json:=admin.params_sanity_check(defaults_json->'subsets', requested_json->'subsets');

        -- extract the relevant parameters

        {% for subset_name in parsing_strings.subsets_json -%}
            {{ subset_name }}   := requested_json->'subsets'->'{{ subset_name }}'->>'value';
        {% endfor %}

        --let's set St_AsMVT's extent as a function of the zoom level
        --in order to reduce network usage and increase the UX.
        EXECUTE format('SELECT * FROM admin.util_lookup_mvt_extent(%s)',z) INTO mvt_extent;


		DROP TABLE IF EXISTS sdg_tmp_table;

        SELECT format('CREATE TEMPORARY TABLE sdg_tmp_table AS (
            SELECT
			a."iso3cd" AS iso3cd
			{% for year in parsing_strings.years -%} , a.value_{{ year }} {% endfor %}
            {% if parsing_strings.value_latest > 0 %} , a.value_latest {% endif %}
			FROM {{ parsing_strings.schema_name }}.{{ parsing_strings.admin_level }} a
			WHERE
    			indicator = ''{{ parsing_strings.indicator }}''
			{% for subset_name in parsing_strings.subsets_json -%} AND a.{{ subset_name }} = ''%s'' {% endfor %}
            {% if parsing_strings.value_latest > 0 %} AND a.value_latest IS NOT NULL {% endif %}
        );'
        {% for subset_name in parsing_strings.subsets_json -%} , {{ subset_name }} {% endfor %}
        ) INTO my_query;

        EXECUTE my_query;

--        RAISE WARNING 'my_query: %', my_query;
--        SELECT COUNT(*) FROM sdg_tmp_table INTO featcount;
--        RAISE WARNING 'featcount %', featcount;

		CREATE INDEX IF NOT EXISTS "sdg_tmp_table_idx1" ON "sdg_tmp_table" (iso3cd);

		DROP TABLE IF EXISTS bounds;
        CREATE TEMPORARY TABLE bounds AS (
			SELECT ST_TileEnvelope(z,x,y) AS geom
		);

		DROP TABLE IF EXISTS mvtgeom;

        EXECUTE format('SELECT * FROM admin.util_lookup_simplified_table_name(''admin'',''{{ parsing_strings.admin_level }}'',%s)',z) INTO simplified_table_name;

--        RAISE WARNING 'Using simplified table %', simplified_table_name;


        EXECUTE format('CREATE TEMPORARY TABLE mvtgeom AS (

            SELECT ST_AsMVTGeom(a.geom, bounds.geom, extent => %s, buffer => %s) AS geom,
			ROW_NUMBER () OVER (ORDER BY a.iso3cd) AS fid,
			a.iso3cd
            {% for year in parsing_strings.years -%} , CAST(h.value_{{ year }} as FLOAT) {% endfor %}
            {% if parsing_strings.value_latest > 0 %} , CAST(h.value_latest as FLOAT)  {% endif %}
			--definition_multiplier as ext_multiplier_val
            FROM admin."%s" a
			JOIN bounds ON ST_Intersects(a.geom, bounds.geom)
            JOIN sdg_tmp_table h ON a.iso3cd = h.iso3cd
            ORDER BY a.iso3cd
            --LIMIT feat_limit
            );',
            mvt_extent, mvt_buffer,
            simplified_table_name
            );

        --RAISE WARNING 'SIMPLIFIED into %', simplified_table_name;
        -- use 'default' as a layer name to make it possible to visualize it via pg_tileServ's internal map viewer
--        layer_name := 'default';

        SELECT ST_AsMVT(mvtgeom.*,layer_name, mvt_extent, 'geom', 'fid')
		FROM mvtgeom
		INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION {{ parsing_strings.schema_name }}.f_{{ parsing_strings.indicator_clean }} IS 'This is f_{{ parsing_strings.indicator_clean }}
{% if parsing_strings.description is defined %} - {{ parsing_strings.description }}
{% endif %}';

--SELECT * FROM "{{ parsing_strings.schema_name }}"."f_{{ parsing_strings.indicator_clean }}"(0,0,0,'{"subsets":
--    {{ parsing_strings.subsets_json_double_quoted }}
--    }') AS OUTP;