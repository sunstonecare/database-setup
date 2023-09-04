CREATE TYPE test_target AS
(
  first_name TEXT, last_name TEXT
);

CREATE OR REPLACE FUNCTION insert_test_data(client_id INT, max_sessions INT, start_date timestamptz) RETURNS VOID AS
$$
DECLARE
  targets test_target[] = ARRAY [('Rolf', 'Pettersen')::test_target, ('Eivind', 'Sjønes')::test_target]::test_target[]
  current_target test_target
BEGIN
    FOREACH current_target IN ARRAY targets
    LOOP
      INSERT INTO test_table (first_name, last_name) VALUES (current_target.first_name, current_target.last_name);
    END LOOP;
END
$$ LANGUAGE plpgsql;

SAVEPOINT insert_test_data;
DO
$$
  BEGIN
    PERFORM insert_test_data();
  END;
$$;
