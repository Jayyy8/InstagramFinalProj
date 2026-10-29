-- Removes every seed account made by supabase/seed.sql, with all of their
-- posts, reels, stories, notes, follows, likes and comments (they are
-- deleted along with the account). Real accounts are not touched.
delete from auth.users where email like '%@seed.invalid';
