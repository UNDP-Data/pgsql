DROP FUNCTION IF EXISTS calc_hhr_table;

CREATE OR REPLACE FUNCTION drr.calc_hhr_table(
    func_defaults JSONB, sanitized_jsonb JSONB
    )
    RETURNS TABLE (gdlcode TEXT, hazard_index FLOAT, vulnerability_index FLOAT, exposure_index FLOAT, heat_health_index FLOAT) AS $$


-- PL/PgSQL function to calculate the Heat Heath Risk


    DECLARE

        max_t_adjustment  float default 0;
        hdi_adjustment float default 0;
        working_age_pop_adjustment float default 0;
        gnipc_adjustment float default 0;
        vhi_adjustment float default 0;
        pop_density_adjustment float default 0;

        max_t_min  float default 0;
        hdi_min float default 0;
        working_age_pop_min float default 0;

        vhi_min float default 0;
        pop_density_min float default 0;

        max_t_max  float default 0;
        hdi_max float default 0;
        working_age_pop_max float default 0;

        vhi_max float default 0;
        pop_density_max float default 0;

        max_t_value  float default 0;
        hdi_value float default 0;
        working_age_pop_value float default 0;
        gnipc_value float default 0;
        vhi_value float default 0;
        pop_density_value float default 0;

        gnipc_min float default 0;
        gnipc_max float default 100;
        log_gnipc_min decimal;
        log_gnipc_max decimal;
        log_gnipc_diff decimal;

        pop_min  decimal;
        pop_max  decimal;
        pop_diff decimal;



        hazard_index decimal;
        vulnerability_index decimal;
        exposure_index decimal;
        dependency_ratio decimal;

        hhr FLOAT;

        temperature_index decimal;

        non_dangerous_temp decimal;
        dangerous_temp decimal;
        temp_range decimal;

        gnipc_normalized_log decimal;
        pop_density_normalized decimal;

        missing_data integer;


        debug_val_str varchar;

	BEGIN

        --26.66 to 39.4 Celsius degrees as per https://www.weather.gov/ama/heatindex
        non_dangerous_temp := 299.82;
        dangerous_temp := 312.55;
        missing_data := 0;
        temp_range := dangerous_temp - non_dangerous_temp;

        -- extract the relevant parameters
        max_t_adjustment             := sanitized_jsonb->'max_t_adjustment'->'value';
        hdi_adjustment               := sanitized_jsonb->'hdi_adjustment'->'value';
        working_age_pop_adjustment   := sanitized_jsonb->'working_age_pop_adjustment'->'value';
        gnipc_adjustment             := sanitized_jsonb->'gnipc_adjustment'->'value';
        vhi_adjustment               := sanitized_jsonb->'vhi_adjustment'->'value';
        pop_density_adjustment       := sanitized_jsonb->'pop_density_adjustment'->'value';

        -- recast once to avoid doing that every row
        max_t_min               := (func_defaults->'max_t_adjustment'->'abs_limits'->'min')::float;
        hdi_min                 := (func_defaults->'hdi_adjustment'->'abs_limits'->'min')::float;
        working_age_pop_min     := (func_defaults->'working_age_pop_adjustment'->'abs_limits'->'min')::float;
        gnipc_min               := (func_defaults->'gnipc_adjustment'->'abs_limits'->'min')::float;
        vhi_min                 := (func_defaults->'vhi_adjustment'->'abs_limits'->'min')::float;
        pop_density_min         := (func_defaults->'pop_density_adjustment'->'abs_limits'->'min')::float;

        max_t_max               := (func_defaults->'max_t_adjustment'->'abs_limits'->'max')::float;
        hdi_max                 := (func_defaults->'hdi_adjustment'->'abs_limits'->'max')::float;
        working_age_pop_max     := (func_defaults->'working_age_pop_adjustment'->'abs_limits'->'max')::float;
        gnipc_max               := (func_defaults->'gnipc_adjustment'->'abs_limits'->'max')::float;
        vhi_max                 := (func_defaults->'vhi_adjustment'->'abs_limits'->'max')::float;
        pop_density_max         := (func_defaults->'pop_density_adjustment'->'abs_limits'->'max')::float;


        -- extract parameters to normalize gni
        SELECT h."gnipc"
		FROM drr.hhr_input_data h
		ORDER BY h."gnipc" ASC LIMIT 1
		INTO gnipc_min;

        SELECT h."gnipc"
		FROM drr.hhr_input_data h
		ORDER BY h."gnipc" DESC LIMIT 1
		INTO gnipc_max;

        log_gnipc_min := LOG(gnipc_min);
        log_gnipc_max := LOG(gnipc_max);
        log_gnipc_diff := log_gnipc_max - log_gnipc_min;

        -- extract parameters to normalize pop_density
        SELECT h."pop_density"
		FROM drr.hhr_input_data h
		ORDER BY h."pop_density" ASC LIMIT 1
		INTO pop_min;

        SELECT h."pop_density"
		FROM drr.hhr_input_data h
		ORDER BY h."pop_density" DESC LIMIT 1
		INTO pop_max;

		pop_diff := pop_max - pop_min;


--        IF log_gnipc_diff = 0 THEN
--            log_gnipc_diff = 1;
--            missing_data = 1;
--        END IF;
--
--        IF working_age_pop_perc =0 THEN
--            working_age_pop_perc = 1;
--            missing_data = 1;
--        END IF;
--
--        IF pop_diff = 0 THEN
--            pop_diff = 1;
--            missing_data = 1;
--        END IF;
--
--
--        dependency_ratio := (1- working_age_pop_perc)/working_age_pop_perc;

--pop_density_normalized = (pop_density - pop_min) / (pop_diff);

--        DROP TABLE IF EXISTS debug_table;
--        CREATE TEMPORARY TABLE debug_table AS (
--        WITH helper_table AS (
--            SELECT h.gdlcode,
--                LEAST(GREATEST (((h.max_t + max_t_adjustment) - non_dangerous_temp)/temp_range, 0),1) as temperature_index,
--                LEAST(GREATEST (h."hdi" * (1+hdi_adjustment/100),hdi_min),hdi_max) as hdi,
--                LEAST(GREATEST (h."working_age_pop" * (1+working_age_pop_adjustment/100),hdi_min),hdi_max) as working_age_pop_perc,
--                (log(LEAST(GREATEST (h."gnipc" * (1+gnipc_adjustment/100),gnipc_min),gnipc_max)) - log_gnipc_min) / (log_gnipc_diff) AS gnipc_normalized_log,
--                LEAST(GREATEST (h."vhi" * (1+vhi_adjustment/100),vhi_min),vhi_max) as vhi,
--                ((LEAST(GREATEST (h."pop_density" * (1+pop_density_adjustment/100),pop_density_min),pop_density_max) - pop_min) / pop_diff ) as pop_density_normalized
--            FROM drr.hhr_input_data h
--        )
--            SELECT
--                ht.*,
--                ht.temperature_index AS hazard_index,
--                (1- ht.working_age_pop_perc)/ht.working_age_pop_perc as dependency_ratio,
--                ( (1-ht.hdi) + (1- ht.working_age_pop_perc)/ht.working_age_pop_perc ) * 0.44 + ( (1-ht.gnipc_normalized_log) + (1-ht.vhi) ) * 0.56 AS vulnerability_index,
--                ht.pop_density_normalized AS exposure_index
--            FROM helper_table ht
--            WHERE ht.gdlcode = 'TURr103'
--            LIMIT 2
--        );
--
--        SELECT json_agg(dt) FROM debug_table dt into debug_val_str;
--        RAISE WARNING 'debug_table rows: %',debug_val_str;
--        RAISE WARNING 'log_gnipc_min:%, log_gnipc_max%, gnipc_max: %', log_gnipc_min, log_gnipc_max, gnipc_max;


        RETURN QUERY
        WITH helper_table AS (
            SELECT h.gdlcode,
                LEAST(GREATEST (((h.max_t + max_t_adjustment) - non_dangerous_temp)/temp_range, 0),1) as temperature_index,
                LEAST(GREATEST (h."hdi" * (1+hdi_adjustment/100),hdi_min),hdi_max) as hdi,
                LEAST(GREATEST (h."working_age_pop" * (1+working_age_pop_adjustment/100),hdi_min),hdi_max) as working_age_pop_perc,
                (log(LEAST(GREATEST (h."gnipc" * (1+gnipc_adjustment/100),gnipc_min),gnipc_max)) - log_gnipc_min) / (log_gnipc_diff) AS gnipc_normalized_log,
                LEAST(GREATEST (h."vhi" * (1+vhi_adjustment/100),vhi_min),vhi_max) as vhi,
                ((LEAST(GREATEST (h."pop_density" * (1+pop_density_adjustment/100),pop_density_min),pop_density_max) - pop_min) / pop_diff ) as pop_density_normalized
            FROM drr.hhr_input_data h
        ),
            helper_table2 AS (
            SELECT
                ht."gdlcode" AS gdlcode,
                ht.temperature_index AS hazard_index,
                ( (1-ht.hdi) + (1- ht.working_age_pop_perc)/ht.working_age_pop_perc ) * 0.44 + ( (1-ht.gnipc_normalized_log) + (1-ht.vhi) ) * 0.56 AS vulnerability_index,
                ht.pop_density_normalized AS exposure_index
            FROM helper_table ht)
        SELECT
            ht2.gdlcode,
            ht2.hazard_index,
            ht2.vulnerability_index,
            ht2.exposure_index,
            ( ht2.hazard_index * 0.22 + ht2.vulnerability_index * 0.33 + ht2.exposure_index * 0.44 ) AS heat_health_index
        FROM helper_table2 AS ht2;




--------
--
--
--        -- normalize the temperature
--        CASE
--		    WHEN max_t < non_dangerous_temp then
--               temperature_index = 1 ;
--            WHEN max_t >= dangerous_temp then
--	           temperature_index = 1 ;
--            ELSE
--               temperature_index = (max_t - non_dangerous_temp) / (dangerous_temp - non_dangerous_temp) ;
--        END CASE;
--
--        -- cap hdi to 1.00
--        IF (hdi > 1) THEN
--         hdi := 1;
--        END IF;
--
--        -- normalize GNI
--        gnipc_normalized_log = (log(gnipc) - log_gnipc_min) / (log_gnipc_diff);
--
--
--        -- normalize pop_density
--        pop_density_normalized = (pop_density - pop_min) / (pop_diff);
--
----		RAISE WARNING 'gnipc %, gnipc_normalized_log %, pop_density % ,pop_density_normalized %, dependency_ratio %',gnipc, gnipc_normalized_log, pop_density, pop_density_normalized, dependency_ratio;
--
--		hazard_index := temperature_index;
--		vulnerability_index := ((1-hdi) + dependency_ratio) * 0.44 + ((1-gnipc_normalized_log) + (1-vhi)) * 0.56;
--		exposure_index := pop_density_normalized;
--
--        hhr := hazard_index * 0.22 + vulnerability_index * 0.33 + exposure_index * 0.44;
--        hhr := hhr * 100;
--
--        IF (missing_data > 0) THEN
--            hhr := -999;
--        END IF;

--		RAISE NOTICE 'hazard_index %, vulnerability_index %, exposure_index %', hazard_index, vulnerability_index, exposure_index;
		--RAISE NOTICE 'hhr %', hhr;

--	RETURN hhr;
	--RETURN 1;
END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

--SELECT * FROM drr.calc_hhr(0.1, 0.1, 0.5, 0.6, 0.7, 0.8,1,2,3,4);