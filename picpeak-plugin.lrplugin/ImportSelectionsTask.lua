--[[
    Import a PicPeak event's proofing selections into the Lightroom catalog
    (PicPeak/picpeak#745).

    The flow this serves: the client marked colours and stars on unedited
    camera JPGs in the gallery; the editor now wants the CORRESPONDING RAW
    files in the catalog, already carrying those marks, so the edit can start
    from the picks instead of from a spreadsheet.

    Matching is on the camera-original filename. PicPeak preserves it in
    `source_filename` (backend migration 185) precisely because the stored
    filename is rewritten on upload and `original_filename` gets overwritten
    the first time a render is uploaded back.

    Writing `picpeakPhotoId` onto the imported RAW is the load-bearing step,
    not a nicety: it is what lets the finished render be matched back to its
    proof later even though the editor renamed the file in between.
]]

require("ColorLabelMerge")

ImportSelectionsTask = {}

-- Index a folder by lowercase stem -> full path.
--
-- Later entries deliberately do not overwrite earlier ones: two files sharing
-- a stem (IMG_1234.CR3 next to IMG_1234.JPG) are the same shot, and the first
-- one found is as good an answer as any. What must NOT happen is a silent
-- flip-flop between runs, so the first wins consistently.
local function indexFolder(folderPath, recurse)
    local index = {}
    local count = 0
    local iterator = recurse and LrFileUtils.recursiveFiles or LrFileUtils.files
    for filePath in iterator(folderPath) do
        if util.isSupportedPhotoExtension(filePath) then
            local stem = util.normalizedStem(filePath)
            if stem and index[stem] == nil then
                index[stem] = filePath
                count = count + 1
            end
        end
    end
    log:info("ImportSelectionsTask: indexed " .. count .. " file(s) under " .. tostring(folderPath))
    return index, count
end

-- Resolve one picpeak photo to a local file.
--
-- Two passes, strongest key first: the exact stem, then the trailing digit
-- run. The digit run is opt-in because it is a much weaker key — see
-- util.trailingDigitRun for why it must be the LONGEST run.
local function resolveLocalFile(photo, index, digitIndex, allowNumberMatch)
    local name = photo.source_filename or photo.original_filename or photo.filename
    if util.nilOrEmpty(name) then
        return nil, "no filename on the PicPeak photo"
    end

    local stem = util.normalizedStem(name)
    if stem and index[stem] then
        return index[stem]
    end

    if allowNumberMatch then
        local token = util.trailingDigitRun(name)
        if token and digitIndex[token] then
            local candidates = digitIndex[token]
            if #candidates == 1 then
                return candidates[1]
            end
            -- Refuse rather than guess. Picking one would mark the wrong
            -- photo, and a wrong colour label is worse than a missing one
            -- because nothing about it looks wrong afterwards.
            return nil, #candidates .. " local files share the number " .. token
        end
    end

    return nil, "no local file named " .. tostring(name)
end

local function buildDigitIndex(index)
    local digitIndex = {}
    for _, filePath in pairs(index) do
        local token = util.trailingDigitRun(filePath)
        if token then
            digitIndex[token] = digitIndex[token] or {}
            table.insert(digitIndex[token], filePath)
        end
    end
    return digitIndex
end

--[[
    Run the import.

    @param settings table:
        api, eventId, eventName, folderPath, recurse,
        allowNumberMatch, applyColors, applyRatings, mergeMode,
        addMissingToCatalog, collectionName, filters (for getEventPhotos)
    @param progressScope optional LrProgressScope
    @return summary table
]]
function ImportSelectionsTask.run(settings, progressScope)
    local summary = {
        fetched = 0, matched = 0, imported = 0, alreadyInCatalog = 0,
        colorsWritten = 0, ratingsWritten = 0, conflicts = 0,
        unmatched = {}, errors = {},
    }

    local photos, fetchError = settings.api:getEventPhotos(settings.eventId, settings.filters)
    if not photos then
        summary.fatal = fetchError or "Could not fetch photos from PicPeak."
        return summary
    end
    summary.fetched = #photos
    if #photos == 0 then
        return summary
    end

    local index, indexedCount = indexFolder(settings.folderPath, settings.recurse)
    summary.indexed = indexedCount
    local digitIndex = settings.allowNumberMatch and buildDigitIndex(index) or {}

    local catalog = LrApplication.activeCatalog()
    if not catalog then
        summary.fatal = "Cannot access the Lightroom catalog."
        return summary
    end

    -- Pass 1: resolve picpeak photos to local paths. Done entirely outside
    -- any catalog write access — resolving needs no lock, and holding one
    -- across a folder scan would freeze the UI for the whole run.
    local resolved = {}
    for _, photo in ipairs(photos) do
        if progressScope and progressScope:isCanceled() then
            summary.canceled = true
            return summary
        end
        local filePath, reason = resolveLocalFile(photo, index, digitIndex, settings.allowNumberMatch)
        if filePath then
            table.insert(resolved, { photo = photo, filePath = filePath })
        else
            table.insert(summary.unmatched, {
                name = photo.source_filename or photo.original_filename or photo.filename,
                reason = reason,
            })
        end
    end
    summary.matched = #resolved

    -- Pass 2: add to the catalog. addPhoto needs write access, and a fresh
    -- import must land before its metadata can be written.
    local catalogPhotos = {}
    local ok, writeError = LrTasks.pcall(function()
        catalog:withWriteAccessDo("Import PicPeak selections", function()
            for i, entry in ipairs(resolved) do
                if progressScope then
                    progressScope:setPortionComplete(i, #resolved * 2)
                end
                -- findPhotoByPath FIRST, always. addPhoto's behaviour for a
                -- file already in the catalog is not something to rely on,
                -- and most editors have already imported at least some of
                -- the shoot.
                local lrPhoto = catalog:findPhotoByPath(entry.filePath)
                if lrPhoto then
                    summary.alreadyInCatalog = summary.alreadyInCatalog + 1
                elseif settings.addMissingToCatalog then
                    -- pcall returns (ok, result); on success `result` IS the
                    -- new LrPhoto, on failure it is the error.
                    local addOk, addResult = LrTasks.pcall(function()
                        return catalog:addPhoto(entry.filePath)
                    end)
                    if addOk and addResult then
                        lrPhoto = addResult
                        summary.imported = summary.imported + 1
                    else
                        table.insert(summary.errors, {
                            name = entry.filePath,
                            reason = "could not add to catalog: " .. tostring(addResult),
                        })
                    end
                end
                if lrPhoto then
                    table.insert(catalogPhotos, { lrPhoto = lrPhoto, photo = entry.photo })
                end
            end
        end, { timeout = 30 })
    end)
    if not ok then
        summary.fatal = "Catalog write failed: " .. tostring(writeError)
        return summary
    end

    -- Pass 3: apply the marks and stamp the picpeak ids.
    ok, writeError = LrTasks.pcall(function()
        catalog:withWriteAccessDo("Apply PicPeak marks", function()
            for i, entry in ipairs(catalogPhotos) do
                if progressScope then
                    progressScope:setPortionComplete(#resolved + i, #resolved * 2)
                end
                local lrPhoto = entry.lrPhoto
                local photo = entry.photo

                if settings.applyColors then
                    local existing = lrPhoto:getRawMetadata("colorNameForLabel")
                    local newValue, conflicted = ColorLabelMerge.resolveColor(
                        photo.color_label, existing, settings.mergeMode
                    )
                    if conflicted then
                        summary.conflicts = summary.conflicts + 1
                    end
                    if newValue then
                        lrPhoto:setRawMetadata("colorNameForLabel", newValue)
                        summary.colorsWritten = summary.colorsWritten + 1
                    end
                end

                if settings.applyRatings then
                    local existing = lrPhoto:getRawMetadata("rating")
                    local newValue, conflicted = ColorLabelMerge.resolveRating(
                        photo.rating, existing, settings.mergeMode
                    )
                    if conflicted then
                        summary.conflicts = summary.conflicts + 1
                    end
                    if newValue then
                        lrPhoto:setRawMetadata("rating", newValue)
                        summary.ratingsWritten = summary.ratingsWritten + 1
                    end
                end

                -- The link that survives a rename. Without this, a render
                -- exported from this RAW has no reliable way home.
                lrPhoto:setPropertyForPlugin(_PLUGIN, "picpeakPhotoId", tostring(photo.id))
                lrPhoto:setPropertyForPlugin(_PLUGIN, "picpeakEventId", tostring(settings.eventId))
                local sourceName = photo.source_filename or photo.original_filename
                if sourceName then
                    lrPhoto:setPropertyForPlugin(_PLUGIN, "picpeakSourceFilename", tostring(sourceName))
                end
            end
        end, { timeout = 30 })
    end)
    if not ok then
        summary.fatal = "Applying marks failed: " .. tostring(writeError)
        return summary
    end

    -- Pass 4: collect. A collection is how the editor actually works with the
    -- result, and it needs its own write access block.
    if not util.nilOrEmpty(settings.collectionName) and #catalogPhotos > 0 then
        local collected = LrTasks.pcall(function()
            catalog:withWriteAccessDo("Create PicPeak collection", function()
                local collection = catalog:createCollection(settings.collectionName, nil, true)
                if collection then
                    local toAdd = {}
                    for _, entry in ipairs(catalogPhotos) do
                        table.insert(toAdd, entry.lrPhoto)
                    end
                    collection:addPhotos(toAdd)
                    summary.collectionName = settings.collectionName
                end
            end, { timeout = 30 })
        end)
        if not collected then
            -- Non-fatal: the marks are already written, which is the part
            -- that matters. Say so rather than reporting a clean run.
            table.insert(summary.errors, {
                name = settings.collectionName,
                reason = "marks were applied but the collection could not be created",
            })
        end
    end

    return summary
end

return ImportSelectionsTask
