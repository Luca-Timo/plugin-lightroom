--[[
    Merge rules for colour labels and star ratings (PicPeak/picpeak#745).

    Two DIFFERENT merges live here, and conflating them is the bug this file
    exists to prevent:

    1. SOURCE merge — several opinions inside PicPeak collapsing to one value.
       The server already does this and sends the result as `color_label` /
       `rating`, so the plugin normally just reads those. The priority order
       is mirrored here anyway, because the catalog merge below needs it.

    2. CATALOG merge — the PicPeak value versus a label the photo ALREADY
       carries in Lightroom. This one is the plugin's own problem: a re-run,
       or an editor who pre-triaged before uploading proofs, must not have
       their work silently overwritten.

    COLOR_PRIORITY mirrors COLOR_LABEL_PRIORITY in the picpeak backend
    (backend/src/constants/colorLabels.js) — update both together. Green is
    first because in the proofing workflow this exists for, green means
    "1st choice": the pick that must survive a disagreement.
]]

ColorLabelMerge = {}

ColorLabelMerge.COLOR_PRIORITY = { "green", "yellow", "red", "blue", "purple" }

-- Lightroom's own label names for the `colorNameForLabel` raw metadata key.
-- Lowercase, matching what getRawMetadata RETURNS — so a value read back and
-- written again round-trips to the same swatch instead of turning into a
-- custom label.
ColorLabelMerge.LIGHTROOM_COLOR_NAMES = {
    red = "red",
    yellow = "yellow",
    green = "green",
    blue = "blue",
    purple = "purple",
}

--[[
    Values `colorNameForLabel` uses to mean "this photo has no label".

    An unlabelled photo does NOT read back as nil or "" — Lightroom answers
    with "grey". Treating that as a real existing label made every freshly
    imported photo look like a conflict, so `fill_empty` (the default) refused
    to write a single colour: the first real run reported 7 conflicts and 0
    colours written on 7 photos that had just been added to the catalog and
    could not have carried a label at all.

    Matched case-insensitively, with the American spelling and "none" accepted
    too, because guessing wrong here fails silently in exactly that way.
]]
local UNSET_LABELS = {
    [""] = true, grey = true, gray = true, none = true,
}

function ColorLabelMerge.isUnsetLabel(value)
    if value == nil then
        return true
    end
    return UNSET_LABELS[tostring(value):lower()] == true
end

-- How a conflict between PicPeak and Lightroom resolves. Values are stored in
-- prefs, so keep the strings stable.
ColorLabelMerge.MODES = {
    { title = "Fill empty only (never overwrite)", value = "fill_empty" },
    { title = "PicPeak wins", value = "picpeak_wins" },
    { title = "Lightroom wins", value = "lightroom_wins" },
    { title = "Highest priority wins", value = "priority" },
}

function ColorLabelMerge.lightroomColorName(color)
    if color == nil or color == "" then
        return nil
    end
    return ColorLabelMerge.LIGHTROOM_COLOR_NAMES[tostring(color):lower()]
end

local function priorityIndex(color)
    if color == nil or color == "" then
        return nil
    end
    local needle = tostring(color):lower()
    for i, c in ipairs(ColorLabelMerge.COLOR_PRIORITY) do
        if c == needle then
            return i
        end
    end
    return nil
end

--[[
    Resolve one colour.

    @param incoming  lowercase picpeak colour, or nil
    @param existing  the Lightroom colour name already on the photo, or nil/""
    @param mode      one of ColorLabelMerge.MODES values
    @return newValue (Lightroom colour name to write, or nil for "leave alone"),
            conflicted (true when both sides had a DIFFERENT value)
]]
function ColorLabelMerge.resolveColor(incoming, existing, mode)
    local incomingName = ColorLabelMerge.lightroomColorName(incoming)
    local hasExisting = not ColorLabelMerge.isUnsetLabel(existing)

    if incomingName == nil then
        return nil, false
    end
    if not hasExisting then
        return incomingName, false
    end
    if incomingName == tostring(existing):lower() then
        return nil, false
    end

    -- Both sides carry a value and they disagree.
    if mode == "picpeak_wins" then
        return incomingName, true
    elseif mode == "lightroom_wins" then
        return nil, true
    elseif mode == "priority" then
        -- An existing label Lightroom knows but PicPeak does not (a custom
        -- one) has no priority index. Treat it as lowest rather than
        -- discarding it, so a custom label is never silently destroyed by a
        -- mode the user chose for its ranking, not for its overwriting.
        local incomingIdx = priorityIndex(incoming)
        local existingIdx = priorityIndex(existing)
        if incomingIdx == nil then
            return nil, true
        end
        if existingIdx == nil then
            return nil, true
        end
        if incomingIdx < existingIdx then
            return incomingName, true
        end
        return nil, true
    end

    -- "fill_empty" and any unknown mode: never overwrite. Defaulting an
    -- unrecognised mode to the destructive branch is how a typo in prefs
    -- eats somebody's triage.
    return nil, true
end

--[[
    Resolve one star rating. Same contract as resolveColor.

    "priority" means the higher rating wins, which is the rating analogue of
    the colour ordering: a rating is a magnitude, so losing the higher of the
    two quietly demotes a photo somebody rated highly.
]]
function ColorLabelMerge.resolveRating(incoming, existing, mode)
    local incomingValue = tonumber(incoming) or 0
    local existingValue = tonumber(existing) or 0

    if incomingValue <= 0 then
        return nil, false
    end
    if existingValue <= 0 then
        return incomingValue, false
    end
    if incomingValue == existingValue then
        return nil, false
    end

    if mode == "picpeak_wins" then
        return incomingValue, true
    elseif mode == "lightroom_wins" then
        return nil, true
    elseif mode == "priority" then
        if incomingValue > existingValue then
            return incomingValue, true
        end
        return nil, true
    end

    return nil, true
end

return ColorLabelMerge
