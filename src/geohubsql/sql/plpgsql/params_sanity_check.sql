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
		_numeric_max_value_field_length constant int :=  10;
		_text_max_value_field_length constant int    := 255;

    BEGIN

        FOR _key, _payload IN SELECT * FROM jsonb_each_text(default_param)
            LOOP

			_this_value := requested_params->_key->>'value'::varchar;

			CASE
			    WHEN ((default_param->_key->>'type') = 'numeric') THEN

                    IF (length(_this_value) >= _numeric_max_value_field_length) THEN
                        _this_value := left(_this_value, _numeric_max_value_field_length);

                    END IF;

                    IF _this_value IS NOT NULL
                        AND ((default_param->_key->'limits'->>'min')::numeric <= _this_value::numeric)
                       AND ((default_param->_key->'limits'->>'max')::numeric >= _this_value::numeric)
                    THEN
                        _sanitized_value := regexp_replace(_this_value, '[^0-9.-]+','','g')::jsonb;
                    ELSE
                        _sanitized_value := default_param->_key->'value';
                    END IF;

                WHEN ((default_param->_key->>'type') = 'text') THEN

--                    _sanitized_value := LEFT(regexp_replace(_this_value, '[^a-zA-Z0-9_\-\.]+','','g'),_text_max_value_field_length)::jsonb;
					_this_value	     := LEFT(_this_value,_text_max_value_field_length);
-- 					RAISE WARNING 'TEXT this_value 1 %: %', _key, _this_value;
					_this_value	     := regexp_replace(_this_value, '[^a-zA-Z0-9_\-\. ]+','','g');
-- 					RAISE WARNING 'TEXT this_value 2 %: %', _key, _this_value;
                    IF (length(_this_value)=0) THEN
                        _this_value='null'; --lower case, because we want a JSON null
                    END IF;

					_sanitized_value := to_jsonb(_this_value);
-- 					RAISE WARNING 'TEXT _sanitized_value - %: %',_key, _sanitized_value;

                ELSE
                    _sanitized_value := default_param->_key->>'value';

                END CASE;




            --RAISE WARNING 'SIZE: %' $.default_param._key.'value'.size()::text;
--             RAISE WARNING 'k: %, p:%, saniv:%', _key, _payload, _sanitized_value;
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
