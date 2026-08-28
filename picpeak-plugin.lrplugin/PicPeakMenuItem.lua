--[[
    Library > Plug-in Extras > PicPeak Importer

    The plugin's single entry point, and it opens the importer directly.

    There was a hub here — a launcher window whose buttons opened the importer
    or the connection screen. It existed so that ONE macOS App Shortcut could
    reach every feature. That premise turned out to be false: Lightroom builds
    the Plug-in Extras items lazily, after macOS has already applied key
    equivalents at launch, so an App Shortcut binds to the plugin-name header
    and never to the item. No shortcut is possible.

    Without a shortcut to justify it the hub was a click in front of the only
    screen anyone wanted, so the importer IS the main window now. Connection
    is a button on it.

    Dispatch is still by return value rather than nested modals: the importer
    closes, the connection screen opens, then the importer comes back.
]]

require("ImportSelectionsDialog")
require("ConnectionDialog")

LrTasks.startAsyncTask(function()
    local ok, err = LrTasks.pcall(function()
        -- Bounded rather than `while true`: each pass is a real user decision,
        -- but a bug that always returned "connection" would otherwise spin
        -- dialogs forever with no way out.
        for _ = 1, 20 do
            if ImportSelectionsDialog.show() ~= "connection" then
                return
            end
            ConnectionDialog.show()
        end
    end)
    if not ok then
        log:error("PicPeakMenuItem failed: " .. tostring(err))
        ErrorHandler.handleError(
            "Something went wrong opening PicPeak. See the plug-in log for details.",
            "PicPeakMenuItem: " .. tostring(err)
        )
    end
end)
