-- =================================================================
-- FORWARD: drop 63 clean cut tables (board 11401, 2026-11-18)
-- BEFORE: 161 tables, 803 triggers, 498 functions
-- =================================================================

-- ===  FORWARD SECTION  ===

SELECT guardops.destroy_unlock_add('guardops.law_group', 'board 11401', 30);
DROP TABLE guardops.law_group CASCADE;

SELECT guardops.destroy_unlock_add('guardops.law_group_member', 'board 11401', 30);
DROP TABLE guardops.law_group_member CASCADE;

SELECT guardops.destroy_unlock_add('guardops.laws_served', 'board 11401', 30);
DROP TABLE guardops.laws_served CASCADE;

SELECT guardops.destroy_unlock_add('guardops.look_taken', 'board 11401', 30);
DROP TABLE guardops.look_taken CASCADE;

SELECT guardops.destroy_unlock_add('guardops.batch_freeze', 'board 11401', 30);
DROP TABLE guardops.batch_freeze CASCADE;

SELECT guardops.destroy_unlock_add('guardops.batch_page_read', 'board 11401', 30);
DROP TABLE guardops.batch_page_read CASCADE;

SELECT guardops.destroy_unlock_add('guardops.batch_read', 'board 11401', 30);
DROP TABLE guardops.batch_read CASCADE;

SELECT guardops.destroy_unlock_add('guardops.handoff_check_whitelist', 'board 11401', 30);
DROP TABLE guardops.handoff_check_whitelist CASCADE;

SELECT guardops.destroy_unlock_add('guardops.handoff_floor_claim', 'board 11401', 30);
DROP TABLE guardops.handoff_floor_claim CASCADE;

SELECT guardops.destroy_unlock_add('guardops.press_taint', 'board 11401', 30);
DROP TABLE guardops.press_taint CASCADE;

SELECT guardops.destroy_unlock_add('guardops.seat_ask', 'board 11401', 30);
DROP TABLE guardops.seat_ask CASCADE;

SELECT guardops.destroy_unlock_add('guardops.retire_ask', 'board 11401', 30);
DROP TABLE guardops.retire_ask CASCADE;

SELECT guardops.destroy_unlock_add('guardops.fire_attestation_used', 'board 11401', 30);
DROP TABLE guardops.fire_attestation_used CASCADE;

SELECT guardops.destroy_unlock_add('guardops.fire_fetch_meta', 'board 11401', 30);
DROP TABLE guardops.fire_fetch_meta CASCADE;

SELECT guardops.destroy_unlock_add('guardops.fire_pass', 'board 11401', 30);
DROP TABLE guardops.fire_pass CASCADE;

SELECT guardops.destroy_unlock_add('guardops.fire_review', 'board 11401', 30);
DROP TABLE guardops.fire_review CASCADE;

SELECT guardops.destroy_unlock_add('guardops.fire_review_request', 'board 11401', 30);
DROP TABLE guardops.fire_review_request CASCADE;

SELECT guardops.destroy_unlock_add('guardops.fire_review_scan', 'board 11401', 30);
DROP TABLE guardops.fire_review_scan CASCADE;

SELECT guardops.destroy_unlock_add('guardops.order_amendment', 'board 11401', 30);
DROP TABLE guardops.order_amendment CASCADE;

SELECT guardops.destroy_unlock_add('guardops.order_end', 'board 11401', 30);
DROP TABLE guardops.order_end CASCADE;

SELECT guardops.destroy_unlock_add('guardops.order_file_seen', 'board 11401', 30);
DROP TABLE guardops.order_file_seen CASCADE;

SELECT guardops.destroy_unlock_add('guardops.order_hold', 'board 11401', 30);
DROP TABLE guardops.order_hold CASCADE;

SELECT guardops.destroy_unlock_add('guardops.order_queue', 'board 11401', 30);
DROP TABLE guardops.order_queue CASCADE;

SELECT guardops.destroy_unlock_add('guardops.order_tally', 'board 11401', 30);
DROP TABLE guardops.order_tally CASCADE;

SELECT guardops.destroy_unlock_add('guardops.phone_menu_press', 'board 11401', 30);
DROP TABLE guardops.phone_menu_press CASCADE;

SELECT guardops.destroy_unlock_add('guardops.phone_menu_sent', 'board 11401', 30);
DROP TABLE guardops.phone_menu_sent CASCADE;

SELECT guardops.destroy_unlock_add('guardops.phone_offer', 'board 11401', 30);
DROP TABLE guardops.phone_offer CASCADE;

SELECT guardops.destroy_unlock_add('guardops.phone_press', 'board 11401', 30);
DROP TABLE guardops.phone_press CASCADE;

SELECT guardops.destroy_unlock_add('guardops.review_carry', 'board 11401', 30);
DROP TABLE guardops.review_carry CASCADE;

SELECT guardops.destroy_unlock_add('guardops.review_rate_limit', 'board 11401', 30);
DROP TABLE guardops.review_rate_limit CASCADE;

SELECT guardops.destroy_unlock_add('guardops.review_round', 'board 11401', 30);
DROP TABLE guardops.review_round CASCADE;

SELECT guardops.destroy_unlock_add('guardops.review_severity_log', 'board 11401', 30);
DROP TABLE guardops.review_severity_log CASCADE;

SELECT guardops.destroy_unlock_add('guardops.review_signer_key', 'board 11401', 30);
DROP TABLE guardops.review_signer_key CASCADE;

SELECT guardops.destroy_unlock_add('guardops.migration_review', 'board 11401', 30);
DROP TABLE guardops.migration_review CASCADE;

SELECT guardops.destroy_unlock_add('guardops.round_log', 'board 11401', 30);
DROP TABLE guardops.round_log CASCADE;

SELECT guardops.destroy_unlock_add('guardops.agent_claim_pull', 'board 11401', 30);
DROP TABLE guardops.agent_claim_pull CASCADE;

SELECT guardops.destroy_unlock_add('guardops.agent_claim_record', 'board 11401', 30);
DROP TABLE guardops.agent_claim_record CASCADE;

SELECT guardops.destroy_unlock_add('guardops.build_crossing', 'board 11401', 30);
DROP TABLE guardops.build_crossing CASCADE;

SELECT guardops.destroy_unlock_add('guardops.build_finding', 'board 11401', 30);
DROP TABLE guardops.build_finding CASCADE;

SELECT guardops.destroy_unlock_add('guardops.build_step', 'board 11401', 30);
DROP TABLE guardops.build_step CASCADE;

SELECT guardops.destroy_unlock_add('guardops.crossing_papers', 'board 11401', 30);
DROP TABLE guardops.crossing_papers CASCADE;

SELECT guardops.destroy_unlock_add('guardops.door_call_rule', 'board 11401', 30);
DROP TABLE guardops.door_call_rule CASCADE;

SELECT guardops.destroy_unlock_add('guardops.door_snapshot', 'board 11401', 30);
DROP TABLE guardops.door_snapshot CASCADE;

SELECT guardops.destroy_unlock_add('guardops.engine_piece', 'board 11401', 30);
DROP TABLE guardops.engine_piece CASCADE;

SELECT guardops.destroy_unlock_add('guardops.floor_deferred', 'board 11401', 30);
DROP TABLE guardops.floor_deferred CASCADE;

SELECT guardops.destroy_unlock_add('guardops.floor_map', 'board 11401', 30);
DROP TABLE guardops.floor_map CASCADE;

SELECT guardops.destroy_unlock_add('guardops.floor_reading', 'board 11401', 30);
DROP TABLE guardops.floor_reading CASCADE;

SELECT guardops.destroy_unlock_add('guardops.jargon_words', 'board 11401', 30);
DROP TABLE guardops.jargon_words CASCADE;

SELECT guardops.destroy_unlock_add('guardops.line_station', 'board 11401', 30);
DROP TABLE guardops.line_station CASCADE;

SELECT guardops.destroy_unlock_add('guardops.outside_beat_log', 'board 11401', 30);
DROP TABLE guardops.outside_beat_log CASCADE;

SELECT guardops.destroy_unlock_add('guardops.p1_oracle', 'board 11401', 30);
DROP TABLE guardops.p1_oracle CASCADE;

SELECT guardops.destroy_unlock_add('guardops.park_step', 'board 11401', 30);
DROP TABLE guardops.park_step CASCADE;

SELECT guardops.destroy_unlock_add('guardops.piece_join', 'board 11401', 30);
DROP TABLE guardops.piece_join CASCADE;

SELECT guardops.destroy_unlock_add('guardops.plan_gap', 'board 11401', 30);
DROP TABLE guardops.plan_gap CASCADE;

SELECT guardops.destroy_unlock_add('guardops.plan_gap_ask', 'board 11401', 30);
DROP TABLE guardops.plan_gap_ask CASCADE;

SELECT guardops.destroy_unlock_add('guardops.plan_gap_read', 'board 11401', 30);
DROP TABLE guardops.plan_gap_read CASCADE;

SELECT guardops.destroy_unlock_add('guardops.room', 'board 11401', 30);
DROP TABLE guardops.room CASCADE;

SELECT guardops.destroy_unlock_add('guardops.signin_refresh', 'board 11401', 30);
DROP TABLE guardops.signin_refresh CASCADE;

SELECT guardops.destroy_unlock_add('guardops.signin_refusal_run', 'board 11401', 30);
DROP TABLE guardops.signin_refusal_run CASCADE;

SELECT guardops.destroy_unlock_add('guardops.site_handoff', 'board 11401', 30);
DROP TABLE guardops.site_handoff CASCADE;

SELECT guardops.destroy_unlock_add('guardops.site_session', 'board 11401', 30);
DROP TABLE guardops.site_session CASCADE;

SELECT guardops.destroy_unlock_add('guardops.spec_sheet', 'board 11401', 30);
DROP TABLE guardops.spec_sheet CASCADE;

SELECT guardops.destroy_unlock_add('guardops.factory_pull_log', 'board 11401', 30);
DROP TABLE guardops.factory_pull_log CASCADE;


-- ===  ROLLBACK SECTION  ===

-- ----- factory_pull_log -----

CREATE TABLE guardops.factory_pull_log (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    kind TEXT NOT NULL,
    post_id BIGINT,
    order_id BIGINT,
    fired_sha TEXT,
    request_id BIGINT,
    http_status INTEGER,
    pull_status TEXT,
    verdict TEXT,
    detail TEXT,
    bell_id BIGINT,
    at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.factory_pull_log ADD CONSTRAINT factory_pull_log_pkey PRIMARY KEY (id);
ALTER TABLE guardops.factory_pull_log ADD CONSTRAINT factory_pull_log_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.factory_pull_log ADD CONSTRAINT factory_pull_log_order_id_acct_fkey FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id);
ALTER TABLE guardops.factory_pull_log ADD CONSTRAINT factory_pull_log_order_id_fkey FOREIGN KEY (order_id) REFERENCES guardops.job_order (id);
ALTER TABLE guardops.factory_pull_log ADD CONSTRAINT factory_pull_log_post_id_acct_fkey FOREIGN KEY (post_id, account_id) REFERENCES guardops.factory_pull_log (id, account_id);
ALTER TABLE guardops.factory_pull_log ADD CONSTRAINT factory_pull_log_post_id_fkey FOREIGN KEY (post_id) REFERENCES guardops.factory_pull_log (id);
ALTER TABLE guardops.factory_pull_log ADD CONSTRAINT factory_pull_log_kind_check CHECK (kind = ANY (ARRAY['POST'::text, 'JUDGE'::text]));
ALTER TABLE guardops.factory_pull_log ADD CONSTRAINT factory_pull_log_shape CHECK (((kind = 'POST'::text) AND (post_id IS NULL) AND (order_id IS NOT NULL) AND (fired_sha IS NOT NULL) AND (verdict IS NULL)) OR ((kind = 'JUDGE'::text) AND (post_id IS NOT NULL) AND (verdict IS NOT NULL)));
ALTER TABLE guardops.factory_pull_log ADD CONSTRAINT factory_pull_log_verdict_check CHECK (verdict = ANY (ARRAY['OK'::text, 'IN_PROGRESS'::text, 'RING'::text]));

CREATE UNIQUE INDEX factory_pull_log_id_account_key ON guardops.factory_pull_log USING btree (id, account_id);
CREATE UNIQUE INDEX factory_pull_log_one_judge ON guardops.factory_pull_log USING btree (post_id) WHERE (kind = 'JUDGE'::text);

ALTER TABLE guardops.factory_pull_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.factory_pull_log AS PERMISSIVE FOR SELECT TO code_builder, proof_reader USING (true);
CREATE POLICY postgres_read ON guardops.factory_pull_log AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY postgres_write ON guardops.factory_pull_log AS PERMISSIVE FOR INSERT TO postgres WITH CHECK (true);
CREATE POLICY tenancy_wall ON guardops.factory_pull_log AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.factory_pull_log FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_factory_pull_log AFTER INSERT OR UPDATE ON guardops.factory_pull_log FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_factory_pull_log BEFORE INSERT OR DELETE OR UPDATE ON guardops.factory_pull_log FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_factory_pull_log_truncate BEFORE TRUNCATE ON guardops.factory_pull_log FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.factory_pull_log FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- spec_sheet -----

CREATE TABLE guardops.spec_sheet (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    module TEXT NOT NULL,
    ledger_ref INTEGER NOT NULL,
    designed JSONB NOT NULL,
    actual JSONB NOT NULL,
    holes JSONB NOT NULL,
    desk_report TEXT NOT NULL,
    born_late BOOLEAN DEFAULT false NOT NULL,
    verdict_ref BIGINT NOT NULL,
    written_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.spec_sheet ADD CONSTRAINT spec_sheet_pkey PRIMARY KEY (id);
ALTER TABLE guardops.spec_sheet ADD CONSTRAINT spec_sheet_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.spec_sheet ADD CONSTRAINT spec_sheet_ledger_ref_acct_fkey FOREIGN KEY (account_id, ledger_ref) REFERENCES guardops.build_record (account_id, id);
ALTER TABLE guardops.spec_sheet ADD CONSTRAINT spec_sheet_ledger_ref_fkey FOREIGN KEY (ledger_ref) REFERENCES guardops.build_record (id);
ALTER TABLE guardops.spec_sheet ADD CONSTRAINT spec_sheet_verdict_ref_acct_fkey FOREIGN KEY (account_id, verdict_ref) REFERENCES guardops.verdict (account_id, id);
ALTER TABLE guardops.spec_sheet ADD CONSTRAINT spec_sheet_verdict_ref_fkey FOREIGN KEY (verdict_ref) REFERENCES guardops.verdict (id);
ALTER TABLE guardops.spec_sheet ADD CONSTRAINT spec_sheet_module_key UNIQUE (account_id, module);

CREATE UNIQUE INDEX spec_sheet_module_key ON guardops.spec_sheet USING btree (account_id, module);

ALTER TABLE guardops.spec_sheet ENABLE ROW LEVEL SECURITY;

CREATE POLICY proof_reader_read ON guardops.spec_sheet AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY spec_sheet_read ON guardops.spec_sheet AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY tenancy_wall ON guardops.spec_sheet AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.spec_sheet FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.spec_sheet FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('written_by');
CREATE TRIGGER audit_spec_sheet AFTER INSERT OR UPDATE ON guardops.spec_sheet FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER floor_watch BEFORE INSERT OR DELETE OR UPDATE ON guardops.spec_sheet FOR EACH ROW EXECUTE FUNCTION guardops.floor_check('GUARD');
CREATE TRIGGER guard_spec_sheet BEFORE INSERT OR DELETE OR UPDATE ON guardops.spec_sheet FOR EACH ROW EXECUTE FUNCTION guardops.guard_spec_sheet();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.spec_sheet FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- site_session -----

CREATE TABLE guardops.site_session (
    account_id BIGINT DEFAULT 1 NOT NULL,
    id BIGINT NOT NULL,
    token_hash TEXT NOT NULL,
    connected_account_id BIGINT NOT NULL,
    started_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    expires_at TIMESTAMPTZ DEFAULT (now() + '14 days'::interval) NOT NULL,
    last_seen_at TIMESTAMPTZ,
    customer_id BIGINT
);

ALTER TABLE guardops.site_session ADD CONSTRAINT site_session_pkey PRIMARY KEY (id);
ALTER TABLE guardops.site_session ADD CONSTRAINT site_session_token_hash_key UNIQUE (token_hash);

CREATE UNIQUE INDEX site_session_token_hash_key ON guardops.site_session USING btree (token_hash);

ALTER TABLE guardops.site_session ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.site_session AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.site_session AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.site_session AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.site_session FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_site_session AFTER INSERT OR UPDATE ON guardops.site_session FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.site_session FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- site_handoff -----

CREATE TABLE guardops.site_handoff (
    account_id BIGINT DEFAULT 1 NOT NULL,
    id BIGINT NOT NULL,
    code_hash TEXT NOT NULL,
    connected_account_id BIGINT NOT NULL,
    made_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    expires_at TIMESTAMPTZ DEFAULT (now() + '00:02:00'::interval) NOT NULL,
    used_at TIMESTAMPTZ
);

ALTER TABLE guardops.site_handoff ADD CONSTRAINT site_handoff_pkey PRIMARY KEY (id);
ALTER TABLE guardops.site_handoff ADD CONSTRAINT site_handoff_code_hash_key UNIQUE (code_hash);

CREATE UNIQUE INDEX site_handoff_code_hash_key ON guardops.site_handoff USING btree (code_hash);

ALTER TABLE guardops.site_handoff ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.site_handoff AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.site_handoff AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.site_handoff AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.site_handoff FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_site_handoff AFTER INSERT OR UPDATE ON guardops.site_handoff FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.site_handoff FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- signin_refusal_run -----

CREATE TABLE guardops.signin_refusal_run (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    database_id BIGINT NOT NULL,
    connected_account_id BIGINT NOT NULL,
    in_a_row INTEGER DEFAULT 0 NOT NULL,
    last_refused_at TIMESTAMPTZ,
    last_cleared_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.signin_refusal_run ADD CONSTRAINT signin_refusal_run_pkey PRIMARY KEY (id);
ALTER TABLE guardops.signin_refusal_run ADD CONSTRAINT signin_refusal_run_connected_account_id_fkey FOREIGN KEY (connected_account_id) REFERENCES guardops.connected_account (id);
ALTER TABLE guardops.signin_refusal_run ADD CONSTRAINT signin_refusal_run_database_id_fkey FOREIGN KEY (database_id) REFERENCES guardops.watched_database (id);

CREATE UNIQUE INDEX signin_refusal_run_one_per_pair ON guardops.signin_refusal_run USING btree (account_id, database_id, connected_account_id);

ALTER TABLE guardops.signin_refusal_run ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.signin_refusal_run AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.signin_refusal_run AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.signin_refusal_run AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.signin_refusal_run FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_signin_refusal_run AFTER INSERT OR UPDATE ON guardops.signin_refusal_run FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.signin_refusal_run FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- signin_refresh -----

CREATE TABLE guardops.signin_refresh (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    connected_id BIGINT NOT NULL,
    old_secret TEXT NOT NULL,
    new_secret TEXT,
    request_id BIGINT,
    state TEXT DEFAULT 'PENDING'::text NOT NULL,
    failed_why TEXT,
    asked_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    asked_by TEXT DEFAULT SESSION_USER NOT NULL
);

ALTER TABLE guardops.signin_refresh ADD CONSTRAINT signin_refresh_pkey PRIMARY KEY (id);
ALTER TABLE guardops.signin_refresh ADD CONSTRAINT signin_refresh_connected_id_fkey FOREIGN KEY (connected_id) REFERENCES guardops.connected_account (id);
ALTER TABLE guardops.signin_refresh ADD CONSTRAINT signin_refresh_state_check CHECK (state = ANY (ARRAY['PENDING'::text, 'DONE'::text, 'FAILED'::text]));

ALTER TABLE guardops.signin_refresh ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.signin_refresh AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.signin_refresh AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.signin_refresh AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.signin_refresh FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_signin_refresh AFTER INSERT OR UPDATE ON guardops.signin_refresh FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.signin_refresh FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- room -----

CREATE TABLE guardops.room (
    id BIGINT NOT NULL,
    name TEXT NOT NULL,
    what_it_is TEXT NOT NULL,
    status TEXT DEFAULT 'ACTIVE'::text NOT NULL,
    retired_by BIGINT,
    declared_on DATE DEFAULT CURRENT_DATE NOT NULL,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.room ADD CONSTRAINT room_pkey PRIMARY KEY (id);
ALTER TABLE guardops.room ADD CONSTRAINT room_retired_by_fkey FOREIGN KEY (retired_by) REFERENCES guardops.room (id);
ALTER TABLE guardops.room ADD CONSTRAINT room_name_key UNIQUE (name);
ALTER TABLE guardops.room ADD CONSTRAINT room_check CHECK ((status <> 'ACTIVE'::text) OR (retired_by IS NULL));
ALTER TABLE guardops.room ADD CONSTRAINT room_check1 CHECK ((status <> 'RETIRED'::text) OR (retired_by IS NOT NULL));
ALTER TABLE guardops.room ADD CONSTRAINT room_name_check CHECK (name ~ '^[A-Z][A-Z0-9_]{1,29}$'::text);
ALTER TABLE guardops.room ADD CONSTRAINT room_status_check CHECK (status = ANY (ARRAY['ACTIVE'::text, 'RETIRED'::text]));
ALTER TABLE guardops.room ADD CONSTRAINT room_what_it_is_check CHECK (length(btrim(what_it_is)) >= 20);

CREATE UNIQUE INDEX room_name_key ON guardops.room USING btree (name);

ALTER TABLE guardops.room ENABLE ROW LEVEL SECURITY;

CREATE POLICY room_read ON guardops.room AS PERMISSIVE FOR SELECT TO code_builder, proof_reader USING (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.room FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.room FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('created_by');
CREATE TRIGGER audit_room AFTER INSERT OR UPDATE ON guardops.room FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER floor_watch BEFORE INSERT OR DELETE OR UPDATE ON guardops.room FOR EACH ROW EXECUTE FUNCTION guardops.floor_check('FLOOR');
CREATE TRIGGER room_append_only BEFORE DELETE OR UPDATE ON guardops.room FOR EACH ROW EXECUTE FUNCTION guardops.room_append_only();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.room FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- plan_gap_read -----

CREATE TABLE guardops.plan_gap_read (
    id BIGINT NOT NULL,
    account_id BIGINT NOT NULL,
    gap_id BIGINT NOT NULL,
    read_by TEXT NOT NULL,
    read_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL
);

ALTER TABLE guardops.plan_gap_read ADD CONSTRAINT plan_gap_read_pkey PRIMARY KEY (id);
ALTER TABLE guardops.plan_gap_read ADD CONSTRAINT plan_gap_read_acct_fk FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.plan_gap_read ADD CONSTRAINT plan_gap_read_gap_fk FOREIGN KEY (gap_id) REFERENCES guardops.plan_gap (id);
ALTER TABLE guardops.plan_gap_read ADD CONSTRAINT plan_gap_read_once UNIQUE (gap_id);
ALTER TABLE guardops.plan_gap_read ADD CONSTRAINT plan_gap_read_by_chk CHECK (btrim(read_by) <> ''::text);

CREATE UNIQUE INDEX plan_gap_read_once ON guardops.plan_gap_read USING btree (gap_id);

ALTER TABLE guardops.plan_gap_read ENABLE ROW LEVEL SECURITY;

CREATE POLICY plan_gap_read_code_builder_read ON guardops.plan_gap_read AS PERMISSIVE FOR SELECT TO code_builder USING (account_id = guardops.current_account());
CREATE POLICY plan_gap_read_proof_reader_read ON guardops.plan_gap_read AS PERMISSIVE FOR SELECT TO proof_reader USING (account_id = guardops.current_account());

CREATE TRIGGER audit_plan_gap_read AFTER INSERT OR UPDATE ON guardops.plan_gap_read FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.plan_gap_read REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.plan_gap_read REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.plan_gap_read REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER plan_gap_read_guard BEFORE INSERT OR DELETE OR UPDATE ON guardops.plan_gap_read FOR EACH ROW EXECUTE FUNCTION guardops.guard_plan_gap_read();
CREATE TRIGGER plan_gap_read_guard_truncate BEFORE TRUNCATE ON guardops.plan_gap_read FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_plan_gap_read();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.plan_gap_read FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- plan_gap_ask -----

CREATE TABLE guardops.plan_gap_ask (
    id BIGINT NOT NULL,
    account_id BIGINT NOT NULL,
    plan_module TEXT NOT NULL,
    gap_ids BIGINT[] NOT NULL,
    asked_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    asked_by TEXT NOT NULL,
    answered_at TIMESTAMPTZ,
    answer TEXT,
    answered_by TEXT
);

ALTER TABLE guardops.plan_gap_ask ADD CONSTRAINT plan_gap_ask_pkey PRIMARY KEY (id);
ALTER TABLE guardops.plan_gap_ask ADD CONSTRAINT plan_gap_ask_acct_fk FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.plan_gap_ask ADD CONSTRAINT plan_gap_ask_answer_ok CHECK (answer = ANY (ARRAY['YES'::text, 'NO'::text]));
ALTER TABLE guardops.plan_gap_ask ADD CONSTRAINT plan_gap_ask_answer_pair CHECK (((answered_at IS NULL) = (answer IS NULL)) AND ((answered_at IS NULL) = (answered_by IS NULL)));
ALTER TABLE guardops.plan_gap_ask ADD CONSTRAINT plan_gap_ask_module_chk CHECK ((btrim(plan_module) <> ''::text) AND (length(plan_module) <= 200));
ALTER TABLE guardops.plan_gap_ask ADD CONSTRAINT plan_gap_ask_no_gaps CHECK (array_length(gap_ids, 1) > 0);

CREATE UNIQUE INDEX plan_gap_ask_one_open ON guardops.plan_gap_ask USING btree (account_id, plan_module) WHERE (answered_at IS NULL);

ALTER TABLE guardops.plan_gap_ask ENABLE ROW LEVEL SECURITY;

CREATE POLICY plan_gap_ask_code_builder_read ON guardops.plan_gap_ask AS PERMISSIVE FOR SELECT TO code_builder USING (account_id = guardops.current_account());
CREATE POLICY plan_gap_ask_proof_reader_read ON guardops.plan_gap_ask AS PERMISSIVE FOR SELECT TO proof_reader USING (true);

CREATE TRIGGER audit_plan_gap_ask AFTER INSERT OR UPDATE ON guardops.plan_gap_ask FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.plan_gap_ask REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.plan_gap_ask REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.plan_gap_ask REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER plan_gap_ask_guard BEFORE DELETE OR UPDATE ON guardops.plan_gap_ask FOR EACH ROW EXECUTE FUNCTION guardops.guard_plan_gap_ask();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.plan_gap_ask FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- plan_gap -----

CREATE TABLE guardops.plan_gap (
    account_id BIGINT NOT NULL,
    id BIGINT NOT NULL,
    plan_module TEXT NOT NULL,
    step_no INTEGER NOT NULL,
    noted_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    noted_by TEXT NOT NULL
);

ALTER TABLE guardops.plan_gap ADD CONSTRAINT plan_gap_pkey PRIMARY KEY (id);
ALTER TABLE guardops.plan_gap ADD CONSTRAINT plan_gap_account_fk FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.plan_gap ADD CONSTRAINT plan_gap_unique UNIQUE (account_id, plan_module, step_no);
ALTER TABLE guardops.plan_gap ADD CONSTRAINT plan_gap_module_check CHECK ((btrim(plan_module) <> ''::text) AND (length(plan_module) <= 200));
ALTER TABLE guardops.plan_gap ADD CONSTRAINT plan_gap_step_range CHECK ((step_no >= 1) AND (step_no <= 1000));

CREATE UNIQUE INDEX plan_gap_unique ON guardops.plan_gap USING btree (account_id, plan_module, step_no);

ALTER TABLE guardops.plan_gap ENABLE ROW LEVEL SECURITY;

CREATE POLICY plan_gap_code_builder_read ON guardops.plan_gap AS PERMISSIVE FOR SELECT TO code_builder USING (account_id = guardops.current_account());
CREATE POLICY plan_gap_proof_reader_read ON guardops.plan_gap AS PERMISSIVE FOR SELECT TO proof_reader USING (true);

CREATE TRIGGER audit_plan_gap AFTER INSERT OR UPDATE ON guardops.plan_gap FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.plan_gap REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.plan_gap REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.plan_gap REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER plan_gap_guard BEFORE DELETE OR UPDATE ON guardops.plan_gap FOR EACH ROW EXECUTE FUNCTION guardops.guard_plan_gap();
CREATE TRIGGER plan_gap_guard_truncate BEFORE TRUNCATE ON guardops.plan_gap FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_plan_gap();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.plan_gap FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- piece_join -----

CREATE TABLE guardops.piece_join (
    account_id BIGINT NOT NULL,
    id BIGINT NOT NULL,
    part_id BIGINT NOT NULL,
    joins_to_part_id BIGINT,
    joins_to_name TEXT,
    built_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    joined_at TIMESTAMPTZ,
    proof_ref TEXT,
    recorded_by TEXT NOT NULL,
    joined_by TEXT
);

ALTER TABLE guardops.piece_join ADD CONSTRAINT piece_join_pkey PRIMARY KEY (id);
ALTER TABLE guardops.piece_join ADD CONSTRAINT piece_join_account_fk FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.piece_join ADD CONSTRAINT piece_join_joins_to_fk FOREIGN KEY (joins_to_part_id) REFERENCES guardops.order_part (id);
ALTER TABLE guardops.piece_join ADD CONSTRAINT piece_join_part_fk FOREIGN KEY (part_id) REFERENCES guardops.order_part (id);
ALTER TABLE guardops.piece_join ADD CONSTRAINT piece_join_part_unique UNIQUE (account_id, part_id);
ALTER TABLE guardops.piece_join ADD CONSTRAINT piece_join_has_target CHECK ((joins_to_part_id IS NOT NULL) OR ((joins_to_name IS NOT NULL) AND (btrim(joins_to_name) <> ''::text)));

CREATE UNIQUE INDEX piece_join_part_unique ON guardops.piece_join USING btree (account_id, part_id);

ALTER TABLE guardops.piece_join ENABLE ROW LEVEL SECURITY;

CREATE POLICY piece_join_code_builder_read ON guardops.piece_join AS PERMISSIVE FOR SELECT TO code_builder USING (account_id = guardops.current_account());
CREATE POLICY piece_join_proof_reader_read ON guardops.piece_join AS PERMISSIVE FOR SELECT TO proof_reader USING (true);

CREATE TRIGGER audit_piece_join AFTER INSERT OR UPDATE ON guardops.piece_join FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.piece_join REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.piece_join REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.piece_join REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.piece_join FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- park_step -----

CREATE TABLE guardops.park_step (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    kind TEXT NOT NULL,
    park_id BIGINT,
    board_id BIGINT,
    order_id BIGINT,
    hold_id BIGINT,
    needs TEXT,
    reason TEXT NOT NULL,
    actor TEXT NOT NULL,
    login TEXT DEFAULT SESSION_USER NOT NULL,
    at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_pkey PRIMARY KEY (id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_board_id_acct_fkey FOREIGN KEY (account_id, board_id) REFERENCES guardops.board_item (account_id, id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_board_id_fkey FOREIGN KEY (board_id) REFERENCES guardops.board_item (id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_hold_id_acct_fkey FOREIGN KEY (account_id, hold_id) REFERENCES guardops.order_hold (account_id, id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_hold_id_fkey FOREIGN KEY (hold_id) REFERENCES guardops.order_hold (id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_order_id_acct_fkey FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_order_id_fkey FOREIGN KEY (order_id) REFERENCES guardops.job_order (id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_park_id_acct_fkey FOREIGN KEY (account_id, park_id) REFERENCES guardops.park_step (account_id, id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_park_id_fkey FOREIGN KEY (park_id) REFERENCES guardops.park_step (id);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_kind_check CHECK (kind = ANY (ARRAY['PARK'::text, 'UNPARK'::text]));
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_park_names_work CHECK ((kind = 'UNPARK'::text) OR (board_id IS NOT NULL) OR (order_id IS NOT NULL));
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_park_says_what CHECK ((kind = 'UNPARK'::text) OR (length(btrim(COALESCE(needs, ''::text))) >= 3));
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_reason_check CHECK (length(btrim(reason)) >= 10);
ALTER TABLE guardops.park_step ADD CONSTRAINT park_step_unpark_names_park CHECK ((kind = 'UNPARK'::text) = (park_id IS NOT NULL));

CREATE INDEX park_step_by_board ON guardops.park_step USING btree (board_id);
CREATE INDEX park_step_by_order ON guardops.park_step USING btree (order_id);
CREATE UNIQUE INDEX park_step_id_account_key ON guardops.park_step USING btree (id, account_id);
CREATE UNIQUE INDEX park_step_one_unpark ON guardops.park_step USING btree (park_id) WHERE (kind = 'UNPARK'::text);

ALTER TABLE guardops.park_step ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.park_step AS PERMISSIVE FOR SELECT TO code_builder, firing_seat, proof_reader USING (true);
CREATE POLICY postgres_read ON guardops.park_step AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY tenancy_wall ON guardops.park_step AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.park_step FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_park_step AFTER INSERT OR UPDATE ON guardops.park_step FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_park_step BEFORE INSERT OR DELETE OR UPDATE ON guardops.park_step FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_park_step_truncate BEFORE TRUNCATE ON guardops.park_step FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.park_step FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- p1_oracle -----

CREATE TABLE guardops.p1_oracle (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    order_id BIGINT NOT NULL,
    part_name TEXT NOT NULL,
    old_stands BOOLEAN,
    taken_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_by TEXT DEFAULT 'CODE:0134'::text NOT NULL
);

ALTER TABLE guardops.p1_oracle ADD CONSTRAINT p1_oracle_pk PRIMARY KEY (order_id);
ALTER TABLE guardops.p1_oracle ADD CONSTRAINT p1_oracle_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.p1_oracle ADD CONSTRAINT p1_oracle_order_id_fkey FOREIGN KEY (order_id) REFERENCES guardops.job_order (id) ON DELETE CASCADE;

ALTER TABLE guardops.p1_oracle ENABLE ROW LEVEL SECURITY;

CREATE POLICY p1_oracle_read ON guardops.p1_oracle AS PERMISSIVE FOR SELECT TO code_builder, proof_reader USING (account_id = guardops.current_account());
CREATE POLICY tenancy_wall ON guardops.p1_oracle AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.p1_oracle FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_p1_oracle AFTER INSERT OR UPDATE ON guardops.p1_oracle FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.p1_oracle FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- outside_beat_log -----

CREATE TABLE guardops.outside_beat_log (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.floor_account() NOT NULL,
    outcome TEXT NOT NULL,
    wrong_jobs TEXT,
    request_id BIGINT,
    at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.outside_beat_log ADD CONSTRAINT outside_beat_log_pkey PRIMARY KEY (id);
ALTER TABLE guardops.outside_beat_log ADD CONSTRAINT outside_beat_log_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.outside_beat_log ADD CONSTRAINT outside_beat_log_outcome_check CHECK (outcome = ANY (ARRAY['ok'::text, 'fail'::text]));

ALTER TABLE guardops.outside_beat_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.outside_beat_log AS PERMISSIVE FOR SELECT TO code_builder, proof_reader USING (true);
CREATE POLICY postgres_write ON guardops.outside_beat_log AS PERMISSIVE FOR INSERT TO postgres WITH CHECK (true);
CREATE POLICY tenancy_wall ON guardops.outside_beat_log AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.outside_beat_log FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_outside_beat_log AFTER INSERT OR UPDATE ON guardops.outside_beat_log FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_outside_beat_log BEFORE INSERT OR DELETE OR UPDATE ON guardops.outside_beat_log FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_outside_beat_log_truncate BEFORE TRUNCATE ON guardops.outside_beat_log FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.outside_beat_log FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- line_station -----

CREATE TABLE guardops.line_station (
    station_no INTEGER NOT NULL,
    phase_no INTEGER NOT NULL,
    phase_name TEXT NOT NULL,
    label TEXT NOT NULL
);

ALTER TABLE guardops.line_station ADD CONSTRAINT line_station_pkey PRIMARY KEY (station_no);
ALTER TABLE guardops.line_station ADD CONSTRAINT line_station_phase_no_check CHECK ((phase_no >= 1) AND (phase_no <= 4));
ALTER TABLE guardops.line_station ADD CONSTRAINT line_station_station_no_check CHECK ((station_no >= 1) AND (station_no <= 12));

CREATE TRIGGER audit_line_station AFTER INSERT OR UPDATE ON guardops.line_station FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.line_station REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.line_station REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.line_station REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.line_station FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- jargon_words -----

CREATE TABLE guardops.jargon_words (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    word TEXT NOT NULL,
    added_by TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.jargon_words ADD CONSTRAINT jargon_words_pkey PRIMARY KEY (id);
ALTER TABLE guardops.jargon_words ADD CONSTRAINT jargon_words_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.jargon_words ADD CONSTRAINT jargon_words_word_key UNIQUE (account_id, word);
ALTER TABLE guardops.jargon_words ADD CONSTRAINT jargon_words_word_check CHECK ((word = lower(word)) AND (word ~ '^[a-z0-9][a-z0-9 _-]*$'::text));

CREATE UNIQUE INDEX jargon_words_word_key ON guardops.jargon_words USING btree (account_id, word);

ALTER TABLE guardops.jargon_words ENABLE ROW LEVEL SECURITY;

CREATE POLICY jargon_words_read ON guardops.jargon_words AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.jargon_words AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.jargon_words AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.jargon_words FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.jargon_words FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('added_by');
CREATE TRIGGER audit_jargon_words AFTER INSERT OR UPDATE ON guardops.jargon_words FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER floor_watch BEFORE INSERT OR DELETE OR UPDATE ON guardops.jargon_words FOR EACH ROW EXECUTE FUNCTION guardops.floor_check('LAW');
CREATE TRIGGER guard_jargon_words BEFORE DELETE OR UPDATE ON guardops.jargon_words FOR EACH ROW EXECUTE FUNCTION guardops.guard_jargon_words();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.jargon_words FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- floor_reading -----

CREATE TABLE guardops.floor_reading (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    login TEXT DEFAULT SESSION_USER NOT NULL,
    subject TEXT,
    at TIMESTAMPTZ DEFAULT now() NOT NULL,
    snapshot JSONB NOT NULL
);

ALTER TABLE guardops.floor_reading ADD CONSTRAINT floor_reading_pkey PRIMARY KEY (id);

ALTER TABLE guardops.floor_reading ENABLE ROW LEVEL SECURITY;
ALTER TABLE guardops.floor_reading FORCE ROW LEVEL SECURITY;

CREATE POLICY floor_reading_own_account ON guardops.floor_reading AS PERMISSIVE FOR ALL TO public USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER audit_floor_reading AFTER INSERT OR UPDATE ON guardops.floor_reading FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.floor_reading FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- floor_map -----

CREATE TABLE guardops.floor_map (
    table_name TEXT NOT NULL,
    room TEXT NOT NULL,
    added_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.floor_map ADD CONSTRAINT floor_map_pkey PRIMARY KEY (table_name);
ALTER TABLE guardops.floor_map ADD CONSTRAINT floor_map_room_check CHECK (room = ANY (ARRAY['ORDERBOOK'::text, 'ALARMS'::text, 'FLOOR'::text, 'CAMERA'::text, 'VAULT'::text, 'GIT'::text, 'LAW'::text, 'PROOF'::text, 'GUARD'::text]));

ALTER TABLE guardops.floor_map ENABLE ROW LEVEL SECURITY;

CREATE POLICY floor_map_read ON guardops.floor_map AS PERMISSIVE FOR SELECT TO code_builder, guardops_guard_reader, proof_reader USING (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.floor_map FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_floor_map AFTER INSERT OR UPDATE ON guardops.floor_map FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER floor_map_guard BEFORE DELETE OR UPDATE ON guardops.floor_map FOR EACH ROW EXECUTE FUNCTION guardops.floor_map_guard();
CREATE TRIGGER floor_watch BEFORE INSERT OR DELETE OR UPDATE ON guardops.floor_map FOR EACH ROW EXECUTE FUNCTION guardops.floor_check('FLOOR');
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.floor_map FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- floor_deferred -----

CREATE TABLE guardops.floor_deferred (
    table_name TEXT NOT NULL,
    reason TEXT NOT NULL,
    deferred_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.floor_deferred ADD CONSTRAINT floor_deferred_pkey PRIMARY KEY (table_name);
ALTER TABLE guardops.floor_deferred ADD CONSTRAINT floor_deferred_table_name_fkey FOREIGN KEY (table_name) REFERENCES guardops.floor_map (table_name);

ALTER TABLE guardops.floor_deferred ENABLE ROW LEVEL SECURITY;

CREATE POLICY floor_deferred_read ON guardops.floor_deferred AS PERMISSIVE FOR SELECT TO code_builder, guardops_guard_reader, proof_reader USING (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.floor_deferred FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_floor_deferred AFTER INSERT OR UPDATE ON guardops.floor_deferred FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER floor_watch BEFORE INSERT OR DELETE OR UPDATE ON guardops.floor_deferred FOR EACH ROW EXECUTE FUNCTION guardops.floor_check('FLOOR');
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.floor_deferred FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- engine_piece -----

CREATE TABLE guardops.engine_piece (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    piece TEXT NOT NULL,
    label TEXT NOT NULL,
    value TEXT NOT NULL,
    state TEXT DEFAULT 'ACTIVE'::text NOT NULL,
    is_watched BOOLEAN DEFAULT false NOT NULL,
    max_quiet_minutes INTEGER,
    ruling_ref TEXT,
    created_by TEXT DEFAULT SESSION_USER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.engine_piece ADD CONSTRAINT engine_piece_pkey PRIMARY KEY (id);
ALTER TABLE guardops.engine_piece ADD CONSTRAINT engine_piece_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.engine_piece ADD CONSTRAINT engine_piece_label_check CHECK ((length(btrim(label)) >= 1) AND (length(btrim(label)) <= 100));
ALTER TABLE guardops.engine_piece ADD CONSTRAINT engine_piece_max_quiet_minutes_check CHECK ((max_quiet_minutes IS NULL) OR (max_quiet_minutes > 0));
ALTER TABLE guardops.engine_piece ADD CONSTRAINT engine_piece_piece_check CHECK (piece = ANY (ARRAY['relay_task'::text, 'environment'::text, 'start_card'::text, 'heartbeat'::text]));
ALTER TABLE guardops.engine_piece ADD CONSTRAINT engine_piece_state_check CHECK (state = ANY (ARRAY['ACTIVE'::text, 'RETIRED'::text]));
ALTER TABLE guardops.engine_piece ADD CONSTRAINT engine_piece_value_check CHECK ((length(btrim(value)) >= 1) AND (length(btrim(value)) <= 500));

CREATE INDEX engine_piece_latest ON guardops.engine_piece USING btree (piece, label, id DESC);

ALTER TABLE guardops.engine_piece ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.engine_piece AS PERMISSIVE FOR SELECT TO code_builder, firing_seat, proof_reader USING (account_id = guardops.current_account());
CREATE POLICY postgres_read ON guardops.engine_piece AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY tenancy_wall ON guardops.engine_piece AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.engine_piece FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_engine_piece AFTER INSERT OR UPDATE ON guardops.engine_piece FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_engine_piece BEFORE INSERT OR DELETE OR UPDATE ON guardops.engine_piece FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_engine_piece_truncate BEFORE TRUNCATE ON guardops.engine_piece FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.engine_piece FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- door_snapshot -----

CREATE TABLE guardops.door_snapshot (
    id INTEGER DEFAULT nextval('guardops.door_snapshot_id_seq'::regclass) NOT NULL,
    purpose TEXT DEFAULT 'undo_point'::text NOT NULL,
    oid_captured OID NOT NULL,
    func_label TEXT NOT NULL,
    line_count INTEGER NOT NULL,
    body_verbatim TEXT NOT NULL,
    grants_acl TEXT,
    restore_sql TEXT NOT NULL,
    captured_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.door_snapshot ADD CONSTRAINT door_snapshot_pkey PRIMARY KEY (id);

ALTER TABLE guardops.door_snapshot ENABLE ROW LEVEL SECURITY;

CREATE POLICY door_snapshot_strong_seat ON guardops.door_snapshot AS PERMISSIVE FOR SELECT TO public USING ((guardops.is_strong_seat() OR (SESSION_USER = ANY (ARRAY['code_builder'::name, 'firing_seat'::name]))));

CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.door_snapshot REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.door_snapshot REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.door_snapshot REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.door_snapshot FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- door_call_rule -----

CREATE TABLE guardops.door_call_rule (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    plain_name TEXT NOT NULL,
    door_name TEXT NOT NULL,
    arg_type_oids TEXT DEFAULT ''::text NOT NULL,
    refuses TEXT,
    supersedes BIGINT,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.door_call_rule ADD CONSTRAINT door_call_rule_pkey PRIMARY KEY (id);
ALTER TABLE guardops.door_call_rule ADD CONSTRAINT door_call_rule_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.door_call_rule ADD CONSTRAINT door_call_rule_supersedes_acct_fkey FOREIGN KEY (supersedes, account_id) REFERENCES guardops.door_call_rule (id, account_id);
ALTER TABLE guardops.door_call_rule ADD CONSTRAINT door_call_rule_supersedes_fkey FOREIGN KEY (supersedes) REFERENCES guardops.door_call_rule (id);
ALTER TABLE guardops.door_call_rule ADD CONSTRAINT door_call_rule_created_by_check CHECK (length(btrim(created_by)) > 0);
ALTER TABLE guardops.door_call_rule ADD CONSTRAINT door_call_rule_door_name_check CHECK (length(btrim(door_name)) > 0);
ALTER TABLE guardops.door_call_rule ADD CONSTRAINT door_call_rule_no_self CHECK ((supersedes IS NULL) OR (supersedes <> id));
ALTER TABLE guardops.door_call_rule ADD CONSTRAINT door_call_rule_plain_name_check CHECK (length(btrim(plain_name)) > 0);

CREATE UNIQUE INDEX door_call_rule_id_account_key ON guardops.door_call_rule USING btree (id, account_id);

ALTER TABLE guardops.door_call_rule ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenancy_wall ON guardops.door_call_rule AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());
CREATE POLICY weak_seat_read ON guardops.door_call_rule AS PERMISSIVE FOR SELECT TO code_builder, harness_runner, proof_reader USING (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.door_call_rule FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.door_call_rule FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('created_by');
CREATE TRIGGER audit_door_call_rule AFTER INSERT ON guardops.door_call_rule FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER door_only_gate BEFORE INSERT OR UPDATE ON guardops.door_call_rule FOR EACH ROW EXECUTE FUNCTION guardops.door_only_gate();
CREATE TRIGGER guard_door_call_rule BEFORE DELETE OR UPDATE ON guardops.door_call_rule FOR EACH ROW EXECUTE FUNCTION guardops.guard_door_call_rule();
CREATE TRIGGER guard_door_call_rule_truncate BEFORE TRUNCATE ON guardops.door_call_rule FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_door_call_rule();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.door_call_rule FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- crossing_papers -----

CREATE TABLE guardops.crossing_papers (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    plan_id BIGINT NOT NULL,
    test_run TEXT NOT NULL,
    live_look TEXT NOT NULL,
    what_if_wrong TEXT NOT NULL,
    undo_plan TEXT NOT NULL,
    written_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    spent_at TIMESTAMPTZ
);

ALTER TABLE guardops.crossing_papers ADD CONSTRAINT crossing_papers_pkey PRIMARY KEY (id);
ALTER TABLE guardops.crossing_papers ADD CONSTRAINT crossing_papers_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.crossing_papers ADD CONSTRAINT crossing_papers_plan_id_acct_fkey FOREIGN KEY (plan_id, account_id) REFERENCES guardops.build_plan (id, account_id);
ALTER TABLE guardops.crossing_papers ADD CONSTRAINT crossing_papers_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES guardops.build_plan (id);
ALTER TABLE guardops.crossing_papers ADD CONSTRAINT crossing_papers_live_look_check CHECK (length(btrim(live_look)) > 0);
ALTER TABLE guardops.crossing_papers ADD CONSTRAINT crossing_papers_test_run_check CHECK (length(btrim(test_run)) > 0);
ALTER TABLE guardops.crossing_papers ADD CONSTRAINT crossing_papers_undo_plan_check CHECK (length(btrim(undo_plan)) > 0);
ALTER TABLE guardops.crossing_papers ADD CONSTRAINT crossing_papers_what_if_wrong_check CHECK (length(btrim(what_if_wrong)) > 0);

ALTER TABLE guardops.crossing_papers ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_write ON guardops.crossing_papers AS PERMISSIVE FOR INSERT TO code_builder WITH CHECK (true);
CREATE POLICY crossing_papers_read ON guardops.crossing_papers AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.crossing_papers AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.crossing_papers AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.crossing_papers FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.crossing_papers FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('written_by');
CREATE TRIGGER audit_crossing_papers AFTER INSERT OR UPDATE ON guardops.crossing_papers FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER floor_watch BEFORE INSERT OR DELETE OR UPDATE ON guardops.crossing_papers FOR EACH ROW EXECUTE FUNCTION guardops.floor_check('GUARD');
CREATE TRIGGER guard_crossing_papers BEFORE INSERT OR DELETE OR UPDATE ON guardops.crossing_papers FOR EACH ROW EXECUTE FUNCTION guardops.guard_crossing_papers();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.crossing_papers FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- build_step -----

CREATE TABLE guardops.build_step (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    law_id BIGINT NOT NULL,
    step_no SMALLINT NOT NULL,
    step_name TEXT NOT NULL,
    says_what TEXT,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.build_step ADD CONSTRAINT build_step_pkey PRIMARY KEY (id);
ALTER TABLE guardops.build_step ADD CONSTRAINT build_step_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.build_step ADD CONSTRAINT build_step_law_id_acct_fkey FOREIGN KEY (law_id, account_id) REFERENCES guardops.law (id, account_id);
ALTER TABLE guardops.build_step ADD CONSTRAINT build_step_law_id_fkey FOREIGN KEY (law_id) REFERENCES guardops.law (id);
ALTER TABLE guardops.build_step ADD CONSTRAINT build_step_law_step_uq UNIQUE (law_id, step_no);
ALTER TABLE guardops.build_step ADD CONSTRAINT build_step_created_by_check CHECK (length(btrim(created_by)) > 0);
ALTER TABLE guardops.build_step ADD CONSTRAINT build_step_name_check CHECK (length(btrim(step_name)) > 0);
ALTER TABLE guardops.build_step ADD CONSTRAINT build_step_step_no_check CHECK ((step_no >= 1) AND (step_no <= 12));

CREATE UNIQUE INDEX build_step_law_step_uq ON guardops.build_step USING btree (law_id, step_no);

ALTER TABLE guardops.build_step ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenancy_wall ON guardops.build_step AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());
CREATE POLICY weak_seat_read ON guardops.build_step AS PERMISSIVE FOR SELECT TO code_builder, harness_runner, proof_reader USING (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.build_step FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.build_step FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('created_by');
CREATE TRIGGER audit_build_step AFTER INSERT OR UPDATE ON guardops.build_step FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_build_step BEFORE DELETE OR UPDATE ON guardops.build_step FOR EACH ROW EXECUTE FUNCTION guardops.guard_build_crossing();
CREATE TRIGGER guard_build_step_truncate BEFORE TRUNCATE ON guardops.build_step FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_build_crossing();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.build_step FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- build_finding -----

CREATE TABLE guardops.build_finding (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    build_name TEXT NOT NULL,
    build_key TEXT,
    finding_key TEXT NOT NULL,
    reader TEXT NOT NULL,
    pass_no SMALLINT NOT NULL,
    severity TEXT NOT NULL,
    detail TEXT NOT NULL,
    written_by TEXT NOT NULL,
    actor TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    order_id BIGINT,
    reviewer_label TEXT,
    our_grade TEXT,
    pr INTEGER,
    head TEXT
);

ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_pkey PRIMARY KEY (id);
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_key_uq UNIQUE (account_id, build_key, finding_key, reader);
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_actor_check CHECK (actor = ANY (ARRAY['WAQAR'::text, 'OPUS'::text, 'CODE'::text]));
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_build_name_check CHECK (length(btrim(build_name)) > 0);
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_detail_check CHECK (length(btrim(detail)) > 0);
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_finding_key_check CHECK ((finding_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text) AND (length(finding_key) <= 60));
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_head_format CHECK ((head IS NULL) OR (head ~ '^[0-9a-f]{40}$'::text));
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_our_grade_vocab CHECK (our_grade = ANY (ARRAY['CRITICAL'::text, 'MAJOR'::text, 'MINOR'::text, 'TRIVIAL'::text]));
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_pass_no_check CHECK (pass_no >= 1);
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_reader_check CHECK (length(btrim(reader)) > 0);
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_severity_check CHECK (length(btrim(severity)) > 0);
ALTER TABLE guardops.build_finding ADD CONSTRAINT build_finding_written_by_check CHECK (length(btrim(written_by)) > 0);

CREATE UNIQUE INDEX build_finding_key_uq ON guardops.build_finding USING btree (account_id, build_key, reader, finding_key);

ALTER TABLE guardops.build_finding ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenancy_wall ON guardops.build_finding AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());
CREATE POLICY weak_seat_read ON guardops.build_finding AS PERMISSIVE FOR SELECT TO code_builder, harness_runner, proof_reader USING (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.build_finding FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.build_finding FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('actor', 'written_by');
CREATE TRIGGER audit_build_finding AFTER INSERT OR UPDATE ON guardops.build_finding FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER build_finding_stamp BEFORE INSERT ON guardops.build_finding FOR EACH ROW EXECUTE FUNCTION guardops.build_finding_stamp();
CREATE TRIGGER door_only_gate BEFORE INSERT OR UPDATE ON guardops.build_finding FOR EACH ROW EXECUTE FUNCTION guardops.door_only_gate();
CREATE TRIGGER guard_build_finding BEFORE DELETE OR UPDATE ON guardops.build_finding FOR EACH ROW EXECUTE FUNCTION guardops.guard_build_finding();
CREATE TRIGGER guard_build_finding_truncate BEFORE TRUNCATE ON guardops.build_finding FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_build_finding();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.build_finding FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- build_crossing -----

CREATE TABLE guardops.build_crossing (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    build_name TEXT NOT NULL,
    build_key TEXT,
    step_no SMALLINT NOT NULL,
    outcome TEXT NOT NULL,
    detail TEXT,
    fix_line TEXT,
    ending TEXT,
    reason TEXT,
    found_count SMALLINT,
    order_id BIGINT,
    written_by TEXT NOT NULL,
    actor TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_pkey PRIMARY KEY (id);
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_order_id_acct_fkey FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id);
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_order_id_fkey FOREIGN KEY (order_id) REFERENCES guardops.job_order (id);
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_actor_check CHECK (actor = ANY (ARRAY['WAQAR'::text, 'OPUS'::text, 'CODE'::text]));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_build_name_check CHECK (length(btrim(build_name)) > 0);
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_count_other CHECK ((step_no = ANY (ARRAY[8, 10])) OR (found_count IS NULL));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_done_shape CHECK ((outcome <> 'DONE'::text) OR ((fix_line IS NULL) AND (ending IS NULL) AND (reason IS NULL)));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_ending_check CHECK ((ending IS NULL) OR (ending = ANY (ARRAY['SENT_BACK'::text, 'BOUNCED'::text, 'HALTED'::text])));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_failed_shape CHECK ((outcome <> 'FAILED'::text) OR ((fix_line IS NOT NULL) AND (ending IS NOT NULL) AND (reason IS NULL)));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_found_nonneg CHECK ((found_count IS NULL) OR (found_count >= 0));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_order_below3 CHECK ((step_no >= 3) OR (order_id IS NULL));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_outcome_check CHECK (outcome = ANY (ARRAY['DONE'::text, 'FAILED'::text, 'SKIPPED'::text]));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_skipped_shape CHECK ((outcome <> 'SKIPPED'::text) OR ((reason IS NOT NULL) AND (fix_line IS NULL) AND (ending IS NULL)));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_step10_count CHECK ((step_no <> 10) OR ((found_count IS NOT NULL) = (outcome <> 'SKIPPED'::text)));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_step8_count CHECK ((step_no <> 8) OR ((found_count IS NOT NULL) AND (outcome <> 'SKIPPED'::text)));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_step_no_check CHECK ((step_no >= 1) AND (step_no <= 12));
ALTER TABLE guardops.build_crossing ADD CONSTRAINT build_crossing_written_by_check CHECK (length(btrim(written_by)) > 0);

ALTER TABLE guardops.build_crossing ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenancy_wall ON guardops.build_crossing AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());
CREATE POLICY weak_seat_read ON guardops.build_crossing AS PERMISSIVE FOR SELECT TO code_builder, harness_runner, proof_reader USING (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.build_crossing FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.build_crossing FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('actor', 'written_by');
CREATE TRIGGER audit_build_crossing AFTER INSERT OR UPDATE ON guardops.build_crossing FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER build_crossing_stamp BEFORE INSERT ON guardops.build_crossing FOR EACH ROW EXECUTE FUNCTION guardops.build_crossing_stamp();
CREATE TRIGGER guard_build_crossing BEFORE DELETE OR UPDATE ON guardops.build_crossing FOR EACH ROW EXECUTE FUNCTION guardops.guard_build_crossing();
CREATE TRIGGER guard_build_crossing_truncate BEFORE TRUNCATE ON guardops.build_crossing FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_build_crossing();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.build_crossing FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- agent_claim_record -----

CREATE TABLE guardops.agent_claim_record (
    account_id BIGINT DEFAULT 1 NOT NULL,
    id BIGINT NOT NULL,
    database_id BIGINT NOT NULL,
    their_id BIGINT NOT NULL,
    said_at TIMESTAMPTZ NOT NULL,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    rows_touched BIGINT NOT NULL,
    agent_name TEXT NOT NULL,
    taken_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.agent_claim_record ADD CONSTRAINT agent_claim_record_pkey PRIMARY KEY (id);
ALTER TABLE guardops.agent_claim_record ADD CONSTRAINT agent_claim_record_database_id_their_id_key UNIQUE (database_id, their_id);

CREATE UNIQUE INDEX agent_claim_record_database_id_their_id_key ON guardops.agent_claim_record USING btree (database_id, their_id);

ALTER TABLE guardops.agent_claim_record ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.agent_claim_record AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY guard_owner_read ON guardops.agent_claim_record AS PERMISSIVE FOR SELECT TO guard_owner USING (true);
CREATE POLICY proof_reader_read ON guardops.agent_claim_record AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.agent_claim_record AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.agent_claim_record FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_agent_claim_record AFTER INSERT OR UPDATE ON guardops.agent_claim_record FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.agent_claim_record FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- agent_claim_pull -----

CREATE TABLE guardops.agent_claim_pull (
    account_id BIGINT DEFAULT 1 NOT NULL,
    id BIGINT NOT NULL,
    database_id BIGINT NOT NULL,
    since_their_id BIGINT DEFAULT 0 NOT NULL,
    request_id BIGINT,
    state TEXT DEFAULT 'PENDING'::text NOT NULL,
    rows_taken INTEGER,
    failed_why TEXT,
    asked_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    asked_by TEXT DEFAULT SESSION_USER NOT NULL,
    ack_through BIGINT
);

ALTER TABLE guardops.agent_claim_pull ADD CONSTRAINT agent_claim_pull_pkey PRIMARY KEY (id);

ALTER TABLE guardops.agent_claim_pull ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.agent_claim_pull AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.agent_claim_pull AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.agent_claim_pull AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.agent_claim_pull FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_agent_claim_pull AFTER INSERT OR UPDATE ON guardops.agent_claim_pull FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.agent_claim_pull FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- round_log -----

CREATE TABLE guardops.round_log (
    id BIGINT NOT NULL,
    round TEXT NOT NULL,
    finished_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.round_log ADD CONSTRAINT round_log_pkey PRIMARY KEY (id);
ALTER TABLE guardops.round_log ADD CONSTRAINT round_log_round_check CHECK (round = ANY (ARRAY['FLOOR'::text, 'CHECKS'::text, 'SWEEP'::text]));

ALTER TABLE guardops.round_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY round_log_read ON guardops.round_log AS PERMISSIVE FOR SELECT TO code_builder, proof_reader USING (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.round_log FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_round_log AFTER INSERT OR UPDATE ON guardops.round_log FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_round_log BEFORE DELETE OR UPDATE ON guardops.round_log FOR EACH ROW EXECUTE FUNCTION guardops.guard_round_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.round_log FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- migration_review -----

CREATE TABLE guardops.migration_review (
    id BIGINT NOT NULL,
    account_id BIGINT NOT NULL,
    migration_file TEXT NOT NULL,
    review_kind TEXT NOT NULL,
    pr_number INTEGER,
    head_sha TEXT,
    critical_count INTEGER DEFAULT 0 NOT NULL,
    major_count INTEGER DEFAULT 0 NOT NULL,
    minor_count INTEGER DEFAULT 0 NOT NULL,
    trivial_count INTEGER DEFAULT 0 NOT NULL,
    findings_text TEXT,
    waiver_reason TEXT,
    recorded_by TEXT NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    file_sha TEXT
);

ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_pkey PRIMARY KEY (id);
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_critical_count_check CHECK (critical_count >= 0);
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_head_sha_check CHECK ((head_sha IS NULL) OR (head_sha ~ '^[0-9a-f]{7,40}$'::text));
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_kind_pr_or_sha CHECK (((review_kind = 'PR'::text) AND (pr_number IS NOT NULL)) OR ((review_kind = 'CLI'::text) AND (head_sha IS NOT NULL)));
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_major_count_check CHECK (major_count >= 0);
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_migration_file_check CHECK (migration_file ~ '^[0-9]+_[A-Za-z0-9_]+\.sql$'::text);
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_minor_count_check CHECK (minor_count >= 0);
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_recorded_by_check CHECK (btrim(recorded_by) <> ''::text);
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_review_kind_check CHECK (review_kind = ANY (ARRAY['CLI'::text, 'PR'::text]));
ALTER TABLE guardops.migration_review ADD CONSTRAINT migration_review_trivial_count_check CHECK (trivial_count >= 0);

CREATE INDEX idx_migration_review_lookup ON guardops.migration_review USING btree (account_id, migration_file);
CREATE INDEX migration_review_file_sha_idx ON guardops.migration_review USING btree (account_id, migration_file, file_sha) WHERE (file_sha IS NOT NULL);

ALTER TABLE guardops.migration_review ENABLE ROW LEVEL SECURITY;

CREATE POLICY migration_review_account_isolation ON guardops.migration_review AS RESTRICTIVE FOR ALL TO public USING (account_id = guardops.current_account());
CREATE POLICY migration_review_readers ON guardops.migration_review AS PERMISSIVE FOR SELECT TO code_builder, firing_seat USING (account_id = guardops.current_account());

CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.migration_review REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.migration_review REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.migration_review REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER migration_review_backdoor_lock BEFORE INSERT ON guardops.migration_review FOR EACH ROW EXECUTE FUNCTION guardops.guard_migration_review_insert();
CREATE TRIGGER migration_review_guard BEFORE DELETE OR UPDATE ON guardops.migration_review FOR EACH ROW EXECUTE FUNCTION guardops.guard_migration_review();
CREATE TRIGGER migration_review_guard_truncate BEFORE TRUNCATE ON guardops.migration_review FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_migration_review();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.migration_review FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- review_signer_key -----

CREATE TABLE guardops.review_signer_key (
    key_id TEXT NOT NULL,
    public_key BYTEA NOT NULL,
    status TEXT DEFAULT 'active'::text NOT NULL,
    note TEXT,
    at TIMESTAMPTZ DEFAULT now() NOT NULL,
    retired_at TIMESTAMPTZ
);

ALTER TABLE guardops.review_signer_key ADD CONSTRAINT review_signer_key_pkey PRIMARY KEY (key_id);
ALTER TABLE guardops.review_signer_key ADD CONSTRAINT review_signer_key_status_check CHECK (status = ANY (ARRAY['active'::text, 'retired'::text]));

ALTER TABLE guardops.review_signer_key ENABLE ROW LEVEL SECURITY;

CREATE POLICY review_signer_key_read ON guardops.review_signer_key AS PERMISSIVE FOR SELECT TO public USING (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.review_signer_key FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_review_signer_key AFTER INSERT OR UPDATE ON guardops.review_signer_key FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.review_signer_key FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- review_severity_log -----

CREATE TABLE guardops.review_severity_log (
    id BIGSERIAL NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    pr INTEGER NOT NULL,
    head TEXT NOT NULL,
    source TEXT NOT NULL,
    critical_count INTEGER DEFAULT 0 NOT NULL,
    major_count INTEGER DEFAULT 0 NOT NULL,
    minor_count INTEGER DEFAULT 0 NOT NULL,
    trivial_count INTEGER DEFAULT 0 NOT NULL,
    logged_by TEXT DEFAULT SESSION_USER NOT NULL,
    logged_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL
);

ALTER TABLE guardops.review_severity_log ADD CONSTRAINT review_severity_log_pkey PRIMARY KEY (id);
ALTER TABLE guardops.review_severity_log ADD CONSTRAINT review_severity_log_critical_count_check CHECK (critical_count >= 0);
ALTER TABLE guardops.review_severity_log ADD CONSTRAINT review_severity_log_head_check CHECK (head ~ '^[0-9a-f]{40}$'::text);
ALTER TABLE guardops.review_severity_log ADD CONSTRAINT review_severity_log_major_count_check CHECK (major_count >= 0);
ALTER TABLE guardops.review_severity_log ADD CONSTRAINT review_severity_log_minor_count_check CHECK (minor_count >= 0);
ALTER TABLE guardops.review_severity_log ADD CONSTRAINT review_severity_log_source_check CHECK (source = ANY (ARRAY['local'::text, 'scan'::text]));
ALTER TABLE guardops.review_severity_log ADD CONSTRAINT review_severity_log_trivial_count_check CHECK (trivial_count >= 0);

ALTER TABLE guardops.review_severity_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY account_isolation ON guardops.review_severity_log AS PERMISSIVE FOR ALL TO public USING (account_id = guardops.current_account());

CREATE TRIGGER audit_review_severity_log AFTER INSERT OR UPDATE ON guardops.review_severity_log FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_review_severity_log BEFORE DELETE OR UPDATE ON guardops.review_severity_log FOR EACH ROW EXECUTE FUNCTION guardops.guard_review_severity_log();
CREATE TRIGGER guard_review_severity_log_trunc BEFORE TRUNCATE ON guardops.review_severity_log FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_review_severity_log();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.review_severity_log REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.review_severity_log REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.review_severity_log REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.review_severity_log FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- review_round -----

CREATE TABLE guardops.review_round (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    pr INTEGER NOT NULL,
    round_no INTEGER NOT NULL,
    asked_by TEXT NOT NULL,
    slip_id BIGINT,
    asked_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    landed_at TIMESTAMPTZ,
    refused BOOLEAN DEFAULT false NOT NULL,
    gh_review_id BIGINT,
    deadline_at TIMESTAMPTZ DEFAULT (clock_timestamp() + '00:20:00'::interval) NOT NULL,
    last_heartbeat_at TIMESTAMPTZ,
    timed_out BOOLEAN DEFAULT false NOT NULL
);

ALTER TABLE guardops.review_round ADD CONSTRAINT review_round_pkey PRIMARY KEY (id);

CREATE UNIQUE INDEX review_round_pr_round_uq ON guardops.review_round USING btree (account_id, pr, round_no);
CREATE UNIQUE INDEX uq_review_round_gh_review_id ON guardops.review_round USING btree (account_id, pr, gh_review_id) WHERE (gh_review_id IS NOT NULL);

ALTER TABLE guardops.review_round ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenancy_wall ON guardops.review_round AS PERMISSIVE FOR ALL TO public USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER audit_review_round AFTER INSERT OR UPDATE ON guardops.review_round FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_review_round BEFORE DELETE OR UPDATE ON guardops.review_round FOR EACH ROW EXECUTE FUNCTION guardops.guard_review_round();
CREATE TRIGGER guard_review_round_truncate BEFORE TRUNCATE ON guardops.review_round FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_review_round();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.review_round REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.review_round REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.review_round REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.review_round FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- review_rate_limit -----

CREATE TABLE guardops.review_rate_limit (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    note TEXT NOT NULL,
    read_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    refused_round_id BIGINT,
    clears_at TIMESTAMPTZ
);

ALTER TABLE guardops.review_rate_limit ADD CONSTRAINT review_rate_limit_pkey PRIMARY KEY (id);

ALTER TABLE guardops.review_rate_limit ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenancy_wall ON guardops.review_rate_limit AS PERMISSIVE FOR ALL TO public USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER audit_review_rate_limit AFTER INSERT OR UPDATE ON guardops.review_rate_limit FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_review_rate_limit BEFORE DELETE OR UPDATE ON guardops.review_rate_limit FOR EACH ROW EXECUTE FUNCTION guardops.guard_review_rate_limit();
CREATE TRIGGER guard_review_rate_limit_truncate BEFORE TRUNCATE ON guardops.review_rate_limit FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_review_rate_limit();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.review_rate_limit REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.review_rate_limit REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.review_rate_limit REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.review_rate_limit FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- review_carry -----

CREATE TABLE guardops.review_carry (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    pr INTEGER NOT NULL,
    reviewed_head TEXT NOT NULL,
    fire_head TEXT NOT NULL,
    note TEXT NOT NULL,
    recorded_by TEXT DEFAULT SESSION_USER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.review_carry ADD CONSTRAINT review_carry_pkey PRIMARY KEY (id);
ALTER TABLE guardops.review_carry ADD CONSTRAINT review_carry_check CHECK (reviewed_head <> fire_head);
ALTER TABLE guardops.review_carry ADD CONSTRAINT review_carry_fire_head_check CHECK (fire_head ~ '^[0-9a-f]{40}$'::text);
ALTER TABLE guardops.review_carry ADD CONSTRAINT review_carry_note_check CHECK (length(btrim(note)) >= 10);
ALTER TABLE guardops.review_carry ADD CONSTRAINT review_carry_reviewed_head_check CHECK (reviewed_head ~ '^[0-9a-f]{40}$'::text);

ALTER TABLE guardops.review_carry ENABLE ROW LEVEL SECURITY;

CREATE POLICY account_isolation ON guardops.review_carry AS PERMISSIVE FOR ALL TO public USING (account_id = guardops.current_account());

CREATE TRIGGER audit_review_carry AFTER INSERT OR UPDATE ON guardops.review_carry FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_review_carry BEFORE DELETE OR UPDATE ON guardops.review_carry FOR EACH ROW EXECUTE FUNCTION guardops.guard_review_carry();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.review_carry REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.review_carry REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.review_carry REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.review_carry FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- phone_press -----

CREATE TABLE guardops.phone_press (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    offer_id BIGINT NOT NULL,
    update_id BIGINT NOT NULL,
    choice TEXT NOT NULL,
    chat_id BIGINT NOT NULL,
    board_id BIGINT,
    login TEXT DEFAULT SESSION_USER NOT NULL,
    pressed_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.phone_press ADD CONSTRAINT phone_press_pkey PRIMARY KEY (id);
ALTER TABLE guardops.phone_press ADD CONSTRAINT phone_press_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.phone_press ADD CONSTRAINT phone_press_offer_id_acct_fkey FOREIGN KEY (account_id, offer_id) REFERENCES guardops.phone_offer (account_id, id);
ALTER TABLE guardops.phone_press ADD CONSTRAINT phone_press_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES guardops.phone_offer (id);
ALTER TABLE guardops.phone_press ADD CONSTRAINT phone_press_update_id_key UNIQUE (update_id);
ALTER TABLE guardops.phone_press ADD CONSTRAINT phone_press_choice_check CHECK (choice = ANY (ARRAY['DO'::text, 'PARK'::text, 'IGNORE'::text, 'MORE'::text]));

CREATE UNIQUE INDEX phone_press_one_decision ON guardops.phone_press USING btree (offer_id) WHERE (choice <> 'MORE'::text);
CREATE UNIQUE INDEX phone_press_update_id_key ON guardops.phone_press USING btree (update_id);

ALTER TABLE guardops.phone_press ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.phone_press AS PERMISSIVE FOR SELECT TO code_builder, proof_reader USING (true);
CREATE POLICY postgres_read ON guardops.phone_press AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY tenancy_wall ON guardops.phone_press AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.phone_press FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_phone_press AFTER INSERT OR UPDATE ON guardops.phone_press FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_phone_press BEFORE INSERT OR DELETE OR UPDATE ON guardops.phone_press FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_phone_press_truncate BEFORE TRUNCATE ON guardops.phone_press FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.phone_press FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- phone_offer -----

CREATE TABLE guardops.phone_offer (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    about TEXT NOT NULL,
    fix_plain TEXT NOT NULL,
    do_action TEXT NOT NULL,
    ring_id BIGINT,
    bell_id BIGINT,
    board_id BIGINT,
    nonce TEXT NOT NULL,
    offered_by TEXT DEFAULT SESSION_USER NOT NULL,
    offered_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.phone_offer ADD CONSTRAINT phone_offer_pkey PRIMARY KEY (id);
ALTER TABLE guardops.phone_offer ADD CONSTRAINT phone_offer_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.phone_offer ADD CONSTRAINT phone_offer_about_check CHECK (length(btrim(about)) > 0);
ALTER TABLE guardops.phone_offer ADD CONSTRAINT phone_offer_do_action_check CHECK (do_action = ANY (ARRAY['STRONG_SEAT_FIX'::text, 'PARK_BOARD'::text, 'RING_TO_SUMMARY'::text, 'FACTORY_OFF'::text, 'FACTORY_ON'::text]));
ALTER TABLE guardops.phone_offer ADD CONSTRAINT phone_offer_fix_plain_check CHECK (length(btrim(fix_plain)) > 0);
ALTER TABLE guardops.phone_offer ADD CONSTRAINT phone_offer_nonce_check CHECK (nonce ~ '^[0-9a-f]{12}$'::text);

CREATE UNIQUE INDEX phone_offer_id_account_key ON guardops.phone_offer USING btree (id, account_id);

ALTER TABLE guardops.phone_offer ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.phone_offer AS PERMISSIVE FOR SELECT TO code_builder, proof_reader USING (true);
CREATE POLICY postgres_read ON guardops.phone_offer AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY tenancy_wall ON guardops.phone_offer AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.phone_offer FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_phone_offer AFTER INSERT OR UPDATE ON guardops.phone_offer FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_phone_offer BEFORE INSERT OR DELETE OR UPDATE ON guardops.phone_offer FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_phone_offer_truncate BEFORE TRUNCATE ON guardops.phone_offer FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.phone_offer FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- phone_menu_sent -----

CREATE TABLE guardops.phone_menu_sent (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    update_id BIGINT,
    request_id BIGINT,
    login TEXT DEFAULT SESSION_USER NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.phone_menu_sent ADD CONSTRAINT phone_menu_sent_pkey PRIMARY KEY (id);
ALTER TABLE guardops.phone_menu_sent ADD CONSTRAINT phone_menu_sent_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);

ALTER TABLE guardops.phone_menu_sent ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.phone_menu_sent AS PERMISSIVE FOR SELECT TO code_builder, firing_seat, proof_reader USING (true);
CREATE POLICY postgres_read ON guardops.phone_menu_sent AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY tenancy_wall ON guardops.phone_menu_sent AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.phone_menu_sent FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_phone_menu_sent AFTER INSERT OR UPDATE ON guardops.phone_menu_sent FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_phone_menu_sent BEFORE INSERT OR DELETE OR UPDATE ON guardops.phone_menu_sent FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_phone_menu_sent_truncate BEFORE TRUNCATE ON guardops.phone_menu_sent FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.phone_menu_sent FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- phone_menu_press -----

CREATE TABLE guardops.phone_menu_press (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    update_id BIGINT NOT NULL,
    data TEXT NOT NULL,
    chat_id BIGINT NOT NULL,
    login TEXT DEFAULT SESSION_USER NOT NULL,
    pressed_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.phone_menu_press ADD CONSTRAINT phone_menu_press_pkey PRIMARY KEY (id);
ALTER TABLE guardops.phone_menu_press ADD CONSTRAINT phone_menu_press_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.phone_menu_press ADD CONSTRAINT phone_menu_press_update_id_key UNIQUE (update_id);
ALTER TABLE guardops.phone_menu_press ADD CONSTRAINT phone_menu_press_data_check CHECK (data ~~ 'mn:%'::text);

CREATE UNIQUE INDEX phone_menu_press_update_id_key ON guardops.phone_menu_press USING btree (update_id);

ALTER TABLE guardops.phone_menu_press ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.phone_menu_press AS PERMISSIVE FOR SELECT TO code_builder, firing_seat, proof_reader USING (true);
CREATE POLICY postgres_read ON guardops.phone_menu_press AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY tenancy_wall ON guardops.phone_menu_press AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.phone_menu_press FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_phone_menu_press AFTER INSERT OR UPDATE ON guardops.phone_menu_press FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_phone_menu_press BEFORE INSERT OR DELETE OR UPDATE ON guardops.phone_menu_press FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_phone_menu_press_truncate BEFORE TRUNCATE ON guardops.phone_menu_press FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.phone_menu_press FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- order_tally -----

CREATE TABLE guardops.order_tally (
    account_id BIGINT DEFAULT 1 NOT NULL,
    order_id BIGINT NOT NULL,
    ordered INTEGER,
    built INTEGER,
    proven INTEGER,
    missing INTEGER,
    dropped INTEGER,
    extra INTEGER,
    worked_out_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    trouble TEXT
);

ALTER TABLE guardops.order_tally ADD CONSTRAINT order_tally_pkey PRIMARY KEY (order_id);
ALTER TABLE guardops.order_tally ADD CONSTRAINT order_tally_order_id_fkey FOREIGN KEY (order_id) REFERENCES guardops.job_order (id);

ALTER TABLE guardops.order_tally ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.order_tally AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.order_tally AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.order_tally AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_tally FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_order_tally AFTER INSERT OR UPDATE ON guardops.order_tally FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.order_tally FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- order_queue -----

CREATE TABLE guardops.order_queue (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    kind TEXT NOT NULL,
    queue_id BIGINT,
    position INTEGER,
    job_name TEXT,
    files TEXT[],
    db_objects TEXT[],
    spec JSONB,
    order_id BIGINT,
    reason TEXT,
    actor TEXT NOT NULL,
    login TEXT DEFAULT SESSION_USER NOT NULL,
    at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_pkey PRIMARY KEY (id);
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_order_id_acct_fkey FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id);
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_order_id_fkey FOREIGN KEY (order_id) REFERENCES guardops.job_order (id);
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_queue_id_acct_fkey FOREIGN KEY (account_id, queue_id) REFERENCES guardops.order_queue (account_id, id);
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_queue_id_fkey FOREIGN KEY (queue_id) REFERENCES guardops.order_queue (id);
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_drop_says_why CHECK ((kind <> 'DROP'::text) OR (length(btrim(COALESCE(reason, ''::text))) >= 10));
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_end_names_item CHECK ((kind = 'QUEUE'::text) OR (queue_id IS NOT NULL));
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_item_shape CHECK ((kind <> 'QUEUE'::text) OR ((queue_id IS NULL) AND ("position" IS NOT NULL) AND (length(btrim(COALESCE(job_name, ''::text))) > 0) AND (jsonb_typeof(spec) = 'array'::text) AND (jsonb_array_length(spec) > 0)));
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_kind_check CHECK (kind = ANY (ARRAY['QUEUE'::text, 'OPENED'::text, 'DROP'::text]));
ALTER TABLE guardops.order_queue ADD CONSTRAINT order_queue_opened_names_order CHECK ((kind <> 'OPENED'::text) OR (order_id IS NOT NULL));

CREATE UNIQUE INDEX order_queue_id_account_key ON guardops.order_queue USING btree (id, account_id);
CREATE UNIQUE INDEX order_queue_one_end ON guardops.order_queue USING btree (queue_id) WHERE (kind = ANY (ARRAY['OPENED'::text, 'DROP'::text]));

ALTER TABLE guardops.order_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.order_queue AS PERMISSIVE FOR SELECT TO code_builder, firing_seat, proof_reader USING (true);
CREATE POLICY postgres_read ON guardops.order_queue AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY tenancy_wall ON guardops.order_queue AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_queue FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_order_queue AFTER INSERT OR UPDATE ON guardops.order_queue FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_order_queue BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_queue FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_order_queue_truncate BEFORE TRUNCATE ON guardops.order_queue FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.order_queue FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- order_hold -----

CREATE TABLE guardops.order_hold (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    order_id BIGINT NOT NULL,
    kind TEXT NOT NULL,
    hold_id BIGINT,
    reason TEXT NOT NULL,
    actor TEXT NOT NULL,
    login TEXT DEFAULT SESSION_USER NOT NULL,
    at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.order_hold ADD CONSTRAINT order_hold_pkey PRIMARY KEY (id);
ALTER TABLE guardops.order_hold ADD CONSTRAINT order_hold_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.order_hold ADD CONSTRAINT order_hold_hold_id_acct_fkey FOREIGN KEY (account_id, hold_id) REFERENCES guardops.order_hold (account_id, id);
ALTER TABLE guardops.order_hold ADD CONSTRAINT order_hold_hold_id_fkey FOREIGN KEY (hold_id) REFERENCES guardops.order_hold (id);
ALTER TABLE guardops.order_hold ADD CONSTRAINT order_hold_order_id_acct_fkey FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id);
ALTER TABLE guardops.order_hold ADD CONSTRAINT order_hold_order_id_fkey FOREIGN KEY (order_id) REFERENCES guardops.job_order (id);
ALTER TABLE guardops.order_hold ADD CONSTRAINT order_hold_kind_check CHECK (kind = ANY (ARRAY['PLACE'::text, 'LIFT'::text]));
ALTER TABLE guardops.order_hold ADD CONSTRAINT order_hold_lift_names_place CHECK ((kind = 'LIFT'::text) = (hold_id IS NOT NULL));
ALTER TABLE guardops.order_hold ADD CONSTRAINT order_hold_reason_check CHECK (length(btrim(reason)) >= 10);

CREATE INDEX order_hold_by_order ON guardops.order_hold USING btree (order_id);
CREATE UNIQUE INDEX order_hold_id_account_key ON guardops.order_hold USING btree (id, account_id);
CREATE UNIQUE INDEX order_hold_one_lift ON guardops.order_hold USING btree (hold_id) WHERE (kind = 'LIFT'::text);

ALTER TABLE guardops.order_hold ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.order_hold AS PERMISSIVE FOR SELECT TO code_builder, firing_seat, proof_reader USING (true);
CREATE POLICY postgres_read ON guardops.order_hold AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY tenancy_wall ON guardops.order_hold AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_hold FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_order_hold AFTER INSERT OR UPDATE ON guardops.order_hold FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_order_hold BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_hold FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_order_hold_truncate BEFORE TRUNCATE ON guardops.order_hold FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.order_hold FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- order_file_seen -----

CREATE TABLE guardops.order_file_seen (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    order_id BIGINT NOT NULL,
    sha TEXT NOT NULL,
    path TEXT NOT NULL,
    read_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    parts_landed INTEGER NOT NULL,
    parts_skipped INTEGER NOT NULL,
    read_by TEXT DEFAULT SESSION_USER NOT NULL
);

ALTER TABLE guardops.order_file_seen ADD CONSTRAINT order_file_seen_pkey PRIMARY KEY (order_id);
ALTER TABLE guardops.order_file_seen ADD CONSTRAINT order_file_seen_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.order_file_seen ADD CONSTRAINT order_file_seen_order_fk FOREIGN KEY (order_id) REFERENCES guardops.job_order (id) ON DELETE RESTRICT;
ALTER TABLE guardops.order_file_seen ADD CONSTRAINT order_file_seen_order_id_acct_fkey FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id);
ALTER TABLE guardops.order_file_seen ADD CONSTRAINT order_file_seen_counts CHECK ((parts_landed >= 0) AND (parts_skipped >= 0));
ALTER TABLE guardops.order_file_seen ADD CONSTRAINT order_file_seen_path_nonblank CHECK (length(btrim(path)) > 0);
ALTER TABLE guardops.order_file_seen ADD CONSTRAINT order_file_seen_sha_shape CHECK (sha ~ '^[0-9a-f]{40}$'::text);

ALTER TABLE guardops.order_file_seen ENABLE ROW LEVEL SECURITY;

CREATE POLICY order_file_seen_read ON guardops.order_file_seen AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY tenancy_wall ON guardops.order_file_seen AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_file_seen FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.order_file_seen FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('read_by');
CREATE TRIGGER audit_order_file_seen AFTER INSERT OR UPDATE ON guardops.order_file_seen FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER floor_watch BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_file_seen FOR EACH ROW EXECUTE FUNCTION guardops.floor_check('ORDERBOOK');
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.order_file_seen FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- order_end -----

CREATE TABLE guardops.order_end (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    order_id BIGINT NOT NULL,
    kind TEXT NOT NULL,
    reason TEXT NOT NULL,
    hold_id BIGINT,
    actor TEXT NOT NULL,
    login TEXT DEFAULT SESSION_USER NOT NULL,
    at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.order_end ADD CONSTRAINT order_end_pkey PRIMARY KEY (id);
ALTER TABLE guardops.order_end ADD CONSTRAINT order_end_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.order_end ADD CONSTRAINT order_end_hold_id_acct_fkey FOREIGN KEY (account_id, hold_id) REFERENCES guardops.order_hold (account_id, id);
ALTER TABLE guardops.order_end ADD CONSTRAINT order_end_hold_id_fkey FOREIGN KEY (hold_id) REFERENCES guardops.order_hold (id);
ALTER TABLE guardops.order_end ADD CONSTRAINT order_end_order_id_acct_fkey FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id);
ALTER TABLE guardops.order_end ADD CONSTRAINT order_end_order_id_fkey FOREIGN KEY (order_id) REFERENCES guardops.job_order (id);
ALTER TABLE guardops.order_end ADD CONSTRAINT order_end_order_id_key UNIQUE (order_id);
ALTER TABLE guardops.order_end ADD CONSTRAINT order_end_kind_check CHECK (kind = 'ABANDONED'::text);
ALTER TABLE guardops.order_end ADD CONSTRAINT order_end_reason_check CHECK (length(btrim(reason)) >= 20);

CREATE UNIQUE INDEX order_end_order_id_key ON guardops.order_end USING btree (order_id);

ALTER TABLE guardops.order_end ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.order_end AS PERMISSIVE FOR SELECT TO code_builder, firing_seat, proof_reader USING (true);
CREATE POLICY postgres_read ON guardops.order_end AS PERMISSIVE FOR SELECT TO postgres USING (true);
CREATE POLICY tenancy_wall ON guardops.order_end AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_end FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_order_end AFTER INSERT OR UPDATE ON guardops.order_end FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guard_order_end BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_end FOR EACH ROW EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER guard_order_end_truncate BEFORE TRUNCATE ON guardops.order_end FOR EACH STATEMENT EXECUTE FUNCTION guardops.guard_append_only_log();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.order_end FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- order_amendment -----

CREATE TABLE guardops.order_amendment (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    order_id BIGINT NOT NULL,
    kind TEXT NOT NULL,
    target TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'PENDING'::text NOT NULL,
    requested_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    decided_at TIMESTAMPTZ,
    superseded_by BIGINT,
    outcome TEXT
);

ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_pkey PRIMARY KEY (id);
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_order_id_acct_fkey FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id);
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_order_id_fkey FOREIGN KEY (order_id) REFERENCES guardops.job_order (id) ON DELETE CASCADE;
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_decided_pair CHECK ((status = 'PENDING'::text) = (decided_at IS NULL));
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_kind_chk CHECK (kind = ANY (ARRAY['FILE'::text, 'DB_OBJECT'::text, 'JOB'::text, 'CHECK'::text, 'REHEARSAL'::text, 'FIRED'::text]));
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_outcome_domain CHECK ((outcome IS NULL) OR (outcome = ANY (ARRAY['PASS'::text, 'FAIL'::text])));
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_outcome_required CHECK ((kind = ANY (ARRAY['CHECK'::text, 'REHEARSAL'::text])) = (outcome IS NOT NULL));
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_reason_nonempty CHECK (length(btrim(reason)) > 0);
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_status_chk CHECK (status = ANY (ARRAY['PENDING'::text, 'APPROVED'::text, 'DENIED'::text]));
ALTER TABLE guardops.order_amendment ADD CONSTRAINT order_amendment_target_nonempty CHECK (length(btrim(target)) > 0);

ALTER TABLE guardops.order_amendment ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.order_amendment AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.order_amendment AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.order_amendment AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_amendment FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER aab_login_signs_the_row BEFORE INSERT OR UPDATE ON guardops.order_amendment FOR EACH ROW EXECUTE FUNCTION guardops.login_signs_the_row('requested_by');
CREATE TRIGGER audit_order_amendment AFTER INSERT OR UPDATE ON guardops.order_amendment FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER door_only_gate BEFORE INSERT OR UPDATE ON guardops.order_amendment FOR EACH ROW EXECUTE FUNCTION guardops.door_only_gate();
CREATE TRIGGER floor_watch BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_amendment FOR EACH ROW EXECUTE FUNCTION guardops.floor_check('ORDERBOOK');
CREATE TRIGGER guard_order_amendment BEFORE INSERT OR DELETE OR UPDATE ON guardops.order_amendment FOR EACH ROW EXECUTE FUNCTION guardops.guard_order_amendment();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.order_amendment FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- fire_review_scan -----

CREATE TABLE guardops.fire_review_scan (
    id BIGINT NOT NULL,
    pr INTEGER NOT NULL,
    head TEXT NOT NULL,
    looked BOOLEAN NOT NULL,
    latest_verdict_at_head TEXT,
    open_findings INTEGER NOT NULL,
    summary_clean BOOLEAN,
    raw JSONB NOT NULL,
    recorded_by TEXT DEFAULT SESSION_USER NOT NULL,
    checked_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.fire_review_scan ADD CONSTRAINT fire_review_scan_pkey PRIMARY KEY (id);

CREATE TRIGGER audit_fire_review_scan AFTER INSERT OR UPDATE ON guardops.fire_review_scan FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.fire_review_scan REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.fire_review_scan REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.fire_review_scan REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.fire_review_scan FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- fire_review_request -----

CREATE TABLE guardops.fire_review_request (
    request_id BIGINT NOT NULL,
    pr INTEGER NOT NULL,
    asked_by TEXT DEFAULT SESSION_USER NOT NULL,
    at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.fire_review_request ADD CONSTRAINT fire_review_request_pkey PRIMARY KEY (request_id);

CREATE TRIGGER audit_fire_review_request AFTER INSERT OR UPDATE ON guardops.fire_review_request FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.fire_review_request FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- fire_review -----

CREATE TABLE guardops.fire_review (
    id BIGINT NOT NULL,
    gh_review_id BIGINT NOT NULL,
    pr INTEGER NOT NULL,
    head TEXT NOT NULL,
    reviewer TEXT NOT NULL,
    verdict TEXT NOT NULL,
    submitted_at TIMESTAMPTZ,
    recorded_by TEXT DEFAULT SESSION_USER NOT NULL,
    at TIMESTAMPTZ DEFAULT now() NOT NULL,
    checked_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.fire_review ADD CONSTRAINT fire_review_pkey PRIMARY KEY (id);
ALTER TABLE guardops.fire_review ADD CONSTRAINT fire_review_gh_review_id_key UNIQUE (gh_review_id);

CREATE UNIQUE INDEX fire_review_gh_review_id_key ON guardops.fire_review USING btree (gh_review_id);

CREATE TRIGGER audit_fire_review AFTER INSERT OR UPDATE ON guardops.fire_review FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.fire_review FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- fire_pass -----

CREATE TABLE guardops.fire_pass (
    id BIGINT NOT NULL,
    request_id BIGINT NOT NULL,
    head TEXT NOT NULL,
    md5 TEXT NOT NULL,
    pass_path TEXT NOT NULL,
    evidence JSONB NOT NULL,
    fired_by TEXT DEFAULT SESSION_USER NOT NULL,
    at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.fire_pass ADD CONSTRAINT fire_pass_pkey PRIMARY KEY (id);

CREATE TRIGGER audit_fire_pass AFTER INSERT OR UPDATE ON guardops.fire_pass FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.fire_pass REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.fire_pass REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.fire_pass REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.fire_pass FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- fire_fetch_meta -----

CREATE TABLE guardops.fire_fetch_meta (
    request_id BIGINT NOT NULL,
    sha TEXT NOT NULL,
    path TEXT NOT NULL,
    pr INTEGER,
    fetched_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.fire_fetch_meta ADD CONSTRAINT fire_fetch_meta_pkey PRIMARY KEY (request_id);
ALTER TABLE guardops.fire_fetch_meta ADD CONSTRAINT fire_fetch_meta_path_check CHECK (path ~ '^migrations/[0-9A-Za-z_.-]+\.sql$'::text);
ALTER TABLE guardops.fire_fetch_meta ADD CONSTRAINT fire_fetch_meta_sha_check CHECK (sha ~ '^[0-9a-f]{40}$'::text);

CREATE TRIGGER audit_fire_fetch_meta AFTER INSERT OR UPDATE ON guardops.fire_fetch_meta FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.fire_fetch_meta REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.fire_fetch_meta REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.fire_fetch_meta REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.fire_fetch_meta FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- fire_attestation_used -----

CREATE TABLE guardops.fire_attestation_used (
    sig_hex TEXT NOT NULL,
    head TEXT NOT NULL,
    md5 TEXT NOT NULL,
    request_id BIGINT NOT NULL,
    key_id TEXT NOT NULL,
    fired_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.fire_attestation_used ADD CONSTRAINT fire_attestation_used_pkey PRIMARY KEY (sig_hex);

CREATE UNIQUE INDEX fire_attestation_used_request_once ON guardops.fire_attestation_used USING btree (request_id);

ALTER TABLE guardops.fire_attestation_used ENABLE ROW LEVEL SECURITY;

CREATE POLICY guard_owner_insert ON guardops.fire_attestation_used AS PERMISSIVE FOR INSERT TO guard_owner WITH CHECK (true);

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.fire_attestation_used FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_fire_attestation_used AFTER INSERT OR UPDATE ON guardops.fire_attestation_used FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.fire_attestation_used FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- retire_ask -----

CREATE TABLE guardops.retire_ask (
    id BIGINT NOT NULL,
    account_id BIGINT NOT NULL,
    object_name TEXT NOT NULL,
    object_kind TEXT NOT NULL,
    what_it_did TEXT NOT NULL,
    why_dead TEXT NOT NULL,
    proof TEXT NOT NULL,
    asked_by TEXT NOT NULL,
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    asked_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.retire_ask ADD CONSTRAINT retire_ask_pkey PRIMARY KEY (id);
ALTER TABLE guardops.retire_ask ADD CONSTRAINT retire_ask_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.retire_ask ADD CONSTRAINT retire_ask_approved_complete CHECK (((approved_by IS NULL) AND (approved_at IS NULL)) OR ((approved_by IS NOT NULL) AND (btrim(approved_by) <> ''::text) AND (approved_at IS NOT NULL)));
ALTER TABLE guardops.retire_ask ADD CONSTRAINT retire_ask_asked_by_check CHECK (btrim(asked_by) <> ''::text);
ALTER TABLE guardops.retire_ask ADD CONSTRAINT retire_ask_object_kind_check CHECK (object_kind = ANY (ARRAY['FUNCTION'::text, 'TABLE'::text, 'TRIGGER'::text, 'VIEW'::text]));
ALTER TABLE guardops.retire_ask ADD CONSTRAINT retire_ask_object_name_check CHECK (btrim(object_name) <> ''::text);
ALTER TABLE guardops.retire_ask ADD CONSTRAINT retire_ask_proof_check CHECK (btrim(proof) <> ''::text);
ALTER TABLE guardops.retire_ask ADD CONSTRAINT retire_ask_what_it_did_check CHECK (btrim(what_it_did) <> ''::text);
ALTER TABLE guardops.retire_ask ADD CONSTRAINT retire_ask_why_dead_check CHECK (btrim(why_dead) <> ''::text);

CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.retire_ask REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.retire_ask REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.retire_ask REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.retire_ask FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- seat_ask -----

CREATE TABLE guardops.seat_ask (
    account_id BIGINT DEFAULT 1 NOT NULL,
    id BIGINT NOT NULL,
    asked_by TEXT NOT NULL,
    asked_of TEXT NOT NULL,
    about_board BIGINT,
    question TEXT NOT NULL,
    choices JSONB DEFAULT '[]'::jsonb NOT NULL,
    recommend TEXT,
    state TEXT DEFAULT 'OPEN'::text NOT NULL,
    answer TEXT,
    because TEXT,
    asked_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    answered_by TEXT,
    answered_at TIMESTAMPTZ
);

ALTER TABLE guardops.seat_ask ADD CONSTRAINT seat_ask_pkey PRIMARY KEY (id);
ALTER TABLE guardops.seat_ask ADD CONSTRAINT seat_ask_state_check CHECK (state = ANY (ARRAY['OPEN'::text, 'ANSWERED'::text, 'WITHDRAWN'::text]));

ALTER TABLE guardops.seat_ask ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.seat_ask AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY proof_reader_read ON guardops.seat_ask AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.seat_ask AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.seat_ask FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_seat_ask AFTER INSERT OR UPDATE ON guardops.seat_ask FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.seat_ask FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- press_taint -----

CREATE TABLE guardops.press_taint (
    id BIGSERIAL NOT NULL,
    account_id BIGINT DEFAULT guardops.floor_account() NOT NULL,
    tainted_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    tainted_by TEXT DEFAULT (SESSION_USER)::text NOT NULL,
    target_table TEXT NOT NULL,
    target_id BIGINT NOT NULL,
    why TEXT NOT NULL
);

ALTER TABLE guardops.press_taint ADD CONSTRAINT press_taint_pkey PRIMARY KEY (id);
ALTER TABLE guardops.press_taint ADD CONSTRAINT press_taint_target_table_target_id_key UNIQUE (target_id, target_table);

CREATE UNIQUE INDEX press_taint_target_table_target_id_key ON guardops.press_taint USING btree (target_table, target_id);

CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.press_taint REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.press_taint REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.press_taint REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.press_taint FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- handoff_floor_claim -----

CREATE TABLE guardops.handoff_floor_claim (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    handoff_board_id BIGINT NOT NULL,
    claim_text TEXT NOT NULL,
    check_table TEXT NOT NULL,
    check_id_col TEXT NOT NULL,
    check_id_val TEXT NOT NULL,
    check_field TEXT NOT NULL,
    expected_val TEXT NOT NULL,
    filed_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE guardops.handoff_floor_claim ADD CONSTRAINT handoff_floor_claim_pkey PRIMARY KEY (id);
ALTER TABLE guardops.handoff_floor_claim ADD CONSTRAINT handoff_floor_claim_handoff_board_id_fkey FOREIGN KEY (handoff_board_id) REFERENCES guardops.board_item (id);

CREATE INDEX handoff_floor_claim_board_idx ON guardops.handoff_floor_claim USING btree (handoff_board_id);

ALTER TABLE guardops.handoff_floor_claim ENABLE ROW LEVEL SECURITY;

CREATE POLICY handoff_floor_claim_account ON guardops.handoff_floor_claim AS PERMISSIVE FOR ALL TO public USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.handoff_floor_claim REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.handoff_floor_claim REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.handoff_floor_claim REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.handoff_floor_claim FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- handoff_check_whitelist -----

CREATE TABLE guardops.handoff_check_whitelist (
    check_table TEXT NOT NULL,
    check_id_col TEXT NOT NULL,
    check_field TEXT NOT NULL
);

ALTER TABLE guardops.handoff_check_whitelist ADD CONSTRAINT handoff_check_whitelist_pkey PRIMARY KEY (check_table);

CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.handoff_check_whitelist REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.handoff_check_whitelist REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.handoff_check_whitelist REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.handoff_check_whitelist FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- batch_read -----

CREATE TABLE guardops.batch_read (
    id BIGSERIAL NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    plan_id BIGINT NOT NULL,
    page_snapshot TEXT NOT NULL,
    read_by TEXT NOT NULL,
    read_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL
);

ALTER TABLE guardops.batch_read ADD CONSTRAINT batch_read_pkey PRIMARY KEY (id);
ALTER TABLE guardops.batch_read ADD CONSTRAINT batch_read_account_plan_unique UNIQUE (account_id, plan_id);

CREATE UNIQUE INDEX batch_read_account_plan_unique ON guardops.batch_read USING btree (account_id, plan_id);

CREATE TRIGGER guard_batch_read BEFORE INSERT OR DELETE OR UPDATE ON guardops.batch_read FOR EACH ROW EXECUTE FUNCTION guardops.guard_batch_read();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.batch_read FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- batch_page_read -----

CREATE TABLE guardops.batch_page_read (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    plan_board_id BIGINT NOT NULL,
    page_title TEXT NOT NULL,
    page_detail TEXT,
    job_ids BIGINT[] NOT NULL,
    frozen_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    frozen_by TEXT DEFAULT SESSION_USER NOT NULL
);

ALTER TABLE guardops.batch_page_read ADD CONSTRAINT batch_page_read_pkey PRIMARY KEY (id);
ALTER TABLE guardops.batch_page_read ADD CONSTRAINT batch_page_read_plan_board_id_fkey FOREIGN KEY (plan_board_id) REFERENCES guardops.board_item (id);
ALTER TABLE guardops.batch_page_read ADD CONSTRAINT batch_page_read_account_id_plan_board_id_key UNIQUE (account_id, plan_board_id);

CREATE UNIQUE INDEX batch_page_read_account_id_plan_board_id_key ON guardops.batch_page_read USING btree (account_id, plan_board_id);

ALTER TABLE guardops.batch_page_read ENABLE ROW LEVEL SECURITY;

CREATE POLICY batch_page_read_account ON guardops.batch_page_read AS PERMISSIVE FOR ALL TO public USING (account_id = guardops.current_account());

CREATE TRIGGER guard_batch_page_read BEFORE DELETE OR UPDATE ON guardops.batch_page_read FOR EACH ROW EXECUTE FUNCTION guardops.guard_batch_page_read();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.batch_page_read FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- batch_freeze -----

CREATE TABLE guardops.batch_freeze (
    id BIGSERIAL NOT NULL,
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    plan_board_id BIGINT NOT NULL,
    frozen_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    frozen_by TEXT NOT NULL,
    page_title TEXT NOT NULL,
    page_detail TEXT,
    jobs_snapshot JSONB NOT NULL
);

ALTER TABLE guardops.batch_freeze ADD CONSTRAINT batch_freeze_pkey PRIMARY KEY (id);
ALTER TABLE guardops.batch_freeze ADD CONSTRAINT batch_freeze_account_fk FOREIGN KEY (account_id) REFERENCES guardops.account (id);
ALTER TABLE guardops.batch_freeze ADD CONSTRAINT batch_freeze_account_plan_uniq UNIQUE (account_id, plan_board_id);

CREATE UNIQUE INDEX batch_freeze_account_plan_uniq ON guardops.batch_freeze USING btree (account_id, plan_board_id);

CREATE TRIGGER guard_batch_freeze_tg BEFORE INSERT OR DELETE OR UPDATE ON guardops.batch_freeze FOR EACH ROW EXECUTE FUNCTION guardops.guard_batch_freeze();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.batch_freeze FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- look_taken -----

CREATE TABLE guardops.look_taken (
    id BIGINT NOT NULL,
    account_id BIGINT DEFAULT guardops.floor_account() NOT NULL,
    login TEXT NOT NULL,
    taken_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    subject TEXT,
    seen JSONB NOT NULL
);

ALTER TABLE guardops.look_taken ADD CONSTRAINT look_taken_pkey PRIMARY KEY (id);
ALTER TABLE guardops.look_taken ADD CONSTRAINT look_taken_account_id_fkey FOREIGN KEY (account_id) REFERENCES guardops.account (id);

ALTER TABLE guardops.look_taken ENABLE ROW LEVEL SECURITY;
ALTER TABLE guardops.look_taken FORCE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.look_taken AS PERMISSIVE FOR SELECT TO code_builder, guard_owner, proof_reader USING (true);
CREATE POLICY take_look_write ON guardops.look_taken AS PERMISSIVE FOR INSERT TO guard_owner WITH CHECK (true);
CREATE POLICY tenancy_wall ON guardops.look_taken AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.look_taken FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_look_taken AFTER INSERT OR UPDATE ON guardops.look_taken FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.look_taken FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- laws_served -----

CREATE TABLE guardops.laws_served (
    id BIGSERIAL NOT NULL,
    served_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    job_ref TEXT NOT NULL,
    files TEXT[],
    db_objects TEXT[],
    groups TEXT[],
    law_ids BIGINT[] NOT NULL,
    law_count INTEGER NOT NULL,
    unknown_groups TEXT[],
    served_to TEXT NOT NULL
);

ALTER TABLE guardops.laws_served ADD CONSTRAINT laws_served_pkey PRIMARY KEY (id);

ALTER TABLE guardops.laws_served ENABLE ROW LEVEL SECURITY;

CREATE POLICY laws_served_code_builder_select ON guardops.laws_served AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY laws_served_proof_reader_select ON guardops.laws_served AS PERMISSIVE FOR SELECT TO guardops_guard_reader USING (true);

CREATE TRIGGER audit_laws_served AFTER INSERT OR UPDATE ON guardops.laws_served FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.laws_served REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.laws_served REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.laws_served REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.laws_served FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- law_group_member -----

CREATE TABLE guardops.law_group_member (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    law_id BIGINT NOT NULL,
    group_code TEXT NOT NULL,
    noticed_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    noticed_by TEXT DEFAULT SESSION_USER NOT NULL
);

ALTER TABLE guardops.law_group_member ADD CONSTRAINT law_group_member_pkey PRIMARY KEY (id);
ALTER TABLE guardops.law_group_member ADD CONSTRAINT law_group_member_group_fk FOREIGN KEY (account_id, group_code) REFERENCES guardops.law_group (account_id, code);
ALTER TABLE guardops.law_group_member ADD CONSTRAINT law_group_member_law_fk FOREIGN KEY (law_id) REFERENCES guardops.law (id);
ALTER TABLE guardops.law_group_member ADD CONSTRAINT law_group_member_one_per_law UNIQUE (account_id, law_id);

CREATE INDEX law_group_member_by_group_idx ON guardops.law_group_member USING btree (account_id, group_code);
CREATE UNIQUE INDEX law_group_member_one_per_law ON guardops.law_group_member USING btree (account_id, law_id);

ALTER TABLE guardops.law_group_member ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.law_group_member AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY guard_owner_read ON guardops.law_group_member AS PERMISSIVE FOR SELECT TO guard_owner USING (true);
CREATE POLICY proof_reader_read ON guardops.law_group_member AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.law_group_member AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.law_group_member FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_law_group_member AFTER INSERT OR UPDATE ON guardops.law_group_member FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.law_group_member REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.law_group_member REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.law_group_member REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.law_group_member FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();

-- ----- law_group -----

CREATE TABLE guardops.law_group (
    account_id BIGINT DEFAULT guardops.current_account() NOT NULL,
    id BIGINT NOT NULL,
    code TEXT NOT NULL,
    title TEXT NOT NULL,
    noticed_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    noticed_by TEXT DEFAULT SESSION_USER NOT NULL
);

ALTER TABLE guardops.law_group ADD CONSTRAINT law_group_pkey PRIMARY KEY (id);
ALTER TABLE guardops.law_group ADD CONSTRAINT law_group_code_once UNIQUE (account_id, code);

CREATE UNIQUE INDEX law_group_code_once ON guardops.law_group USING btree (account_id, code);

ALTER TABLE guardops.law_group ENABLE ROW LEVEL SECURITY;

CREATE POLICY code_builder_read ON guardops.law_group AS PERMISSIVE FOR SELECT TO code_builder USING (true);
CREATE POLICY guard_owner_read ON guardops.law_group AS PERMISSIVE FOR SELECT TO guard_owner USING (true);
CREATE POLICY proof_reader_read ON guardops.law_group AS PERMISSIVE FOR SELECT TO proof_reader USING (true);
CREATE POLICY tenancy_wall ON guardops.law_group AS RESTRICTIVE FOR ALL TO code_builder, firing_seat, guardops_guard_reader USING (account_id = guardops.current_account()) WITH CHECK (account_id = guardops.current_account());

CREATE TRIGGER aaa_writer_stamp BEFORE INSERT OR DELETE OR UPDATE ON guardops.law_group FOR EACH STATEMENT EXECUTE FUNCTION guardops.writer_stamp();
CREATE TRIGGER audit_law_group AFTER INSERT OR UPDATE ON guardops.law_group FOR EACH ROW EXECUTE FUNCTION guardops.audit_write();
CREATE TRIGGER guardops_watch_delete AFTER DELETE ON guardops.law_group REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_insert AFTER INSERT ON guardops.law_group REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER guardops_watch_update AFTER UPDATE ON guardops.law_group REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION guardops_watch.record_write();
CREATE TRIGGER zz_no_destroy_truncate BEFORE TRUNCATE ON guardops.law_group FOR EACH STATEMENT EXECUTE FUNCTION guardops_lock.no_destroy_truncate_guard();


