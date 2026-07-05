--[[
    PicPeakAPI – Lua client for PicPeak v1 API.
    Authentication: Bearer token (Authorization: Bearer pp_live_xxx).
    Base path: /api/v1
]]

local API_BASE_PATH = "/api/v1"
local HTTP_TIMEOUT_DEFAULT = 30
local HTTP_TIMEOUT_UPLOAD = 300

local SUCCESS_STATUS_GET = 200
local SUCCESS_STATUS_POST = { [200] = true, [201] = true }
local SUCCESS_STATUS_CUSTOM = { [200] = true, [201] = true, [204] = true }

PicPeakAPI = {}
PicPeakAPI.__index = PicPeakAPI

-- ---------------------------------------------------------------------------
-- Private helpers
-- ---------------------------------------------------------------------------

local function safeDecodeJson(response, context)
    local ok, decoded = LrTasks.pcall(function()
        return JSON:decode(response or "{}")
    end)
    if not ok or decoded == nil then
        log:error("PicPeakAPI " .. context .. ": JSON decode failed: " .. tostring(decoded))
        return nil
    end
    return decoded
end

local function logRequestStart(api, method, apiPath)
    log:trace("PicPeakAPI: Preparing " .. method .. " request " .. api.url .. API_BASE_PATH .. apiPath)
end

local function handleRequestFailure(method, apiPath, status, headers, response)
    log:error(
        "PicPeakAPI "
            .. tostring(method)
            .. " request failed: "
            .. apiPath
            .. " (status "
            .. tostring(status or "?")
            .. ")"
    )
    if headers then
        log:error("Response headers: " .. util.dumpTable(headers))
    end
    local parsedErrorString = "HTTP " .. tostring(status or "Error")
    if response ~= nil then
        log:error("Response body: " .. tostring(response))
        local decoded = safeDecodeJson(response, "handleRequestFailure")
        if type(decoded) == "table" then
            local msg = decoded.error or decoded.message
            if type(msg) == "string" then
                parsedErrorString = parsedErrorString .. " - " .. msg
            end
        end
    end
    return parsedErrorString
end

-- ---------------------------------------------------------------------------
-- Constructor
-- ---------------------------------------------------------------------------

function PicPeakAPI:new(url, apiToken)
    local o = setmetatable({}, PicPeakAPI)
    o.url = (url ~= nil and type(url) == "string") and url or ""
    o.apiToken = (apiToken ~= nil and type(apiToken) == "string") and apiToken or ""
    return o
end

function PicPeakAPI:reconfigure(url, apiToken)
    self.url = (url ~= nil and type(url) == "string") and url or self.url or ""
    self.apiToken = (apiToken ~= nil and type(apiToken) == "string") and apiToken or self.apiToken or ""
    log:trace("PicPeak reconfigured with URL: " .. self.url)
end

-- ---------------------------------------------------------------------------
-- Headers
-- ---------------------------------------------------------------------------

function PicPeakAPI:createHeaders()
    local token = (self.apiToken ~= nil and type(self.apiToken) == "string") and self.apiToken or ""
    return {
        { field = "Authorization", value = "Bearer " .. token },
        { field = "Accept", value = "application/json" },
        { field = "Content-Type", value = "application/json" },
    }
end

function PicPeakAPI:createHeadersForMultipart()
    local token = (self.apiToken ~= nil and type(self.apiToken) == "string") and self.apiToken or ""
    return {
        { field = "Authorization", value = "Bearer " .. token },
        { field = "Accept", value = "application/json" },
    }
end

-- ---------------------------------------------------------------------------
-- URL sanitization & connectivity
-- ---------------------------------------------------------------------------

function PicPeakAPI:sanityCheckAndFixURL(url)
    if util.nilOrEmpty(url) then
        return false
    end
    if not string.match(url, "^https?://") then
        return nil
    end
    local sanitized = string.match(url, "^https?://[%w%.%-]+[:%d]*")
    if not sanitized then
        return nil
    end
    if string.len(sanitized) < string.len(url) then
        log:trace("sanityCheckAndFixURL: removed trailing path from URL.")
    end
    return sanitized
end

function PicPeakAPI:checkConnectivity()
    if util.nilOrEmpty(self.url) or util.nilOrEmpty(self.apiToken) then
        log:error("checkConnectivity: URL or API token is empty.")
        return false
    end

    local response, headers = LrHttp.get(
        self.url .. API_BASE_PATH .. "/events?limit=1",
        self:createHeaders()
    )

    if not headers then
        log:error("checkConnectivity: no response headers (network error or invalid URL)")
        return false
    end
    if headers.status == 200 then
        return true
    else
        log:error("checkConnectivity: test failed, status=" .. tostring(headers.status))
        if response then
            log:error("Response: " .. tostring(response))
        end
        local errReason = "HTTP " .. tostring(headers.status)
        return false, errReason
    end
end

-- ---------------------------------------------------------------------------
-- Dialog helpers
-- ---------------------------------------------------------------------------

local function _trimString(s)
    if type(s) ~= "string" then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

function PicPeakAPI.validateUrlForDialog(url, baseUrl, baseApiToken)
    local raw = (type(url) == "string") and url or ""
    local trimmed = _trimString(raw)
    if trimmed == "" then
        return false, url, "URL must not be empty. Example: https://photos.example.com"
    end
    local api = PicPeakAPI:new(baseUrl or "", baseApiToken or "")
    local result = api:sanityCheckAndFixURL(trimmed)
    if result == false then
        return false, url, "URL must not be empty. Example: https://photos.example.com"
    end
    if result == nil then
        return false, url, "Invalid URL format. Example: https://photos.example.com"
    end
    if result ~= trimmed then
        if LrDialogs and LrDialogs.message then
            LrDialogs.message("URL was autocorrected to: " .. result)
        end
    end
    return true, result, ""
end

function PicPeakAPI.testConnection(url, apiToken, existingApi)
    local u = _trimString(type(url) == "string" and url or "")
    local token = (type(apiToken) == "string") and apiToken or ""
    if u == "" or token == "" then
        return false, "Please enter URL and API token first.", nil
    end
    local api = existingApi
    if api and type(api.reconfigure) == "function" then
        api:reconfigure(u, token)
    else
        api = PicPeakAPI:new(u, token)
    end
    local ok, errReason = api:checkConnectivity()
    if ok then
        return true, "Connection test successful", api
    end
    return false, "Connection test failed: " .. tostring(errReason or "Check URL, API token, and network."), api
end

-- ---------------------------------------------------------------------------
-- Events (galleries)
-- ---------------------------------------------------------------------------

-- Returns paginated list of events as { title, value } table for popup menus.
-- Fetches up to maxEvents (default 100) events.
function PicPeakAPI:getEvents(maxEvents)
    maxEvents = maxEvents or 100
    local limit = math.min(maxEvents, 100)
    local path = "/events?limit=" .. limit .. "&page=1"
    local parsedResponse = self:doGetRequest(path)
    local events = {}
    if parsedResponse and type(parsedResponse.events) == "table" then
        for _, row in ipairs(parsedResponse.events) do
            if row and row.id and row.event_name then
                local dateStr = (row.event_date and type(row.event_date) == "string")
                    and (" – " .. string.sub(row.event_date, 1, 10))
                    or ""
                table.insert(events, { title = row.event_name .. dateStr, value = tostring(row.id) })
            end
        end
    end
    return events
end

-- Get event details by ID. Returns event table or nil.
function PicPeakAPI:getEvent(eventId)
    if util.nilOrEmpty(eventId) then
        log:warn("getEvent: eventId empty")
        return nil
    end
    return self:doGetRequest("/events/" .. tostring(eventId))
end

-- Check if an event exists on the server.
function PicPeakAPI:checkIfEventExists(eventId)
    if util.nilOrEmpty(eventId) then
        return false
    end
    local event = self:doGetRequestAllow404("/events/" .. tostring(eventId))
    return event ~= nil
end

-- Get event name by ID.
function PicPeakAPI:getEventName(eventId)
    local event = self:getEvent(eventId)
    return event and event.event_name or nil
end

-- Get event share URL.
function PicPeakAPI:getEventShareUrl(eventId)
    if util.nilOrEmpty(eventId) then
        return nil
    end
    local resp = self:doGetRequest("/events/" .. tostring(eventId) .. "/share-link")
    return resp and resp.share_url or nil
end

-- Create a new gallery event.
-- params table (all optional except event_name and event_type):
--   event_name, event_type, event_date,
--   customer_name, customer_email, customer_phone, admin_email,
--   require_password, password,
--   expires_at, feedback_enabled, color_theme
-- Returns: event id, share_url on success; nil on failure.
function PicPeakAPI:createEvent(params)
    if util.nilOrEmpty(params.event_name) then
        ErrorHandler.handleError("No event name given.", "createEvent: event_name empty")
        return nil
    end

    local body = {
        event_name = params.event_name,
        event_type = (not util.nilOrEmpty(params.event_type)) and params.event_type or "other",
    }

    -- Optional string fields: only include when non-empty
    local function addStr(key) if not util.nilOrEmpty(params[key]) then body[key] = params[key] end end
    addStr("event_date")
    addStr("customer_name")
    addStr("customer_email")
    addStr("customer_phone")
    addStr("admin_email")
    addStr("expires_at")
    addStr("color_theme")

    -- Password protection
    body.require_password = params.require_password and true or false
    if body.require_password and not util.nilOrEmpty(params.password) then
        body.password = params.password
    end

    -- Feedback (explicit boolean so server applies it vs inheriting the global default)
    if params.feedback_enabled ~= nil then
        body.feedback_enabled = params.feedback_enabled and true or false
    end

    log:trace("createEvent body: " .. JSON:encode(body))
    local parsedResponse = self:doPostRequest("/events", body)
    if parsedResponse and parsedResponse.id then
        log:info("createEvent: id=" .. tostring(parsedResponse.id) .. " slug=" .. tostring(parsedResponse.slug))
        return parsedResponse.id, parsedResponse.share_url
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Photos
-- ---------------------------------------------------------------------------

local MIME_TYPES = {
    jpg = "image/jpeg", jpeg = "image/jpeg",
    png = "image/png", tiff = "image/tiff", tif = "image/tiff",
    gif = "image/gif", webp = "image/webp", heic = "image/heic",
    heif = "image/heif", bmp = "image/bmp",
}

local function mimeTypeForFile(path)
    local ext = string.lower(string.match(path or "", "%.([^%.]+)$") or "")
    return MIME_TYPES[ext] or "image/jpeg"
end

-- Upload a single photo file to an event.
-- Returns: photo id (integer) on success, nil + errReason on failure.
function PicPeakAPI:uploadPhoto(eventId, filePath, fileName)
    if util.nilOrEmpty(eventId) then
        ErrorHandler.handleError("No event ID given.", "uploadPhoto: eventId empty")
        return nil, "No event ID"
    end
    if util.nilOrEmpty(filePath) then
        ErrorHandler.handleError("No file path given.", "uploadPhoto: filePath empty")
        return nil, "No file path"
    end

    local apiPath = "/events/" .. tostring(eventId) .. "/photos"
    local name = fileName or LrPathUtils.leafName(filePath)

    local mimeChunks = {
        {
            name = "photo",
            filePath = filePath,
            fileName = name,
            contentType = mimeTypeForFile(filePath),
        },
    }

    local parsedResponse, errReason = self:doMultiPartPostRequest(apiPath, mimeChunks)
    if parsedResponse and parsedResponse.id then
        log:info("uploadPhoto: " .. name .. " -> id=" .. tostring(parsedResponse.id))
        return parsedResponse.id
    end
    return nil, errReason
end

-- ---------------------------------------------------------------------------
-- HTTP request layer
-- ---------------------------------------------------------------------------

function PicPeakAPI:doGetRequest(apiPath)
    logRequestStart(self, "GET", apiPath)
    local response, headers = LrHttp.get(
        self.url .. API_BASE_PATH .. apiPath,
        self:createHeaders()
    )

    if not headers then
        log:error("PicPeakAPI GET: no response headers (network error): " .. apiPath)
        ErrorHandler.handleError("No response from PicPeak server. Check URL and network.", "Connection failed")
        return nil
    end
    if headers.status == SUCCESS_STATUS_GET then
        log:trace("PicPeakAPI GET request succeeded")
        return safeDecodeJson(response, "GET")
    end
    local errReason = handleRequestFailure("GET", apiPath, headers.status, headers, response)
    return nil, errReason
end

function PicPeakAPI:doGetRequestAllow404(apiPath)
    logRequestStart(self, "GET", apiPath)
    local response, headers = LrHttp.get(
        self.url .. API_BASE_PATH .. apiPath,
        self:createHeaders()
    )

    if not headers then
        log:error("PicPeakAPI GET: no response headers: " .. apiPath)
        return nil
    end
    if headers.status == SUCCESS_STATUS_GET then
        return safeDecodeJson(response, "GET")
    end
    if headers.status == 404 or headers.status == 400 then
        log:trace("PicPeakAPI GET: resource not found (" .. tostring(headers.status) .. "): " .. apiPath)
        return nil
    end
    handleRequestFailure("GET", apiPath, headers.status, headers, response)
    return nil
end

function PicPeakAPI:doPostRequest(apiPath, postBody)
    logRequestStart(self, "POST", apiPath)
    if postBody ~= nil then
        log:trace("PicPeakAPI: POST body " .. JSON:encode(postBody))
    end
    local response, headers = LrHttp.post(
        self.url .. API_BASE_PATH .. apiPath,
        JSON:encode(postBody),
        self:createHeaders(),
        "POST",
        HTTP_TIMEOUT_DEFAULT
    )

    if not headers then
        log:error("PicPeakAPI POST: no response headers: " .. apiPath)
        ErrorHandler.handleError("No response from PicPeak server. Check URL and network.", "Connection failed")
        return nil
    end
    if SUCCESS_STATUS_POST[headers.status] then
        log:trace("PicPeakAPI POST request succeeded")
        return safeDecodeJson(response, "POST")
    end
    local errReason = handleRequestFailure("POST", apiPath, headers.status, headers, response)
    return nil, errReason
end

function PicPeakAPI:doMultiPartPostRequest(apiPath, mimeChunks)
    logRequestStart(self, "multipart POST", apiPath)
    local response, headers = LrHttp.postMultipart(
        self.url .. API_BASE_PATH .. apiPath,
        mimeChunks,
        self:createHeadersForMultipart(),
        HTTP_TIMEOUT_UPLOAD
    )

    if not headers then
        log:error("PicPeakAPI multipart POST: no response headers: " .. apiPath)
        ErrorHandler.handleError("No response from PicPeak server. Check URL and network.", "Connection failed")
        return nil
    end
    if SUCCESS_STATUS_POST[headers.status] then
        return safeDecodeJson(response, "multipart POST")
    end
    local errReason = handleRequestFailure("multipart POST", apiPath, headers.status, headers, response)
    return nil, errReason
end
