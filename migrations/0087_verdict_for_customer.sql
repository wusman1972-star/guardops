-- Board 11989: single-transaction wrapper so the screen can read a verdict over REST
CREATE OR REPLACE FUNCTION guardops.verdict_for_customer(p_customer bigint, p_job_id bigint)
  RETURNS TABLE(kind text, what text, proof text)
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = ''
AS $$
BEGIN
  PERFORM guardops.act_as_house(p_customer);
  RETURN QUERY SELECT * FROM guardops.job_verdict(p_job_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION guardops.verdict_for_customer(bigint, bigint) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION guardops.verdict_for_customer(bigint, bigint) TO service_role;
