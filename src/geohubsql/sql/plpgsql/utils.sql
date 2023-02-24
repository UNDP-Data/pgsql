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
        ELSE
            IF (input_value > abs_max) THEN
                _sanitized_value = abs_max;
            ELSE
               _sanitized_value = input_value;
            END IF;
        END IF;

        --RAISE WARNING 'WARN utils_enforce_limits %, %, % -> %', input_value, abs_min, abs_max, _sanitized_value;
        RETURN _sanitized_value;

    END
$utils_enforce_limits$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;


--SELECT * FROM admin.utils_enforce_limits (100.01,0,100);
