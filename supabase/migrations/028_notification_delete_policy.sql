create policy "members can delete studio notifs"
  on notifications for delete
  using (studio_id in (
    select studio_id from user_studio_roles where user_id = auth.uid()
  ));
