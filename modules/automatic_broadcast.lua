-- automatic_broadcast.lua  –  Proof-of-Concept for 2kDer
---------------------------------------------------------------------

-- When this script is active, 2kDer will automatically swap your
-- in-game broadcast graphics (scoreboard, wipes, etc.) depending on
-- what kind of match you're about to play.

-- It works exactly like the automatic scoreboard switching in PES
-- Sider – but now for NBA 2K14. The idea (and huge respect) comes
-- from the PES-Modding team.

-- Right now this is a pure PoC. The core 2kDer DLL isn't finished
-- yet, so the memory reading and file redirection parts won't actually
-- run. But once the DLL is injected and firing events, all the logic
-- here will work as described.

-- The script reads the game's current state (playoff round, date,
-- teams, etc.) directly from memory – addresses that the Chinese
-- modding community already mapped years ago (shout-out to
-- Dream Stars and the Baidu Tieba folks). It then tells 2kDer's
-- LiveFF system to serve the appropriate broadcast pack without
-- ever touching the original newscorebug.iff or wipe files.

-- What it handles:
-- • Regular season / Quick Game – picks a random network from
-- a configurable pool (TNT, ESPN, NBA TV, TNT Gold, etc.)
-- • NBA Playoffs – uses different packs per round (1st round,
-- Conference Finals, NBA Finals) and even a special Game 1
-- variant for the Finals.
-- • All‑Star Game – automatically detected and switched.
-- • Special calendar dates – Christmas, Valentine's, Halloween,
-- Thanksgiving (you can add more easily).
-- • Any other mode (Euroleague, Blacktop, Training, etc.) falls
-- back to a default ESPN‑style pack.

-- The user can tweak everything via the companion .ini file
-- (automatic_broadcast.ini) without ever opening this Lua script.

-- We keep everything inside a local table called 'mod'. 2kDer expects
-- it to be returned at the end of the file.
local mod = {}

-- +------------------------------------------------------------------+
-- | Default configuration                                            |
-- +------------------------------------------------------------------+
-- All of these can be overridden by the user's automatic_broadcast.ini.
mod.config = {

    -- The pack that gets used when nothing special is going on.
    -- Must match a folder inside liveff/broadcasts/ .
    default = "nba_espn",

    -- The list of broadcast packs used for regular season & quick games
    -- (game mode 0, 1, 2). We pick randomly from this pool.
    regular_packs = {
        "tnt", "espn", "nbatv", "tnt_gold"
    },

    -- How the random selection behaves:
    --   "random_each_game"  → new random choice every match
    --   "random_per_session" → picks once when the game starts and sticks
    --                           until you close NBA 2K14.
    random_mode = "random_each_game",

    -- Playoff round overrides (only used when game_mode == 3).
    -- playoff_round comes from memory: 0 = regular season, 1 = first round,
    -- 2 = conference semis, 3 = conference finals, 4 = NBA Finals.
    playoffs_rd1  = "tnt",            -- first round + semis
    playoffs_conf = "tnt_conf",       -- conference finals
    finals        = "espn_finals",    -- Finals (games 2-7)
    finals_game1  = "espn_finals_g1", -- special Game 1 opening night

    -- All‑Star Game (game_mode == 7).
    all_star = "tnt_allstar",

    -- Calendar‑based overrides: when the in‑game date matches one of
    -- these "MM-DD" strings, we force the corresponding pack.
    special_dates = {
        ["12-25"] = "christmas",
        ["02-14"] = "valentine",
        ["10-31"] = "halloween",
        ["11-23"] = "thanksgiving"
    }
}

-- +------------------------------------------------------------------+
-- | Internal state (not user‑configurable)                          |
-- +------------------------------------------------------------------+
-- If random_mode is "random_per_session", we cache the chosen pack here
-- so that all matches during the same session use the same broadcast style.
local session_pack = nil

-- +------------------------------------------------------------------+
-- | Helper functions                                                 |
-- +------------------------------------------------------------------+
-- Returns a random element from a table, or the default pack if the
-- table happens to be empty (safety net).
local function random_choice(tbl)
    if #tbl == 0 then
        return mod.config.default
    end
    return tbl[math.random(#tbl)]
end

-- +------------------------------------------------------------------+
-- | init() – called exactly once when 2kDer loads the module        |
-- +------------------------------------------------------------------+
function mod.init(ctx)
    -- Try to load user overrides from automatic_broadcast.ini.
    -- ctx:load_config() is a helper that 2kDer will provide. If the
    -- file doesn't exist, it returns nil and we just keep the defaults.
    local ini = ctx:load_config("automatic_broadcast.ini")
    if ini then
        -- Merge everything from the ini into mod.config. Complex values
        -- like tables will need extra care in the final core, but for
        -- now we assume simple key‑value pairs.
        for k, v in pairs(ini) do
            mod.config[k] = v
        end
    end

    -- If we're in "random_per_session" mode, pick one network now and
    -- store it for the rest of this session.
    if mod.config.random_mode == "random_per_session" then
        session_pack = random_choice(mod.config.regular_packs)
        ctx:log("[AutoBroadcast] Session‑locked broadcast: " .. session_pack)
    end

    ctx:log("[AutoBroadcast] Initialised")
end

-- +------------------------------------------------------------------+
-- | choose_broadcast() – the brain of the operation                 |
-- +------------------------------------------------------------------+
-- Reads the current game state from memory (via 2kDer's memory API)
-- and decides which broadcast pack folder to use.
--
-- The memory addresses (ctx.mem.*) are discovered at startup by
-- 2kDer's pattern scanner. They correspond to the well‑known offsets
-- used by Chinese tools like Dream Stars – we just give them friendly
-- names here.
local function choose_broadcast(ctx)
    -- game_mode values:
    --   0 = Quick Game
    --   1 = Association
    --   2 = Season
    --   3 = Playoffs
    --   4 = Euroleague
    --   5 = Blacktop
    --   6 = Training
    --   7 = All‑Star Game
    --   8 = MyCareer
    local game_mode   = memory.read(ctx.mem.game_mode, "int")

    -- playoff_round: 0 = regular season, 1-4 = rounds (see above)
    local playoff_rd  = memory.read(ctx.mem.playoff_round, "int")

    -- series_game: 1-7 (only meaningful in playoffs)
    local series_game = memory.read(ctx.mem.series_game, "int")

    -- in‑game calendar date, stored as a readable string "MM-DD"
    -- (e.g., "12-25" for Christmas).
    local month_day   = memory.read(ctx.mem.calendar_md, "string", 5)

    -- 1) All‑Star Game – always override everything else.
    if game_mode == 7 then
        return mod.config.all_star
    end

    -- 2) Playoffs – we're in game_mode 3 and have a valid round.
    if game_mode == 3 and playoff_rd > 0 then
        if playoff_rd == 4 then
            -- NBA Finals: use Game 1 package for the opener,
            -- regular Finals package for games 2-7.
            if series_game == 1 then
                return mod.config.finals_game1
            else
                return mod.config.finals
            end
        elseif playoff_rd == 3 then
            return mod.config.playoffs_conf   -- Conference Finals
        else
            return mod.config.playoffs_rd1    -- 1st & 2nd rounds
        end
    end

    -- 3) Special calendar date – completely ignore random/pack pools
    -- on holidays. This lets you force Christmas courts, Valentine's
    -- scoreboards, etc.
    if mod.config.special_dates[month_day] then
        return mod.config.special_dates[month_day]
    end

    -- 4) Regular game: Quick Game (0), Association (1) or Season (2).
    if game_mode == 0 or game_mode == 1 or game_mode == 2 then
        if mod.config.random_mode == "random_per_session" and session_pack then
            return session_pack      -- use the session‑locked pack
        else
            return random_choice(mod.config.regular_packs) -- roll the dice
        end
    end

    -- 5) Fallback – Euroleague, Blacktop, Training, MyCareer, etc.
    return mod.config.default
end

-- +------------------------------------------------------------------+
-- | apply_broadcast() – tells 2kDer which files to redirect         |
-- +------------------------------------------------------------------+
-- Takes the chosen pack name (e.g., "tnt") and registers LiveFF
-- redirects for the scoreboard and any extra wipe/transition files.
-- The actual redirection happens when the game tries to open those
-- files during the loading screen, so we must call this *before*
-- the loading starts. That's why it's triggered by the set_teams event.
local function apply_broadcast(ctx, pack_folder)
    local base = "liveff/broadcasts/" .. pack_folder .. "/"

    -- Redirect the main scoreboard overlay (newscorebug.iff).
    local sb_path = base .. "newscorebug.iff"
    if ctx:file_exists(sb_path) then
        ctx:add_file_redirect("newscorebug.iff", sb_path)
    else
        -- It's not a fatal error – the game will just use its original
        -- scoreboard. We log it so you know the pack is incomplete.
        ctx:log("[AutoBroadcast] WARNING: missing " .. sb_path)
    end

    -- Wipe / transition files are optional. Many broadcast packs
    -- replace wipe/replay transitions and intro stings.
    -- The exact internal filenames vary from pack to pack, so we just
    -- try all the common ones. If a file doesn't exist, we skip it.
    local wipe_files = {
        "replay.bin", "sting.bin", "intro.bin", "tran.bin",
        "wipe.bin", "transition.bin"
    }
    for _, fname in ipairs(wipe_files) do
        local wpath = base .. "wipe/" .. fname
        if ctx:file_exists(wpath) then
            -- The game might keep wipes in a "wipe" subfolder,
            -- so we redirect that specific path.
            ctx:add_file_redirect("wipe/" .. fname, wpath)
        end
    end

    ctx:log("[AutoBroadcast] Switched to pack: " .. pack_folder)
end

-- +------------------------------------------------------------------+
-- | Event handlers (called by 2kDer at the right moments)           |
-- +------------------------------------------------------------------+
-- set_teams fires right after the home & away teams are determined.
-- That's the earliest safe moment to pick a broadcast pack based on
-- game mode and team IDs. We read memory, choose the pack, and set
-- up the file redirects.
function mod.on_set_teams(ctx)
    local pack = choose_broadcast(ctx)
    apply_broadcast(ctx, pack)
end

-- set_conditions fires when the match conditions (stadium, weather,
-- time of day, etc.) are finalised. We don't need it for broadcast
-- switching, but it's a good hook if you later want to force a
-- certain arena or lighting depending on the pack.
function mod.on_set_conditions(ctx)
    -- Placeholder: nothing here yet, but you could, for example,
    -- adjust stadium lighting to match a playoff atmosphere.
end

-- +------------------------------------------------------------------+
-- | Module return – this table is what 2kDer actually loads.        |
-- +------------------------------------------------------------------+
return {
    init   = mod.init,
    events = {
        set_teams      = mod.on_set_teams,
        set_conditions = mod.on_set_conditions
    }
}
