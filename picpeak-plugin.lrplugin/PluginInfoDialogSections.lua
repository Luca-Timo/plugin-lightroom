require("PicPeakAPI")
require("SharedDialogSections")

PluginInfoDialogSections = {}

function PluginInfoDialogSections.startDialog(propertyTable)
    if prefs.logging == nil then
        prefs.logging = false
    end
    propertyTable.logging = prefs.logging
    -- The connection lives here too (#745). Import selections is a Library
    -- menu item with no export dialog behind it, so the Plug-in Manager is
    -- the only place a user can sign in before using it.
    SharedDialogSections.syncConnectionPrefs(propertyTable)
    propertyTable:addObserver("logging", function(props)
        prefs.logging = props.logging
    end)
end

function PluginInfoDialogSections.sectionsForBottomOfDialog(f, propertyTable)
    local bind = LrView.bind

    return {
        SharedDialogSections.getServerConnectionSection(f, propertyTable),
        {
            bind_to_object = propertyTable,
            title = "PicPeak Plugin Logging",
            f:row({
                f:static_text({
                    title = util.getLogfilePath(),
                }),
            }),
            f:row({
                spacing = f:control_spacing(),
                f:checkbox({
                    title = "Enable debug logging",
                    value = bind("logging"),
                }),
                f:push_button({
                    title = "Show logfile",
                    action = function()
                        LrShell.revealInShell(util.getLogfilePath())
                    end,
                }),
            }),
        },
    }
end

function PluginInfoDialogSections.endDialog(propertyTable)
    prefs.logging = propertyTable.logging
    if propertyTable.logging then
        log:enable("logfile")
    else
        log:disable()
    end
end
