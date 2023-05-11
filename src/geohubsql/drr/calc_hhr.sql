CREATE OR REPLACE FUNCTION drr.calc_hrr(
    max_t decimal ,
    hdi decimal ,
    dependency_ratio decimal ,
    gnipc decimal ,
    vhi decimal ,
    pop_density decimal
    )
    RETURNS FLOAT AS $$

-- PL/PgSQL function to calculate the Heat Heath Risk


    DECLARE

        hazard_index decimal;
        vulnerability_index decimal;
        exposure_index decimal;
        hhr FLOAT;

        temperature_index decimal;

        non_dangerous_temp decimal;
        dangerous_temp decimal;

	BEGIN

        --26.66 to 39.4 Celsius degrees as per https://www.weather.gov/ama/heatindex
        non_dangerous_temp := 299.82;
        dangerous_temp := 312.55;

        CASE
		    WHEN max_t < non_dangerous_temp then
               temperature_index = 1 ;
            WHEN max_t >= dangerous_temp then
	           temperature_index = 1 ;
            ELSE
               temperature_index = (max_t - non_dangerous_temp) / (dangerous_temp - non_dangerous_temp) ;
        END CASE;


		hazard_index := temperature_index;
		vulnerability_index := (hdi + dependency_ratio) * 0.44 + (gnipc + vhi) * 0.56;
		exposure_index := pop_density;

        hhr := hazard_index * 0.25 + vulnerability_index * 0.25 + exposure_index * 0.25;

		--RAISE NOTICE 'hazard_index %, vulnerability_index %, exposure_index %', hazard_index, vulnerability_index, exposure_index;
		--RAISE NOTICE 'hhr %', hhr;

	RETURN hhr;
END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;

--SELECT * FROM drr.calc_hhr(0.1, 0.1, 0.5, 0.6, 0.7, 0.8);