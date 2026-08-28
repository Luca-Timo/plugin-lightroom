--[[
    The PicPeak hub — one menu item, everything reachable from inside it.

    Lightroom Classic gives plugins no way to create a top-level menu and no
    way to create a panel; File/Library > Plug-in Extras are the only entry
    points that exist. So rather than scattering several entries through
    Plug-in Extras, there is ONE entry ("PicPeak") that opens this window, and
    the window dispatches to everything else. A single OS-level App Shortcut
    on that one title then reaches the whole plugin.

    Dispatch is by the dialog's own buttons rather than nested modal dialogs:
    presentModalDialog returns "ok" / "other" / "cancel", the hub closes, the
    chosen flow runs, and the hub reopens. Nesting modals is where Lightroom
    plugins tend to deadlock, and this avoids it entirely.
]]

require("ImportSelectionsDialog")
require("ConnectionDialog")
require("TokenStore")

PicPeakHub = {}

local function statusLines()
    local prefs = _G.prefs
    local lines = {}

    if util.nilOrEmpty(prefs.url) then
        table.insert(lines, "No server configured yet — start with Connection.")
    else
        table.insert(lines, "Server: " .. tostring(prefs.url))
        if not util.nilOrEmpty(prefs.signedInAs) then
            local expiry = ""
            if not util.nilOrEmpty(prefs.tokenExpiresAt) then
                expiry = "  (token expires " .. string.sub(tostring(prefs.tokenExpiresAt), 1, 10) .. ")"
            end
            table.insert(lines, "Signed in as " .. tostring(prefs.signedInAs) .. expiry)
        elseif not util.nilOrEmpty(TokenStore.get(prefs.url)) then
            table.insert(lines, "Connected with a manually entered API token.")
        else
            table.insert(lines, "Not signed in.")
        end
    end

    if not util.nilOrEmpty(prefs.import_folderPath) then
        table.insert(lines, "Last RAW folder: " .. tostring(prefs.import_folderPath))
    end
    return lines
end

function PicPeakHub.show()
    -- Loop so the hub comes back after each action, which is what makes it
    -- feel like one window rather than a chain of dialogs.
    local keepOpen = true
    while keepOpen do
        local choice
        LrFunctionContext.callWithContext("picpeakHub", function(context)
            local f = LrView.osFactory()
            local props = LrBinding.makePropertyTable(context)

            local column = {
                spacing = f:control_spacing(),
                bind_to_object = props,
                f:static_text({
                    title = "PicPeak Importer",
                    font = "<system/bold>",
                }),
                f:static_text({
                    title = "Round-trip your client's proofing selections.",
                    font = "<system/small>",
                }),
                f:separator({ fill_horizontal = 1 }),
            }
            for _, line in ipairs(statusLines()) do
                table.insert(column, f:static_text({
                    title = line,
                    font = "<system/small>",
                    fill_horizontal = 1,
                    truncation = "middle",
                }))
            end
            table.insert(column, f:separator({ fill_horizontal = 1 }))
            table.insert(column, f:static_text({
                title = "Import selections  —  pull the client's colours and stars onto your RAWs\n"
                    .. "Connection        —  server, sign-in and API token\n\n"
                    .. "To send finished edits back, use the PicPeak Publisher in the\n"
                    .. "Publish Services panel: re-publishing replaces the proof in place\n"
                    .. "and keeps the client's marks.",
                font = "<system/small>",
            }))

            choice = LrDialogs.presentModalDialog({
                title = "PicPeak Importer",
                contents = f:column(column),
                actionVerb = "Import selections",
                otherVerb = "Connection",
                cancelVerb = "Close",
            })
        end)

        if choice == "ok" then
            ImportSelectionsDialog.show()
        elseif choice == "other" then
            ConnectionDialog.show()
        else
            keepOpen = false
        end
    end
end

return PicPeakHub
