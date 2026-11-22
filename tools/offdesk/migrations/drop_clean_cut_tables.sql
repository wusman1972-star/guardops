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
