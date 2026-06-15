require("PicPeakAPI")
require("MetadataTask")
require("SharedDialogSections")

PublishTask = {}

-- ---------------------------------------------------------------------------
-- Resolve or create the event for a publish collection.
-- Returns: eventId (string) or nil.
-- ---------------------------------------------------------------------------
local function resolvePublishEvent(picpeak, exportContext)
    local publishedCollection = exportContext.publishedCollection
    local collectionSettings = publishedCollection:getCollectionInfoSummary().collectionSettings
    local strategy = collectionSettings.albumCreationStrategy or "collection"
    local eventId = publishedCollection:getRemoteId()
    local collectionName = publishedCollection:getName()
    local exportSession = exportContext.exportSession

    log:trace("resolvePublishEvent: strategy=" .. strategy .. " remoteId=" .. tostring(eventId))

    if strategy == "existing" and collectionSettings.remoteId then
        eventId = tostring(collectionSettings.remoteId)
    end

    if eventId and eventId ~= "" then
        if picpeak:checkIfEventExists(eventId) then
            local shareUrl = picpeak:getEventShareUrl(eventId)
            exportSession:recordRemoteCollectionId(eventId)
            if shareUrl then
                exportSession:recordRemoteCollectionUrl(shareUrl)
            end
            return eventId
        else
            log:warn("resolvePublishEvent: stored event " .. eventId .. " no longer exists, creating new one")
            eventId = nil
        end
    end

    -- Create new event from collection name
    log:info("resolvePublishEvent: creating new event '" .. collectionName .. "'")
    local eventType = collectionSettings.eventType or "other"
    local newId = picpeak:createEvent({
        event_name = collectionName,
        event_type = eventType,
        require_password = false,
    })
    if not newId then
        ErrorHandler.handleError(
            "Failed to create PicPeak event for collection '" .. collectionName .. "'. Check connection.",
            "resolvePublishEvent: createEvent returned nil"
        )
        return nil
    end
    newId = tostring(newId)
    local shareUrl = picpeak:getEventShareUrl(newId)
    exportSession:recordRemoteCollectionId(newId)
    if shareUrl then
        exportSession:recordRemoteCollectionUrl(shareUrl)
    end
    log:info("resolvePublishEvent: created event id=" .. newId)
    return newId
end

-- ---------------------------------------------------------------------------
-- Main publish entry point
-- ---------------------------------------------------------------------------

function PublishTask.processRenderedPhotos(functionContext, exportContext)
    local exportSession, exportParams, picpeak = util.validateExportContextAndConnect(exportContext, "Publish")
    if not exportSession then
        return nil
    end

    local eventId = resolvePublishEvent(picpeak, exportContext)
    if not eventId then
        return nil
    end

    local nPhotos = exportSession:countRenditions()
    local progressTitle = (exportParams.url and exportParams.url ~= "") and exportParams.url or "PicPeak"
    log:info("=== PicPeak Publish START: " .. nPhotos .. " photos | url=" .. tostring(exportParams.url)
        .. " | eventId=" .. tostring(eventId) .. " ===")

    local progressScope = LrProgressScope({
        title = util.buildSimpleUploadProgressTitle(nPhotos, "Publishing", progressTitle),
        functionContext = functionContext,
    })

    local failures = {}
    local done = 0

    for _, rendition in exportContext:renditions({ stopIfCanceled = true }) do
        local success, pathOrMessage = rendition:waitForRender()
        if progressScope:isCanceled() then
            break
        end

        if success then
            local photo = rendition.photo
            local fileName = photo:getFormattedMetadata("fileName")

            local photoId, errReason = picpeak:uploadPhoto(eventId, pathOrMessage, fileName)
            util.safeDeleteTempFile(pathOrMessage)

            if not photoId then
                log:error("PublishTask: upload failed for " .. fileName .. ": " .. tostring(errReason))
                table.insert(failures, fileName .. " (" .. (errReason or "Upload failed") .. ")")
            else
                local photoIdStr = tostring(photoId)
                MetadataTask.setPhotoId(photo, photoIdStr)
                MetadataTask.setEventId(photo, eventId)
                rendition:recordPublishedPhotoId(photoIdStr)
                local shareUrl = picpeak:getEventShareUrl(eventId)
                if shareUrl then
                    rendition:recordPublishedPhotoUrl(shareUrl)
                end
                log:info("PublishTask: uploaded " .. fileName .. " -> photoId=" .. photoIdStr)
            end
        else
            log:warn("PublishTask: render failed: " .. tostring(pathOrMessage))
            util.safeDeleteTempFile(pathOrMessage)
        end

        done = done + 1
        progressScope:setPortionComplete(done, nPhotos)
        if done == 1 or done % 10 == 0 or done == nPhotos then
            log:info("Publish progress: " .. done .. "/" .. nPhotos)
        end
    end

    progressScope:done()
    log:info("=== PicPeak Publish DONE: " .. nPhotos .. " photos | failures=" .. #failures .. " ===")
    util.reportUploadFailures(failures)
end

-- ---------------------------------------------------------------------------
-- Collection management callbacks
-- ---------------------------------------------------------------------------

function PublishTask.deletePhotosFromPublishedCollection(
    publishSettings,
    arrayOfPhotoIds,
    deletedCallback,
    localCollectionId
)
    -- PicPeak v1 API has no endpoint to delete individual photos.
    -- We mark them as deleted in Lightroom so they won't be republished,
    -- but they remain in the PicPeak gallery on the server.
    if #arrayOfPhotoIds > 0 then
        LrDialogs.message(
            "PicPeak: Photos removed from collection",
            "Note: The PicPeak API does not support deleting photos via the API. "
                .. tostring(#arrayOfPhotoIds)
                .. " photo(s) were removed from the Lightroom publish collection but remain in the PicPeak gallery."
                .. " Remove them manually in PicPeak if needed.",
            "info"
        )
    end
    for _, photoId in ipairs(arrayOfPhotoIds) do
        deletedCallback(photoId)
    end
end

function PublishTask.deletePublishedCollection(publishSettings, info)
    -- PicPeak v1 API has no delete event endpoint (admin-only in UI).
    if info.remoteId and info.remoteId ~= "" then
        LrDialogs.message(
            "PicPeak: Gallery not deleted",
            "The PicPeak API does not support deleting gallery events. "
                .. "The Lightroom collection was removed, but the gallery (event id="
                .. tostring(info.remoteId)
                .. ") still exists in PicPeak. Delete it manually if needed.",
            "info"
        )
    end
end

function PublishTask.renamePublishedCollection(publishSettings, info)
    -- PicPeak v1 API has no rename event endpoint.
    log:trace("renamePublishedCollection: rename not supported by PicPeak v1 API")
end

function PublishTask.shouldDeletePhotosFromServiceOnDeleteFromCatalog(publishSettings, nPhotos)
    return nil
end

function PublishTask.validatePublishedCollectionName(name)
    if util.nilOrEmpty(name) then
        return false, "Event name must not be empty."
    end
    return true, ""
end

function PublishTask.getCollectionBehaviorInfo(publishSettings)
    return {
        defaultCollectionName = "My Gallery",
        defaultCollectionCanBeDeleted = true,
        canAddCollection = true,
    }
end

-- ---------------------------------------------------------------------------
-- Per-collection settings (event type selection)
-- ---------------------------------------------------------------------------

function PublishTask.viewForCollectionSettings(f, publishSettings, info)
    if info.publishedCollection ~= nil then
        -- Editing an existing collection: show read-only info
        local remoteId = info.publishedCollection:getRemoteId()
        if remoteId then
            return f:row({
                f:static_text({
                    title = "PicPeak event ID: " .. tostring(remoteId),
                    alignment = "left",
                    font = "<system/small>",
                }),
            })
        end
        return f:row({})
    end

    -- New collection: choose event type
    info.pluginContext.eventType = "other"
    info.pluginContext.albumCreationStrategy = "collection"
    info.pluginContext.picpeakEvents = { { title = "Please select", value = "0" } }

    LrTasks.startAsyncTask(function()
        local picpeak = PicPeakAPI:new(publishSettings.url, publishSettings.apiToken)
        local events = picpeak:getEvents()
        if events and #events > 0 then
            local items = { { title = "Please select", value = "0" } }
            for _, e in ipairs(events) do
                table.insert(items, e)
            end
            info.pluginContext.picpeakEvents = items
        end
    end)

    local bind = LrView.bind
    local share = LrView.share

    return f:group_box({
        bind_to_object = info.pluginContext,
        title = "PicPeak Event Settings",
        fill_horizontal = 1,
        f:column({
            spacing = f:control_spacing(),
            fill_horizontal = 1,
            f:row({
                f:static_text({
                    title = "This collection will be synced to a PicPeak gallery event.",
                    alignment = "left",
                    font = "<system/small>",
                    fill_horizontal = 1,
                }),
            }),
            f:separator({ fill_horizontal = 1 }),
            f:radio_button({
                title = "Create new event from collection name",
                checked_value = "collection",
                value = bind("albumCreationStrategy"),
            }),
            f:row({
                f:static_text({
                    title = "    Event type:",
                    alignment = "right",
                }),
                f:popup_menu({
                    value = bind("eventType"),
                    items = require("SharedDialogSections").EVENT_TYPES,
                    immediate = true,
                    enabled = LrBinding.keyEquals("albumCreationStrategy", "collection"),
                }),
            }),
            f:row({
                f:radio_button({
                    title = "Use existing event",
                    checked_value = "existing",
                    value = bind("albumCreationStrategy"),
                }),
                f:popup_menu({
                    items = bind("picpeakEvents"),
                    value = bind("selectedEventId"),
                    width_in_chars = 28,
                    enabled = LrBinding.keyEquals("albumCreationStrategy", "existing"),
                    immediate = true,
                }),
            }),
        }),
    })
end

function PublishTask.endDialogForCollectionSettings(publishSettings, info)
    log:trace("endDialogForCollectionSettings")
    local props = info.pluginContext
    if info.why == "ok" then
        local strategy = props.albumCreationStrategy or "collection"
        info.collectionSettings.albumCreationStrategy = strategy
        info.collectionSettings.eventType = props.eventType or "other"

        if strategy == "existing" then
            local sel = props.selectedEventId
            if util.nilOrEmpty(sel) or sel == "0" then
                ErrorHandler.handleError("No event selected.", "endDialogForCollectionSettings: no event selected")
                return
            end
            info.collectionSettings.remoteId = sel
        end
    end
end

function PublishTask.updateCollectionSettings(publishSettings, info)
    log:trace("updateCollectionSettings")
    if not info or not info.collectionSettings then
        return
    end
    local props = info.collectionSettings
    if props.albumCreationStrategy == "existing" and props.remoteId then
        local picpeak = PicPeakAPI:new(publishSettings.url, publishSettings.apiToken)
        if not picpeak:checkConnectivity() then
            log:warn("updateCollectionSettings: PicPeak not reachable")
            return
        end
        local eventId = tostring(props.remoteId)
        local name = picpeak:getEventName(eventId)
        local shareUrl = picpeak:getEventShareUrl(eventId)
        if not name then
            name = "Event " .. eventId
        end
        log:trace("updateCollectionSettings: binding to event id=" .. eventId .. " name=" .. name)
        local catalog = LrApplication.activeCatalog()
        if catalog and info.publishedCollection then
            catalog:withWriteAccessDo("Bind PicPeak event", function()
                info.publishedCollection:setRemoteId(eventId)
                if shareUrl then
                    info.publishedCollection:setRemoteUrl(shareUrl)
                end
                info.publishedCollection:setName(name)
            end)
        end
    end
end
