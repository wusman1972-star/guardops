CREATE SEQUENCE IF NOT EXISTS guardops.customer_notice_id_seq AS bigint;

CREATE TABLE guardops.customer_notice (
  account_id   bigint      NOT NULL DEFAULT 1,
  id           bigint      NOT NULL DEFAULT nextval('guardops.customer_notice_id_seq'),
  customer_id  bigint      NOT NULL,
  database_id  bigint      NOT NULL,
  kind         text        NOT NULL,
  about        bigint,
  headline     text        NOT NULL,
  body         text        NOT NULL,
  state        text        NOT NULL DEFAULT 'NEW',
  held_why     text,
  made_at      timestamptz NOT NULL DEFAULT now(),
  made_by      text        NOT NULL DEFAULT SESSION_USER,
  sent_at      timestamptz,
  sent_to      text,
  request_id   bigint,
  send_error   text,
  delivered    boolean,
  reply_status integer,
  CONSTRAINT customer_notice_pkey             PRIMARY KEY (id),
  CONSTRAINT customer_notice_kind_check       CHECK (kind  = ANY (ARRAY['CHANGED'::text, 'WRITE'::text])),
  CONSTRAINT customer_notice_state_check      CHECK (state = ANY (ARRAY['NEW'::text, 'SENT'::text, 'HELD'::text, 'NO_WAY_TO_TELL'::text, 'FAILED'::text])),
  CONSTRAINT customer_notice_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES guardops.customer(id),
  CONSTRAINT customer_notice_database_id_fkey FOREIGN KEY (database_id) REFERENCES guardops.watched_database(id)
);

ALTER SEQUENCE guardops.customer_notice_id_seq OWNED BY guardops.customer_notice.id;

CREATE UNIQUE INDEX customer_notice_once ON guardops.customer_notice
  USING btree (customer_id, database_id, kind, COALESCE(about, 0::bigint));

CREATE INDEX customer_notice_waiting ON guardops.customer_notice
  USING btree (state, id)
  WHERE state = ANY (ARRAY['NEW'::text, 'HELD'::text]);
