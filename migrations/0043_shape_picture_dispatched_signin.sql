-- board 11845: record the sign-in that dispatched each signed request on the picture,
-- so signin_dead can act on the right sign-in even if the user signs in again before
-- the response is collected.
ALTER TABLE guardops.shape_picture
  ADD COLUMN IF NOT EXISTS dispatched_signin_id bigint
  REFERENCES guardops.connected_account(id);
