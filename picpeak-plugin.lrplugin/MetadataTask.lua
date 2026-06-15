MetadataTask = {}

local keyPhotoId = "picpeakPhotoId"
local keyEventId = "picpeakEventId"

local function writeField(photo, key, value)
    if not photo then
        log:warn("MetadataTask.writeField: photo is nil")
        return false
    end
    local catalog = LrApplication.activeCatalog()
    if not catalog then
        log:warn("MetadataTask.writeField: cannot access catalog")
        return false
    end
    local valueToSet = (value ~= nil and value ~= "") and tostring(value) or ""
    local success = false
    local ok, err = LrTasks.pcall(function()
        catalog:withPrivateWriteAccessDo(function()
            photo:setPropertyForPlugin(_PLUGIN, key, valueToSet)
            success = true
        end, { timeout = 5 })
    end)
    if not ok then
        log:error("MetadataTask.writeField: failed to write " .. key .. ": " .. tostring(err))
        return false
    end
    return success
end

function MetadataTask.setPhotoId(photo, photoId)
    return writeField(photo, keyPhotoId, photoId)
end

function MetadataTask.getPhotoId(photo)
    if not photo then return nil end
    local v = photo:getPropertyForPlugin(_PLUGIN, keyPhotoId)
    return (v and v ~= "") and v or nil
end

function MetadataTask.setEventId(photo, eventId)
    return writeField(photo, keyEventId, eventId)
end

function MetadataTask.getEventId(photo)
    if not photo then return nil end
    local v = photo:getPropertyForPlugin(_PLUGIN, keyEventId)
    return (v and v ~= "") and v or nil
end
