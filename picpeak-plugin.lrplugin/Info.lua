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
    --
    -- No trailing ellipsis, deliberately. Convention says a title that opens a
    -- dialog gets one, but macOS App Shortcuts matches the menu title
    -- CHARACTER FOR CHARACTER — and "…" is a single U+2026, not three dots, so
    -- a user assigning a keyboard shortcut has to paste it rather than type
    -- it. Lightroom gives plugins no way to bind a shortcut themselves, so the
    -- App Shortcut is the only route to one-keystroke access and it wins over
    -- the punctuation convention.
    LrLibraryMenuItems = {
        {
            title = "Import selections from PicPeak",
            file = "ImportSelectionsMenuItem.lua",
        },
    },

    LrMetadataProvider = "MetadataProvider.lua",

    LrPluginInfoProvider = "PluginInfo.lua",

    LrPluginInfoURL = "https://github.com/bmachek/lrc-picpeak",

    VERSION = { major = 1, minor = 1, revision = 0, build = 0 },
}
