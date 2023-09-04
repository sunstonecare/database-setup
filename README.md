# Sunstone database setup demo repo
This is a demo repo for setting up a postgres database the Sunstone way.

1: Running `run.sh` is used for setting up a local db and running tests.
2: `create_migrations.sh` is used for generating migrations based on the schema changes made.
3: All tables created will have shadow logging in the shadow schema.

We use CI to check that migrations have been added and that there are no differences between the schema 
and the migrations. `bin/posgres_migrator` has some diff abilities and is used behind the scenes to create migrations.

We have also added a MD5 check to make sure that a migration is not run if the history is not complete.