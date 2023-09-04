------ TEMPLATE -----
-- SAVEPOINT XXXXXXXXX;
-- DO
-- $$
--   BEGIN
--   END
-- $$ LANGUAGE plpgsql;
-- ROLLBACK TO SAVEPOINT XXXXXXXXX;

SAVEPOINT test_computed_column;
DO
$$
  BEGIN
    ASSERT (select display_name from test_table where first_name = 'Eivind') = 'Eivind Sjønes', 'Should have a computed full display name';
  END
$$ LANGUAGE plpgsql;
ROLLBACK TO SAVEPOINT test_computed_column;
