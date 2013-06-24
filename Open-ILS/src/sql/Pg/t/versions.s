\set ECHO
\set QUIET 1
-- Turn off echo and keep things quiet.

-- Format the output for nice TAP.
\pset format unaligned
\pset tuples_only true
\pset pager

-- Revert all changes on failure.
\set ON_ERROR_ROLLBACK 1
\set ON_ERROR_STOP true
\set QUIET 1

-- Load the TAP functions.
BEGIN;

-- Plan the tests.
SELECT plan(2);

-- Run the tests.

SELECT CASE WHEN pg_version_num() >= 90000
    THEN pass('Running PostgreSQL 9+')
    ELSE fail('Not running PostgreSQL 9+')
END;

SELECT isnt_empty(
    'SELECT COUNT(*) FROM config.upgrade_log',
    'Have rows in config.upgrade_log'
);

-- Finish the tests and clean up.
SELECT * FROM finish();
ROLLBACK;
