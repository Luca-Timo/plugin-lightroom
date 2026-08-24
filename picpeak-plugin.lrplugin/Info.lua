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

    -- Library > Plug-in Extras. The round-trip's import half (#745) is not an
    -- export or a publish, so it needs its own entry point.
    LrLibraryMenuItems = {
        {
            title = "Import selections from PicPeak…",
            file = "ImportSelectionsMenuItem.lua",
        },
    },

    LrMetadataProvider = "MetadataProvider.lua",

    LrPluginInfoProvider = "PluginInfo.lua",

    LrPluginInfoURL = "https://github.com/bmachek/lrc-picpeak",

    VERSION = { major = 1, minor = 1, revision = 0, build = 0 },
}
