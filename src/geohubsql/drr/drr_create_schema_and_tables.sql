-- create the Disaster Risk Recovery schema

CREATE SCHEMA IF NOT EXISTS "drr";
GRANT SELECT,USAGE ON ALL TABLES IN SCHEMA "drr" TO "tileserver";
GRANT CREATE,USAGE ON SCHEMA "drr" TO "tileserver";
ALTER DEFAULT PRIVILEGES IN SCHEMA "drr" GRANT SELECT ON TABLES TO "tileserver" WITH GRANT OPTION;
ALTER DEFAULT PRIVILEGES IN SCHEMA "drr" GRANT SELECT ON TABLES TO "tileserver";


CREATE TABLE drr.hhr_input_data
(gdlcode text CONSTRAINT order_details_pk PRIMARY KEY,
max_t decimal,
hdi decimal,
working_age_pop decimal,
gnipc decimal,
vhi decimal,
pop_density decimal
);


GRANT EXECUTE ON FUNCTION drr.dynamic_subnational_hhr TO "tileserver";