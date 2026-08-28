# PicPeak plugin for Lightroom Classic

Upload galleries to a self-hosted [PicPeak](https://github.com/PicPeak/picpeak)
server from Lightroom Classic — and bring the client's proofing selections back
into your catalog.

## Install

1. Download or clone this repository.
2. In Lightroom Classic: **File → Plug-in Manager → Add**, and point it at the
   `picpeak-plugin.lrplugin` folder.
3. Enter your PicPeak server URL and click **Sign in…**.

No build step — the plugin runs directly from the folder.

## Connecting

Click **Sign in…** and enter your PicPeak administrator email and password. The
plugin exchanges them once for an API token scoped to this machine, stores only
that token, and never keeps your password. You can see and revoke the token any
time in PicPeak under **Settings → API Tokens**.

If your server enforces SSO or has reCAPTCHA enabled, password sign-in cannot
work from a plugin. Open **Advanced** and paste an API token created in
**Settings → API Tokens** with the `admin` scope.

> The token is stored in Lightroom's own preferences file, which is not the OS
> keychain. Sign-in gives it a one-year expiry for that reason.

## What it does

### Export

Send selected photos to a PicPeak event. Pick an existing gallery or create one
from the export dialog, with customer details, password protection and expiry.

### Publish

Map a Lightroom publish collection to a PicPeak event and keep them in sync.
Re-publishing an edited photo now **updates it in place** — it keeps its id, the
client's ratings and colour labels, its comments and its position in the
gallery.

### Import selections — the round-trip

**Library → Plug-in Extras → PicPeak Importer**

Everything lives in that one window — importing selections, and the server
connection. Lightroom Classic has no API for a top-level menu or a docked
panel, so a single hub behind a single menu item is the closest thing
available, and it means one keyboard shortcut reaches the whole plugin.

### Giving it a keyboard shortcut

Lightroom gives plugins no way to bind a shortcut, so use the OS. On macOS:
**System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts → +**, pick
Adobe Lightroom Classic, and enter the menu title exactly:

```
PicPeak Importer
```

The title carries no trailing ellipsis on purpose — App Shortcuts matches it
character for character, and `…` is a single character you would have to paste
rather than type.

The workflow this serves:

1. Upload the unedited camera JPGs (`IMG_1234.JPG`) to a PicPeak event.
2. The client marks colour labels and stars while proofing. You can add your own
   marks in the admin view.
3. In Lightroom, open **PicPeak Importer** and choose **Import selections**, pick the event and
   the folder holding your RAW files, and pick what to bring in — everything, or
   only what was marked.
4. The plugin matches each picked photo to its RAW by filename, adds it to the
   catalog if it isn't there yet, and applies the colour labels and star
   ratings.
5. Edit, rename however you like, and publish back. The finished render replaces
   its proof in the gallery.

Step 5 works after a rename because the plugin stamps the PicPeak photo id onto
the catalog photo during import. The id travels with the photo, so the filename
is free to change.

#### Merging, not overwriting

Choose what happens when a photo already carries a *different* colour or rating
in Lightroom:

| Mode | Behaviour |
|---|---|
| **Fill empty only** (default) | Never touch a photo that already has a value |
| **PicPeak wins** | Overwrite unconditionally |
| **Lightroom wins** | Write only where Lightroom is empty |
| **Highest priority wins** | Green → yellow → red → blue → purple; higher star count wins |

Every run reports how many conflicts it saw, so nothing is quietly lost.

#### Multi-camera shoots

Two bodies both produce `IMG_1234.JPG`. Rename on ingest, before upload, so the
camera index is part of the number:

```
cam11234.jpg    cam21234.jpg
```

The matcher reads the **longest** trailing digit run, so `11234` and `21234`
stay distinct where a plain `1234` would collide.

If you use the optional *"Also match by trailing file number"* fallback (for
RAWs that were renamed before proofing), keep that full number in your delivery
name — `Smith_Wedding_11234.jpg`, not `Smith_Wedding_1234.jpg`. Truncating it
back to four digits brings the collision straight back. Files that do share a
number are skipped and reported, never guessed at.

## Requirements

- Lightroom Classic (Lua SDK 3.0+)
- A PicPeak server with the v1 API enabled
- An account with permission to create API tokens (`settings.integrations`)

The import feature needs a PicPeak server that has
[`GET /api/v1/events/:id/photos`](https://github.com/PicPeak/picpeak/pull/1165).
Export and publish work against older servers; re-publish falls back to skipping
where the replace endpoint is missing.

## Troubleshooting

Enable logging in **File → Plug-in Manager → PicPeak → Logging**, reproduce the
problem, then use **Show log file**.

## Credit

Initial implementation by [@bmachek](https://github.com/bmachek)
([lrc-picpeak](https://github.com/bmachek/lrc-picpeak)).
