require("PublishDialogSections")
require("PublishTask")

return {
    startDialog = PublishDialogSections.startDialog,
    sectionsForTopOfDialog = PublishDialogSections.sectionsForTopOfDialog,
    sectionsForBottomOfDialog = PublishDialogSections.sectionsForBottomOfDialog,
    hideSections = { "exportLocation" },
    allowFileFormats = nil,
    allowColorSpaces = nil,
    canExportVideo = false,
    supportsCustomSortOrder = false,
    supportsIncrementalPublish = "only",

    exportPresetFields = {
        { key = "url", default = "" },
        { key = "apiToken", default = "" },
    },

    titleForPublishedCollection = "PicPeak event",
    titleForPublishedSmartCollection = "PicPeak event (Smart collection)",

    getCollectionBehaviorInfo = PublishTask.getCollectionBehaviorInfo,

    processRenderedPhotos = PublishTask.processRenderedPhotos,

    canAddCommentsToService = false,

    deletePhotosFromPublishedCollection = PublishTask.deletePhotosFromPublishedCollection,
    deletePublishedCollection = PublishTask.deletePublishedCollection,
    renamePublishedCollection = PublishTask.renamePublishedCollection,
    shouldDeletePhotosFromServiceOnDeleteFromCatalog = PublishTask.shouldDeletePhotosFromServiceOnDeleteFromCatalog,
    validatePublishedCollectionName = PublishTask.validatePublishedCollectionName,

    viewForCollectionSettings = PublishTask.viewForCollectionSettings,
    endDialogForCollectionSettings = PublishTask.endDialogForCollectionSettings,
    updateCollectionSettings = PublishTask.updateCollectionSettings,
}
