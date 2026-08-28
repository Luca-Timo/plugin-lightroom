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
    -- The title must NOT equal LrPluginName, and must say what it DOES.
    --
    -- Lightroom draws the plugin name as a DISABLED section header above its
    -- items in Plug-in Extras. With both called "PicPeak" the submenu held two
    -- entries reading the same thing, and macOS App Shortcuts binds to the
    -- first match — the header — so the shortcut appeared next to something
    -- unclickable and did nothing.
    --
    -- "Open PicPeak" fixed the binding but read like it opens the website.
    -- Under a header that already says "PicPeak", the item has to name the
    -- action, not repeat the product.
    --
    -- No trailing ellipsis either: App Shortcuts matches the title CHARACTER
    -- FOR CHARACTER, and "…" is a single U+2026 the user would have to paste
    -- rather than type. Lightroom gives plugins no way to bind a shortcut
    -- themselves, so that route has to stay easy.
    LrLibraryMenuItems = {
        {
            title = "PicPeak Importer",
            file = "PicPeakMenuItem.lua",
        },
    },

    LrMetadataProvider = "MetadataProvider.lua",

    LrPluginInfoProvider = "PluginInfo.lua",

    LrPluginInfoURL = "https://github.com/bmachek/lrc-picpeak",

    VERSION = { major = 1, minor = 2, revision = 0, build = 0 },
}
