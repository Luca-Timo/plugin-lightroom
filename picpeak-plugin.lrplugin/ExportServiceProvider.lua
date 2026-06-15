require("ExportDialogSections")
require("ExportTask")

return {

    hideSections = { "exportLocation" },

    allowFileFormats = nil,

    allowColorSpaces = nil,

    exportPresetFields = {
        { key = "url",                      default = "" },
        { key = "apiToken",                 default = "" },
        { key = "eventMode",                default = "none" },
        { key = "eventId",                  default = nil },
        -- New event fields
        { key = "newEventName",             default = "" },
        { key = "newEventType",             default = "other" },
        { key = "newEventDate",             default = "" },
        { key = "newEventCustomerName",     default = "" },
        { key = "newEventCustomerEmail",    default = "" },
        { key = "newEventCustomerPhone",    default = "" },
        { key = "newEventAdminEmail",       default = "" },
        { key = "newEventRequirePassword",  default = false },
        { key = "newEventPassword",         default = "" },
        { key = "newEventExpiresAt",        default = "" },
        { key = "newEventFeedbackEnabled",  default = false },
        { key = "newEventColorTheme",       default = "" },
    },

    canExportVideo = false,

    startDialog = ExportDialogSections.startDialog,
    sectionsForTopOfDialog = ExportDialogSections.sectionsForTopOfDialog,
    sectionsForBottomOfDialog = ExportDialogSections.sectionsForBottomOfDialog,

    processRenderedPhotos = ExportTask.processRenderedPhotos,
}
