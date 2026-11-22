-- migrations/0012_commit_object.sql

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
