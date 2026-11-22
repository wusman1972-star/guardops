-- migrations/0001_core_thirteen.sql
-- Thirteen core tables for guardops schema.
-- Source of truth: Supabase project lauttgnmksnxohigaqee, schema guardops.
-- Structure only: columns, types, defaults, identity, sequences, PKs, FKs,
-- unique/check constraints, indexes. No triggers, views, RLS, grants, seed rows.

CREATE SCHEMA guardops;

-- Sequences used as column defaults (not identity columns)
CREATE SEQUENCE guardops.commit_seen_id_seq;
CREATE SEQUENCE guardops.connected_account_id_seq;
CREATE SEQUENCE guardops.repo_link_id_seq;
CREATE SEQUENCE guardops.shape_picture_id_seq;
CREATE SEQUENCE guardops.watched_database_id_seq;

-- Stub so DEFAULT guardops.current_account() compiles.
-- The real implementation is deployed separately.
CREATE FUNCTION guardops.current_account()
    RETURNS bigint LANGUAGE sql STABLE
    AS $$ SELECT 1::bigint $$;

-- 1. account
CREATE TABLE guardops.account (
    id            bigint      GENERATED ALWAYS AS IDENTITY,
    name          text        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    repos_allowed integer     NOT NULL DEFAULT 1,
    CONSTRAINT account_pkey                PRIMARY KEY (id),
    CONSTRAINT account_name_nonblank       CHECK (length(btrim(name)) > 0),
    CONSTRAINT account_repos_allowed_check CHECK (repos_allowed >= 1)
);

-- 2. customer
CREATE TABLE guardops.customer (
    account_id           bigint      NOT NULL DEFAULT 1,
    id                   bigint      GENERATED ALWAYS AS IDENTITY,
    provider             text        NOT NULL DEFAULT 'supabase',
    external_id          text        NOT NULL,
    email                text,
    first_seen           timestamptz NOT NULL DEFAULT now(),
    last_seen            timestamptz,
    is_founder           boolean     NOT NULL DEFAULT false,
    seen_how_it_works_at timestamptz,
    CONSTRAINT customer_pkey                     PRIMARY KEY (id),
    CONSTRAINT customer_provider_external_id_key UNIQUE (provider, external_id)
);

-- 3. connected_account
CREATE TABLE guardops.connected_account (
    account_id        bigint      NOT NULL DEFAULT guardops.current_account(),
    id                bigint      NOT NULL DEFAULT nextval('guardops.connected_account_id_seq'),
    provider          text        NOT NULL DEFAULT 'supabase',
    org_slug          text,
    approved_at       timestamptz NOT NULL DEFAULT now(),
    token_secret_name text        NOT NULL,
    status            text        NOT NULL DEFAULT 'ACTIVE',
    expires_at        timestamptz,
    customer_id       bigint,
    CONSTRAINT connected_account_pkey PRIMARY KEY (id)
);

-- 4. watched_database
CREATE TABLE guardops.watched_database (
    account_id           bigint      NOT NULL DEFAULT guardops.current_account(),
    id                   bigint      NOT NULL DEFAULT nextval('guardops.watched_database_id_seq'),
    label                text        NOT NULL,
    secret_name          text,
    status               text        NOT NULL DEFAULT 'ACTIVE',
    created_by           text        NOT NULL DEFAULT SESSION_USER,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    connect_mode         text        NOT NULL DEFAULT 'CONNECTION',
    project_ref          text,
    connected_account_id bigint,
    is_test              boolean     NOT NULL DEFAULT false,
    CONSTRAINT watched_database_pkey             PRIMARY KEY (id),
    CONSTRAINT watched_database_signin_known     FOREIGN KEY (connected_account_id) REFERENCES guardops.connected_account (id),
    CONSTRAINT watched_database_mode_known       CHECK (connect_mode = ANY (ARRAY['CONNECTION'::text, 'SIGNED'::text])),
    CONSTRAINT watched_database_one_way_in       CHECK (
        ((connect_mode = 'CONNECTION'::text) AND (secret_name IS NOT NULL))
        OR ((connect_mode = 'SIGNED'::text) AND (project_ref IS NOT NULL) AND (connected_account_id IS NOT NULL))
    ),
    CONSTRAINT watched_database_project_ref_shape CHECK ((project_ref IS NULL) OR (project_ref ~ '^[a-z0-9]{20}$'::text))
);

-- 5. repo_link
CREATE TABLE guardops.repo_link (
    account_id bigint      NOT NULL DEFAULT guardops.current_account(),
    id         bigint      NOT NULL DEFAULT nextval('guardops.repo_link_id_seq'),
    repo       text        NOT NULL,
    branch     text        NOT NULL,
    linked_at  timestamptz NOT NULL DEFAULT now(),
    linked_by  text        NOT NULL,
    active     boolean     NOT NULL DEFAULT false,
    CONSTRAINT repo_link_pkey            PRIMARY KEY (id),
    CONSTRAINT repo_link_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id),
    CONSTRAINT repo_link_repo_branch_key UNIQUE (account_id, repo, branch)
);

-- composite-FK target for repo_pull and commit_seen
CREATE UNIQUE INDEX repo_link_id_account_key
    ON guardops.repo_link USING btree (id, account_id);

CREATE UNIQUE INDEX repo_link_one_active_idx
    ON guardops.repo_link USING btree (account_id)
    WHERE active;

-- 6. repo_pull
CREATE TABLE guardops.repo_pull (
    account_id    bigint      NOT NULL DEFAULT guardops.current_account(),
    id            bigint      GENERATED BY DEFAULT AS IDENTITY,
    repo_link_id  bigint      NOT NULL,
    opened_at     timestamptz NOT NULL DEFAULT now(),
    closed_at     timestamptz,
    pulled_by     text        NOT NULL DEFAULT SESSION_USER,
    head_sha      text,
    oldest_sha    text,
    prev_head_sha text,
    commits_new   integer,
    kind          text,
    proof_status  text        NOT NULL DEFAULT 'OPEN',
    signature     text,
    abort_reason  text,
    CONSTRAINT repo_pull_pkey                   PRIMARY KEY (id),
    CONSTRAINT repo_pull_account_id_fkey        FOREIGN KEY (account_id) REFERENCES guardops.account (id),
    CONSTRAINT repo_pull_repo_link_id_fkey      FOREIGN KEY (repo_link_id) REFERENCES guardops.repo_link (id),
    CONSTRAINT repo_pull_repo_link_id_acct_fkey FOREIGN KEY (repo_link_id, account_id) REFERENCES guardops.repo_link (id, account_id),
    CONSTRAINT repo_pull_kind_check             CHECK ((kind IS NULL) OR (kind = ANY (ARRAY['FIRST'::text, 'FORWARD'::text, 'FORCE_PUSH'::text, 'LEGACY'::text]))),
    CONSTRAINT repo_pull_proof_status_check     CHECK (proof_status = ANY (ARRAY['OPEN'::text, 'PROVEN'::text, 'UNPROVEN'::text, 'ABORTED'::text]))
);

-- composite-FK target for commit_seen and pull_commit
CREATE UNIQUE INDEX repo_pull_id_account_key
    ON guardops.repo_pull USING btree (id, account_id);

CREATE UNIQUE INDEX repo_pull_one_open_per_link
    ON guardops.repo_pull USING btree (repo_link_id)
    WHERE (proof_status = 'OPEN'::text);

-- 7. shape_picture
CREATE TABLE guardops.shape_picture (
    account_id   bigint      NOT NULL DEFAULT guardops.current_account(),
    id           bigint      NOT NULL DEFAULT nextval('guardops.shape_picture_id_seq'),
    database_id  bigint      NOT NULL,
    taken_at     timestamptz NOT NULL DEFAULT now(),
    taken_by     text        NOT NULL DEFAULT SESSION_USER,
    object_count integer     NOT NULL DEFAULT 0,
    source       text        NOT NULL DEFAULT 'CONNECTION',
    state        text        NOT NULL DEFAULT 'DONE',
    request_id   bigint,
    failed_why   text,
    judged_at    timestamptz,
    kind         text,
    CONSTRAINT shape_picture_pkey             PRIMARY KEY (id),
    CONSTRAINT shape_picture_database_id_fkey FOREIGN KEY (database_id) REFERENCES guardops.watched_database (id),
    CONSTRAINT shape_picture_source_known     CHECK (source = ANY (ARRAY['CONNECTION'::text, 'SIGNED'::text])),
    CONSTRAINT shape_picture_state_known      CHECK (state = ANY (ARRAY['PENDING'::text, 'DONE'::text, 'FAILED'::text]))
);

-- 8. shape_object  (no primary key on source floor)
CREATE TABLE guardops.shape_object (
    account_id   bigint NOT NULL DEFAULT guardops.current_account(),
    picture_id   bigint NOT NULL,
    schema_name  text   NOT NULL,
    object_name  text   NOT NULL,
    object_kind  text   NOT NULL,
    column_shape jsonb  NOT NULL,
    row_estimate bigint,
    bytes        bigint,
    CONSTRAINT shape_object_picture_id_fkey FOREIGN KEY (picture_id) REFERENCES guardops.shape_picture (id)
);

CREATE INDEX shape_object_by_picture
    ON guardops.shape_object USING btree (picture_id);

-- 9. shape_change
CREATE TABLE guardops.shape_change (
    account_id      bigint      NOT NULL DEFAULT guardops.current_account(),
    id              bigint      GENERATED ALWAYS AS IDENTITY,
    database_id     bigint      NOT NULL,
    picture_id      bigint      NOT NULL,
    prev_picture_id bigint      NOT NULL,
    change_kind     text        NOT NULL,
    schema_name     text        NOT NULL,
    object_name     text        NOT NULL,
    object_kind     text,
    noticed_at      timestamptz NOT NULL DEFAULT now(),
    noticed_by      text        NOT NULL DEFAULT SESSION_USER,
    CONSTRAINT shape_change_pkey    PRIMARY KEY (id),
    CONSTRAINT shape_change_once    UNIQUE (picture_id, change_kind, schema_name, object_name),
    CONSTRAINT shape_change_kind_ck CHECK (change_kind = ANY (ARRAY['APPEARED'::text, 'GONE'::text, 'COLUMNS'::text]))
);

CREATE INDEX shape_change_database_idx
    ON guardops.shape_change USING btree (database_id);

CREATE INDEX shape_change_picture_idx
    ON guardops.shape_change USING btree (picture_id);

-- 10. write_record
CREATE TABLE guardops.write_record (
    account_id   bigint      NOT NULL DEFAULT 1,
    id           bigint      GENERATED ALWAYS AS IDENTITY,
    database_id  bigint      NOT NULL,
    their_id     bigint      NOT NULL,
    seen_at      timestamptz NOT NULL,
    table_name   text        NOT NULL,
    operation    text        NOT NULL,
    rows_touched bigint      NOT NULL,
    CONSTRAINT write_record_pkey                     PRIMARY KEY (id),
    CONSTRAINT write_record_database_id_their_id_key UNIQUE (database_id, their_id)
);

CREATE INDEX write_record_by_time
    ON guardops.write_record USING btree (database_id, seen_at DESC);

-- 11. commit_seen
CREATE TABLE guardops.commit_seen (
    account_id    bigint      NOT NULL DEFAULT guardops.current_account(),
    id            bigint      NOT NULL DEFAULT nextval('guardops.commit_seen_id_seq'),
    repo_link_id  bigint      NOT NULL,
    repo          text        NOT NULL,
    sha           text        NOT NULL,
    author        text,
    committed_at  timestamptz,
    message       text,
    files         jsonb       NOT NULL DEFAULT '{}'::jsonb,
    seen_at       timestamptz NOT NULL DEFAULT now(),
    first_pull_id bigint      NOT NULL,
    CONSTRAINT commit_seen_pkey                    PRIMARY KEY (id),
    CONSTRAINT commit_seen_account_id_fkey         FOREIGN KEY (account_id) REFERENCES guardops.account (id),
    CONSTRAINT commit_seen_repo_link_id_fkey       FOREIGN KEY (repo_link_id) REFERENCES guardops.repo_link (id),
    CONSTRAINT commit_seen_repo_link_id_acct_fkey  FOREIGN KEY (repo_link_id, account_id) REFERENCES guardops.repo_link (id, account_id),
    CONSTRAINT commit_seen_first_pull_id_fkey      FOREIGN KEY (first_pull_id) REFERENCES guardops.repo_pull (id),
    CONSTRAINT commit_seen_first_pull_id_acct_fkey FOREIGN KEY (first_pull_id, account_id) REFERENCES guardops.repo_pull (id, account_id),
    CONSTRAINT commit_seen_link_sha_key            UNIQUE (repo_link_id, sha),
    CONSTRAINT commit_seen_files_object            CHECK (jsonb_typeof(files) = 'object'::text),
    CONSTRAINT commit_seen_files_strings           CHECK (NOT jsonb_path_exists(files, 'strict $.*?(@.type() != "string")'::jsonpath))
);

-- composite-FK target for pull_commit
CREATE UNIQUE INDEX commit_seen_id_account_key
    ON guardops.commit_seen USING btree (id, account_id);

-- 12. commit_object
CREATE TABLE guardops.commit_object (
    account_id     bigint      NOT NULL DEFAULT guardops.current_account(),
    commit_seen_id bigint      NOT NULL,
    repo_link_id   bigint      NOT NULL,
    committed_at   timestamptz,
    file_key       text        NOT NULL,
    is_delete      boolean     NOT NULL,
    obj_lines      text,
    built_at       timestamptz NOT NULL DEFAULT now(),
    created_by     text        NOT NULL DEFAULT 'CODE:0134'::text,
    CONSTRAINT commit_object_pk                  PRIMARY KEY (commit_seen_id, file_key),
    CONSTRAINT commit_object_account_id_fkey     FOREIGN KEY (account_id) REFERENCES guardops.account (id),
    CONSTRAINT commit_object_commit_seen_id_fkey FOREIGN KEY (commit_seen_id) REFERENCES guardops.commit_seen (id) ON DELETE CASCADE
);

CREATE INDEX commit_object_file_lookup
    ON guardops.commit_object USING btree (account_id, repo_link_id, file_key, committed_at DESC);

CREATE INDEX commit_object_obj_lookup
    ON guardops.commit_object USING btree (account_id, repo_link_id, committed_at DESC)
    WHERE (obj_lines IS NOT NULL);

-- 13. pull_commit
CREATE TABLE guardops.pull_commit (
    pull_id        bigint NOT NULL,
    commit_seen_id bigint NOT NULL,
    account_id     bigint NOT NULL DEFAULT guardops.current_account(),
    CONSTRAINT pull_commit_pkey                     PRIMARY KEY (pull_id, commit_seen_id),
    CONSTRAINT pull_commit_account_id_fkey          FOREIGN KEY (account_id) REFERENCES guardops.account (id),
    CONSTRAINT pull_commit_commit_seen_id_fkey      FOREIGN KEY (commit_seen_id) REFERENCES guardops.commit_seen (id),
    CONSTRAINT pull_commit_commit_seen_id_acct_fkey FOREIGN KEY (commit_seen_id, account_id) REFERENCES guardops.commit_seen (id, account_id),
    CONSTRAINT pull_commit_pull_id_fkey             FOREIGN KEY (pull_id) REFERENCES guardops.repo_pull (id),
    CONSTRAINT pull_commit_pull_id_acct_fkey        FOREIGN KEY (pull_id, account_id) REFERENCES guardops.repo_pull (id, account_id)
);

CREATE INDEX pull_commit_commit_seen_id
    ON guardops.pull_commit USING btree (commit_seen_id);
