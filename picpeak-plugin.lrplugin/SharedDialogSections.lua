require("PicPeakAPI")

SharedDialogSections = {}

-- PicPeak event types for UI menus
SharedDialogSections.EVENT_TYPES = {
    { title = "Other", value = "other" },
    { title = "Wedding", value = "wedding" },
    { title = "Birthday", value = "birthday" },
    { title = "Corporate", value = "corporate" },
    { title = "Family", value = "family" },
}

-- Generate the 'PicPeak Server connection' dialog section
function SharedDialogSections.getServerConnectionSection(f, propertyTable)
    local bind = LrView.bind
    local share = LrView.share

    return {
        title = "PicPeak Server connection",
        bind_to_object = propertyTable,
        f:row({
            f:static_text({
                title = "URL:",
                alignment = "right",
                width = share("labelWidth"),
            }),
            f:edit_field({
                value = bind("url"),
                truncation = "middle",
                immediate = false,
                fill_horizontal = 1,
                validate = function(_, url)
                    return PicPeakAPI.validateUrlForDialog(url, propertyTable.url, propertyTable.apiToken)
                end,
            }),
            f:push_button({
                title = "Test connection",
                action = function()
                    LrTasks.startAsyncTask(function()
                        local _, message, api =
                            PicPeakAPI.testConnection(propertyTable.url, propertyTable.apiToken, propertyTable.picpeak)
                        if api then
                            propertyTable.picpeak = api
                        end
                        LrDialogs.message(message)
                    end)
                end,
            }),
        }),
        f:row({
            f:static_text({
                title = "API Token:",
                alignment = "right",
                width = share("labelWidth"),
            }),
            f:password_field({
                value = bind("apiToken"),
                truncation = "middle",
                immediate = false,
                fill_horizontal = 1,
            }),
        }),
        f:row({
            margin_top = 2,
            f:static_text({ title = "", alignment = "right", width = share("labelWidth") }),
            f:static_text({
                title = "Token must have 'write' and 'admin' scopes. Create one in PicPeak → Settings → API Tokens.",
                alignment = "left",
                fill_horizontal = 1,
                font = "<system/small>",
            }),
        }),
    }
end

return SharedDialogSections
