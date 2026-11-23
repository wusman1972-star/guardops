CREATE OR REPLACE FUNCTION guardops.tables_worth_guarding(p_picture_id bigint)
 RETURNS TABLE(schema_name text, object_name text, suggested boolean, reason text, score integer)
 LANGUAGE sql
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
with t as (
  select o.schema_name, o.object_name, o.row_estimate, o.bytes,
         lower(o.object_name) as nm,
         (select string_agg(lower(c->>'name'), ' ') from jsonb_array_elements(o.column_shape) c) as cols
    from guardops.shape_object o
   where o.picture_id = p_picture_id and o.object_kind = 'table'
), marked as (
  select t.*,
    (cols ~ '(amount|price|total|balance|salary|invoice|payment|currency|iban|card_|cardnumber|cvv)') as money,
    (cols ~ '(email|phone|mobile|address|passport|national|cnic|nic_|date_of_birth|dob|full_name|first_name|last_name)') as people,
    (cols ~ '(password|token|secret|api_key|apikey|hash|salt)') as keys,
    (nm ~ '(customer|client|user|account|order|invoice|payment|booking|reservation|contract|rental|lead|deal|employee|member|patient|appointment)') as core_name,
    (coalesce(row_estimate,0) > 1000) as busy
  from t
)
select schema_name, object_name,
  (money or people or keys or core_name) as suggested,
  nullif(concat_ws(', ',
    case when money     then 'holds money figures' end,
    case when people    then 'holds personal details' end,
    case when keys      then 'holds passwords or keys' end,
    case when core_name then 'looks like a core business table' end,
    case when busy      then 'one of the busier tables' end), '') as reason,
  (case when keys then 4 else 0 end + case when money then 3 else 0 end
   + case when people then 3 else 0 end + case when core_name then 2 else 0 end
   + case when busy then 1 else 0 end) as score
from marked
order by 5 desc, coalesce(bytes,0) desc;
$function$
