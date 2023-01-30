DROP FUNCTION IF EXISTS admin.params_sanity_check;

CREATE OR REPLACE FUNCTION admin.params_sanity_check(
   default_param jsonb,
   requested_params jsonb
   )

RETURNS json AS $params_sanity_check$

    DECLARE
        _sanitized_jsonb jsonb = '{}';
        _key varchar;
        _payload varchar;
		_output_payload jsonb;
        _sanitized_value jsonb;
        _outp varchar;
        _path text[];
		_this_value varchar;
		_max_value_field_length constant int := 10;

    BEGIN

        FOR _key, _payload IN SELECT * FROM jsonb_each_text(default_param)
            LOOP

			_this_value := requested_params->_key->>'value'::varchar;

			IF (length(_this_value) >= _max_value_field_length) THEN
				_this_value := left(_this_value, _max_value_field_length);
			END IF;

            IF  _this_value IS NOT NULL
			AND ((default_param->_key->'limits'->>'min')::numeric <= _this_value::numeric)
            AND ((default_param->_key->'limits'->>'max')::numeric >= _this_value::numeric)
            THEN

				_sanitized_value := regexp_replace(_this_value, '[^0-9.]+','','g')::jsonb;
                --_sanitized_value := requested_params->_key->'value';

            ELSE
                _sanitized_value := default_param->_key->'value';

            END IF;
            --RAISE WARNING 'SIZE: %' $.default_param._key.'value'.size()::text;
            --RAISE WARNING 'k: %, p:%, saniv:%', _key, _payload, _sanitized_value;
			_output_payload:=jsonb_build_object('value',_sanitized_value);
            _path:=array[_key];

			--it seems jsonb_set has troubles creating nested objects
			_sanitized_jsonb := jsonb_set(_sanitized_jsonb, _path, _output_payload, TRUE);

        END LOOP;

        --_outp:=jsonb_pretty(_sanitized_jsonb);
        --RAISE WARNING '_outp: %', _outp;

        RETURN _sanitized_jsonb;

    END
$params_sanity_check$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;


--SELECT * FROM admin.params_sanity_check (
--	'{ "le_incr":{"limits":{"min":-10,"max":10},"value":0},"eys_incr":{"limits":{"min":-10,"max":10},"value":0},"mys_incr":{"limits":{"min":-10,"max":10},"value":0},"gni_incr":{"limits":{"min":-30000,"max":30000},"value":0}}'::jsonb,
--	'{ "le_incr":{"value":1.13555626333},"eys_incr":{"value":999},"mys_incr":{"value":-333},"gni_incr":{"value":40000}}'::jsonb
--);
