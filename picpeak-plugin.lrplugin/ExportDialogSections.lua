require("PicPeakAPI")
require("SharedDialogSections")

ExportDialogSections = {}

function ExportDialogSections.startDialog(propertyTable)
    LrTasks.startAsyncTask(function()
        propertyTable.picpeak = PicPeakAPI:new(propertyTable.url, propertyTable.apiToken)
        propertyTable.events = propertyTable.picpeak:getEvents()
    end)
end

-------------------------------------------------------------------------------

function ExportDialogSections.sectionsForBottomOfDialog(f, propertyTable)
    return {
        SharedDialogSections.getServerConnectionSection(f, propertyTable),
    }
end

-------------------------------------------------------------------------------

function ExportDialogSections.sectionsForTopOfDialog(_, propertyTable)
    local f = LrView.osFactory()
    local bind = LrView.bind

    return {
        {
            title = "PicPeak Gallery Event",
            bind_to_object = propertyTable,
            f:column({
                spacing = f:control_spacing(),

                -- Event mode selector
                f:row({
                    f:static_text({
                        title = "Upload to event:",
                        alignment = "right",
                        width = LrView.share("labelWidth"),
                    }),
                    f:popup_menu({
                        alignment = "left",
                        immediate = true,
                        items = {
                            { title = "Choose on export", value = "onexport" },
                            { title = "Existing event", value = "existing" },
                            { title = "Create new event", value = "new" },
                            { title = "Do not use an event", value = "none" },
                        },
                        value = bind("eventMode"),
                    }),
                }),

                -- Existing event picker (visible when eventMode == "existing")
                f:row({
                    visible = LrBinding.keyEquals("eventMode", "existing"),
                    f:static_text({
                        title = "Event:",
                        alignment = "right",
                        width = LrView.share("labelWidth"),
                    }),
                    f:popup_menu({
                        truncation = "middle",
                        width_in_chars = 30,
                        fill_horizontal = 1,
                        value = bind("eventId"),
                        items = bind("events"),
                        immediate = true,
                    }),
                    f:push_button({
                        title = "Refresh",
                        action = function()
                            LrTasks.startAsyncTask(function()
                                if not propertyTable.picpeak then
                                    propertyTable.picpeak = PicPeakAPI:new(propertyTable.url, propertyTable.apiToken)
                                end
                                propertyTable.events = propertyTable.picpeak:getEvents()
                            end)
                        end,
                    }),
                }),

                -- New event fields (visible when eventMode == "new")
                f:column({
                    visible = LrBinding.keyEquals("eventMode", "new"),
                    spacing = f:control_spacing(),

                    f:row({
                        f:static_text({
                            title = "Event name:",
                            alignment = "right",
                            width = LrView.share("labelWidth"),
                        }),
                        f:edit_field({
                            value = bind("newEventName"),
                            fill_horizontal = 1,
                            immediate = true,
                        }),
                    }),
                    f:row({
                        f:static_text({
                            title = "Event type:",
                            alignment = "right",
                            width = LrView.share("labelWidth"),
                        }),
                        f:popup_menu({
                            value = bind("newEventType"),
                            items = SharedDialogSections.EVENT_TYPES,
                            immediate = true,
                        }),
                    }),
                    f:row({
                        f:static_text({
                            title = "Date (YYYY-MM-DD):",
                            alignment = "right",
                            width = LrView.share("labelWidth"),
                        }),
                        f:edit_field({
                            value = bind("newEventDate"),
                            width_in_chars = 14,
                            immediate = true,
                        }),
                        f:static_text({
                            title = "optional",
                            font = "<system/small>",
                        }),
                    }),
                    f:row({
                        f:static_text({
                            title = "Password protect:",
                            alignment = "right",
                            width = LrView.share("labelWidth"),
                        }),
                        f:checkbox({
                            title = "Require password to view gallery",
                            value = bind("newEventRequirePassword"),
                        }),
                    }),
                    f:row({
                        visible = bind("newEventRequirePassword"),
                        f:static_text({
                            title = "Password:",
                            alignment = "right",
                            width = LrView.share("labelWidth"),
                        }),
                        f:password_field({
                            value = bind("newEventPassword"),
                            fill_horizontal = 1,
                            immediate = true,
                        }),
                    }),
                }),
            }),
        },
    }
end
