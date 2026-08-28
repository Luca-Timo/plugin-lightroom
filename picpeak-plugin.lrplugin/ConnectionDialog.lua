--[[
    The server connection as a standalone modal, for the PicPeak hub.

    The same controls also appear as a *section* in the Export dialog and the
    Plug-in Manager. All three share SharedDialogSections.getConnectionRows,
    and all three read and write the same prefs, so signing in from any of
    them enables every other surface.
]]

require("SharedDialogSections")

ConnectionDialog = {}

function ConnectionDialog.show()
    LrFunctionContext.callWithContext("picpeakConnection", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        SharedDialogSections.syncConnectionPrefs(props)

        local column = {
            spacing = f:control_spacing(),
            bind_to_object = props,
        }
        for _, row in ipairs(SharedDialogSections.getConnectionRows(f, props)) do
            table.insert(column, row)
        end

        LrDialogs.presentModalDialog({
            title = "PicPeak — Connection",
            contents = f:column(column),
            actionVerb = "Done",
            cancelVerb = "< exclude >",
        })
    end)
end

return ConnectionDialog
