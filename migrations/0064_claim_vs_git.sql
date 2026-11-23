-- Board 11869 part 7. claim_vs_git, REWRITTEN rather than lifted, onto the new
-- job and claim tables. Takes a claim id, not a ledger id.
--
-- What is kept, word for word in behaviour: the four verdicts (found, missing,
-- not-checkable, unproven), one row per claim, the reader judging nothing and
-- writing nothing; the sha matched by PREFIX against commit_seen of the job own
-- repo; the claim escaped before LIKE so it is data and never a pattern; the
-- evidence rule that only a commit sighted by a PROVEN pull counts; the matched
-- commit files riding out of the same query so a duplicate sha cannot answer
-- file claims from the wrong commit; the NONE sentinel reading unproven, since
-- nothing claimed is nothing denied; a non-object files row reading empty
-- rather than raising; Windows and non-repo-shaped paths reading not-checkable.
--
-- What changes, and why: the old door parsed 'ORDER-n' out of a ledger text
-- field to find the repo and, when that failed, guessed the repo if exactly one
-- was linked and refused otherwise (rules B and C). job.repo_link_id is NOT
-- NULL, so the repo is always named and that whole guess-or-refuse branch is
-- gone. not-checkable survives for its other two causes.

CREATE OR REPLACE FUNCTION guardops.claim_vs_git(p_claim_id bigint)
 RETURNS TABLE(claim_kind text, claim_value text, verdict text, detail text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_sha_claim    text;
  v_files        text[];
  v_repo_link_id bigint;
  v_esc          text;
  v_sha          text;
  v_have         boolean := false;
  v_files_json   jsonb;
  f              text;
  v_p            text;
begin
  select c.sha_claimed, c.files_claimed, j.repo_link_id
    into v_sha_claim, v_files, v_repo_link_id
    from guardops.claim c
    join guardops.job j
      on j.id = c.job_id and j.account_id = c.account_id
   where c.id = p_claim_id and c.account_id = guardops.current_account();
  if not found then
    claim_kind := 'claim'; claim_value := p_claim_id::text;
    verdict := 'missing'; detail := 'no such claim';
    return next; return;
  end if;

  -- (1) the sha claim, prefix-matched against commit_seen of the job's repo.
  claim_kind := 'git_commit'; claim_value := coalesce(v_sha_claim, 'NONE');
  if v_sha_claim is null or v_sha_claim = 'NONE' then
    verdict := 'unproven'; detail := 'no sha claimed';
  else
    v_esc := replace(replace(replace(v_sha_claim, '\', '\\'), '%', '\%'), '_', '\_');
    select cs.sha, (case when jsonb_typeof(cs.files) = 'object' then cs.files else '{}'::jsonb end)
      into v_sha, v_files_json
      from guardops.commit_seen cs
     where cs.sha like v_esc || '%' and cs.repo_link_id = v_repo_link_id
       and cs.account_id = guardops.current_account()
       -- evidence only when a PROVEN pull has sighted the commit
       and exists (select 1
                     from guardops.pull_commit pc
                     join guardops.repo_pull rp
                       on rp.id = pc.pull_id and rp.account_id = guardops.current_account()
                    where pc.commit_seen_id = cs.id
                      and pc.account_id = guardops.current_account()
                      and rp.proof_status = 'PROVEN')
     order by cs.committed_at desc nulls last, cs.id desc
     limit 1;
    if v_sha is not null then
      v_have := true;
      verdict := 'found'; detail := 'commit_seen sha ' || v_sha;
    else
      verdict := 'missing'; detail := 'no linked-repo commit begins with this sha';
    end if;
  end if;
  return next;

  -- (2) each claimed file, checked as a files key of the matched commit.
  if v_files is null or array_length(v_files, 1) is null
     or (array_length(v_files, 1) = 1 and v_files[1] = 'NONE') then
    claim_kind := 'file'; claim_value := 'NONE';
    verdict := 'unproven'; detail := 'no files claimed';
    return next;
  else
    foreach f in array v_files loop
      claim_kind := 'file'; claim_value := f;
      if f = 'NONE' then
        verdict := 'unproven'; detail := 'no file claimed';
      elsif f ~ '\\' or f ~ '^[A-Za-z]:' then
        verdict := 'not-checkable'; detail := 'a local path, not a repo path';
      elsif f !~ '^(\./)?[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$' then
        verdict := 'not-checkable'; detail := 'not a repo-path shape';
      elsif not v_have then
        if v_sha_claim is null or v_sha_claim = 'NONE' then
          verdict := 'unproven'; detail := 'no commit claimed to anchor this file';
        else
          verdict := 'missing'; detail := 'the claimed commit was not found';
        end if;
      else
        v_p := regexp_replace(f, '^\./', '');
        if v_files_json ? v_p then
          verdict := 'found'; detail := 'a files key of ' || left(v_sha, 7);
        else
          verdict := 'missing'; detail := 'not a files key of ' || left(v_sha, 7);
        end if;
      end if;
      return next;
    end loop;
  end if;
  return;
end
$function$;
