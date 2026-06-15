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
            id = "picpeakEventId",
            title = "PicPeak Event ID",
            dataType = "string",
            readOnly = true,
            browsable = false,
            searchable = false,
        },
    },

    schemaVersion = 1,
}
