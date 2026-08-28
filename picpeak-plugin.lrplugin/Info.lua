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

    -- Library > Plug-in Extras. ONE entry, deliberately.
    --
    -- Lightroom Classic has no API for a top-level menu and none for a panel;
    -- File/Library > Plug-in Extras are the only entry points a plugin gets.
    -- So rather than scattering "Import", "Connection", "Re-import" through
    -- Plug-in Extras, a single "PicPeak" item opens a hub that dispatches to
    -- all of them — which also means one OS-level App Shortcut on this title
    -- reaches the entire plugin.
    --
    -- Two entries: the overview is the landing page, the importer is the
    -- shortcut past it for the repeat import — which is most of them.
    --
    -- "PicPeak" deliberately repeats LrPluginName here. Lightroom draws the
    -- plugin name as a DISABLED section header above these items, so the
    -- submenu reads "PicPeak" twice. That is cosmetic and was only ever a real
    -- problem for macOS App Shortcuts, which binds to the first title match
    -- and would attach to the header — and no App Shortcut can reach these
    -- items anyway, because Lightroom builds them lazily when the menu opens,
    -- after key equivalents have already been applied at launch. Verified
    -- against a real install; do not re-litigate without testing in the menu.
    LrLibraryMenuItems = {
        {
            title = "PicPeak",
            file = "PicPeakMenuItem.lua",
        },
        {
            title = "PicPeak Importer",
            file = "PicPeakImportMenuItem.lua",
        },
    },

    LrMetadataProvider = "MetadataProvider.lua",

    LrPluginInfoProvider = "PluginInfo.lua",

    LrPluginInfoURL = "https://github.com/bmachek/lrc-picpeak",

    VERSION = { major = 1, minor = 2, revision = 0, build = 0 },
}
