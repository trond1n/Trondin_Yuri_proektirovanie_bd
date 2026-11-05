-- FOOD-109

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'inspector') THEN
        CREATE ROLE inspector LOGIN PASSWORD 'NetoSQL2025';
    ELSE
        ALTER ROLE inspector WITH LOGIN PASSWORD 'NetoSQL2025';
    END IF;
END $$;

GRANT ALL PRIVILEGES ON SCHEMA trondin_food TO inspector;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA trondin_food TO inspector;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA trondin_food TO inspector;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA trondin_food TO inspector;

GRANT USAGE ON SCHEMA exts TO inspector;
GRANT USAGE ON SCHEMA information_schema TO inspector;
GRANT USAGE ON SCHEMA pg_catalog TO inspector;
