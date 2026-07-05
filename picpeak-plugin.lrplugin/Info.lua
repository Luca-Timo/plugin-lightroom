return {

    LrSdkVersion = 3.0,
    LrSdkMinimumVersion = 3.0,

    LrToolkitIdentifier = "lrc-picpeak-plugin",

    LrPluginName = "PicPeak",

    LrInitPlugin = "Init.lua",

    LrExportServiceProvider = {
        {
            title = "PicPeak Exporter",
            file = "ExportServiceProvider.lua",
        },
        {
            title = "PicPeak Publisher",
            file = "PublishServiceProvider.lua",
        },
    },

    LrMetadataProvider = "MetadataProvider.lua",

    LrPluginInfoProvider = "PluginInfo.lua",

    LrPluginInfoURL = "https://github.com/bmachek/lrc-picpeak",

    VERSION = { major = 1, minor = 0, revision = 0, build = 0 },
}
