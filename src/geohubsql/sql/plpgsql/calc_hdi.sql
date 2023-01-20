CREATE OR REPLACE FUNCTION admin.calc_hdi(
    LE decimal ,
    MYS decimal ,
    EYS decimal ,
    GNI decimal
    )
    RETURNS decimal AS $$

-- PL/PgSQL function to calculate the Human Development Index
-- requires 4 input values:
--			LE:  "Life expectancy" (in years)
--			MYS: "Expected years schooling" (in years)
--			EYS: "Mean years schooling" (in years)
--			GNI: "Log Gross National Income per capita" (in USD)
-- returns a decimal value

    DECLARE
        LEI decimal;
        MYSI decimal;
        EYSI decimal;
        EI decimal;
        II decimal;
        HDI decimal;

	BEGIN
		SELECT (LE-20)/65 INTO LEI;
		SELECT MYS/15 INTO MYSI;
		SELECT EYS/18 INTO EYSI;
		SELECT (MYSI+EYSI)/2  INTO EI;
		SELECT (LN(GNI)-LN(100))/LN(750) INTO II;

		SELECT cbrt(LEI*EI*II) INTO HDI;

		--RAISE NOTICE 'LE %, MYS %, EYS %, GNI %', LE, MYS, EYS, GNI;
		--RAISE NOTICE 'LEI %, MYSI %, EYSI %, EI %, II %', LEI, MYSI, EYSI, EI, II;
		--RAISE NOTICE 'HDI %', HDI;

	RETURN HDI;
END
$$ LANGUAGE plpgsql VOLATILE STRICT PARALLEL SAFE;
