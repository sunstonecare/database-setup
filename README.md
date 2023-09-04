# Sunstone database setup demo repo
This is a demo repo for setting up a postgres database the Sunstone way.

1: Running `run.sh` is used for setting up a local db and running tests.
2: `create_migrations.sh` is used for generating migrations based on the schema changes made.
3: All tables created will have shadow logging in the shadow schema.