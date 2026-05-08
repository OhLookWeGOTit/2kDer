-- live_texture_injection.lua  –  Proof‑of‑Concept for 2kDer
---------------------------------------------------------------------

-- This module extends the LiveFF system with the ability to inject
-- individual loose textures into .iff archives on the fly.

-- How it works (once the C++ core exposes the right API):
--   1. You dump the contents of an .iff file (e.g., newscorebug.iff)
--      into liveff_dump/<name>/ using the hotkey or a Lua call.
--   2. You edit any .dds texture you like.
--   3. You place the modified file into
--         liveff_textures/<iffname>/<internal_path>
--      (for example: liveff_textures/newscorebug.iff/score_bg.dds)
--   4. The next time the game loads that .iff, 2kDer will patch the
--      archive in memory, replacing the original entry with your
--      loose file. No repacking, no hex editing, no permanent
--      overwrites.

-- This module is a PoC skeleton. It assumes the C++ side provides:
--   ctx:dump_iff(iff_name)          – extract all files to liveff_dump/
--   ctx:list_loose_textures(iff)    – returns a table of available overrides
--   ctx:set_texture_override(iff, internal_path) – register a single override
--   The core will then patch the ZIP stream automatically.

local mod = {}

-- ---------- default configuration ----------
mod.config = {
    -- Which key triggers a texture dump of the currently loading .iff
    dump_key = "F7",

    -- If true, automatically reload the patched .iff whenever a file
    -- in liveff_textures/ changes (requires folder watcher in C++ core)
    auto_reload = false
}

-- ---------- init ----------
function mod.init(ctx)
    local ini = ctx:load_config("live_texture_injection.ini")
    if ini then
        for k, v in pairs(ini) do
            mod.config[k] = v
        end
    end

    -- Register a key handler for the dump hotkey (once input API is ready)
    -- ctx:on_key_down(mod.config.dump_key, function() ... end)

    ctx:log("[LiveTexture] Initialised")
end

-- ---------- optional event: after a file redirect is set ----------
-- This handler is called whenever LiveFF resolves a file.
-- We can use it to attach texture overrides for the specific .iff being loaded.
function mod.on_file_redirected(ctx, original_name, resolved_path)
    -- Strip any liveff path to get the base folder name
    local base = original_name:match("([^/\\]+)%.iff$")
    if not base then return end

    -- Check if we have any loose textures for this .iff
    local overrides = ctx:list_loose_textures(original_name) or {}
    for _, internal_path in ipairs(overrides) do
        ctx:log("[LiveTexture] Overriding " .. internal_path .. " in " .. original_name)
        ctx:set_texture_override(original_name, internal_path)
    end
end

return {
    init   = mod.init,
    events = {
        file_redirected = mod.on_file_redirected
    }
}
