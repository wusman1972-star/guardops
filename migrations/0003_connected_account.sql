-- migrations/0003_connected_account.sql

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
