# _gen.ps1 - Generate drop_clean_cut_tables.sql from parsed JSON temp files
# Board 11401, 2026-11-18

$ErrorActionPreference = 'Stop'

$basePath = 'C:\Users\T480\Desktop\migrations'

# Load data
$cols1 = Get-Content "$basePath\_cols1.json" -Raw | ConvertFrom-Json
$cols2 = Get-Content "$basePath\_cols2.json" -Raw | ConvertFrom-Json
$constraints = Get-Content "$basePath\_constraints.json" -Raw | ConvertFrom-Json
$triggers = Get-Content "$basePath\_triggers.json" -Raw | ConvertFrom-Json

# Merge cols
$allCols = @($cols1) + @($cols2)

# Build lookup: table_name -> ordered columns
$colsByTable = @{}
foreach ($c in $allCols) {
    $t = $c.table_name
    if (-not $colsByTable.ContainsKey($t)) { $colsByTable[$t] = [System.Collections.Generic.List[object]]::new() }
    $colsByTable[$t].Add($c)
}
# Sort each table's columns by ordinal_position
$tableKeys = @($colsByTable.Keys)
foreach ($t in $tableKeys) {
    $colsByTable[$t] = @($colsByTable[$t] | Sort-Object ordinal_position)
}

# Build trigger lookup: table_name -> list of {trigger_def, tgenabled, trigger_name}
$trigsByTable = @{}
foreach ($tr in $triggers) {
    $t = $tr.table_name
    if (-not $trigsByTable.ContainsKey($t)) { $trigsByTable[$t] = [System.Collections.Generic.List[object]]::new() }
    $trigsByTable[$t].Add([PSCustomObject]@{ trigger_def = $tr.trigger_def; tgenabled = $tr.tgenabled; trigger_name = $tr.trigger_name })
}

# Forward order (63 tables)
$forwardOrder = @(
    'law_group','law_group_member','laws_served',
    'look_taken','batch_freeze','batch_page_read','batch_read','handoff_check_whitelist','handoff_floor_claim','press_taint','seat_ask','retire_ask',
    'fire_attestation_used','fire_fetch_meta','fire_pass','fire_review','fire_review_request','fire_review_scan',
    'order_amendment','order_end','order_file_seen','order_hold','order_queue','order_tally',
    'phone_menu_press','phone_menu_sent','phone_offer','phone_press',
    'review_carry','review_rate_limit','review_round','review_severity_log','review_signer_key','migration_review','round_log',
    'agent_claim_pull','agent_claim_record','build_crossing','build_finding','build_step','crossing_papers','door_call_rule','door_snapshot','engine_piece','floor_deferred','floor_map','floor_reading','jargon_words','line_station','outside_beat_log','p1_oracle','park_step','piece_join','plan_gap','plan_gap_ask','plan_gap_read','room','signin_refresh','signin_refusal_run','site_handoff','site_session','spec_sheet','factory_pull_log'
)

# Rollback = reverse
$rollbackOrder = @($forwardOrder | Select-Object -Last ($forwardOrder.Count) | ForEach-Object { $_ })
[array]::Reverse($rollbackOrder)

# RLS status
$rlsEnabled = @{
    'agent_claim_pull'=$true; 'agent_claim_record'=$true; 'batch_freeze'=$false; 'batch_page_read'=$true; 'batch_read'=$false;
    'build_crossing'=$true; 'build_finding'=$true; 'build_step'=$true; 'crossing_papers'=$true; 'door_call_rule'=$true;
    'door_snapshot'=$true; 'engine_piece'=$true; 'factory_pull_log'=$true; 'fire_attestation_used'=$true;
    'fire_fetch_meta'=$false; 'fire_pass'=$false; 'fire_review'=$false; 'fire_review_request'=$false; 'fire_review_scan'=$false;
    'floor_deferred'=$true; 'floor_map'=$true; 'floor_reading'=$true; 'handoff_check_whitelist'=$false; 'handoff_floor_claim'=$true;
    'jargon_words'=$true; 'law_group'=$true; 'law_group_member'=$true; 'laws_served'=$true; 'line_station'=$false;
    'look_taken'=$true; 'migration_review'=$true; 'order_amendment'=$true; 'order_end'=$true; 'order_file_seen'=$true;
    'order_hold'=$true; 'order_queue'=$true; 'order_tally'=$true; 'outside_beat_log'=$true; 'p1_oracle'=$true;
    'park_step'=$true; 'phone_menu_press'=$true; 'phone_menu_sent'=$true; 'phone_offer'=$true; 'phone_press'=$true;
    'piece_join'=$true; 'plan_gap'=$true; 'plan_gap_ask'=$true; 'plan_gap_read'=$true; 'press_taint'=$false;
    'retire_ask'=$false; 'review_carry'=$true; 'review_rate_limit'=$true; 'review_round'=$true; 'review_severity_log'=$true;
    'review_signer_key'=$true; 'room'=$true; 'round_log'=$true; 'seat_ask'=$true; 'signin_refresh'=$true;
    'signin_refusal_run'=$true; 'site_handoff'=$true; 'site_session'=$true; 'spec_sheet'=$true
}
$rlsForced = @{
    'floor_reading'=$true; 'look_taken'=$true
}

# Policies: table -> list of policy strings
$policies = @{}

function Add-Policy($tbl, $name, $perm, $roles, $cmd, $qual, $check) {
    if (-not $policies.ContainsKey($tbl)) { $policies[$tbl] = [System.Collections.Generic.List[string]]::new() }
    $rolesStr = ($roles | ForEach-Object { $_ }) -join ', '

    # Build USING clause
    $usingClause = ''
    if ($qual -ne 'null' -and $qual) {
        $qualExpr = $qual
        $qualExpr = $qualExpr -replace 'account_id=current_account\(\)', 'account_id = guardops.current_account()'
        if ($qual -eq 'true') { $qualExpr = 'true' }
        if ($qual -eq 'SPECIAL_DOOR_SNAPSHOT') {
            $qualExpr = "(guardops.is_strong_seat() OR (SESSION_USER = ANY (ARRAY['code_builder'::name, 'firing_seat'::name])))"
        }
        $usingClause = " USING ($qualExpr)"
    }

    # Build WITH CHECK clause
    $checkClause = ''
    if ($check -ne 'null' -and $check) {
        $checkExpr = $check
        $checkExpr = $checkExpr -replace 'account_id=current_account\(\)', 'account_id = guardops.current_account()'
        if ($check -eq 'true') { $checkExpr = 'true' }
        $checkClause = " WITH CHECK ($checkExpr)"
    }

    $sql = "CREATE POLICY $name ON guardops.$tbl AS $perm FOR $cmd TO $rolesStr$usingClause$checkClause;"
    $policies[$tbl].Add($sql)
}

# agent_claim_pull
Add-Policy 'agent_claim_pull' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'agent_claim_pull' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'agent_claim_pull' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# agent_claim_record
Add-Policy 'agent_claim_record' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'agent_claim_record' 'guard_owner_read' 'PERMISSIVE' @('guard_owner') 'SELECT' 'true' 'null'
Add-Policy 'agent_claim_record' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'agent_claim_record' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# batch_page_read
Add-Policy 'batch_page_read' 'batch_page_read_account' 'PERMISSIVE' @('public') 'ALL' 'account_id=current_account()' 'null'

# build_crossing
Add-Policy 'build_crossing' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'
Add-Policy 'build_crossing' 'weak_seat_read' 'PERMISSIVE' @('code_builder','harness_runner','proof_reader') 'SELECT' 'true' 'null'

# build_finding
Add-Policy 'build_finding' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'
Add-Policy 'build_finding' 'weak_seat_read' 'PERMISSIVE' @('code_builder','harness_runner','proof_reader') 'SELECT' 'true' 'null'

# build_step
Add-Policy 'build_step' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'
Add-Policy 'build_step' 'weak_seat_read' 'PERMISSIVE' @('code_builder','harness_runner','proof_reader') 'SELECT' 'true' 'null'

# crossing_papers
Add-Policy 'crossing_papers' 'code_builder_write' 'PERMISSIVE' @('code_builder') 'INSERT' 'null' 'true'
Add-Policy 'crossing_papers' 'crossing_papers_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'crossing_papers' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'crossing_papers' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# door_call_rule
Add-Policy 'door_call_rule' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'
Add-Policy 'door_call_rule' 'weak_seat_read' 'PERMISSIVE' @('code_builder','harness_runner','proof_reader') 'SELECT' 'true' 'null'

# door_snapshot
Add-Policy 'door_snapshot' 'door_snapshot_strong_seat' 'PERMISSIVE' @('public') 'SELECT' 'SPECIAL_DOOR_SNAPSHOT' 'null'

# engine_piece
Add-Policy 'engine_piece' 'code_builder_read' 'PERMISSIVE' @('code_builder','firing_seat','proof_reader') 'SELECT' 'account_id=current_account()' 'null'
Add-Policy 'engine_piece' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'engine_piece' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# factory_pull_log
Add-Policy 'factory_pull_log' 'code_builder_read' 'PERMISSIVE' @('code_builder','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'factory_pull_log' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'factory_pull_log' 'postgres_write' 'PERMISSIVE' @('postgres') 'INSERT' 'null' 'true'
Add-Policy 'factory_pull_log' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# fire_attestation_used
Add-Policy 'fire_attestation_used' 'guard_owner_insert' 'PERMISSIVE' @('guard_owner') 'INSERT' 'null' 'true'

# floor_deferred
Add-Policy 'floor_deferred' 'floor_deferred_read' 'PERMISSIVE' @('code_builder','guardops_guard_reader','proof_reader') 'SELECT' 'true' 'null'

# floor_map
Add-Policy 'floor_map' 'floor_map_read' 'PERMISSIVE' @('code_builder','guardops_guard_reader','proof_reader') 'SELECT' 'true' 'null'

# floor_reading
Add-Policy 'floor_reading' 'floor_reading_own_account' 'PERMISSIVE' @('public') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# handoff_floor_claim
Add-Policy 'handoff_floor_claim' 'handoff_floor_claim_account' 'PERMISSIVE' @('public') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# jargon_words
Add-Policy 'jargon_words' 'jargon_words_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'jargon_words' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'jargon_words' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# law_group
Add-Policy 'law_group' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'law_group' 'guard_owner_read' 'PERMISSIVE' @('guard_owner') 'SELECT' 'true' 'null'
Add-Policy 'law_group' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'law_group' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# law_group_member
Add-Policy 'law_group_member' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'law_group_member' 'guard_owner_read' 'PERMISSIVE' @('guard_owner') 'SELECT' 'true' 'null'
Add-Policy 'law_group_member' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'law_group_member' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# laws_served
Add-Policy 'laws_served' 'laws_served_code_builder_select' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'laws_served' 'laws_served_proof_reader_select' 'PERMISSIVE' @('guardops_guard_reader') 'SELECT' 'true' 'null'

# look_taken
Add-Policy 'look_taken' 'code_builder_read' 'PERMISSIVE' @('code_builder','guard_owner','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'look_taken' 'take_look_write' 'PERMISSIVE' @('guard_owner') 'INSERT' 'null' 'true'
Add-Policy 'look_taken' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# migration_review
Add-Policy 'migration_review' 'migration_review_account_isolation' 'RESTRICTIVE' @('public') 'ALL' 'account_id=current_account()' 'null'
Add-Policy 'migration_review' 'migration_review_readers' 'PERMISSIVE' @('code_builder','firing_seat') 'SELECT' 'account_id=current_account()' 'null'

# order_amendment
Add-Policy 'order_amendment' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'order_amendment' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'order_amendment' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# order_end
Add-Policy 'order_end' 'code_builder_read' 'PERMISSIVE' @('code_builder','firing_seat','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'order_end' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'order_end' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# order_file_seen
Add-Policy 'order_file_seen' 'order_file_seen_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'order_file_seen' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# order_hold
Add-Policy 'order_hold' 'code_builder_read' 'PERMISSIVE' @('code_builder','firing_seat','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'order_hold' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'order_hold' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# order_queue
Add-Policy 'order_queue' 'code_builder_read' 'PERMISSIVE' @('code_builder','firing_seat','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'order_queue' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'order_queue' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# order_tally
Add-Policy 'order_tally' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'order_tally' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'order_tally' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# outside_beat_log
Add-Policy 'outside_beat_log' 'code_builder_read' 'PERMISSIVE' @('code_builder','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'outside_beat_log' 'postgres_write' 'PERMISSIVE' @('postgres') 'INSERT' 'null' 'true'
Add-Policy 'outside_beat_log' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# p1_oracle
Add-Policy 'p1_oracle' 'p1_oracle_read' 'PERMISSIVE' @('code_builder','proof_reader') 'SELECT' 'account_id=current_account()' 'null'
Add-Policy 'p1_oracle' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# park_step
Add-Policy 'park_step' 'code_builder_read' 'PERMISSIVE' @('code_builder','firing_seat','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'park_step' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'park_step' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# phone_menu_press
Add-Policy 'phone_menu_press' 'code_builder_read' 'PERMISSIVE' @('code_builder','firing_seat','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'phone_menu_press' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'phone_menu_press' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# phone_menu_sent
Add-Policy 'phone_menu_sent' 'code_builder_read' 'PERMISSIVE' @('code_builder','firing_seat','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'phone_menu_sent' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'phone_menu_sent' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# phone_offer
Add-Policy 'phone_offer' 'code_builder_read' 'PERMISSIVE' @('code_builder','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'phone_offer' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'phone_offer' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# phone_press
Add-Policy 'phone_press' 'code_builder_read' 'PERMISSIVE' @('code_builder','proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'phone_press' 'postgres_read' 'PERMISSIVE' @('postgres') 'SELECT' 'true' 'null'
Add-Policy 'phone_press' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# piece_join
Add-Policy 'piece_join' 'piece_join_code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'account_id=current_account()' 'null'
Add-Policy 'piece_join' 'piece_join_proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'

# plan_gap
Add-Policy 'plan_gap' 'plan_gap_code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'account_id=current_account()' 'null'
Add-Policy 'plan_gap' 'plan_gap_proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'

# plan_gap_ask
Add-Policy 'plan_gap_ask' 'plan_gap_ask_code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'account_id=current_account()' 'null'
Add-Policy 'plan_gap_ask' 'plan_gap_ask_proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'

# plan_gap_read
Add-Policy 'plan_gap_read' 'plan_gap_read_code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'account_id=current_account()' 'null'
Add-Policy 'plan_gap_read' 'plan_gap_read_proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'account_id=current_account()' 'null'

# review_carry
Add-Policy 'review_carry' 'account_isolation' 'PERMISSIVE' @('public') 'ALL' 'account_id=current_account()' 'null'

# review_rate_limit
Add-Policy 'review_rate_limit' 'tenancy_wall' 'PERMISSIVE' @('public') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# review_round
Add-Policy 'review_round' 'tenancy_wall' 'PERMISSIVE' @('public') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# review_severity_log
Add-Policy 'review_severity_log' 'account_isolation' 'PERMISSIVE' @('public') 'ALL' 'account_id=current_account()' 'null'

# review_signer_key
Add-Policy 'review_signer_key' 'review_signer_key_read' 'PERMISSIVE' @('public') 'SELECT' 'true' 'null'

# room
Add-Policy 'room' 'room_read' 'PERMISSIVE' @('code_builder','proof_reader') 'SELECT' 'true' 'null'

# round_log
Add-Policy 'round_log' 'round_log_read' 'PERMISSIVE' @('code_builder','proof_reader') 'SELECT' 'true' 'null'

# seat_ask
Add-Policy 'seat_ask' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'seat_ask' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'seat_ask' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# signin_refresh
Add-Policy 'signin_refresh' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'signin_refresh' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'signin_refresh' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# signin_refusal_run
Add-Policy 'signin_refusal_run' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'signin_refusal_run' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'signin_refusal_run' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# site_handoff
Add-Policy 'site_handoff' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'site_handoff' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'site_handoff' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# site_session
Add-Policy 'site_session' 'code_builder_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'site_session' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'site_session' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# spec_sheet
Add-Policy 'spec_sheet' 'proof_reader_read' 'PERMISSIVE' @('proof_reader') 'SELECT' 'true' 'null'
Add-Policy 'spec_sheet' 'spec_sheet_read' 'PERMISSIVE' @('code_builder') 'SELECT' 'true' 'null'
Add-Policy 'spec_sheet' 'tenancy_wall' 'RESTRICTIVE' @('code_builder','firing_seat','guardops_guard_reader') 'ALL' 'account_id=current_account()' 'account_id=current_account()'

# Hardcoded multi-col FK constraint names
$multiColFKs = @{
    'build_crossing_order_id_acct_fkey'      = 'FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id)'
    'build_step_law_id_acct_fkey'            = 'FOREIGN KEY (law_id, account_id) REFERENCES guardops.law (id, account_id)'
    'crossing_papers_plan_id_acct_fkey'      = 'FOREIGN KEY (plan_id, account_id) REFERENCES guardops.build_plan (id, account_id)'
    'door_call_rule_supersedes_acct_fkey'    = 'FOREIGN KEY (supersedes, account_id) REFERENCES guardops.door_call_rule (id, account_id)'
    'factory_pull_log_order_id_acct_fkey'    = 'FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id)'
    'order_amendment_order_id_acct_fkey'     = 'FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id)'
    'order_end_order_id_acct_fkey'           = 'FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id)'
    'order_file_seen_order_id_acct_fkey'     = 'FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id)'
    'order_hold_order_id_acct_fkey'          = 'FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id)'
    'order_queue_order_id_acct_fkey'         = 'FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id)'
    'park_step_order_id_acct_fkey'           = 'FOREIGN KEY (order_id, account_id) REFERENCES guardops.job_order (id, account_id)'
    'factory_pull_log_post_id_acct_fkey'     = 'FOREIGN KEY (post_id, account_id) REFERENCES guardops.factory_pull_log (id, account_id)'
}

# Indexes per table (non-PK, verbatim)
$indexes = @{}
function Add-Index($tbl, $sql) {
    if (-not $indexes.ContainsKey($tbl)) { $indexes[$tbl] = [System.Collections.Generic.List[string]]::new() }
    $indexes[$tbl].Add($sql)
}

Add-Index 'agent_claim_record' 'CREATE UNIQUE INDEX agent_claim_record_database_id_their_id_key ON guardops.agent_claim_record USING btree (database_id, their_id);'
Add-Index 'batch_freeze' 'CREATE UNIQUE INDEX batch_freeze_account_plan_uniq ON guardops.batch_freeze USING btree (account_id, plan_board_id);'
Add-Index 'batch_page_read' 'CREATE UNIQUE INDEX batch_page_read_account_id_plan_board_id_key ON guardops.batch_page_read USING btree (account_id, plan_board_id);'
Add-Index 'batch_read' 'CREATE UNIQUE INDEX batch_read_account_plan_unique ON guardops.batch_read USING btree (account_id, plan_id);'
Add-Index 'build_finding' 'CREATE UNIQUE INDEX build_finding_key_uq ON guardops.build_finding USING btree (account_id, build_key, reader, finding_key);'
Add-Index 'build_step' 'CREATE UNIQUE INDEX build_step_law_step_uq ON guardops.build_step USING btree (law_id, step_no);'
Add-Index 'door_call_rule' 'CREATE UNIQUE INDEX door_call_rule_id_account_key ON guardops.door_call_rule USING btree (id, account_id);'
Add-Index 'engine_piece' 'CREATE INDEX engine_piece_latest ON guardops.engine_piece USING btree (piece, label, id DESC);'
Add-Index 'factory_pull_log' 'CREATE UNIQUE INDEX factory_pull_log_id_account_key ON guardops.factory_pull_log USING btree (id, account_id);'
Add-Index 'factory_pull_log' "CREATE UNIQUE INDEX factory_pull_log_one_judge ON guardops.factory_pull_log USING btree (post_id) WHERE (kind = 'JUDGE'::text);"
Add-Index 'fire_attestation_used' 'CREATE UNIQUE INDEX fire_attestation_used_request_once ON guardops.fire_attestation_used USING btree (request_id);'
Add-Index 'fire_review' 'CREATE UNIQUE INDEX fire_review_gh_review_id_key ON guardops.fire_review USING btree (gh_review_id);'
Add-Index 'handoff_floor_claim' 'CREATE INDEX handoff_floor_claim_board_idx ON guardops.handoff_floor_claim USING btree (handoff_board_id);'
Add-Index 'jargon_words' 'CREATE UNIQUE INDEX jargon_words_word_key ON guardops.jargon_words USING btree (account_id, word);'
Add-Index 'law_group' 'CREATE UNIQUE INDEX law_group_code_once ON guardops.law_group USING btree (account_id, code);'
Add-Index 'law_group_member' 'CREATE INDEX law_group_member_by_group_idx ON guardops.law_group_member USING btree (account_id, group_code);'
Add-Index 'law_group_member' 'CREATE UNIQUE INDEX law_group_member_one_per_law ON guardops.law_group_member USING btree (account_id, law_id);'
Add-Index 'migration_review' 'CREATE INDEX idx_migration_review_lookup ON guardops.migration_review USING btree (account_id, migration_file);'
Add-Index 'migration_review' 'CREATE INDEX migration_review_file_sha_idx ON guardops.migration_review USING btree (account_id, migration_file, file_sha) WHERE (file_sha IS NOT NULL);'
Add-Index 'order_end' 'CREATE UNIQUE INDEX order_end_order_id_key ON guardops.order_end USING btree (order_id);'
Add-Index 'order_hold' 'CREATE INDEX order_hold_by_order ON guardops.order_hold USING btree (order_id);'
Add-Index 'order_hold' 'CREATE UNIQUE INDEX order_hold_id_account_key ON guardops.order_hold USING btree (id, account_id);'
Add-Index 'order_hold' "CREATE UNIQUE INDEX order_hold_one_lift ON guardops.order_hold USING btree (hold_id) WHERE (kind = 'LIFT'::text);"
Add-Index 'order_queue' 'CREATE UNIQUE INDEX order_queue_id_account_key ON guardops.order_queue USING btree (id, account_id);'
Add-Index 'order_queue' "CREATE UNIQUE INDEX order_queue_one_end ON guardops.order_queue USING btree (queue_id) WHERE (kind = ANY (ARRAY['OPENED'::text, 'DROP'::text]));"
Add-Index 'park_step' 'CREATE INDEX park_step_by_board ON guardops.park_step USING btree (board_id);'
Add-Index 'park_step' 'CREATE INDEX park_step_by_order ON guardops.park_step USING btree (order_id);'
Add-Index 'park_step' 'CREATE UNIQUE INDEX park_step_id_account_key ON guardops.park_step USING btree (id, account_id);'
Add-Index 'park_step' "CREATE UNIQUE INDEX park_step_one_unpark ON guardops.park_step USING btree (park_id) WHERE (kind = 'UNPARK'::text);"
Add-Index 'phone_menu_press' 'CREATE UNIQUE INDEX phone_menu_press_update_id_key ON guardops.phone_menu_press USING btree (update_id);'
Add-Index 'phone_offer' 'CREATE UNIQUE INDEX phone_offer_id_account_key ON guardops.phone_offer USING btree (id, account_id);'
Add-Index 'phone_press' "CREATE UNIQUE INDEX phone_press_one_decision ON guardops.phone_press USING btree (offer_id) WHERE (choice <> 'MORE'::text);"
Add-Index 'phone_press' 'CREATE UNIQUE INDEX phone_press_update_id_key ON guardops.phone_press USING btree (update_id);'
Add-Index 'piece_join' 'CREATE UNIQUE INDEX piece_join_part_unique ON guardops.piece_join USING btree (account_id, part_id);'
Add-Index 'plan_gap' 'CREATE UNIQUE INDEX plan_gap_unique ON guardops.plan_gap USING btree (account_id, plan_module, step_no);'
Add-Index 'plan_gap_ask' 'CREATE UNIQUE INDEX plan_gap_ask_one_open ON guardops.plan_gap_ask USING btree (account_id, plan_module) WHERE (answered_at IS NULL);'
Add-Index 'plan_gap_read' 'CREATE UNIQUE INDEX plan_gap_read_once ON guardops.plan_gap_read USING btree (gap_id);'
Add-Index 'press_taint' 'CREATE UNIQUE INDEX press_taint_target_table_target_id_key ON guardops.press_taint USING btree (target_table, target_id);'
Add-Index 'review_round' 'CREATE UNIQUE INDEX review_round_pr_round_uq ON guardops.review_round USING btree (account_id, pr, round_no);'
Add-Index 'review_round' 'CREATE UNIQUE INDEX uq_review_round_gh_review_id ON guardops.review_round USING btree (account_id, pr, gh_review_id) WHERE (gh_review_id IS NOT NULL);'
Add-Index 'room' 'CREATE UNIQUE INDEX room_name_key ON guardops.room USING btree (name);'
Add-Index 'signin_refusal_run' 'CREATE UNIQUE INDEX signin_refusal_run_one_per_pair ON guardops.signin_refusal_run USING btree (account_id, database_id, connected_account_id);'
Add-Index 'site_handoff' 'CREATE UNIQUE INDEX site_handoff_code_hash_key ON guardops.site_handoff USING btree (code_hash);'
Add-Index 'site_session' 'CREATE UNIQUE INDEX site_session_token_hash_key ON guardops.site_session USING btree (token_hash);'
Add-Index 'spec_sheet' 'CREATE UNIQUE INDEX spec_sheet_module_key ON guardops.spec_sheet USING btree (account_id, module);'

# ---- Helper: map column to SQL type ----
function Get-ColType($col) {
    $dt = $col.data_type
    $udt = $col.udt_name
    $def = $col.column_default

    if ($dt -eq 'bigint' -or $udt -eq 'int8') {
        if ($def -and $def -like "nextval(*") { return 'BIGSERIAL' }
        return 'BIGINT'
    }
    if ($dt -eq 'integer' -or $udt -eq 'int4') { return 'INTEGER' }
    if ($dt -eq 'smallint' -or $udt -eq 'int2') { return 'SMALLINT' }
    if ($dt -eq 'text' -or $udt -eq 'text') { return 'TEXT' }
    if ($dt -eq 'boolean' -or $udt -eq 'bool') { return 'BOOLEAN' }
    if ($dt -eq 'jsonb' -or $udt -eq 'jsonb') { return 'JSONB' }
    if ($dt -eq 'uuid' -or $udt -eq 'uuid') { return 'UUID' }
    if ($dt -eq 'timestamp with time zone' -or $udt -eq 'timestamptz') { return 'TIMESTAMPTZ' }
    if ($dt -eq 'date') { return 'DATE' }
    if ($udt -eq 'bytea') { return 'BYTEA' }
    if ($udt -eq 'oid') { return 'OID' }
    if ($dt -eq 'ARRAY') {
        if ($udt -eq '_text') { return 'TEXT[]' }
        if ($udt -eq '_int8') { return 'BIGINT[]' }
        if ($udt -eq '_int4') { return 'INTEGER[]' }
        # generic fallback
        $base = $udt.TrimStart('_')
        return "$($base.ToUpper())[]"
    }
    # fallback
    return $dt.ToUpper()
}

# ---- Helper: build CREATE TABLE for a given table ----
function Get-CreateTable($tbl) {
    $cols = $colsByTable[$tbl]
    if (-not $cols) { return "-- WARNING: no columns found for $tbl" }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("CREATE TABLE guardops.$tbl (")

    $colDefs = [System.Collections.Generic.List[string]]::new()
    foreach ($col in $cols) {
        $sqlType = Get-ColType $col
        $def = $col.column_default
        $nullable = $col.is_nullable

        $colLine = "    $($col.column_name) $sqlType"

        # Add DEFAULT unless BIGSERIAL absorbed it
        if ($sqlType -ne 'BIGSERIAL' -and $def -ne $null -and $def -ne '') {
            $colLine += " DEFAULT $def"
        }

        if ($nullable -eq 'NO') {
            $colLine += ' NOT NULL'
        }

        $colDefs.Add($colLine)
    }

    $lines.Add(($colDefs -join ",`n"))
    $lines.Add(');')
    return $lines -join "`n"
}

# ---- Helper: get constraints for a table ----
function Get-ConstraintSQL($tbl) {
    $result = [System.Collections.Generic.List[string]]::new()

    # Get all constraints for this table
    $tblConstraints = $constraints | Where-Object { $_.table_name -eq $tbl }

    # Deduplicate by constraint_name for processing
    $seenConstraints = @{}

    # Process PKs first — group by constraint_name to handle composite PKs correctly
    $pkGroups = $tblConstraints | Where-Object { $_.constraint_type -eq 'PRIMARY KEY' } | Group-Object constraint_name
    foreach ($grp in $pkGroups) {
        $cn = $grp.Name
        $cols = @($grp.Group | Select-Object -ExpandProperty column_name)
        $colList = $cols -join ', '
        $result.Add("ALTER TABLE guardops.$tbl ADD CONSTRAINT $cn PRIMARY KEY ($colList);")
    }

    # Process FKs
    # First identify multi-col FK names (hardcoded)
    $fkConstraints = $tblConstraints | Where-Object { $_.constraint_type -eq 'FOREIGN KEY' }
    $fkGroups = $fkConstraints | Group-Object constraint_name
    $fkDone = @{}
    foreach ($grp in $fkGroups) {
        $cn = $grp.Name
        if ($fkDone.ContainsKey($cn)) { continue }
        $fkDone[$cn] = $true

        # Check if hardcoded multi-col
        if ($multiColFKs.ContainsKey($cn)) {
            $result.Add("ALTER TABLE guardops.$tbl ADD CONSTRAINT $cn $($multiColFKs[$cn]);")
            continue
        }

        # Single-col FK: get the unique col/table/foreign_col
        $rows = $grp.Group
        # For single-col: all rows have same column_name
        $distinctCols = @($rows | Select-Object -ExpandProperty column_name -Unique)
        if ($distinctCols.Count -gt 1) {
            # Multi-col not in hardcoded list - use alphabetical
            $sortedCols = ($distinctCols | Sort-Object) -join ', '
            $foreignTableArr = @($rows | Select-Object -ExpandProperty foreign_table -Unique)
            $foreignTable = $foreignTableArr[0]
            $distinctFCols = @($rows | Select-Object -ExpandProperty foreign_column -Unique | Sort-Object)
            $sortedFCols = $distinctFCols -join ', '
            $result.Add("ALTER TABLE guardops.$tbl ADD CONSTRAINT $cn FOREIGN KEY ($sortedCols) REFERENCES guardops.$foreignTable ($sortedFCols);")
            continue
        }

        $localCol = $distinctCols[0]
        $foreignTableArr = @($rows | Select-Object -ExpandProperty foreign_table -Unique)
        $foreignTable = $foreignTableArr[0]
        $foreignColArr = @($rows | Select-Object -ExpandProperty foreign_column -Unique)
        $foreignCol = $foreignColArr[0]
        $deleteRuleArr = @($rows | Select-Object -ExpandProperty delete_rule -Unique)
        $deleteRule = $deleteRuleArr[0]
        $updateRuleArr = @($rows | Select-Object -ExpandProperty update_rule -Unique)
        $updateRule = $updateRuleArr[0]

        $fkSql = "ALTER TABLE guardops.$tbl ADD CONSTRAINT $cn FOREIGN KEY ($localCol) REFERENCES guardops.$foreignTable ($foreignCol)"
        if ($deleteRule -and $deleteRule -ne 'NO ACTION') {
            $fkSql += " ON DELETE $deleteRule"
        }
        if ($updateRule -and $updateRule -ne 'NO ACTION') {
            $fkSql += " ON UPDATE $updateRule"
        }
        $fkSql += ';'
        $result.Add($fkSql)
    }

    # Process UNIQUEs
    $uniqConstraints = $tblConstraints | Where-Object { $_.constraint_type -eq 'UNIQUE' }
    $uniqGroups = $uniqConstraints | Group-Object constraint_name
    $uniqDone = @{}
    foreach ($grp in $uniqGroups) {
        $cn = $grp.Name
        if ($uniqDone.ContainsKey($cn)) { continue }
        $uniqDone[$cn] = $true
        $distinctCols = @($grp.Group | Select-Object -ExpandProperty column_name -Unique | Sort-Object)
        $colList = $distinctCols -join ', '
        $result.Add("ALTER TABLE guardops.$tbl ADD CONSTRAINT $cn UNIQUE ($colList);")
    }

    # Process CHECKs (skip _not_null ones)
    $checkConstraints = $tblConstraints | Where-Object { $_.constraint_type -eq 'CHECK' -and $_.constraint_name -notlike '*_not_null' }
    $checkDone = @{}
    foreach ($c in $checkConstraints) {
        $cn = $c.constraint_name
        if ($checkDone.ContainsKey($cn)) { continue }
        $checkDone[$cn] = $true
        $clause = $c.check_clause
        $result.Add("ALTER TABLE guardops.$tbl ADD CONSTRAINT $cn CHECK $clause;")
    }

    return $result
}

# ---- Build the SQL output ----
$out = [System.Text.StringBuilder]::new()

$out.AppendLine('-- =================================================================') | Out-Null
$out.AppendLine('-- FORWARD: drop 63 clean cut tables (board 11401, 2026-11-18)') | Out-Null
$out.AppendLine('-- BEFORE: 161 tables, 803 triggers, 498 functions') | Out-Null
$out.AppendLine('-- =================================================================') | Out-Null
$out.AppendLine('') | Out-Null
$out.AppendLine('-- ===  FORWARD SECTION  ===') | Out-Null
$out.AppendLine('') | Out-Null

foreach ($tbl in $forwardOrder) {
    $out.AppendLine("SELECT guardops.destroy_unlock_add('guardops.$tbl', 'board 11401', 30);") | Out-Null
    $out.AppendLine("DROP TABLE guardops.$tbl CASCADE;") | Out-Null
    $out.AppendLine('') | Out-Null
}

$out.AppendLine('') | Out-Null
$out.AppendLine('-- ===  ROLLBACK SECTION  ===') | Out-Null
$out.AppendLine('-- Rollback restores table structure only. Rows present before the forward') | Out-Null
$out.AppendLine('-- migration are not restored. All 63 tables are recreated without data.') | Out-Null
$out.AppendLine('') | Out-Null

# Collect all FK lines for the second pass (they need all tables + indexes to exist first)
$allRollbackFKs = [System.Collections.Generic.List[string]]::new()

foreach ($tbl in $rollbackOrder) {
    $out.AppendLine("-- ----- $tbl -----") | Out-Null
    $out.AppendLine('') | Out-Null

    # 1. CREATE TABLE
    $createSql = Get-CreateTable $tbl
    $out.AppendLine($createSql) | Out-Null
    $out.AppendLine('') | Out-Null

    # 2. Non-FK constraints (PK, UNIQUE, CHECK) — FKs deferred to second pass
    $constraintLines = Get-ConstraintSQL $tbl
    $nonFkLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $constraintLines) {
        if ($line -match 'FOREIGN KEY') {
            $allRollbackFKs.Add($line)
        } else {
            $nonFkLines.Add($line)
            $out.AppendLine($line) | Out-Null
        }
    }
    if ($nonFkLines.Count -gt 0) { $out.AppendLine('') | Out-Null }

    # 3. Non-PK indexes — skip those whose name matches an emitted UNIQUE constraint
    $emittedUniqNames = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($line in $nonFkLines) {
        if ($line -match 'ADD CONSTRAINT (\S+) UNIQUE') { $emittedUniqNames.Add($Matches[1]) | Out-Null }
    }
    if ($indexes.ContainsKey($tbl)) {
        $hasIdx = $false
        foreach ($idx in $indexes[$tbl]) {
            if ($idx -match 'CREATE UNIQUE INDEX (\S+)\s' -and $emittedUniqNames.Contains($Matches[1])) { continue }
            $out.AppendLine($idx) | Out-Null
            $hasIdx = $true
        }
        if ($hasIdx) { $out.AppendLine('') | Out-Null }
    }

    # 4. RLS enable
    $rlsOn = $rlsEnabled[$tbl]
    $rlsForce = $rlsForced[$tbl]
    if ($rlsOn) {
        $out.AppendLine("ALTER TABLE guardops.$tbl ENABLE ROW LEVEL SECURITY;") | Out-Null
    }
    # 5. RLS force
    if ($rlsForce) {
        $out.AppendLine("ALTER TABLE guardops.$tbl FORCE ROW LEVEL SECURITY;") | Out-Null
    }
    if ($rlsOn -or $rlsForce) { $out.AppendLine('') | Out-Null }

    # 6. Policies
    if ($policies.ContainsKey($tbl)) {
        foreach ($pol in $policies[$tbl]) {
            $out.AppendLine($pol) | Out-Null
        }
        $out.AppendLine('') | Out-Null
    }

    # 7. Triggers
    if ($trigsByTable.ContainsKey($tbl)) {
        foreach ($trigInfo in $trigsByTable[$tbl]) {
            $td = $trigInfo.trigger_def.TrimEnd()
            if (-not $td.EndsWith(';')) { $td += ';' }
            $out.AppendLine($td) | Out-Null
            if ($trigInfo.tgenabled -eq 'A') {
                $out.AppendLine("ALTER TABLE guardops.$tbl ENABLE ALWAYS TRIGGER $($trigInfo.trigger_name);") | Out-Null
            }
        }
        $out.AppendLine('') | Out-Null
    }
}

# FK PASS: add all foreign keys after all tables and their indexes exist
if ($allRollbackFKs.Count -gt 0) {
    $out.AppendLine('') | Out-Null
    $out.AppendLine('-- ===  ROLLBACK FK PASS  ===') | Out-Null
    $out.AppendLine('-- Foreign keys added after all tables and indexes exist.') | Out-Null
    $out.AppendLine('') | Out-Null
    foreach ($fk in $allRollbackFKs) {
        $out.AppendLine($fk) | Out-Null
    }
}

# Write output
$outPath = "$basePath\drop_clean_cut_tables.sql"
$sqlContent = $out.ToString()
Set-Content -Path $outPath -Value $sqlContent -Encoding UTF8

Write-Host "Written: $outPath"
$lineCount = ($sqlContent -split "`n").Count
$byteSize = (Get-Item $outPath).Length
Write-Host "Lines: $lineCount"
Write-Host "Size: $byteSize bytes"
