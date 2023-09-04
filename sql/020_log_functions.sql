-- Some of the following code was originally copied from http://lloyd.thealbins.com/ShadowTablesVersPGAudit
-- And have been altered to fit Sunstone´s needs
-- public.get_person_id() is sunstone specific and returns current user id

-- This is our implementation, and the claims are set by postgraphile (https://www.graphile.org/postgraphile/)
-- CREATE OR REPLACE FUNCTION get_person_id() RETURNS integer AS
-- $$
-- SELECT CASE WHEN NOT is_numeric(CURRENT_SETTING('jwt.claims.user_id', TRUE)) THEN NULL
--             ELSE (SELECT NULLIF(CURRENT_SETTING('jwt.claims.user_id', TRUE), ''))::INTEGER END
-- $$ LANGUAGE sql
-- IMMUTABLE;

-- For demo purposes this always returns 1
CREATE OR REPLACE FUNCTION get_person_id() RETURNS integer AS
$$
  SELECT 1;
$$ LANGUAGE sql
IMMUTABLE;

CREATE OR REPLACE FUNCTION public.shadow() RETURNS TRIGGER AS
$$
DECLARE
  shadow_schema TEXT;
  shadow_table  TEXT;
BEGIN
  IF (TG_NARGS <> 2) THEN
    RAISE EXCEPTION 'Incorrect number of arguments for shadow_function(schema, table): %', TG_NARGS;
  END IF;

  shadow_schema = TG_ARGV[0];
  shadow_table = TG_ARGV[1];
  IF TG_OP IN ('INSERT', 'UPDATE') AND TG_LEVEL = 'ROW' THEN
    EXECUTE 'INSERT INTO ' || QUOTE_IDENT(shadow_schema) || '.' || QUOTE_IDENT(shadow_table) ||
            ' SELECT public.get_person_id(), $2 , now(), $1.*' USING TG_OP, NEW;
    RETURN NEW;
  ELSIF TG_OP IN ('INSERT', 'UPDATE') AND TG_LEVEL = 'STATEMENT' THEN

    -- Add exemptions here
    -- IF shadow_schema = 'client_shadow' THEN
    --   PERFORM * FROM client c, new_table o WHERE c.id=o.client_id;
    --   IF NOT FOUND THEN RETURN OLD; END IF;
    -- END IF;

    -- IF shadow_schema = 'institution_shadow' THEN      
    --   PERFORM * FROM institution i, new_table o WHERE i.id=o.institution_id;
    --   IF NOT FOUND THEN RETURN OLD; END IF;
    -- END IF;
    
    EXECUTE 'INSERT INTO ' || QUOTE_IDENT(shadow_schema) || '.' || QUOTE_IDENT(shadow_table) ||
            ' SELECT public.get_person_id(), $1 , now(), n.* FROM new_table n' USING TG_OP;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' AND TG_LEVEL = 'ROW' THEN
    EXECUTE 'INSERT INTO ' || QUOTE_IDENT(shadow_schema) || '.' || QUOTE_IDENT(shadow_table) ||
            ' SELECT public.get_person_id(), $2 , now(), $1.*' USING TG_OP, OLD;
    RETURN OLD;
  ELSIF TG_OP = 'DELETE' AND TG_LEVEL = 'STATEMENT' THEN

    -- Add exemptions here
    -- IF shadow_schema = 'client_shadow' THEN
    --   PERFORM * FROM client c, old_table o WHERE c.id=o.client_id;
    --   IF NOT FOUND THEN RETURN OLD; END IF;
    -- END IF;

    -- IF shadow_schema = 'institution_shadow' THEN      
    --   PERFORM * FROM institution i, old_table o WHERE i.id=o.institution_id;
    --   IF NOT FOUND THEN RETURN OLD; END IF;
    -- END IF;

    IF shadow_table = 'institution' THEN 
      PERFORM * FROM institution i, old_table o WHERE i.id=o.id;
      IF NOT FOUND THEN RETURN OLD; END IF;
    END IF;
        
    EXECUTE 'INSERT INTO ' || QUOTE_IDENT(shadow_schema) || '.' || QUOTE_IDENT(shadow_table) ||
            ' SELECT public.get_person_id(), $1 , now(), o.* FROM old_table o' USING TG_OP;

    RETURN OLD;
  ELSIF TG_OP = 'TRUNCATE' THEN
    EXECUTE 'INSERT INTO ' || QUOTE_IDENT(shadow_schema) || '.' || QUOTE_IDENT(shadow_table) ||
            ' (shadow_person_id, action, action_time) VALUES (public.get_person_id(), $1 , now())' USING TG_OP;
    RETURN NULL;
  END IF;

  RETURN NEW;
END;
$$
  LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION public.add_shadow(
  source_schema NAME,
  source_table NAME,
  shadow_schema NAME = NULL::NAME,
  shadow_table NAME = NULL::NAME
)
  RETURNS VOID AS
$$
DECLARE
  r           RECORD;
  version     RECORD;
  trigger_def RECORD;
BEGIN
  IF source_schema IS NULL THEN
    RAISE EXCEPTION 'Must specify source schema: add_shadow(source_schema, source_table, shadow_schema, shadow_table)';
  END IF;
  IF source_table IS NULL THEN
    RAISE EXCEPTION 'Must specify source table: add_shadow(source_schema, source_table, shadow_schema, shadow_table)';
  END IF;
  IF shadow_schema IS NULL THEN
    shadow_schema := source_schema;
  END IF;
  IF shadow_table IS NULL THEN
    shadow_table := source_table || '_s';
  END IF;

  -- Check to see if source table already exists
  SELECT table_schema, table_name INTO r
  FROM information_schema.tables
  WHERE table_schema = source_schema AND table_name = source_table;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Source Table must exist (%.%)', source_schema, source_table;
  END IF;

  -- Check to see if shadow table already exists
  SELECT table_schema, table_name INTO r
  FROM information_schema.tables   
  WHERE table_schema = shadow_schema AND table_name = shadow_table;

  IF FOUND THEN
    RAISE NOTICE 'Shadow Table already exist (%.%)', shadow_schema, shadow_table;
  END IF;

  -- Check to see if triggers already exist
  -- Need to check the object source because the same trigger name may exist more than once in a schema if applied to different tables.
  SELECT trigger_schema, trigger_name
  INTO r
  FROM information_schema.triggers
  WHERE trigger_schema = source_schema
    AND trigger_name IN (LOWER(source_table) || '_tsi', 
                         LOWER(source_table) || '_tsu', 
                         LOWER(source_table) || '_tsd',
                         LOWER(source_table) || '_tss')
    AND event_object_schema = source_schema
    AND event_object_table = source_table;

  IF FOUND THEN
    RAISE EXCEPTION 'Trigger already exist (%.%)', r.trigger_schema, r.trigger_name;
  END IF;

  -- Create Shadow Table
  EXECUTE 'CREATE TABLE ' || QUOTE_IDENT(shadow_schema) || '.' || QUOTE_IDENT(shadow_table) ||
          ' AS SELECT NULL::INT AS shadow_person_id, ''INSERT''::varchar AS action, now() AS action_time, * FROM ' ||
          QUOTE_IDENT(source_schema) || '.' || QUOTE_IDENT(source_table);

  EXECUTE 'ALTER TABLE ' || QUOTE_IDENT(shadow_schema) || '.' || QUOTE_IDENT(shadow_table) ||
          ' ADD CONSTRAINT ' || shadow_table || '_person_id FOREIGN KEY (shadow_person_id) REFERENCES public.person (id)' ||
          ' ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;';

  IF source_schema IN ('institution', 'client') THEN
    EXECUTE format('ALTER TABLE %I.%I ADD CONSTRAINT %s_%s_id FOREIGN KEY (%s_id) REFERENCES public.%s (id) ON DELETE CASCADE;',
      shadow_schema, shadow_table, shadow_table, source_schema, source_schema, source_schema);

    EXECUTE format('CREATE INDEX ON %I.%I (%s_id)', shadow_schema, shadow_table, source_schema);
  END IF;

  -- Add Triggers
  EXECUTE 'CREATE TRIGGER ' || LOWER(source_table) || '_tsi AFTER INSERT ON ' || QUOTE_IDENT(source_schema) || '.' ||
          QUOTE_IDENT(source_table) ||
          ' REFERENCING NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE PROCEDURE public.shadow(' ||
          QUOTE_LITERAL(shadow_schema) || ', ' || QUOTE_LITERAL(shadow_table) || ')';

  EXECUTE 'CREATE TRIGGER ' || LOWER(source_table) || '_tsu AFTER UPDATE ON ' || QUOTE_IDENT(source_schema) || '.' ||
          QUOTE_IDENT(source_table) ||
          ' REFERENCING OLD TABLE AS old_table NEW TABLE AS new_table FOR EACH STATEMENT EXECUTE PROCEDURE public.shadow(' ||
          QUOTE_LITERAL(shadow_schema) || ', ' || QUOTE_LITERAL(shadow_table) || ')';

  EXECUTE 'CREATE TRIGGER ' || LOWER(source_table) || '_tsd AFTER DELETE ON ' || QUOTE_IDENT(source_schema) || '.' ||
          QUOTE_IDENT(source_table) ||
          ' REFERENCING OLD TABLE AS old_table FOR EACH STATEMENT EXECUTE PROCEDURE public.shadow(' ||
          QUOTE_LITERAL(shadow_schema) || ', ' || QUOTE_LITERAL(shadow_table) || ')';

  EXECUTE 'CREATE TRIGGER ' || LOWER(source_table) || '_tss BEFORE TRUNCATE ON ' || QUOTE_IDENT(source_schema) ||
          '.' || QUOTE_IDENT(source_table) || ' FOR EACH STATEMENT EXECUTE PROCEDURE public.shadow(' ||
          QUOTE_LITERAL(shadow_schema) || ', ' || QUOTE_LITERAL(shadow_table) || ')';

  --EXECUTE 'CREATE INDEX ON ' || quote_ident(shadow_schema) || '.' || quote_ident(shadow_table) ||
  --        ' USING btree (id, action_time DESC);';
END;
$$
  LANGUAGE 'plpgsql';

--
CREATE OR REPLACE FUNCTION add_shadow_to_all_tables() RETURNS VOID AS
$$
DECLARE
  shadow_schema TEXT;
  shadow_table  TEXT;
  local_schema  TEXT;
BEGIN
  FOR shadow_schema, shadow_table IN SELECT table_schema, table_name
                                     FROM information_schema.tables
                                     WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
                                       AND table_schema NOT LIKE 'pg_toast%'
                                       AND table_schema NOT LIKE '%shadow%'
                                       AND table_schema NOT LIKE '%cron%'
                                       AND table_name <> '_schema_versions'
                                       AND table_type = 'BASE TABLE'
    LOOP
      local_schema := 'shadow';
      IF shadow_schema != 'public' THEN
        local_schema := shadow_schema || '_shadow';
        PERFORM schema_name FROM information_schema.schemata WHERE schema_name = local_schema;
        IF NOT FOUND THEN
          EXECUTE 'CREATE SCHEMA IF NOT EXISTS ' || local_schema;
        END IF;
      END IF;

      PERFORM FROM information_schema.tables WHERE table_schema = local_schema AND table_name = shadow_table;
      IF NOT FOUND THEN
        PERFORM add_shadow(shadow_schema, shadow_table, local_schema, shadow_table);
      END IF;
    END LOOP;

END
$$ LANGUAGE plpgsql;

