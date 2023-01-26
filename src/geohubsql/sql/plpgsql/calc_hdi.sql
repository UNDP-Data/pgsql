CREATE OR REPLACE FUNCTION admin.calc_hdi(
    life_expectancy decimal ,
    mean_years_of_schooling decimal ,
    expected_years_of_schooling decimal ,
    gross_national_income decimal
    )
    RETURNS FLOAT AS $$

-- PL/PgSQL function to calculate the Human Development Index
-- requires 4 input values:
--			life_expectancy:  "Life expectancy" (in years)
--			mean_years_of_schooling: "Expected years schooling" (in years)
--			expected_years_of_schooling: "Mean years schooling" (in years)
--			gross_national_income: "Log Gross National Income per capita" (in USD)
-- returns a decimal value

    DECLARE
        life_expectancy_index decimal;
        mean_years_of_schooling_index decimal;
        expected_years_of_schooling_index decimal;
        education_index decimal;
        income_index decimal;
        HDI FLOAT;

	BEGIN
		SELECT (life_expectancy-20)/65 INTO life_expectancy_index;
		SELECT mean_years_of_schooling/15 INTO mean_years_of_schooling_index;
		SELECT expected_years_of_schooling/18 INTO expected_years_of_schooling_index;
		SELECT (mean_years_of_schooling_index+expected_years_of_schooling_index)/2  INTO education_index;
		SELECT (LN(gross_national_income)-LN(100))/LN(750) INTO income_index;

		SELECT cbrt(life_expectancy_index*education_index*income_index) INTO HDI;

		--RAISE NOTICE 'life_expectancy %, mean_years_of_schooling %, expected_years_of_schooling %, gross_national_income %', life_expectancy, mean_years_of_schooling, expected_years_of_schooling, gross_national_income;
		--RAISE NOTICE 'life_expectancy_index %, mean_years_of_schooling_index %, expected_years_of_schooling_index %, education_index %, income_index %', life_expectancy_index, mean_years_of_schooling_index, expected_years_of_schooling_index, education_index, income_index;
		--RAISE NOTICE 'HDI %', HDI;

	RETURN HDI;
END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;
