CREATE OR REPLACE FUNCTION drr.calc_hhr(
    max_t decimal ,
    hdi decimal ,
    working_age_pop_perc decimal ,
    gnipc decimal ,
    vhi decimal ,
    pop_density decimal,
    log_gnipc_min decimal,
    log_gnipc_diff decimal,
    pop_min decimal,
    pop_diff decimal
    )
    RETURNS FLOAT AS $$

-- PL/PgSQL function to calculate the Heat Heath Risk


    DECLARE

        hazard_index decimal;
        vulnerability_index decimal;
        exposure_index decimal;
        dependency_ratio decimal;

        hhr FLOAT;

        temperature_index decimal;

        non_dangerous_temp decimal;
        dangerous_temp decimal;

        gnipc_normalized_log decimal;
        pop_density_normalized decimal;

        missing_data integer;

	BEGIN

        --26.66 to 39.4 Celsius degrees as per https://www.weather.gov/ama/heatindex
        non_dangerous_temp := 299.82;
        dangerous_temp := 312.55;
        missing_data := 0;

        IF log_gnipc_diff = 0 THEN
            log_gnipc_diff = 1;
            missing_data = 1;
        END IF;

        IF working_age_pop_perc =0 THEN
            working_age_pop_perc = 1;
            missing_data = 1;
        END IF;

        IF pop_diff = 0 THEN
            pop_diff = 1;
            missing_data = 1;
        END IF;



        dependency_ratio := (1- working_age_pop_perc)/working_age_pop_perc;




        -- normalize the temperature
        CASE
		    WHEN max_t < non_dangerous_temp then
               temperature_index = 1 ;
            WHEN max_t >= dangerous_temp then
	           temperature_index = 1 ;
            ELSE
               temperature_index = (max_t - non_dangerous_temp) / (dangerous_temp - non_dangerous_temp) ;
        END CASE;

        -- cap hdi to 1.00
        IF (hdi > 1) THEN
         hdi := 1;
        END IF;

        -- normalize GNI
        gnipc_normalized_log = (log(gnipc) - log_gnipc_min) / (log_gnipc_diff);


        -- normalize pop_density
        pop_density_normalized = (pop_density - pop_min) / (pop_diff);

--		RAISE WARNING 'gnipc %, gnipc_normalized_log %, pop_density % ,pop_density_normalized %, dependency_ratio %',gnipc, gnipc_normalized_log, pop_density, pop_density_normalized, dependency_ratio;

		hazard_index := temperature_index;
		vulnerability_index := ((1-hdi) + dependency_ratio) * 0.44 + ((1-gnipc_normalized_log) + (1-vhi)) * 0.56;
		exposure_index := pop_density_normalized;

        hhr := hazard_index * 0.22 + vulnerability_index * 0.33 + exposure_index * 0.44;

        IF (missing_data > 0) THEN
            hhr := -999;
        END IF;

--		RAISE NOTICE 'hazard_index %, vulnerability_index %, exposure_index %', hazard_index, vulnerability_index, exposure_index;
		--RAISE NOTICE 'hhr %', hhr;

	RETURN hhr;
	--RETURN 1;
END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

--SELECT * FROM drr.calc_hhr(0.1, 0.1, 0.5, 0.6, 0.7, 0.8,1,2,3,4);