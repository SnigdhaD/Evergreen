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
SELECT plan(27);

-- Run the tests.
SELECT has_schema('action','Has action schema'); 
SELECT has_schema('action_trigger','Has action_trigger schema'); 
SELECT has_schema('actor','Has actor schema');
SELECT has_schema('acq','Has acq schema'); 
SELECT has_schema('asset','Has actor schema');
SELECT has_schema('auditor','Has auditor schema'); 
SELECT has_schema('authority','Has authority schema'); 
SELECT has_schema('biblio','Has biblio schema'); 
SELECT has_schema('booking','Has booking schema'); 
SELECT has_schema('config','Has config schema'); 
SELECT has_schema('container','Has container schema'); 
SELECT has_schema('evergreen','Has evergreen schema'); 
SELECT has_schema('extend_reporter','Has extend_reporter schema'); 
SELECT has_schema('metabib','Has metabib schema'); 
SELECT has_schema('money','Has money schema'); 
SELECT has_schema('offline','Has offline schema'); 
SELECT has_schema('permission','Has permission schema'); 
SELECT has_schema('public','Has public schema'); 
SELECT has_schema('query','Has query schema'); 
SELECT has_schema('reporter','Has reporter schema'); 
SELECT has_schema('search','Has search schema'); 
SELECT has_schema('serial','Has serial schema'); 
SELECT has_schema('staging','Has staging schema'); 
SELECT has_schema('stats','Has stats schema'); 
SELECT has_schema('url_verify','Has url_verify schema'); 
SELECT has_schema('vandelay','Has vandelay schema'); 
SELECT has_schema('unapi','Has unapi schema'); 

-- Finish the tests and clean up.
SELECT * FROM finish();
ROLLBACK;
