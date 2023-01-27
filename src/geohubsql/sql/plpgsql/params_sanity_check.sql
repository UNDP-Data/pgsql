DROP FUNCTION IF EXISTS eval_max;

CREATE OR REPLACE FUNCTION admin.eval_max (a decimal default 0, b decimal default 0)
RETURNS decimal AS $eval_max$
declare
	eval_max decimal;
BEGIN
	eval_max:=a;
	IF (b>a) THEN
		eval_max := b;
	END IF;
   RETURN eval_max;
END;
$eval_max$ LANGUAGE plpgsql;

-----------------------------------

DROP FUNCTION IF EXISTS admin.params_sanity_check;

CREATE OR REPLACE FUNCTION admin.params_sanity_check(
   default_param json,
   requested_params json
   )

RETURNS json AS $params_sanity_check$

    DECLARE
        sanitized_json json;

    BEGIN
        -- placemark
        sanitized_json := requested_params;

        RETURN sanitized_json;

    END
$params_sanity_check$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;
