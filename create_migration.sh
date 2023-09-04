#!/bin/bash

set -e
CURRENT_PATH=$(dirname $(realpath "$0"))
source "$CURRENT_PATH/.env"
DSN=$DATABASE_URL #default
RED='\033[0;31m'
NC='\033[0m' # No Color

# shellcheck disable=SC2162
if [ -z "$1" ]
then
    read -p "Enter migration name:" migration_name
else
    migration_name="$1"
fi

echo "Migrating local db before creating new migration:"
"$CURRENT_PATH"/bin/postgres_migrator --pg-url "$DSN" migrate
echo -e "\nGenerating new migration after local migration"
"$CURRENT_PATH"/bin/postgres_migrator generate "$migration_name"
NEW_MIGRATION="$CURRENT_PATH"/migrations/$(ls -t "$CURRENT_PATH"/migrations | head -1)

add_section() {
    echo -e "\n-- $1" >> "$NEW_MIGRATION"
    cat "$2" >> "$NEW_MIGRATION"
    echo "-- END $1" >> "$NEW_MIGRATION"
}

# Re add permissions if any
add_section "PERMISSIONS" "$CURRENT_PATH/sql/902_permissions.sql"

MD5_BEFORE_MIGRATION=$(psql -At service=local -c "select md5(string_agg(current_version || '.' || previous_version, ','))::text from _schema_versions ;" | head -n 1)

if [ -z "$MD5_BEFORE_MIGRATION" ] || [ "$MD5_BEFORE_MIGRATION" = "[NULL]" ]
then
    echo "MD5 is empty, local database not created from migration, bailing out! Migration file $NEW_MIGRATION not deleted"
    exit 1
fi

cat <<EOT >> "$NEW_MIGRATION"

-- VERIFICATION
DO
\$\$
  DECLARE
    new_m5 TEXT;

  BEGIN
    new_m5:= (SELECT MD5(STRING_AGG(current_version || '.' || previous_version, ','))::TEXT FROM _schema_versions);

    ASSERT new_m5 ='$MD5_BEFORE_MIGRATION', format('MD5 of migrations: $MD5_BEFORE_MIGRATION does not equal %s, something fishy is going on, aborting.', new_m5);
  END
\$\$ LANGUAGE plpgsql;
-- END VERIFICATION
EOT

if rg -i "DROP TABLE" "$NEW_MIGRATION" >/dev/null; then
    echo "${RED}New migration contains DROP table, make sure you know what you are doing!${NC}"
fi

git add "$NEW_MIGRATION"
