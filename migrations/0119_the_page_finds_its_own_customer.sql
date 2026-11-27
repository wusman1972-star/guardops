-- migrations/0119_the_page_finds_its_own_customer.sql
-- Board 12219: one-argument overload of page_lines that resolves the customer itself.
--
-- guardops.page_lines(p_customer, p_job_id) already exists and keeps working.
-- This adds guardops.page_lines(p_job_id) which looks up the account from the job,
-- picks the lowest-id customer of that account, and delegates to the two-argument form.

CREATE OR REPLACE FUNCTION guardops.page_lines(p_job_id bigint)
RETURNS TABLE(line_no integer, heading text, body text, proof text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_account_id  bigint;
  v_customer_id bigint;
BEGIN
  SELECT j.account_id INTO v_account_id
    FROM guardops.job j
   WHERE j.id = p_job_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'job % was not found', p_job_id;
  END IF;

  SELECT c.id INTO v_customer_id
    FROM guardops.customer c
   WHERE c.account_id = v_account_id
   ORDER BY c.id
   LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'account % has no customer yet', v_account_id;
  END IF;

  PERFORM guardops.act_as_house(v_customer_id);
  RETURN QUERY SELECT * FROM guardops.page_lines(v_customer_id, p_job_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.page_lines(bigint) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION guardops.page_lines(bigint) TO service_role;

DO $proof$
DECLARE
  r         record;
  v_count   int;
  v_match   int;
  v_refused boolean;
  v_msg     text;
  v_one     int;
  v_whole   int;
  v_wall    int;
BEGIN
  BEGIN

    -- Proof 1: page_lines(132) with the job id alone returns seven rows; show all headings
    SELECT count(*) INTO v_count FROM guardops.page_lines(132);
    RAISE NOTICE 'proof_1  row_count  got=%  want=7  pass=%', v_count, (v_count = 7);
    IF v_count <> 7 THEN
      RAISE EXCEPTION '0119 proof 1 failed: page_lines(132) returned % rows, want 7', v_count;
    END IF;
    FOR r IN SELECT line_no, heading FROM guardops.page_lines(132) ORDER BY line_no LOOP
      RAISE NOTICE 'proof_1  line=%  heading="%"', r.line_no, r.heading;
    END LOOP;

    -- Proof 2: row-for-row identical to page_lines(175, 132)
    SELECT count(*) INTO v_match
      FROM guardops.page_lines(132)       AS a
      JOIN guardops.page_lines(175, 132)  AS b ON a.line_no = b.line_no
     WHERE a.heading = b.heading
       AND a.body    = b.body
       AND a.proof   = b.proof;
    RAISE NOTICE 'proof_2  identical_rows  got=%  want=7  pass=%', v_match, (v_match = 7);
    FOR r IN
      SELECT a.line_no,
             (a.heading = b.heading AND a.body = b.body AND a.proof = b.proof) AS same,
             a.heading  AS one_arg_heading,
             b.heading  AS two_arg_heading
        FROM guardops.page_lines(132)      AS a
        JOIN guardops.page_lines(175, 132) AS b ON a.line_no = b.line_no
       ORDER BY a.line_no
    LOOP
      RAISE NOTICE 'proof_2  line=%  same=%  heading="%"', r.line_no, r.same, r.one_arg_heading;
    END LOOP;
    IF v_match <> 7 THEN
      RAISE EXCEPTION '0119 proof 2 failed: only % of 7 rows match', v_match;
    END IF;

    -- Proof 3: non-existent job raises a plain not-found, not [NO HOUSE], not empty
    v_refused := false;
    BEGIN
      PERFORM guardops.page_lines(999999999);
    EXCEPTION WHEN OTHERS THEN
      v_refused := true;
      v_msg := SQLERRM;
    END;
    RAISE NOTICE 'proof_3  raised=%  msg="%"  no_house=%  pass=%',
      v_refused, v_msg,
      (v_msg LIKE '%[NO HOUSE]%'),
      (v_refused AND v_msg NOT LIKE '%[NO HOUSE]%');
    IF NOT v_refused THEN
      RAISE EXCEPTION '0119 proof 3 failed: no exception raised for non-existent job';
    END IF;
    IF v_msg LIKE '%[NO HOUSE]%' THEN
      RAISE EXCEPTION '0119 proof 3 failed: raised [NO HOUSE] instead of plain not-found: %', v_msg;
    END IF;

    -- Proof 4: existing test suites do not regress
    SELECT count(*) INTO v_one   FROM guardops.one_run_test()   WHERE pass = true;
    SELECT count(*) INTO v_whole FROM guardops.whole_run_test() WHERE pass = true;
    SELECT count(*) INTO v_wall  FROM guardops.wall_test()      WHERE pass = true;
    RAISE NOTICE 'proof_4a  one_run_test   got=%  want=8   pass=%', v_one,   (v_one   = 8);
    RAISE NOTICE 'proof_4b  whole_run_test got=%  want=12  pass=%', v_whole, (v_whole = 12);
    RAISE NOTICE 'proof_4c  wall_test      got=%  want=18  pass=%', v_wall,  (v_wall  = 18);
    IF v_one <> 8 OR v_whole <> 12 OR v_wall <> 18 THEN
      RAISE EXCEPTION '0119 regression: one_run=% whole_run=% wall=%', v_one, v_whole, v_wall;
    END IF;

    RAISE NOTICE '0119 all proofs passed';
    RAISE EXCEPTION '0119_proof_rollback';

  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> '0119_proof_rollback' THEN
      RAISE;
    END IF;
  END;
END;
$proof$;
