#!/bin/bash
set -e

CURRENT_PATH=$(dirname $(realpath "$0"))
source "$CURRENT_PATH/.env"
DSN=$DATABASE_URL #default
CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"


run_psql() {
  psql -Atx "$DSN" -f "$1" -v ON_ERROR_STOP=1 >> db_init.log
}

create_schema_from_source() {
  echo "Creating database and running initialization scripts"
  for value in $(find "$CURRENT_PATH/sql/" -name "*.sql" | sort); do
    if [ -f "$value" ]; then
      run_psql "$value"
    fi
  done
  echo "Init done"
}

test_db() {
  echo "Running sql tests"
  ALL_FILES=""
  for value in $(find "$CURRENT_PATH/tests/" -type f \( -name "*.sql" \) | sort); do
    if [ -f "$value" ]; then
      ALL_FILES="$ALL_FILES -f $value"
    fi
  done
  echo $ALL_FILES
  psql -Atx "$DSN" "$ALL_FILES" --single-transaction -v ON_ERROR_STOP=1 >> db_init.log
  echo "Tests OK ${CHECK_MARK}"
}

create_schema_from_source
test_db