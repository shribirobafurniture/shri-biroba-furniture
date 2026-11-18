create or replace function public.customer_cancel_order(
  p_order_code text,
  p_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  changed_count integer;
begin
  if p_order_code is null or p_phone is null then
    return jsonb_build_object(
      'success', false,
      'message', 'Order code and phone are required'
    );
  end if;

  update public.orders
  set order_status = 'Cancelled'
  where upper(order_code) = upper(trim(p_order_code))
    and regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g')
        = regexp_replace(p_phone, '[^0-9]', '', 'g')
    and order_status in ('New', 'Confirmed');

  get diagnostics changed_count = row_count;

  if changed_count = 0 then
    return jsonb_build_object(
      'success', false,
      'message', 'Order not found or not eligible for cancellation'
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Order cancelled successfully'
  );
end;
$$;

revoke all on function public.customer_cancel_order(text,text) from public;

grant execute on function public.customer_cancel_order(text,text)
to anon, authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
end $$;
