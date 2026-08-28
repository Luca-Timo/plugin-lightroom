--[[
    Library > Plug-in Extras > PicPeak

    The plugin's single entry point. Everything else is reached from the hub,
    so one OS-level keyboard shortcut on this title covers the whole plugin.
]]

require("PicPeakHub")

LrTasks.startAsyncTask(function()
    local ok, err = LrTasks.pcall(function()
        PicPeakHub.show()
    end)
    if not ok then
        log:error("PicPeakMenuItem failed: " .. tostring(err))
        ErrorHandler.handleError(
            "Something went wrong opening PicPeak. See the plug-in log for details.",
            "PicPeakMenuItem: " .. tostring(err)
        )
    end
end)
