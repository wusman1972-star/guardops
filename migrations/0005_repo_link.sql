-- migrations/0005_repo_link.sql

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
