require("MetadataTask")

return {

    metadataFieldsForPhotos = {
        {
            id = "picpeakPhotoId",
            title = "PicPeak Photo ID",
            dataType = "string",
            readOnly = true,
            browsable = true,
            searchable = true,
        },
        {
            id = "picpeakSourceFilename",
            title = "PicPeak Source Filename",
            -- The camera-original name the photo was proofed under. The photo
            -- id above is the primary key home, but this survives a catalog
            -- rebuild or a photo re-added by hand, where plugin properties do
            -- not — and it is what the number-match fallback reads.
            dataType = "string",
            readOnly = true,
            browsable = true,
            searchable = true,
        },
        {
            id = "picpeakEventId",
            title = "PicPeak Event ID",
            dataType = "string",
            readOnly = true,
            browsable = false,
            searchable = false,
        },
    },

    -- Bumped to 2 when picpeakSourceFilename was added (#745). No migration
    -- function: the new field simply reads empty on photos stamped by v1, and
    -- the next import fills it in. Discarding the existing photo/event ids to
    -- "migrate" would break exactly the links this feature depends on.
    schemaVersion = 2,
}
