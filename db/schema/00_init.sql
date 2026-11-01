-- FOOD-101
CREATE SCHEMA IF NOT EXISTS exts;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA exts;
DROP SCHEMA IF EXISTS trondin_food CASCADE; -- для дропа ошибок при тестах
CREATE SCHEMA trondin_food;