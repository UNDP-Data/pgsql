CREATE OR REPLACE FUNCTION admin.martin(
    z integer default 0,
    x integer default 0,
    y integer default 0,
    query_params json default '{}'::json,
    function_name text default 'admin.hdi_subnat_extarg'
    )


RETURNS bytea AS $$

    DECLARE
        mvt bytea;
        --layer_name varchar := 'admin.martin';
        --defaults_json jsonb;
		--requested_json jsonb;
		--sanitized_json jsonb;


    BEGIN
        --mvt:=admin.hdi_subnat_extarg(z,x,y,query_params::text);
        --mvt:=function_name(z,x,y,query_params::text);

        EXECUTE 'SELECT '||function_name||'('||z||','||x||','||y||','''||query_params||'''::text)'
        INTO mvt;

        RETURN mvt;

    END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION admin.martin IS 'This is martin, please insert the desired incremental values';

--
--SELECT * FROM admin.martin(0,0,0,'{
--  "le_incr":
--    {"value":1},
--  "eys_incr":
--     {"value":2},
--    "mys_incr":
--     {"value":3},
--  "gni_incr":
--     {"value":4}
--}') AS OUTP;
--

-- works in QGIS:
-- http://172.18.0.5:3000/rpc/admin.martin/{z}/{x}/{y}.pbf?function_name=hdi_subnat_extarg&query_params={"le_incr":{"value":1},"eys_incr":{"value":2},"mys_incr":{"value":3},"gni_incr":{"value":4}}

