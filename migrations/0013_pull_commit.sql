-- migrations/0013_pull_commit.sql

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
