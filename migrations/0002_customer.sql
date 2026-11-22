-- migrations/0002_customer.sql

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
