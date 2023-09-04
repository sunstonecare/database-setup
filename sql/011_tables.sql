CREATE TABLE IF NOT EXISTS person
(
  id             INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS test_table
(
  id             INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  display_name   TEXT GENERATED ALWAYS AS (COALESCE(first_name || ' ' || last_name, first_name, last_name)) STORED,
  first_name     TEXT,
  last_name      TEXT
);

CREATE TABLE IF NOT exists test_2(
  id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY
);