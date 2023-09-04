create table IF NOT EXISTS public._schema_versions (
    current_version character(14) not null UNIQUE,
    previous_version character(14) UNIQUE REFERENCES _schema_versions(current_version),
    constraint "_schema_versions_check" CHECK (current_version > previous_version)
);

CREATE UNIQUE INDEX IF NOT EXISTS i_schema_versions ON public._schema_versions USING btree (((previous_version IS NULL))) WHERE (previous_version IS NULL);
COMMENT ON TABLE public._schema_versions IS E'@omit';