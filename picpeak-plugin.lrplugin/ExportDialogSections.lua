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
    local lw = LrView.share("labelWidth")

    return {
        {
            title = "PicPeak Gallery Event",
            bind_to_object = propertyTable,
            f:column({
                spacing = f:control_spacing(),

                -- Mode selector
                f:row({
                    f:static_text({ title = "Upload to event:", alignment = "right", width = lw }),
                    f:popup_menu({
                        alignment = "left",
                        immediate = true,
                        items = {
                            { title = "Choose on export",     value = "onexport" },
                            { title = "Existing event",       value = "existing" },
                            { title = "Create new event",     value = "new" },
                            { title = "Do not use an event",  value = "none" },
                        },
                        value = bind("eventMode"),
                    }),
                }),

                -- Existing event picker
                f:row({
                    visible = LrBinding.keyEquals("eventMode", "existing"),
                    f:static_text({ title = "Event:", alignment = "right", width = lw }),
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

                -- New event fields
                f:column({
                    visible = LrBinding.keyEquals("eventMode", "new"),
                    spacing = f:control_spacing(),

                    -- Basic info
                    f:group_box({
                        title = "Event Details",
                        fill_horizontal = 1,
                        f:column({
                            spacing = f:control_spacing(),
                            fill_horizontal = 1,
                            f:row({
                                f:static_text({ title = "Event name:", alignment = "right", width = lw }),
                                f:edit_field({ value = bind("newEventName"), fill_horizontal = 1, immediate = true }),
                            }),
                            f:row({
                                f:static_text({ title = "Event type:", alignment = "right", width = lw }),
                                f:popup_menu({
                                    value = bind("newEventType"),
                                    items = SharedDialogSections.EVENT_TYPES,
                                    immediate = true,
                                }),
                            }),
                            f:row({
                                f:static_text({ title = "Event date:", alignment = "right", width = lw }),
                                f:edit_field({
                                    value = bind("newEventDate"),
                                    width_in_chars = 14,
                                    immediate = true,
                                }),
                                f:static_text({ title = "YYYY-MM-DD, optional", font = "<system/small>" }),
                            }),
                        }),
                    }),

                    -- Customer information
                    f:group_box({
                        title = "Customer Information",
                        fill_horizontal = 1,
                        f:column({
                            spacing = f:control_spacing(),
                            fill_horizontal = 1,
                            f:row({
                                f:static_text({ title = "Customer name:", alignment = "right", width = lw }),
                                f:edit_field({ value = bind("newEventCustomerName"), fill_horizontal = 1, immediate = true }),
                            }),
                            f:row({
                                f:static_text({ title = "Customer email:", alignment = "right", width = lw }),
                                f:edit_field({ value = bind("newEventCustomerEmail"), fill_horizontal = 1, immediate = true }),
                            }),
                            f:row({
                                f:static_text({ title = "Customer phone:", alignment = "right", width = lw }),
                                f:edit_field({
                                    value = bind("newEventCustomerPhone"),
                                    fill_horizontal = 1,
                                    immediate = true,
                                }),
                                f:static_text({ title = "optional", font = "<system/small>" }),
                            }),
                            f:row({
                                f:static_text({ title = "Admin email:", alignment = "right", width = lw }),
                                f:edit_field({ value = bind("newEventAdminEmail"), fill_horizontal = 1, immediate = true }),
                                f:static_text({ title = "for notifications", font = "<system/small>" }),
                            }),
                        }),
                    }),

                    -- Access & expiry
                    f:group_box({
                        title = "Access & Expiry",
                        fill_horizontal = 1,
                        f:column({
                            spacing = f:control_spacing(),
                            fill_horizontal = 1,
                            f:row({
                                f:static_text({ title = "Password protect:", alignment = "right", width = lw }),
                                f:checkbox({
                                    title = "Require password to view gallery",
                                    value = bind("newEventRequirePassword"),
                                }),
                            }),
                            f:row({
                                visible = bind("newEventRequirePassword"),
                                f:static_text({ title = "Gallery password:", alignment = "right", width = lw }),
                                f:password_field({
                                    value = bind("newEventPassword"),
                                    fill_horizontal = 1,
                                    immediate = true,
                                }),
                            }),
                            f:row({
                                f:static_text({ title = "Expires at:", alignment = "right", width = lw }),
                                f:edit_field({
                                    value = bind("newEventExpiresAt"),
                                    width_in_chars = 22,
                                    immediate = true,
                                }),
                                f:static_text({ title = "YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS, optional", font = "<system/small>" }),
                            }),
                        }),
                    }),

                    -- Gallery options
                    f:group_box({
                        title = "Gallery Options",
                        fill_horizontal = 1,
                        f:column({
                            spacing = f:control_spacing(),
                            fill_horizontal = 1,
                            f:row({
                                f:static_text({ title = "Guest feedback:", alignment = "right", width = lw }),
                                f:checkbox({
                                    title = "Enable ratings, likes, comments & favorites",
                                    value = bind("newEventFeedbackEnabled"),
                                }),
                            }),
                            f:row({
                                f:static_text({ title = "Color theme:", alignment = "right", width = lw }),
                                f:edit_field({
                                    value = bind("newEventColorTheme"),
                                    width_in_chars = 20,
                                    immediate = true,
                                }),
                                f:static_text({ title = "PicPeak preset name, optional", font = "<system/small>" }),
                            }),
                        }),
                    }),
                }),
            }),
        },
    }
end
