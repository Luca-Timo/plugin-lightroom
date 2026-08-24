--[[
    Library > Plug-in Extras > Import selections from PicPeak
    (PicPeak/picpeak#745).

    Everything real happens in ImportSelectionsDialog; this exists because
    LrLibraryMenuItems needs a file to point at. The async task is required —
    the dialog makes HTTP calls, and Lightroom forbids those on the main task.
]]

require("ImportSelectionsDialog")

LrTasks.startAsyncTask(function()
    local ok, err = LrTasks.pcall(function()
        ImportSelectionsDialog.show()
    end)
    if not ok then
        log:error("ImportSelectionsMenuItem failed: " .. tostring(err))
        ErrorHandler.handleError(
            "Something went wrong importing PicPeak selections. See the plug-in log for details.",
            "ImportSelectionsMenuItem: " .. tostring(err)
        )
    end
end)
