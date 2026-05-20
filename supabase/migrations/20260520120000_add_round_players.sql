-- ---------------------------------------------------------------
-- rounds.players
--
-- Snapshot of the playing group (the user + up to three others) attached
-- to a single round. Stored as JSONB rather than a side table because:
-- each entry is just a name + handicap captured at round-setup time, and
-- we never need to query across rounds to find "rounds I played with X."
-- ---------------------------------------------------------------

ALTER TABLE rounds
    ADD COLUMN players JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE rounds
    ADD CONSTRAINT rounds_players_max_4 CHECK (
        jsonb_typeof(players) = 'array'
        AND jsonb_array_length(players) <= 4
    );
