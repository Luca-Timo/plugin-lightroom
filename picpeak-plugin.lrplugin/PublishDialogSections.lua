require("PicPeakAPI")
require("SharedDialogSections")

PublishDialogSections = {}

function PublishDialogSections.startDialog(propertyTable)
    LrTasks.startAsyncTask(function()
        propertyTable.picpeak = PicPeakAPI:new(propertyTable.url, propertyTable.apiToken)
    end)
end

function PublishDialogSections.sectionsForTopOfDialog(f, propertyTable)
    return {
        SharedDialogSections.getServerConnectionSection(f, propertyTable),
    }
end
