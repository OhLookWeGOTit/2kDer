-- modules/automatic_broadcast.lua
-- PROOF-OF-CONCEPT SCRIPT for 2kDer
-- Demonstrates future automatic broadcast pack switching based on game context.
-- REQUIRES: 2kDer core DLL with memory API and LiveFF. Not functional yet.

local mod = {
    name = "Automatic Broadcast",
    version = "2.1-PoC",
    author = "2kDer Community",
    config = {
        default = "default",
        regular_packs = {"tnt", "espn", "nbatv", "tnt_gold"},
        random_mode = "random_each_game",   -- or "random_per_session"
        playoffs_rd1 = "tnt",
        playoffs_conf = "tnt",
        finals = "espn",
        finals_game1 = "espn_finals_game1",
        all_star = "tnt_allstar",
        special_dates = {
            ["12-25"] = "christmas",
            ["02-14"] = "valentine",
            ["10-31"] = "halloween",
        }
    }
}

-- Local cache for session-random
local session_pack = nil

function mod.init(ctx)
    -- Load user overrides from automatic_broadcast.ini (if available)
    local ini = ctx:load_config("automatic_broadcast.ini")
    if ini then
        for k, v in pairs(ini) do
            mod.config[k] = v
        end
    end

    -- If random_per_session, pick once for the whole session
    if mod.config.random_mode == "random_per_session" then
        session_pack = random_choice(mod.config.regular_packs)
        ctx:log("[AutoBroadcast] Session pack: " .. session_pack)
    end
    ctx:log("[AutoBroadcast] Initialized")
end

-- Helper: pick a random element from a table
local function random_choice(tbl)
    if #tbl == 0 then return mod.config.default end
    return tbl[math.random(#tbl)]
end

-- Core selection logic (will use memory.read once implemented)
local function choose_broadcast(ctx)
    -- Placeholder: In the final version, these values will come from the memory API
    -- local game_mode   = memory.read(ctx.addresses.game_mode, "int")
    -- local playoff_rd  = memory.read(ctx.addresses.playoff_round, "int")
    -- local series_game = memory.read(ctx.addresses.series_game, "int")
    -- local month_day   = memory.read(ctx.addresses.calendar_md, "string", 5)

    -- For PoC, we simply return a random regular pack as a demonstration
    return random_choice(mod.config.regular_packs)
end

-- Apply file redirections for the chosen pack
local function apply_broadcast(ctx, pack_folder)
    local base = "liveff/broadcasts/" .. pack_folder .. "/"

    -- Scoreboard
    local sb_path = base .. "newscorebug.iff"
    if ctx:file_exists(sb_path) then
        ctx:add_file_redirect("newscorebug.iff", sb_path)
    else
        ctx:log("[AutoBroadcast] WARNING: newscorebug.iff missing in " .. pack_folder)
    end

    -- Wipe files (if present)
    local wipe_files = {"replay.bin", "sting.bin", "intro.bin", "wipe.bin"}
    for _, fname in ipairs(wipe_files) do
        local wipe_src = base .. "wipe/" .. fname
        if ctx:file_exists(wipe_src) then
            ctx:add_file_redirect("wipe/" .. fname, wipe_src)
        end
    end

    ctx:log("[AutoBroadcast] Loaded pack: " .. pack_folder)
end

-- Event called right before the game opens newscorebug.iff
function mod.on_loading_start(ctx)
    local pack = choose_broadcast(ctx)
    apply_broadcast(ctx, pack)
end

return {
    init = mod.init,
    events = {
        loading_start = mod.on_loading_start
    }
}
