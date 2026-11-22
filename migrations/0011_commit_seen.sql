-- migrations/0011_commit_seen.sql

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
