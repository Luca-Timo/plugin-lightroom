--[[
    Where the PicPeak API token lives.

    It used to sit in LrPrefs, which is a plaintext preferences file — and the
    token has to carry the `admin` scope, so that is full account access
    readable by anything on the machine. LrPasswords stores it in the OS
    keychain instead.

    Migration is automatic and one-way: any token found in prefs is moved to
    the keychain on first read and the prefs copy is cleared, so an existing
    install upgrades without the user signing in again and without leaving the
    plaintext copy behind.

    LrPasswords is keyed by an arbitrary string. The server URL is part of the
    key so that pointing the plugin at a different PicPeak does not silently
    reuse the previous server's token.
]]

TokenStore = {}

local LEGACY_PREF_KEY = "apiToken"

local function keyFor(url)
    local host = url
    if type(url) == "string" then
        -- Host only: the same server reached with a trailing slash must not
        -- get a second keychain entry.
        host = url:gsub("/+$", "")
    end
    return "picpeak:apiToken:" .. tostring(host or "")
end

--[[
    Read the token for a server, migrating a legacy plaintext one if present.

    @param url server URL
    @return token string, or "" when there is none
]]
function TokenStore.get(url)
    local legacy = _G.prefs[LEGACY_PREF_KEY]
    if legacy ~= nil and legacy ~= "" then
        -- Move it, then clear it. Done before the keychain read so an
        -- interrupted previous migration cannot strand the token in neither
        -- place: the prefs copy is only cleared once the write returns.
        local ok = LrTasks.pcall(function()
            LrPasswords.store(keyFor(url), legacy)
        end)
        if ok then
            _G.prefs[LEGACY_PREF_KEY] = ""
            log:info("TokenStore: migrated API token from prefs to the keychain")
            return legacy
        end
        -- Keychain unavailable (denied, or a headless context). Keep working
        -- from prefs rather than locking the user out of their own plugin.
        log:warn("TokenStore: keychain unavailable, continuing with the prefs token")
        return legacy
    end

    local stored
    local ok = LrTasks.pcall(function()
        stored = LrPasswords.retrieve(keyFor(url))
    end)
    if not ok then
        log:warn("TokenStore: keychain read failed")
        return ""
    end
    return stored or ""
end

function TokenStore.set(url, token)
    local ok = LrTasks.pcall(function()
        LrPasswords.store(keyFor(url), token or "")
    end)
    if not ok then
        log:error("TokenStore: could not write the token to the keychain")
        return false
    end
    -- Never leave a copy in prefs, including after a re-sign-in on an install
    -- that predates this.
    _G.prefs[LEGACY_PREF_KEY] = ""
    return true
end

function TokenStore.clear(url)
    LrTasks.pcall(function()
        LrPasswords.store(keyFor(url), "")
    end)
    _G.prefs[LEGACY_PREF_KEY] = ""
end

return TokenStore
