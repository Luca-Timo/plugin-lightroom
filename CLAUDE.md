# CLAUDE.md

A Lightroom Classic plugin (Lua) that uploads photos to a self-hosted PicPeak gallery server. It provides two workflows: **Export** (upload selected photos to a PicPeak event/gallery) and **Publish** (maintain synced collections mapped to PicPeak events).

## What is PicPeak?

PicPeak (https://github.com/the-luap/picpeak) is a self-hosted photo sharing platform for photographers and events. It organizes photos into time-limited, optionally password-protected gallery **events** (weddings, birthdays, corporate events, etc.).

## Development & Build

No build step — the plugin runs directly from `picpeak-plugin.lrplugin/` inside Lightroom Classic. Install via Lightroom's Plugin Manager pointing at that directory.

## Architecture

### Entry Points

- **`Info.lua`** — Plugin manifest; declares export/publish providers, metadata provider, SDK version.
- **`Init.lua`** — Runs at load; imports Lightroom SDK globals into `_G` and initializes preferences (`url`, `apiToken`, `logging`).

### Core Modules

- **`PicPeakAPI.lua`** — REST client for PicPeak v1 API (`/api/v1`). Auth: `Authorization: Bearer pp_live_xxx`. Key methods: `getEvents()`, `createEvent(params)`, `uploadPhoto(eventId, filePath, fileName)`, `checkConnectivity()`, `getEventShareUrl(eventId)`.
- **`ExportTask.lua`** — Export workflow: resolve event → iterate renditions → upload each photo → write metadata → show share link.
- **`PublishTask.lua`** — Publish workflow: map collection to event (create if needed) → incremental uploads → collection management callbacks.

### PicPeak API Summary (v1)

Base path: `/api/v1`. Token must have `write` + `admin` scopes.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/events?limit=100` | List events (paginated, max 100) |
| POST | `/events` | Create event (needs event_name, event_type) |
| GET | `/events/:id` | Get event details |
| POST | `/events/:id/photos` | Upload photo (multipart `photo` field) |
| GET | `/events/:id/share-link` | Get share URL |

**Limitations of v1 API**: No delete photo, no delete event, no rename event endpoints. The publish plugin warns users when these operations are attempted.

### Event types

`wedding`, `birthday`, `corporate`, `other`, `family`

### UI Modules

- **`SharedDialogSections.lua`** — Server connection section (URL + token + test button). Also exports `EVENT_TYPES` list.
- **`ExportDialogSections.lua`** / **`PublishDialogSections.lua`** — Service-specific dialog sections.

### Supporting Modules

- **`MetadataTask.lua`** / **`MetadataProvider.lua`** — Store `picpeakPhotoId` and `picpeakEventId` on photos via plugin metadata.
- **`util.lua`** — Shared helpers: `validateExportContextAndConnect`, `buildSimpleUploadProgressTitle`, `reportUploadFailures`, `safeDeleteTempFile`, `getPhotoDeviceId`, `getLogfilePath`, `cutToken`.
- **`ErrorHandler.lua`** — Centralized error dialogs.
- **`JSON.lua`** / **`inspect.lua`** — External libraries (copied from lrc-immich-plugin).

### Lightroom SDK Patterns

- **Async tasks**: All API calls in `LrTasks.startAsyncTask()`.
- **Property tables**: Dialog state two-way bound via `LrBinding`.
- **Progress scopes**: `LrProgressScope` with `functionContext` (not `configureProgress`) for accurate bars.
- **Error handling**: `LrTasks.pcall()` everywhere (not bare `pcall`).
- **Preferences**: Global settings stored in `LrPrefs.prefsForPlugin()`.

### Publish Collection → Event Mapping

A Lightroom publish collection maps to a single PicPeak event by `remoteId`. When creating a new collection, the user can:
- Create a new event from the collection name (with event type)
- Bind to an existing event

Since PicPeak v1 has no delete/rename endpoints, those operations show informational dialogs and mark photos as handled in Lightroom without touching the server.

@.claude/skills/lrc-plugin-dev.md
