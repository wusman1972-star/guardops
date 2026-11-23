-- Board 11869 part 1. RECONSTRUCTED, not lifted: guardops.checker_key is gone
-- from BOTH floors and appears nowhere in the repo, so its shape is taken from
-- the only surviving statement of it - the read inside checker_verify:
--   SELECT secret, digest INTO v_secret, v_digest
--     FROM guardops.checker_key WHERE key_id = 'active';
-- Three deliberate decisions, declared rather than slipped in:
--  (1) No account_id. The old read carries no account filter, so the key belongs
--      to the install, not to a house. Kept that way on purpose - see hole 845.
--  (2) digest is CHECKed to 'sha256'. checker_verify rejects anything whose MAC
--      is not 32 bytes, so a key with any other digest could never verify a
--      single pull. The check turns a silent dead end into a refused insert.
--  (3) The install mints its own secret here. No key is ever carried between
--      databases and nobody hands one out; each customer install gets its own
--      32 random bytes. Re-running the install leaves an existing key alone.

CREATE TABLE IF NOT EXISTS guardops.checker_key (
    key_id     text        NOT NULL,
    secret     bytea       NOT NULL,
    digest     text        NOT NULL DEFAULT 'sha256',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT checker_key_pkey      PRIMARY KEY (key_id),
    CONSTRAINT checker_key_digest_ck CHECK (digest = 'sha256'),
    CONSTRAINT checker_key_secret_ck CHECK (octet_length(secret) >= 32)
);

-- The key is the one object on this floor whose whole worth is who CANNOT read
-- it. Every door that needs it is SECURITY DEFINER and reads it as the owner,
-- so no customer-facing role needs any grant at all.
REVOKE ALL ON guardops.checker_key FROM PUBLIC;
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    EXECUTE 'REVOKE ALL ON guardops.checker_key FROM anon';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    EXECUTE 'REVOKE ALL ON guardops.checker_key FROM authenticated';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    EXECUTE 'REVOKE ALL ON guardops.checker_key FROM service_role';
  END IF;
END
$do$;

ALTER TABLE guardops.checker_key ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE guardops.checker_key IS
  'The install signing key. One row, key_id = active. Read only by SECURITY DEFINER doors (checker_verify); no customer-facing role holds a grant and RLS carries no policy. Minted per install - never copied between databases.';

INSERT INTO guardops.checker_key (key_id, secret, digest)
SELECT 'active', extensions.gen_random_bytes(32), 'sha256'
WHERE NOT EXISTS (SELECT 1 FROM guardops.checker_key WHERE key_id = 'active');
