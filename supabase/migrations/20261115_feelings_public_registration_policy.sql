-- Restore the original public participant-registration path for the shared Feelings schema.
-- Existing tournament participants are not updated or deleted.
begin;
grant insert on mastersite_feelings.participants to anon,authenticated;
create policy mastersite_feelings_public_participant_registration
on mastersite_feelings.participants
for insert to anon,authenticated
with check (
 mastersite_feelings.current_tournament_registration_open()
 and char_length(trim(name)) between 2 and 40
 and team_size = mastersite_feelings.current_tournament_team_size()
 and jsonb_typeof(members)='array'
 and jsonb_array_length(members)=team_size
 and not exists (
   select 1 from jsonb_array_elements_text(members) as member(value)
   where char_length(trim(member.value)) not between 2 and 40
 )
 and (submitted_by is null or submitted_by=(select auth.uid()))
);
commit;
