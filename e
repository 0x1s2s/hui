local function _safeCloneRef(service)
    if type(cloneref) == "function" then
        local ok, result = pcall(cloneref, service)
        if ok and result then return result end
    end
    return service
end

local _ts = _safeCloneRef(game:GetService("TweenService"))
local _uis = _safeCloneRef(game:GetService("UserInputService"))
local _rs = _safeCloneRef(game:GetService("RunService"))
local _ps = _safeCloneRef(game:GetService("Players"))
local _txs = _safeCloneRef(game:GetService("TextService"))
local _gs = _safeCloneRef(game:GetService("GuiService"))
local _hs = _safeCloneRef(game:GetService("HttpService"))
local _ls = _safeCloneRef(game:GetService("Lighting"))

local _Lib = {}
_Lib.__index = _Lib

local _lp = _ps.LocalPlayer
if not _lp then
    local startedAt = os.clock()
    repeat
        task.wait()
        _lp = _ps.LocalPlayer
    until _lp or (os.clock() - startedAt) > 10
end
local _mouse = nil
local _pg = nil
if _lp then
    local okMouse, playerMouse = pcall(function()
        return _lp:GetMouse()
    end)
    if okMouse then
        _mouse = playerMouse
    end

    local okPlayerGui, playerGui = pcall(function()
        return _lp:FindFirstChild("PlayerGui") or _lp:WaitForChild("PlayerGui", 10)
    end)
    if okPlayerGui then
        _pg = playerGui
    end
end

local function _getPlayer()
    if _lp and _lp.Parent then
        return _lp
    end
    _lp = _ps.LocalPlayer or _lp
    return _lp
end

local function _getPlayerName()
    local player = _getPlayer()
    return player and tostring(player.Name) or "Player"
end

local function _getPlayerDisplayName()
    local player = _getPlayer()
    return player and tostring(player.DisplayName or player.Name) or _getPlayerName()
end

local function _getPlayerUserId()
    local player = _getPlayer()
    return player and tonumber(player.UserId) or 0
end

local function _getPlayerCharacter()
    local player = _getPlayer()
    return player and player.Character or nil
end

local _isMobile = _uis.TouchEnabled and not _uis.KeyboardEnabled
local _mScale = _isMobile and 0.7 or 1
local _defFont = Enum.Font.GothamSemibold
local _defFontFam = "rbxasset://fonts/families/GothamSSm.json"
local _palette = {
    Shell = Color3.fromRGB(3, 4, 6),
    Canvas = Color3.fromRGB(5, 6, 8),
    Panel = Color3.fromRGB(8, 10, 12),
    ControlInset = Color3.fromRGB(11, 13, 16),
    TacticalLine = Color3.fromRGB(36, 42, 50),
    Surface = Color3.fromRGB(7, 8, 10),
    SurfaceAlt = Color3.fromRGB(10, 12, 15),
    SurfaceSoft = Color3.fromRGB(15, 18, 22),
    SurfaceHover = Color3.fromRGB(22, 27, 33),
    SurfaceOverlay = Color3.fromRGB(12, 14, 17),
    Stroke = Color3.fromRGB(31, 37, 44),
    StrokeStrong = Color3.fromRGB(54, 64, 76),
    Text = Color3.fromRGB(255, 255, 255),
    TextMuted = Color3.fromRGB(172, 176, 184),
    TextSoft = Color3.fromRGB(116, 123, 134),
    FieldText = Color3.fromRGB(218, 218, 222),
    FieldPlaceholder = Color3.fromRGB(98, 104, 114),
    ToggleOff = Color3.fromRGB(18, 21, 25),
    ToggleKnobOff = Color3.fromRGB(100, 109, 122),
    SliderTrack = Color3.fromRGB(16, 19, 23),
    Button = Color3.fromRGB(15, 18, 22),
    ButtonHover = Color3.fromRGB(24, 29, 35)
}
local _brandIcon = "rbxassetid://95109736896642"
local _activeTweens = setmetatable({}, {__mode = "k"})
local _MIN_PSTEP = 1 / 20
local _LOW_FPS = 42
local _CRIT_FPS = 30
local _DBG_SLOW = 0.018
local _DBG_MAX = 40
local _dbgProf = nil

local function _rndDelay()
end

local function _isDbgEnabled(config)
    if type(config) == "table" then
        if config.DebugBuild == true or config.BuildDebug == true or config.TraceBuild == true then
            return true
        end
    end
    return false
end

local function _mkDbgProf()
    return {
        StartedAt = os.clock(),
        Counters = {},
        Timings = {},
        SlowCalls = {},
        InstanceCounts = {},
        InstanceTimes = {},
        TotalInstances = 0,
        LastReport = nil
    }
end

local function _addDbgCnt(profiler, key, amount)
    if not profiler then
        return
    end
    profiler.Counters[key] = (profiler.Counters[key] or 0) + (amount or 1)
end

local function _addDbgTime(profiler, key, elapsed, detail)
    if not profiler then
        return
    end

    local timing = profiler.Timings[key]
    if not timing then
        timing = {
            Count = 0,
            Total = 0,
            Max = 0,
            MaxDetail = nil
        }
        profiler.Timings[key] = timing
    end

    timing.Count = timing.Count + 1
    timing.Total = timing.Total + elapsed
    if elapsed > timing.Max then
        timing.Max = elapsed
        timing.MaxDetail = detail
    end

    if elapsed >= _DBG_SLOW then
        table.insert(profiler.SlowCalls, {
            Key = key,
            Time = elapsed,
            Detail = detail
        })
        table.sort(profiler.SlowCalls, function(a, b)
            return a.Time > b.Time
        end)
        while #profiler.SlowCalls > _DBG_MAX do
            table.remove(profiler.SlowCalls)
        end
    end
end

local function _addDbgInst(profiler, className, elapsed)
    if not profiler then
        return
    end
    profiler.TotalInstances = profiler.TotalInstances + 1
    profiler.InstanceCounts[className] = (profiler.InstanceCounts[className] or 0) + 1
    profiler.InstanceTimes[className] = (profiler.InstanceTimes[className] or 0) + elapsed
    _addDbgTime(profiler, "Instance.new/" .. tostring(className), elapsed, className)
end

local function _beginDbgTimer(libraryRef, label)
    if not libraryRef or not libraryRef._debugBuildEnabled then
        return nil
    end
    return {
        Library = libraryRef,
        Label = label,
        StartedAt = os.clock()
    }
end

local function _endDbgTimer(token, detail)
    if not token or not token.Library or not token.Library._debugBuildProfiler then
        return
    end
    _addDbgTime(token.Library._debugBuildProfiler, token.Label, os.clock() - token.StartedAt, detail)
end

local function _fmtDbgSec(value)
    return string.format("%.3fms", (tonumber(value) or 0) * 1000)
end

local function _collectDbgTop(source, limit, valueKey)
    local entries = {}
    for key, value in pairs(source or {}) do
        local sortValue
        if type(value) == "table" then
            sortValue = tonumber(value[valueKey or "Total"]) or 0
        else
            sortValue = tonumber(value) or 0
        end
        table.insert(entries, {
            Key = key,
            Value = value,
            SortValue = sortValue
        })
    end
    table.sort(entries, function(a, b)
        return a.SortValue > b.SortValue
    end)
    while #entries > (limit or 10) do
        table.remove(entries)
    end
    return entries
end

local function _cornerRad(pixels)
    return UDim.new(0, math.max(0, math.floor(((tonumber(pixels) or 0) * _mScale) + 0.5)))
end

local _cornerTk = {
    Shell = _cornerRad(16),
    Large = _cornerRad(12),
    Panel = _cornerRad(10),
    Card = _cornerRad(8),
    Tight = _cornerRad(6),
    Micro = _cornerRad(5),
    Pill = UDim.new(1, 0)
}

local function _localRngName(length)
    local chars = "abcdefghijklmnopqrstuvwxyz"
    local result = ""
    for _ = 1, length or 8 do
        result = result .. string.sub(chars, math.random(1, 26), math.random(1, 26))
    end
    return result
end

local _sNames = setmetatable({}, {
    __index = function(t, key)
        t[key] = _localRngName(math.random(6, 12))
        return t[key]
    end
})

local function _assetUrl(id)
    return string.char(114,98,120,97,115,115,101,116,105,100,58,47,47) .. tostring(id)
end

local function _resolveFontEnum(weight)
    if weight == Enum.FontWeight.Bold then
        return Enum.Font.GothamBold
    end
    if weight == Enum.FontWeight.Medium then
        return Enum.Font.GothamMedium
    end
    return _defFont
end

local _ffSupp = false

local function _mkFontDesc(family, weight, style, enumFont)
    return {
        __fd = true,
        Family = family or _defFontFam,
        Weight = weight or Enum.FontWeight.SemiBold,
        Style = style or Enum.FontStyle.Normal,
        EnumFont = enumFont or _resolveFontEnum(weight)
    }
end

local function _isFontDesc(value)
    return type(value) == "table" and value.__fd == true
end

local function _getFbFont(value, fallbackEnum)
    if _isFontDesc(value) then
        return value.EnumFont or fallbackEnum or _defFont
    end
    return fallbackEnum or _defFont
end

local function _applyFont(instance, value, fallbackEnum)
    if not instance or not (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
        return false
    end

    pcall(function()
        instance.Font = _getFbFont(value, fallbackEnum)
    end)
    return false
end

local Font = {
    new = function(family, weight, style)
        family = family or _defFontFam
        weight = weight or Enum.FontWeight.SemiBold
        style = style or Enum.FontStyle.Normal
        return _mkFontDesc(family, weight, style)
    end,
    fromEnum = function(enumFont)
        enumFont = enumFont or _defFont
        return _mkFontDesc(_defFontFam, Enum.FontWeight.SemiBold, Enum.FontStyle.Normal, enumFont)
    end
}

local function _mk(className, properties)
    properties = properties or {}
    local debugProfiler = _dbgProf
    local debugStart = debugProfiler and os.clock() or nil

    local okNew, whatWeJustMade = pcall(Instance.new, className)
    if not okNew or not whatWeJustMade then
        okNew, whatWeJustMade = pcall(Instance.new, "Frame")
        if not okNew or not whatWeJustMade then
            return nil
        end
    end

    if whatWeJustMade:IsA("GuiObject") and properties.BorderSizePixel == nil then
        pcall(function()
            whatWeJustMade.BorderSizePixel = 0
        end)
    end

    for property, value in pairs(properties) do
        if property ~= "Parent" then
            if property == "FontFace" then
                pcall(_applyFont, whatWeJustMade, value)
            else
                pcall(function()
                    whatWeJustMade[property] = value
                end)
            end
        end
    end
    if properties.Parent then
        pcall(function()
            whatWeJustMade.Parent = properties.Parent
        end)
    end
    if debugProfiler then
        _addDbgInst(debugProfiler, className, os.clock() - debugStart)
    end
    return whatWeJustMade
end

local function _mkCorner(parent, radius)
    return _mk("UICorner", {
        CornerRadius = radius or _cornerTk.Card,
        Parent = parent
    })
end

local function _applyStrokeGrad(strokeRef)
    return _mk("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, _palette.StrokeStrong),
            ColorSequenceKeypoint.new(0.5, _palette.Stroke),
            ColorSequenceKeypoint.new(1, _palette.StrokeStrong)
        }),
        Rotation = 260,
        Parent = strokeRef
    })
end

local function _getTextClr(libraryRef)
    if libraryRef and libraryRef.config and typeof(libraryRef.config.TextColor) == "Color3" then
        return libraryRef.config.TextColor
    end
    return _palette.Text
end

local function _getSubClr(libraryRef)
    if libraryRef and libraryRef.config and typeof(libraryRef.config.SubTextColor) == "Color3" then
        return libraryRef.config.SubTextColor
    end
    return _palette.TextMuted
end

local function _fmtKeyDur(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds <= 0 then
        return "Key: Expired"
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if days > 0 then
        return string.format("Key: %dd %dh left", days, hours)
    elseif hours > 0 then
        return string.format("Key: %dh %dm left", hours, minutes)
    end
    return string.format("Key: %dm left", math.max(1, minutes))
end

local function _getRtValue(keys)
    return nil
end

local function _resolveLrmKey()
    local keyValue = _getRtValue({"script_key", "ScriptKey", "SCRIPT_KEY", "luarmor_key", "LuarmorKey", "user_key", "UserKey"})
    if keyValue == nil then
        return nil
    end
    local keyText = tostring(keyValue)
    if keyText == "" then
        return nil
    end
    return keyText
end

local function _resolveRtAuth()
    local expireValue = _getRtValue({"LRM_AuthExpire", "LRM_AuthExpiresAt", "FlowKeyExpiresAt", "KeyExpiresAt", "auth_expire", "authExpire", "expires_at", "expiresAt", "expire_at", "expireAt"})
    local expireNumber = tonumber(expireValue)
    if expireNumber then
        return expireNumber
    end
    return nil
end

local function _resolveAuthData(data)
    if type(data) ~= "table" then
        return nil
    end

    local authExpire = tonumber(data.auth_expire or data.authExpire or data.expires_at or data.expiresAt or data.expire_at or data.expireAt)
    if authExpire then
        return authExpire
    end

    local nested = data.user or data.key or data.auth or data.subscription or data.result
    if type(nested) == "table" then
        return tonumber(nested.auth_expire or nested.authExpire or nested.expires_at or nested.expiresAt or nested.expire_at or nested.expireAt)
    end
    return nil
end

local function _resolveLrmKeyText()
    local secondsLeft = _getRtValue({"LRM_SecondsLeft", "FlowKeyDurationSeconds", "KeyDurationSeconds"})
    if type(secondsLeft) == "number" then
        if secondsLeft == math.huge or secondsLeft < 0 or secondsLeft > 315360000 then
            return "Key: Lifetime", nil
        end
        return _fmtKeyDur(secondsLeft), os.time() + math.max(0, secondsLeft)
    end

    local runtimeAuthExpire = _resolveRtAuth()
    if runtimeAuthExpire then
        if runtimeAuthExpire <= 0 then
            return "Key: Lifetime", nil
        end
        return _fmtKeyDur(runtimeAuthExpire - os.time()), runtimeAuthExpire
    end

    local isPremium = _getRtValue({"LRM_IsUserPremium"})
    if isPremium == true then
        return "Key: Premium", nil
    elseif isPremium == false then
        return "Key: Free", nil
    end

    if _resolveLrmKey() then
        return "Key: Detected", nil
    end
    return nil, nil
end

local function _fmtLrmStatus(status)
    if type(status) ~= "table" then
        return "Key: Check failed", nil
    end

    local code = tostring(status.code or status.Code or "")
    if code == "KEY_VALID" then
        local data = type(status.data) == "table" and status.data or {}
        local authExpire = _resolveAuthData(data)
        if authExpire and authExpire > 0 then
            return _fmtKeyDur(authExpire - os.time()), authExpire
        end
        return "Key: Lifetime", nil
    elseif code == "KEY_EXPIRED" then
        return "Key: Expired", nil
    elseif code == "KEY_BANNED" then
        return "Key: Banned", nil
    elseif code == "KEY_HWID_LOCKED" then
        return "Key: HWID locked", nil
    elseif code == "KEY_INCORRECT" then
        return "Key: Incorrect", nil
    elseif code == "KEY_INVALID" then
        return "Key: Invalid", nil
    elseif code == "SCRIPT_ID_INCORRECT" or code == "SCRIPT_ID_INVALID" then
        return "Key: Bad script ID", nil
    elseif code == "INVALID_EXECUTOR" then
        return "Key: Executor unsupported", nil
    elseif code ~= "" then
        return "Key: " .. string.gsub(code, "_", " "), nil
    end
    return "Key: Check failed", nil
end

local function _resolveKeyText(config)
    if type(config) ~= "table" then
        local runtimeText = _resolveLrmKeyText()
        return runtimeText or "Key: Active"
    end
    if config.KeyDurationText ~= nil and tostring(config.KeyDurationText) ~= "" then
        return tostring(config.KeyDurationText)
    end
    if tonumber(config.KeyExpiresAt) then
        return _fmtKeyDur(tonumber(config.KeyExpiresAt) - os.time())
    end
    if tonumber(config.KeyDurationSeconds) then
        return _fmtKeyDur(tonumber(config.KeyDurationSeconds))
    end
    if config.KeyStatusText ~= nil and tostring(config.KeyStatusText) ~= "" then
        return tostring(config.KeyStatusText)
    end
    local runtimeText = _resolveLrmKeyText()
    return runtimeText or "Key: Active"
end

local function _normMotion(value)
    local normalized = string.lower(tostring(value or "Normal"))
    if normalized == "off" or normalized == "none" or normalized == "false" then
        return "Off"
    elseif normalized == "reduced" or normalized == "low" or normalized == "lite" then
        return "Reduced"
    end
    return "Normal"
end

local function _normDensity(value)
    local normalized = string.lower(tostring(value or "Compact"))
    if normalized == "comfortable" or normalized == "comfort" or normalized == "large" or normalized == "roomy" then
        return "Comfortable"
    end
    return "Compact"
end

local function _normWmStyle(value)
    local normalized = string.lower(tostring(value or "Compact"))
    if normalized == "full" or normalized == "classic" or normalized == "wide" then
        return "Full"
    end
    return "Compact"
end

local function _normSbStyle(value)
    local normalized = string.lower(tostring(value or "Clean"))
    if normalized == "classic" or normalized == "legacy" or normalized == "old" then
        return "Classic"
    end
    return "Clean"
end

local function _normCtrlStyle(value)
    local normalized = string.lower(tostring(value or "Precision"))
    if normalized == "classic" or normalized == "legacy" or normalized == "old" then
        return "Classic"
    end
    return "Precision"
end

local function _normGrpTabStyle(value)
    local normalized = string.lower(tostring(value or "Segmented"))
    if normalized == "classic" or normalized == "legacy" or normalized == "old" then
        return "Classic"
    end
    return "Segmented"
end

local function _mkSurface(parent, backgroundColor, position, size, options)
    options = options or {}
    local frame = _mk("Frame", {
        BackgroundColor3 = backgroundColor or _palette.Surface,
        BackgroundTransparency = options.BackgroundTransparency or 0,
        BorderSizePixel = 0,
        Position = position or UDim2.new(0, 0, 0, 0),
        Size = size or UDim2.new(0, 0, 0, 0),
        ClipsDescendants = options.ClipsDescendants == true,
        ZIndex = options.ZIndex,
        Parent = parent
    })
    if options.CornerRadius then
        _mkCorner(frame, options.CornerRadius)
    end
    local strokeThing = nil
    if options.StrokeColor then
        strokeThing = _mk("UIStroke", {
            Color = options.StrokeColor,
            Thickness = options.StrokeThickness or 1,
            Parent = frame
        })
        if options.StrokeGradient then
            _applyStrokeGrad(strokeThing)
        end
    end
    return frame, strokeThing
end

local function _mkLabel(parent, libraryRef, text, position, size, options)
    options = options or {}
    return _mk("TextLabel", {
        FontFace = options.FontFace or Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        TextColor3 = options.TextColor or _getSubClr(libraryRef),
        Text = text or "",
        BackgroundTransparency = 1,
        Position = position or UDim2.new(0, 0, 0, 0),
        Size = size or UDim2.new(0, 0, 0, 0),
        TextSize = options.TextSize or (14 * _mScale),
        TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left,
        TextYAlignment = options.TextYAlignment,
        TextTruncate = options.TextTruncate,
        TextWrapped = options.TextWrapped == true,
        ClipsDescendants = options.ClipsDescendants == true,
        ZIndex = options.ZIndex,
        AnchorPoint = options.AnchorPoint,
        Visible = options.Visible,
        Parent = parent
    })
end

local function _normIcon(image)
    if image == nil then
        return nil
    end
    if type(image) == "number" then
        return _assetUrl(tostring(image))
    end
    local imageText = tostring(image)
    if tonumber(imageText) then
        return _assetUrl(imageText)
    end
    return imageText
end

local function _mkIcon(parent, image, color, position, size, options)
    options = options or {}
    local iconImage = _mk("ImageLabel", {
        Image = _normIcon(image),
        ImageColor3 = color or _palette.TextMuted,
        ImageTransparency = options.ImageTransparency,
        BackgroundTransparency = 1,
        Position = position or UDim2.new(0, 0, 0, 0),
        Size = size or UDim2.new(0, 0, 0, 0),
        AnchorPoint = options.AnchorPoint,
        ZIndex = options.ZIndex,
        Parent = parent
    })
    if options.FallbackImage ~= nil then
        task.delay(1.25, function()
            if iconImage and iconImage.Parent and iconImage.IsLoaded == false then
                iconImage.Image = _normIcon(options.FallbackImage)
            end
        end)
    end
    return iconImage
end

local function _tween(instance, properties, duration, easingStyle, easingDirection)
    if not instance or type(properties) ~= "table" then
        return nil
    end

    local instanceTweens = _activeTweens[instance]
    if not instanceTweens then
        instanceTweens = {}
        _activeTweens[instance] = instanceTweens
    end

    local hasChangedProperty = false
    for property, value in pairs(properties) do
        local existingTween = instanceTweens[property]
        if existingTween then
            pcall(function()
                existingTween:Cancel()
            end)
            instanceTweens[property] = nil
        end

        local okCurrent, currentValue = pcall(function()
            return instance[property]
        end)
        if not okCurrent or currentValue ~= value then
            hasChangedProperty = true
        end
    end

    if not hasChangedProperty then
        return nil
    end

    if (tonumber(duration) or 0) <= 0 then
        for property, value in pairs(properties) do
            pcall(function()
                instance[property] = value
            end)
        end
        return nil
    end

    local okInfo, tweenInfoYay = pcall(function()
        return TweenInfo.new(duration or 0.22, easingStyle or Enum.EasingStyle.Quint, easingDirection or Enum.EasingDirection.Out)
    end)
    if not okInfo or not tweenInfoYay then
        tweenInfoYay = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end

    local okTween, tweenGoVroom = pcall(function()
        return _ts:Create(instance, tweenInfoYay, properties)
    end)
    if not okTween or not tweenGoVroom then
        for property, value in pairs(properties) do
            pcall(function()
                instance[property] = value
            end)
        end
        return nil
    end

    for property in pairs(properties) do
        instanceTweens[property] = tweenGoVroom
    end

    pcall(function()
        tweenGoVroom.Completed:Connect(function()
            local trackedTweens = _activeTweens[instance]
            if not trackedTweens then
                return
            end
            for property in pairs(properties) do
                if trackedTweens[property] == tweenGoVroom then
                    trackedTweens[property] = nil
                end
            end
        end)
    end)

    local okPlay = pcall(function()
        tweenGoVroom:Play()
    end)
    if not okPlay then
        local trackedTweens = _activeTweens[instance]
        if trackedTweens then
            for property in pairs(properties) do
                if trackedTweens[property] == tweenGoVroom then
                    trackedTweens[property] = nil
                end
            end
        end
        for property, value in pairs(properties) do
            pcall(function()
                instance[property] = value
            end)
        end
        return nil
    end

    return tweenGoVroom
end

local function _dcConn(conn)
    if conn and typeof(conn) == "RBXScriptConnection" then
        pcall(function()
            if conn.Connected then
                conn:Disconnect()
            end
        end)
    elseif type(conn) == "function" then
        pcall(conn)
    end
end

local function _safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return nil
    end

    local ok, result = pcall(callback, ...)
    if not ok then
        warn("[FlowUI] callback error: " .. tostring(result))
        return nil
    end

    return result
end

local function _mkDrag(frame, handle, libraryRef)
    local amIDragging = false
    local activeDragInput
    local whereDidIStart
    local whereWasIBefore
    local targetDragPosition = frame.Position
    local dragLerpSpeed = _isMobile and 18 or 22
    local renderDragConn
    
    handle = handle or frame

    local function stopDragLoop()
        _dcConn(renderDragConn)
        renderDragConn = nil
    end

    local function ensureDragLoop()
        if renderDragConn and renderDragConn.Connected then
            return
        end
        renderDragConn = _rs.RenderStepped:Connect(function(dt)
            if not frame or not frame.Parent then
                stopDragLoop()
                return
            end
            local currentPos = frame.Position
            local goalPos = targetDragPosition
            local offsetDelta = math.abs(goalPos.X.Offset - currentPos.X.Offset) + math.abs(goalPos.Y.Offset - currentPos.Y.Offset)
            if offsetDelta <= 0.1 then
                if currentPos ~= goalPos then
                    frame.Position = goalPos
                end
                if not amIDragging then
                    stopDragLoop()
                end
                return
            end
            local alpha = math.clamp(1 - math.exp(-dragLerpSpeed * dt), 0, 0.45)
            frame.Position = currentPos:Lerp(goalPos, alpha)
        end)
        if libraryRef and type(libraryRef._TrackConnection) == "function" then
            libraryRef:_TrackConnection(renderDragConn)
        end
    end
    
    local function clampTargetPosition()
        if not libraryRef then
            return
        end
        local vpWidth = libraryRef._cachedViewportWidth or _gs.AbsoluteWindowSize.X
        local vpHeight = libraryRef._cachedViewportHeight or _gs.AbsoluteWindowSize.Y
        local frameWidth = frame.Size.X.Offset
        local frameHeight = frame.Size.Y.Offset

        local minX = -vpWidth * targetDragPosition.X.Scale
        local maxX = vpWidth * (1 - targetDragPosition.X.Scale) - frameWidth
        local minY = -vpHeight * targetDragPosition.Y.Scale
        local maxY = vpHeight * (1 - targetDragPosition.Y.Scale) - frameHeight

        targetDragPosition = UDim2.new(
            targetDragPosition.X.Scale,
            math.clamp(targetDragPosition.X.Offset, minX, maxX),
            targetDragPosition.Y.Scale,
            math.clamp(targetDragPosition.Y.Offset, minY, maxY)
        )
    end

    local function updateTargetPositionYay(input)
        local howMuchDidIMove = input.Position - whereDidIStart
        targetDragPosition = UDim2.new(
            whereWasIBefore.X.Scale,
            whereWasIBefore.X.Offset + howMuchDidIMove.X,
            whereWasIBefore.Y.Scale,
            whereWasIBefore.Y.Offset + howMuchDidIMove.Y
        )
        clampTargetPosition()
    end
    
    local inputBeganConn = handle.InputBegan:Connect(function(input)
        local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
        local isTouch = input.UserInputType == Enum.UserInputType.Touch
        if not isMouse and not isTouch then
            return
        end

        amIDragging = true
        activeDragInput = isTouch and input or nil
        whereDidIStart = input.Position
        whereWasIBefore = frame.Position
        targetDragPosition = frame.Position
        ensureDragLoop()
        
        local inputEndConn
        inputEndConn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if frame and frame.Parent then
                    frame.Position = targetDragPosition
                end
                amIDragging = false
                activeDragInput = nil
                stopDragLoop()
                if inputEndConn then
                    inputEndConn:Disconnect()
                    inputEndConn = nil
                end
            end
        end)
        if libraryRef and type(libraryRef._TrackConnection) == "function" then
            libraryRef:_TrackConnection(inputEndConn)
        end
    end)
    
    local userInputChangedConn = _uis.InputChanged:Connect(function(input)
        if not amIDragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            updateTargetPositionYay(input)
        elseif input.UserInputType == Enum.UserInputType.Touch and (activeDragInput == nil or input == activeDragInput) then
            updateTargetPositionYay(input)
        end
    end)

    if libraryRef and type(libraryRef._TrackConnection) == "function" then
        libraryRef:_TrackConnection(inputBeganConn)
        libraryRef:_TrackConnection(userInputChangedConn)
    end
end

local function startFloatingPositionTracker(libraryRef, anchorInstance, updateFn)
    if type(updateFn) ~= "function" or not anchorInstance then
        return nil
    end

    local active = true
    local connections = {}

    local function bindSignal(instance, propertyName)
        if not instance then
            return
        end
        table.insert(connections, libraryRef:_TrackConnection(instance:GetPropertyChangedSignal(propertyName):Connect(updateFn)))
    end

    bindSignal(anchorInstance, "AbsolutePosition")
    bindSignal(anchorInstance, "AbsoluteSize")
    table.insert(connections, libraryRef:_TrackConnection(anchorInstance.AncestryChanged:Connect(updateFn)))

    if libraryRef and libraryRef._sgRef then
        bindSignal(libraryRef._sgRef, "AbsoluteSize")
    end

    updateFn()

    return function()
        if not active then
            return
        end
        active = false
        for i = #connections, 1, -1 do
            _dcConn(connections[i])
            connections[i] = nil
        end
    end
end

local function _attachScrollbar(libraryRef, scrollFrame, parentInstance, options)
    if not libraryRef or not scrollFrame or not parentInstance then
        return nil
    end

    options = options or {}

    local trackWidth = math.max(4, math.floor((options.TrackWidth or (6 * _mScale)) + 0.5))
    local thumbWidth = math.max(2, math.min(trackWidth - 1, math.floor((options.ThumbWidth or (3 * _mScale)) + 0.5)))
    local edgeInset = math.max(1, math.floor((options.EdgeInset or (2 * _mScale)) + 0.5))
    local verticalInset = math.max(2, math.floor((options.VerticalInset or (4 * _mScale)) + 0.5))
    local minThumbHeight = math.max(18, math.floor((options.MinThumbHeight or (26 * _mScale)) + 0.5))
    local idleThumbHeight = math.max(minThumbHeight, math.floor((options.IdleThumbHeight or (42 * _mScale)) + 0.5))
    local alwaysShowTrack = options.AlwaysShowTrack == true
    local zIndex = options.ZIndex or ((scrollFrame.ZIndex or 1) + 2)

    local trackFrame = _mk("Frame", {
        Name = _sNames["ScrollbarTrack"],
        BackgroundColor3 = Color3.fromRGB(18, 18, 18),
        BackgroundTransparency = 0.58,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = zIndex,
        Parent = parentInstance
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = trackFrame})

    local thumbFrame = _mk("Frame", {
        Name = _sNames["ScrollbarThumb"],
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(86, 86, 86),
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(0, thumbWidth, 0, minThumbHeight),
        ZIndex = zIndex + 1,
        Parent = trackFrame
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = thumbFrame})

    local function resolveCanvasHeight()
        local canvasHeight = math.max(scrollFrame.CanvasSize.Y.Offset, 0)
        local okAbsoluteCanvas, absoluteCanvasSize = pcall(function()
            return scrollFrame.AbsoluteCanvasSize
        end)
        if okAbsoluteCanvas and typeof(absoluteCanvasSize) == "Vector2" then
            canvasHeight = math.max(canvasHeight, absoluteCanvasSize.Y)
        end
        return canvasHeight
    end

    local function updateScrollbar()
        if libraryRef._destroyed or not scrollFrame.Parent or not parentInstance.Parent or not trackFrame.Parent then
            return false
        end

        local frameSize = scrollFrame.AbsoluteSize
        local windowHeight = frameSize.Y
        local frameVisible = scrollFrame.Visible and frameSize.X > 0 and frameSize.Y > 0
        local canvasHeight = math.max(resolveCanvasHeight(), windowHeight)
        local canScroll = frameVisible and canvasHeight > (windowHeight + 1)

        if not frameVisible then
            trackFrame.Visible = false
            thumbFrame.Visible = false
            return true
        end

        local parentAbsolute = parentInstance.AbsolutePosition
        local frameAbsolute = scrollFrame.AbsolutePosition
        local trackHeight = math.max(0, frameSize.Y - (verticalInset * 2))
        if trackHeight <= 2 then
            trackFrame.Visible = false
            return true
        end
        local trackX = math.floor((frameAbsolute.X - parentAbsolute.X) + frameSize.X - trackWidth - edgeInset + 0.5)
        local trackY = math.floor((frameAbsolute.Y - parentAbsolute.Y) + verticalInset + 0.5)

        trackFrame.Visible = true
        trackFrame.Position = UDim2.fromOffset(trackX, trackY)
        trackFrame.Size = UDim2.fromOffset(trackWidth, math.floor(trackHeight + 0.5))
        trackFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
        thumbFrame.BackgroundColor3 = Color3.fromRGB(86, 86, 86)

        if not canScroll then
            trackFrame.Visible = alwaysShowTrack
            thumbFrame.Visible = alwaysShowTrack
            if alwaysShowTrack then
                local restingThumbHeight = math.min(idleThumbHeight, trackHeight)
                thumbFrame.Size = UDim2.fromOffset(thumbWidth, math.floor(restingThumbHeight + 0.5))
                thumbFrame.Position = UDim2.fromOffset(math.floor(trackWidth * 0.5 + 0.5), math.floor(math.max(0, (trackHeight - restingThumbHeight) * 0.08) + 0.5))
            end
            return true
        end

        thumbFrame.Visible = true
        local minimumThumbHeight = math.min(minThumbHeight, trackHeight)
        local thumbHeight = math.clamp((windowHeight / canvasHeight) * trackHeight, minimumThumbHeight, trackHeight)
        local maxScroll = math.max(canvasHeight - windowHeight, 0)
        local scrollRatio = maxScroll > 0 and math.clamp(scrollFrame.CanvasPosition.Y / maxScroll, 0, 1) or 0
        local thumbTravel = math.max(trackHeight - thumbHeight, 0)

        thumbFrame.Size = UDim2.fromOffset(thumbWidth, math.floor(thumbHeight + 0.5))
        thumbFrame.Position = UDim2.fromOffset(math.floor(trackWidth * 0.5 + 0.5), math.floor((thumbTravel * scrollRatio) + 0.5))

        return true
    end

    local function bindProperty(propertyName)
        local okSignal, signal = pcall(function()
            return scrollFrame:GetPropertyChangedSignal(propertyName)
        end)
        if okSignal and signal then
            libraryRef:_TrackConnection(signal:Connect(updateScrollbar))
        end
    end

    bindProperty("CanvasPosition")
    bindProperty("CanvasSize")
    bindProperty("AbsoluteSize")
    bindProperty("AbsoluteCanvasSize")
    bindProperty("Visible")

    local stopFloatingTracker = startFloatingPositionTracker(libraryRef, scrollFrame, updateScrollbar)
    if stopFloatingTracker then
        libraryRef:_TrackConnection(stopFloatingTracker)
    end

    if type(libraryRef._scrollbarRefreshers) == "table" then
        table.insert(libraryRef._scrollbarRefreshers, updateScrollbar)
    end

    updateScrollbar()

    return {
        Track = trackFrame,
        Thumb = thumbFrame,
        Refresh = updateScrollbar
    }
end

local _defAvatar = _assetUrl("135756197673563")

local function getPlayerAvatarCuzTheyreBeautiful(userId)
    local debugProfiler = _dbgProf
    local debugStart = debugProfiler and os.clock() or nil
    local didItWork, whatWeGot = pcall(function()
        return _ps:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    end)
    if debugProfiler then
        _addDbgTime(debugProfiler, "Players.GetUserThumbnailAsync", os.clock() - debugStart, tostring(userId))
    end
    if didItWork then
        return whatWeGot
    end
    return _defAvatar
end

local function loadPlayerAvatarAsync(imageLabel, userId)
    if not imageLabel then
        return
    end

    task.spawn(function()
        local avatarImage = getPlayerAvatarCuzTheyreBeautiful(userId)
        if imageLabel and imageLabel.Parent and type(avatarImage) == "string" and avatarImage ~= "" then
            imageLabel.Image = avatarImage
        end
    end)
end

local function resolveAvatar3DUserIdFromRobloxEndpoint(defaultUserId)
    local fallbackUserId = tonumber(defaultUserId) or 1
    local endpoint = "https://thumbnails.roblox.com/v1/users/avatar-3d?userId=" .. tostring(fallbackUserId)

    local debugProfiler = _dbgProf
    local debugStart = debugProfiler and os.clock() or nil
    local okBody, rawBody = pcall(function()
        return game:HttpGet(endpoint)
    end)
    if debugProfiler then
        _addDbgTime(debugProfiler, "HttpGet.avatar-3d", os.clock() - debugStart, tostring(fallbackUserId))
    end
    if not okBody or type(rawBody) ~= "string" or rawBody == "" then
        return fallbackUserId, nil
    end

    local okDecode, payload = pcall(function()
        return _hs:JSONDecode(rawBody)
    end)
    if not okDecode or type(payload) ~= "table" then
        return fallbackUserId, nil
    end

    local resolvedUserId = tonumber(payload.targetId) or tonumber(payload.userId) or fallbackUserId
    local imageUrl = type(payload.imageUrl) == "string" and payload.imageUrl or nil
    return resolvedUserId, imageUrl
end

local function howWideIsThisText(text, textSize, font)
    local debugProfiler = _dbgProf
    local debugStart = debugProfiler and os.clock() or nil
    local textBoundsYay = _txs:GetTextSize(text, textSize, font or Enum.Font.GothamSemibold, Vector2.new(math.huge, math.huge))
    if debugProfiler then
        _addDbgTime(debugProfiler, "TextService.GetTextSize(width)", os.clock() - debugStart, tostring(text):sub(1, 80))
    end
    return textBoundsYay.X
end

local function truncateTextLikeABoss(text, maxWidth, textSize, font)
    local fullWidth = howWideIsThisText(text, textSize, font)
    if fullWidth <= maxWidth then
        return text
    end
    
    local truncated = text
    while howWideIsThisText(truncated .. "...", textSize, font) > maxWidth and #truncated > 0 do
        truncated = truncated:sub(1, -2)
    end
    return truncated .. "..."
end

local function normalizeSearchText(text)
    return string.lower(tostring(text or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeDropdownOptions(options)
    local normalized = {}
    if type(options) == "table" then
        for _, option in ipairs(options) do
            if option ~= nil then
                table.insert(normalized, option)
            end
        end
    end
    if #normalized == 0 then
        normalized[1] = "None"
    end
    return normalized
end

local function getDropdownOptionsSignature(options)
    if type(options) ~= "table" then
        return "0"
    end
    local count = #options
    if count <= 0 then
        return "0"
    end
    local signaturePieces = table.create and table.create(count + 1, "") or {}
    signaturePieces[1] = tostring(count)
    for index, option in ipairs(options) do
        signaturePieces[index + 1] = tostring(option)
    end
    return table.concat(signaturePieces, "\31")
end

local function getNumberDecimalPlaces(value)
    if type(value) ~= "number" then
        return 0
    end
    local valueString = tostring(value)
    local decimalPart = valueString:match("%.(%d+)")
    if decimalPart then
        return #decimalPart
    end
    local exponentPart = valueString:match("[eE]([%+%-]?%d+)")
    if exponentPart then
        local exponent = tonumber(exponentPart) or 0
        if exponent < 0 then
            return -exponent
        end
    end
    return 0
end

local function roundToDecimalPlaces(value, decimals)
    if decimals <= 0 then
        if value >= 0 then
            return math.floor(value + 0.5)
        end
        return math.ceil(value - 0.5)
    end
    local factor = 10 ^ decimals
    if value >= 0 then
        return math.floor(value * factor + 0.5) / factor
    end
    return math.ceil(value * factor - 0.5) / factor
end

local function resolveSliderPrecision(minValue, maxValue, increment, defaultValue)
    local precision = 0
    precision = math.max(precision, getNumberDecimalPlaces(minValue))
    precision = math.max(precision, getNumberDecimalPlaces(maxValue))
    precision = math.max(precision, getNumberDecimalPlaces(increment))
    precision = math.max(precision, getNumberDecimalPlaces(defaultValue))
    return math.clamp(precision, 0, 6)
end

local function normalizeSliderValue(value, minValue, maxValue, increment, precision)
    local numericValue = tonumber(value) or minValue
    numericValue = math.clamp(numericValue, minValue, maxValue)
    local normalizedIncrement = math.max(math.abs(tonumber(increment) or 1), 1e-6)
    local steps = math.floor(((numericValue - minValue) / normalizedIncrement) + 0.5)
    local snappedValue = minValue + (steps * normalizedIncrement)
    snappedValue = roundToDecimalPlaces(snappedValue, precision)
    return math.clamp(snappedValue, minValue, maxValue)
end

local function formatSliderValue(value, precision)
    if precision <= 0 then
        return tostring(roundToDecimalPlaces(value, 0))
    end
    local formatted = string.format("%." .. tostring(precision) .. "f", value)
    formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    return formatted
end

local function serializeConfigValue(value)
    local valueType = typeof(value)
    if valueType == "Color3" then
        return {
            __type = "Color3",
            r = value.R,
            g = value.G,
            b = value.B
        }
    end
    if valueType == "EnumItem" and value.EnumType == Enum.KeyCode then
        return {
            __type = "KeyCode",
            value = value.Name
        }
    end
    return value
end

local function deserializeConfigValue(value)
    if type(value) ~= "table" or not value.__type then
        return value
    end
    if value.__type == "Color3" and value.r and value.g and value.b then
        return Color3.new(value.r, value.g, value.b)
    end
    if value.__type == "KeyCode" and value.value then
        return Enum.KeyCode[value.value] or Enum.KeyCode.Unknown
    end
    return value
end

local function sanitizeConfigName(name)
    local cleanName = tostring(name or "default")
    cleanName = cleanName:gsub("[\\/:*?\"<>|]", "_")
    cleanName = cleanName:gsub("^%s+", ""):gsub("%s+$", "")
    if cleanName == "" then
        cleanName = "default"
    end
    return cleanName
end

local _fs = {
    readfile = type(readfile) == "function" and readfile or nil,
    writefile = type(writefile) == "function" and writefile or nil,
    isfile = type(isfile) == "function" and isfile or nil,
    isfolder = type(isfolder) == "function" and isfolder or nil,
    makefolder = type(makefolder) == "function" and makefolder or nil,
    delfile = type(delfile) == "function" and delfile or nil,
}

local function _getConfigPath()
    return "workspace_configs"
end

local function _ensureConfigDir()
    local folder = _getConfigPath()

    if _fs.isfolder and _fs.isfolder(folder) then
        return true, folder
    end

    if _fs.makefolder then
        pcall(function()
            _fs.makefolder(folder)
        end)
    end

    if _fs.isfolder and _fs.isfolder(folder) then
        return true, folder
    end

    return false, folder
end

local function _getConfigFile(configName)
    return sanitizeConfigName(configName) .. ".json"
end

local function _getWritePath(configName)
    local fileName = _getConfigFile(configName)
    local okFolder, folder = _ensureConfigDir()
    if okFolder then
        return folder .. "/" .. fileName, true
    end
    return fileName, false
end

local function _getReadPaths(configName)
    local fileName = _getConfigFile(configName)
    local folder = _getConfigPath()
    return {
        folder .. "/" .. fileName,
        folder .. "\\" .. fileName,
        fileName
    }
end

local _rtKey = "__FLOW_UI_RUNTIME"
local _sgName = "FlowUIScreen"

local _sharedEnvFallback = {}
local function _getSharedEnv()
    if type(getgenv) == "function" then
        local okEnv, sharedEnv = pcall(getgenv)
        if okEnv and type(sharedEnv) == "table" then
            return sharedEnv
        end
    end

    if type(_G) == "table" then
        return _G
    end

    return _sharedEnvFallback
end

local function _getUiRoots()
    local roots = {}
    local seenRoots = {}

    local function addRoot(root)
        if not root or seenRoots[root] then
            return
        end
        seenRoots[root] = true
        table.insert(roots, root)
    end

    if type(gethui) == "function" then
        local okHui, hui = pcall(gethui)
        if okHui and hui then
            addRoot(_safeCloneRef(hui))
        end
    end

    if _lp then
        local okPlayerGui, playerGui = pcall(function()
            return _lp:FindFirstChild("PlayerGui") or _lp:WaitForChild("PlayerGui", 5)
        end)
        if okPlayerGui and playerGui then
            _pg = playerGui
            addRoot(playerGui)
        elseif _pg then
            addRoot(_pg)
        end
    elseif _pg then
        addRoot(_pg)
    end

    return roots
end

local function _destroyOldSGs()
    local roots = _getUiRoots()

    for _, root in ipairs(roots) do
        local okChildren, children = pcall(function()
            return root:GetChildren()
        end)
        if okChildren and type(children) == "table" then
            for _, child in ipairs(children) do
                if child and child:IsA("ScreenGui") and child.Name == _sgName then
                    pcall(function()
                        child:Destroy()
                    end)
                end
            end
        end
    end
end

local function _cleanupPrev()
    local sharedEnv = _getSharedEnv()
    local previousInstance = rawget(sharedEnv, _rtKey)
    if previousInstance and type(previousInstance) == "table" and type(previousInstance.Destroy) == "function" then
        pcall(function()
            previousInstance:Destroy()
        end)
    end
    rawset(sharedEnv, _rtKey, nil)
    _destroyOldSGs()
end

function _Lib.new(config)
    _cleanupPrev()

    local self = setmetatable({}, _Lib)
    
    self.config = config or {}
    self.config.Name = self.config.Name or "o11 vision"
    self.config.AccentColor = self.config.AccentColor or Color3.fromRGB(0, 116, 215)
    self.config.BackgroundColor = self.config.BackgroundColor or _palette.Shell
    self.config.SecondaryColor = self.config.SecondaryColor or _palette.SurfaceAlt
    self.config.TextColor = self.config.TextColor or Color3.fromRGB(255, 255, 255)
    self.config.SubTextColor = self.config.SubTextColor or _palette.TextMuted
    self.config.Motion = _normMotion(self.config.Motion)
    self.config.Density = _normDensity(self.config.Density)
    self.config.WatermarkStyle = _normWmStyle(self.config.WatermarkStyle)
    self.config.SidebarStyle = _normSbStyle(self.config.SidebarStyle)
    self.config.ControlStyle = _normCtrlStyle(self.config.ControlStyle)
    self.config.GroupTabStyle = _normGrpTabStyle(self.config.GroupTabStyle)
    self.config.CleanCards = self.config.CleanCards ~= false
    self.config.ShowStatusStrip = self.config.ShowStatusStrip == true
    local hasExplicitKeyDurationText = self.config.KeyDurationText ~= nil and tostring(self.config.KeyDurationText) ~= ""
    self.config.KeyDurationText = _resolveKeyText(self.config)
    
    self._sections = {}
    self._tabs = {}
    self._curTab = nil
    self._notifs = {}
    self.isToggledOn = true
    self.dropdownHolderRef = nil
    self.toggleKeyCode = Enum.KeyCode.RightControl
    self.toggleButtonVisible = true
    self._hasExplicitKeyDurationText = hasExplicitKeyDurationText
    self._luarmorScriptKey = _resolveLrmKey()
    self._luarmorKeyStatus = nil
    self._luarmorKeyCheckInFlight = false
    self._keyDurationExpiresAt = not hasExplicitKeyDurationText and tonumber(self.config.KeyExpiresAt) or nil
    if not hasExplicitKeyDurationText and not self._keyDurationExpiresAt and tonumber(config and config.KeyDurationSeconds) then
        self._keyDurationExpiresAt = os.time() + tonumber(config.KeyDurationSeconds)
    end
    if not hasExplicitKeyDurationText and not self._keyDurationExpiresAt then
        local _, runtimeExpiresAt = _resolveLrmKeyText()
        self._keyDurationExpiresAt = runtimeExpiresAt
    end
    self._keyDurationUpdateAccumulator = 0
    self._destroyed = false
    self._connections = {}
    self._debugBuildEnabled = _isDbgEnabled(self.config)
    self._debugBuildProfiler = self._debugBuildEnabled and _mkDbgProf() or nil
    self._debugBuildReportScheduled = false
    if self._debugBuildEnabled then
        _dbgProf = self._debugBuildProfiler
    end
    self._trackedControls = {}
    self._lastControlRegistration = 0
    self._autoConfigName = sanitizeConfigName((self.config.Name or "session") .. "_last")
    local autoConfigSetting = self.config.AutoConfig
    if autoConfigSetting == nil then
        autoConfigSetting = self.config.AutoSaveConfig
    end
    if autoConfigSetting == nil then
        autoConfigSetting = false
    end
    self._autoConfigEnabled = autoConfigSetting == true
    self._autoConfigLoadAttempted = not self._autoConfigEnabled
    self._autoConfigAccumulator = 0
    self._autoConfigInterval = 1.2
    self._autoConfigSnapshot = nil
    self._isApplyingConfig = false
    self._configPathHints = {}
    self._smoothScrollFrames = {}
    self._scrollbarRefreshers = {}
    self._searchQuery = ""
    self._commandPaletteOpen = false
    self._commandPaletteRows = {}
    self._fpsRollingSize = 30
    self._fpsRollingWindow = table.create and table.create(self._fpsRollingSize, 0) or {}
    self._fpsRollingTotal = 0
    self._fpsRollingIndex = 1
    self._fpsRollingCount = 0
    self._latestFPSValue = 0
    self._frameWorkAccumulator = 0
    self._perfSaverLevel = 0
    self._cachedViewportSize = Vector2.new(1280, 720)
    self._cachedViewportWidth = 1280
    self._cachedViewportHeight = 720
    self._cachedViewportAreaScale = 1
    self._blurEffectRef = nil
    self._snowflakes = {}
    self._snowSpawnAccumulator = 0
    self._snowMaxFlakes = _isMobile and 28 or 55
    self._overlayMode = "None"
    self._overlayModes = {"Snow", "Rain", "Stars", "None"}
    self._backgroundFxTime = 0
    self._backgroundFxAccumulator = 0
    self._textGradientAnimationTime = 0
    self._gradientAnimationAccumulator = 0
    self._overlayUpdateAccumulator = 0
    self._watermarkUpdateAccumulator = 0
    self._watermarkLastWidth = 0
    self._refreshJobs = {}
    self._notificationTimestamps = {}
    self._lastNotificationAnyAt = 0
    self._uiVisualSettings = {
        Blur = false,
        Snow = false,
        BackgroundEffects = false,
        TextGradient = false,
        ESPSelfPreview = false,
        HideName = false
    }
    self._fontPresets = {
        {Name = "Gotham", EnumFont = Enum.Font.Gotham, Family = "rbxasset://fonts/families/GothamSSm.json", Weight = Enum.FontWeight.SemiBold},
        {Name = "Gotham Medium", EnumFont = Enum.Font.GothamMedium, Family = "rbxasset://fonts/families/GothamSSm.json", Weight = Enum.FontWeight.Medium},
        {Name = "Montserrat", EnumFont = Enum.Font.Gotham, Family = "rbxasset://fonts/families/Montserrat.json", Weight = Enum.FontWeight.SemiBold},
        {Name = "Nunito", EnumFont = Enum.Font.Gotham, Family = "rbxasset://fonts/families/Nunito.json", Weight = Enum.FontWeight.SemiBold},
        {Name = "Bodoni", EnumFont = Enum.Font.Bodoni},
        {Name = "Garamond", EnumFont = Enum.Font.Garamond},
        {Name = "Source Sans", EnumFont = Enum.Font.SourceSans, Family = "rbxasset://fonts/families/SourceSansPro.json", Weight = Enum.FontWeight.SemiBold},
        {Name = "Highway", EnumFont = Enum.Font.Highway},
        {Name = "Antique", EnumFont = Enum.Font.Antique},
        {Name = "Code", EnumFont = Enum.Font.Code}
    }
    self._fontPresetIndex = 1
    self._gradientLabels = {}
    self._gradientObjects = {}
    self._espPreviewProvider = nil
    self._espPreviewData = nil
    self._espPreviewState = nil
    self._espPreviewResolveAccumulator = 0
    self._espPreviewUpdateAccumulator = 0
    self._espPreviewWasShowing = false
    self._espPreviewPanel = nil
    self._espPreviewViewport = nil
    self._espPreviewWorldModel = nil
    self._espPreviewCamera = nil
    self._espPreviewCharacter = nil
    self._espPreviewLastCharacter = nil
    self._espPreviewPartDefaults = {}
    self._espPreviewHeadPart = nil
    self._espPreviewRootPart = nil
    self._espPreviewVisualState = nil
    self._espPreviewVisualDirty = false
    self._espPreviewProjectionCache = nil
    self._espPreviewProjectionDirty = true
    self._espPreviewHighlight = nil
    self._espPreviewHeaderTag = nil
    self._espPreviewBox = nil
    self._espPreviewBoxStroke = nil
    self._espPreviewHealthTrack = nil
    self._espPreviewHealthFill = nil
    self._espPreviewDot = nil
    self._espPreviewTracer = nil
    self._espPreviewName = nil
    self._espPreviewItem = nil
    self._espPreviewDistance = nil
    self._espPreviewWalkTrack = nil
    self._espPreviewAnimationId = nil
    self._espPreviewAvatar3DUserId = _getPlayerUserId()
    self._espPreviewAvatar3DImageUrl = nil
    self._espPreviewRotationYaw = math.rad(180)
    self._espPreviewRotationTargetYaw = math.rad(180)
    self._espPreviewStaticMode = true
    self._espPreviewAllowManualRotation = true
    self._espPreviewPivotYOffset = -2
    self._espPreviewRotateCapture = nil
    self._espPreviewIsRotating = false
    self._espPreviewRotateInput = nil
    self._espPreviewRotateLastX = 0
    
    self:CreateUI()
    rawset(_getSharedEnv(), _rtKey, self)
    self:_DebugScheduleBuildReport("startup", 3)
    self:_DebugScheduleBuildReport("startup-late", 8)
    
    return self
end

function _Lib:_TrackConnection(conn)
    if conn then
        table.insert(self._connections, conn)
        if #self._connections % 250 == 0 then
            local activeConnections = {}
            for _, item in ipairs(self._connections) do
                if item then
                    if typeof(item) == "RBXScriptConnection" then
                        if item.Connected then
                            table.insert(activeConnections, item)
                        end
                    else
                        table.insert(activeConnections, item)
                    end
                end
            end
            self._connections = activeConnections
        end
    end
    return conn
end

function _Lib:_DebugCount(key, amount)
    if self._debugBuildEnabled and self._debugBuildProfiler then
        _addDbgCnt(self._debugBuildProfiler, key, amount)
    end
end

function _Lib:_DebugBegin(label)
    return _beginDbgTimer(self, label)
end

function _Lib:_DebugEnd(token, detail)
    _endDbgTimer(token, detail)
end

function _Lib:_BuildDebugReport(reason)
    local profiler = self._debugBuildProfiler
    if not self._debugBuildEnabled or not profiler then
        return nil
    end

    local elapsed = os.clock() - profiler.StartedAt
    local lines = {
        "[Debug] " .. tostring(reason or "report") .. " after " .. _fmtDbgSec(elapsed),
        "instances=" .. tostring(profiler.TotalInstances)
            .. " sections=" .. tostring(profiler.Counters.Sections or 0)
            .. " tabs=" .. tostring(profiler.Counters.Tabs or 0)
            .. " groups=" .. tostring(profiler.Counters.Groups or 0)
            .. " controls=" .. tostring(profiler.Counters.Controls or 0)
    }

    local instanceEntries = _collectDbgTop(profiler.InstanceCounts, 8)
    if #instanceEntries > 0 then
        table.insert(lines, "top instance classes:")
        for _, entry in ipairs(instanceEntries) do
            local className = entry.Key
            local count = profiler.InstanceCounts[className] or 0
            local classTime = profiler.InstanceTimes[className] or 0
            table.insert(lines, "  " .. tostring(className) .. " count=" .. tostring(count) .. " time=" .. _fmtDbgSec(classTime))
        end
    end

    local timingEntries = _collectDbgTop(profiler.Timings, 12, "Total")
    if #timingEntries > 0 then
        table.insert(lines, "top timing buckets:")
        for _, entry in ipairs(timingEntries) do
            local timing = entry.Value
            table.insert(lines, "  " .. tostring(entry.Key)
                .. " count=" .. tostring(timing.Count or 0)
                .. " total=" .. _fmtDbgSec(timing.Total or 0)
                .. " max=" .. _fmtDbgSec(timing.Max or 0)
                .. (timing.MaxDetail and (" detail=" .. tostring(timing.MaxDetail)) or ""))
        end
    end

    if #profiler.SlowCalls > 0 then
        table.insert(lines, "slow calls:")
        for index, item in ipairs(profiler.SlowCalls) do
            if index > 12 then
                break
            end
            table.insert(lines, "  " .. tostring(item.Key)
                .. " " .. _fmtDbgSec(item.Time)
                .. (item.Detail and (" detail=" .. tostring(item.Detail)) or ""))
        end
    end

    profiler.LastReport = table.concat(lines, "\n")
    return profiler.LastReport
end

function _Lib:DumpBuildDebug(reason)
    local report = self:_BuildDebugReport(reason or "manual")
    if report then
        local sharedEnv = _getSharedEnv()
        rawset(sharedEnv, _rtKey .. "_debug", report)
        warn(report)
    end
    return report
end

function _Lib:_DebugScheduleBuildReport(reason, delaySeconds)
    if not self._debugBuildEnabled then
        return
    end
    task.delay(tonumber(delaySeconds) or 3, function()
        if self._destroyed then
            return
        end
        self:DumpBuildDebug(reason)
    end)
end

function _Lib:RegisterControl(flag, getter, setter)
    if type(flag) ~= "string" or flag == "" then return end
    if type(getter) ~= "function" or type(setter) ~= "function" then return end
    self._trackedControls[flag] = {
        get = getter,
        set = setter
    }
    self._lastControlRegistration = os.clock()
end

function _Lib:_RegisterRefreshJob(interval, isAliveFn, stepFn)
    if type(stepFn) ~= "function" then
        return nil
    end

    local job = {
        Interval = math.max(tonumber(interval) or 0.5, 0.05),
        IsAlive = isAliveFn,
        Step = stepFn,
        Accumulator = 0
    }

    table.insert(self._refreshJobs, job)
    return job
end

function _Lib:_StepRefreshJobs(dt)
    if not self._refreshJobs then
        return
    end

    local resolvedDt = tonumber(dt) or 0
    for index = #self._refreshJobs, 1, -1 do
        local job = self._refreshJobs[index]
        local keepJob = true

        if type(job) ~= "table" or type(job.Step) ~= "function" then
            keepJob = false
        elseif type(job.IsAlive) == "function" then
            local okAlive, isAlive = pcall(job.IsAlive)
            keepJob = okAlive and isAlive ~= false
        end

        if not keepJob then
            table.remove(self._refreshJobs, index)
        else
            job.Accumulator = (job.Accumulator or 0) + resolvedDt
            if job.Accumulator >= (job.Interval or 0.5) then
                job.Accumulator = 0
                local okStep, keepResult = pcall(job.Step)
                if not okStep or keepResult == false then
                    table.remove(self._refreshJobs, index)
                end
            end
        end
    end
end

function _Lib:_BuildAutoConfigSnapshot()
    local controlsSnapshot = {}
    local trackedFlags = {}

    for flag in pairs(self._trackedControls) do
        table.insert(trackedFlags, flag)
    end

    table.sort(trackedFlags)

    for _, flag in ipairs(trackedFlags) do
        local control = self._trackedControls[flag]
        if control and type(control.get) == "function" then
            local ok, value = pcall(control.get)
            if ok then
                controlsSnapshot[flag] = serializeConfigValue(value)
            end
        end
    end

    local okEncode, encoded = pcall(function()
        return _hs:JSONEncode(controlsSnapshot)
    end)

    if okEncode then
        return encoded
    end

    return nil
end

function _Lib:_TryAutoSaveConfig(forceSave)
    if self._destroyed or not self._autoConfigEnabled or self._isApplyingConfig then
        return false
    end

    if not _fs.writefile or next(self._trackedControls) == nil then
        return false
    end

    local snapshot = self:_BuildAutoConfigSnapshot()
    if not snapshot then
        return false
    end

    if not forceSave and snapshot == self._autoConfigSnapshot then
        return false
    end

    local okSave = self:SaveConfig(self._autoConfigName)
    if okSave then
        self._autoConfigSnapshot = snapshot
    end

    return okSave == true
end

function _Lib:_TryAutoLoadConfig(forceAttempt)
    if self._destroyed then
        return false
    end

    if self._autoConfigLoadAttempted and not forceAttempt then
        return false
    end

    if not _fs.readfile or next(self._trackedControls) == nil then
        return false
    end

    self._isApplyingConfig = true
    local okLoad = self:LoadConfig(self._autoConfigName)
    self._isApplyingConfig = false
    self._autoConfigLoadAttempted = true
    self._autoConfigAccumulator = 0
    self._autoConfigSnapshot = self:_BuildAutoConfigSnapshot()
    return okLoad == true
end

function _Lib:_RefreshViewportMetrics()
    local viewportSize = (self._sgRef and self._sgRef.AbsoluteSize) or Vector2.new(0, 0)
    local width = math.max(200, math.floor(viewportSize.X > 0 and viewportSize.X or 1280))
    local height = math.max(320, math.floor(viewportSize.Y > 0 and viewportSize.Y or 720))
    self._cachedViewportSize = Vector2.new(width, height)
    self._cachedViewportWidth = width
    self._cachedViewportHeight = height
    self._cachedViewportAreaScale = math.clamp(math.sqrt((width * height) / (1280 * 720)), _isMobile and 0.52 or 0.68, 1.12)
end

function _Lib:_InvalidateESPPreviewProjection(clearCache)
    self._espPreviewProjectionDirty = true
    if clearCache then
        self._espPreviewProjectionCache = nil
    end
end

function _Lib:_EnsureBlurEffect()
    if self._blurEffectRef and self._blurEffectRef.Parent then
        return self._blurEffectRef
    end
    local blurName = _sNames["BlurEffect"]
    local existingBlur = _ls:FindFirstChild(blurName)
    if existingBlur and existingBlur:IsA("BlurEffect") then
        self._blurEffectRef = existingBlur
        return existingBlur
    end
    self._blurEffectRef = _mk("BlurEffect", {
        Name = blurName,
        Size = 0,
        Enabled = true,
        Parent = _ls
    })
    return self._blurEffectRef
end

function _Lib:_SetBlurActive(active, instant)
    local blur = self:_EnsureBlurEffect()
    local shouldEnable = self._uiVisualSettings.Blur and active
    local targetSize = shouldEnable and (_isMobile and 14 or 18) or 0
    if instant then
        blur.Size = targetSize
        return
    end
    _tween(blur, {Size = targetSize}, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

function _Lib:_ClearSnowflakes()
    for i = #self._snowflakes, 1, -1 do
        local snowObj = self._snowflakes[i]
        if snowObj and snowObj.instance and snowObj.instance.Parent then
            snowObj.instance:Destroy()
        end
        self._snowflakes[i] = nil
    end
end

function _Lib:_SpawnSnowflake()
    if not self._snowFrame or not self._snowFrame.Parent then
        return
    end
    local width = self._cachedViewportWidth or 200
    local size = math.random(2, 7) * _mScale
    local startX = math.random(-18, width + 18)
    local flake = _mk("ImageLabel", {
        BackgroundTransparency = 1,
        Image = _assetUrl("3570695787"),
        ImageColor3 = Color3.fromRGB(236 + math.random(0, 19), 243 + math.random(0, 12), 255),
        ImageTransparency = math.random(22, 56) / 100,
        Size = UDim2.new(0, size, 0, size),
        Position = UDim2.new(0, startX, 0, -math.random(6, 80)),
        Rotation = math.random(0, 359),
        ZIndex = 2,
        Parent = self._snowFrame
    })
    table.insert(self._snowflakes, {
        overlayType = "Snow",
        instance = flake,
        baseX = startX,
        fallSpeed = math.random(16, 42) * _mScale,
        driftAmount = math.random(12, 42) * _mScale,
        swirlAmount = math.random(2, 10) * _mScale,
        driftSpeed = math.random(5, 15) / 10,
        twinkleSpeed = math.random(6, 15) / 10,
        baseTransparency = flake.ImageTransparency,
        phase = math.random() * math.pi * 2,
        spin = math.random(-14, 14),
        size = size,
        yOffset = flake.Position.Y.Offset
    })
end

function _Lib:_SpawnRainDrop()
    if not self._snowFrame or not self._snowFrame.Parent then
        return
    end
    local width = self._cachedViewportWidth or 200
    local depthScale = math.random(62, 150) / 100
    local length = (math.random(12, 30) * depthScale + 3) * _mScale
    local thickness = math.max(1, math.floor((0.8 + depthScale * 0.9) * _mScale + 0.5))
    local startX = math.random(-58, width + 58)
    local startY = -math.random(30, 180)
    local windSpeed = (math.random(26, 88) * depthScale) * _mScale
    local fallSpeed = (math.random(270, 560) * depthScale) * _mScale
    local angle = math.deg(math.atan(fallSpeed / windSpeed)) - 90
    local drop = _mk("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(176 + math.random(0, 26), 208 + math.random(0, 26), 255),
        BackgroundTransparency = math.random(15, 45) / 100,
        Position = UDim2.new(0, startX, 0, startY),
        Size = UDim2.new(0, thickness, 0, length),
        Rotation = angle,
        ZIndex = depthScale > 1 and 3 or 2,
        Parent = self._snowFrame
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = drop})
    table.insert(self._snowflakes, {
        overlayType = "RainDrop",
        instance = drop,
        xOffset = startX,
        yOffset = startY,
        velocityX = windSpeed,
        velocityY = fallSpeed,
        angle = angle,
        width = thickness,
        length = length,
        baseTransparency = drop.BackgroundTransparency,
        driftSpeed = math.random(11, 24) / 10,
        windJitter = math.random(6, 18) * _mScale,
        stretchPulse = math.random(16, 30) / 10,
        splashChance = 0.55 + math.random() * 0.25,
        phase = math.random() * math.pi * 2
    })
end

function _Lib:_SpawnRainSplash(xPosition, yPosition)
    if not self._snowFrame or not self._snowFrame.Parent then
        return
    end
    local startSize = math.random(2, 5) * _mScale
    local splash = _mk("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(194 + math.random(0, 20), 224 + math.random(0, 22), 255),
        BackgroundTransparency = math.random(24, 42) / 100,
        Position = UDim2.new(0, xPosition, 0, yPosition),
        Size = UDim2.new(0, startSize, 0, math.max(1 * _mScale, startSize * 0.5)),
        ZIndex = 3,
        Parent = self._snowFrame
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = splash})
    local life = math.random(8, 14) / 100
    table.insert(self._snowflakes, {
        overlayType = "RainSplash",
        instance = splash,
        baseX = xPosition,
        yOffset = yPosition,
        life = life,
        totalLife = life,
        startSize = startSize,
        startThickness = math.max(1 * _mScale, startSize * 0.5),
        endSize = math.random(10, 20) * _mScale,
        driftX = math.random(-14, 14) * _mScale,
        baseTransparency = splash.BackgroundTransparency
    })
end

function _Lib:_SpawnStarParticle()
    if not self._snowFrame or not self._snowFrame.Parent then
        return
    end
    local width = self._cachedViewportWidth or 200
    local height = self._cachedViewportHeight or 320
    local size = (math.random(10, 28) / 10) * _mScale
    local startX = math.random(0, width)
    local startY = math.random(0, height)
    local star = _mk("ImageLabel", {
        BackgroundTransparency = 1,
        Image = _assetUrl("3570695787"),
        ImageColor3 = Color3.fromRGB(224 + math.random(0, 28), 233 + math.random(0, 20), 255),
        ImageTransparency = math.random(22, 56) / 100,
        Position = UDim2.new(0, startX, 0, startY),
        Size = UDim2.new(0, size, 0, size),
        ZIndex = 3,
        Parent = self._snowFrame
    })
    table.insert(self._snowflakes, {
        overlayType = "Stars",
        instance = star,
        xOffset = startX,
        yOffset = startY,
        velocityX = (math.random(-16, 16) / 10) * _mScale,
        velocityY = (math.random(-9, 9) / 10) * _mScale,
        baseSize = size,
        driftAmount = math.random(5, 18) * _mScale,
        driftLift = math.random(4, 14) * _mScale,
        driftSpeed = math.random(3, 10) / 10,
        twinkleSpeed = math.random(7, 18) / 10,
        pulseAmount = (math.random(8, 24) / 100),
        baseTransparency = star.ImageTransparency,
        phase = math.random() * math.pi * 2
    })
end

function _Lib:_SetSnowEnabled(enabled)
    self._uiVisualSettings.Snow = enabled == true
    if self._snowFrame then
        self._snowFrame.Visible = self._uiVisualSettings.Snow and self.isToggledOn and self._overlayMode ~= "None"
    end
    if not self._uiVisualSettings.Snow or not self.isToggledOn or self._overlayMode == "None" then
        self._overlayUpdateAccumulator = 0
        self._snowSpawnAccumulator = 0
        self:_ClearSnowflakes()
    end
end

function _Lib:_SetOverlayMode(mode)
    local normalized = string.lower(tostring(mode or "snow"))
    local resolved = "Snow"
    if normalized == "rain" then
        resolved = "Rain"
    elseif normalized == "stars" or normalized == "star" then
        resolved = "Stars"
    elseif normalized == "none" or normalized == "off" then
        resolved = "None"
    end
    local changed = self._overlayMode ~= resolved
    self._overlayMode = resolved
    if self.uiOverlayModeValueLabel then
        self.uiOverlayModeValueLabel.Text = resolved
    end
    if self._snowFrame then
        self._snowFrame.Visible = self.isToggledOn and self._uiVisualSettings.Snow and resolved ~= "None"
    end
    if changed or resolved == "None" then
        self._overlayUpdateAccumulator = 0
        self._snowSpawnAccumulator = 0
        self:_ClearSnowflakes()
    end
end

function _Lib:_SetBackgroundEffectsEnabled(enabled)
    self._uiVisualSettings.BackgroundEffects = enabled == true
    if not self._uiVisualSettings.BackgroundEffects then
        self._backgroundFxAccumulator = 0
    end
    if self.mainBackgroundEffectsFrame then
        self.mainBackgroundEffectsFrame.Visible = self._uiVisualSettings.BackgroundEffects
    end
end

function _Lib:_SetNameHidden(enabled)
    self._uiVisualSettings.HideName = enabled == true
    local hideName = self._uiVisualSettings.HideName == true

    if self.userNameLabel then
        self.userNameLabel.Visible = not hideName
        if not hideName then
            self.userNameLabel.Text = "@" .. _getPlayerName()
        end
    end

    if self.profileUserNameLabel then
        self.profileUserNameLabel.Visible = not hideName
        if not hideName then
            self.profileUserNameLabel.Text = "@" .. _getPlayerName()
        end
    end

    if self._espPreviewHeaderTag then
        self._espPreviewHeaderTag.Visible = not hideName
        if not hideName then
            self._espPreviewHeaderTag.Text = "@" .. _getPlayerName()
        end
    end

    if self._espPreviewPanel then
        self:_UpdateESPPreview(0)
    end
end

function _Lib:_SetTextGradientEnabled(enabled)
    self._uiVisualSettings.TextGradient = enabled == true
    if not self._uiVisualSettings.TextGradient then
        self._gradientAnimationAccumulator = 0
    end
    local accent = self.config.AccentColor
    local gradientSweepSpeed = 0.9
    local animationTime = tonumber(self._textGradientAnimationTime) or 0
    local sweepX = ((animationTime * gradientSweepSpeed) % 2) - 1
    for i = #self._gradientObjects, 1, -1 do
        self._gradientObjects[i] = nil
    end
    for _, label in ipairs(self._gradientLabels) do
        if label and label.Parent then
            local gradientObj = label:FindFirstChild(_sNames["TextGradient"])
            if self._uiVisualSettings.TextGradient then
                if not gradientObj then
                    gradientObj = _mk("UIGradient", {
                        Name = _sNames["TextGradient"],
                        Rotation = 0,
                        Parent = label
                    })
                end
                gradientObj.Rotation = 0
                gradientObj.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, accent:Lerp(Color3.new(1, 1, 1), 0.2)),
                    ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, accent:Lerp(Color3.new(1, 1, 1), 0.35))
                })
                gradientObj.Offset = Vector2.new(sweepX, 0)
                table.insert(self._gradientObjects, gradientObj)
            elseif gradientObj then
                gradientObj:Destroy()
            end
        end
    end
end

function _Lib:_AnimateTextGradients(dt)
    if not self._uiVisualSettings.TextGradient then
        return
    end

    self._gradientAnimationAccumulator = (tonumber(self._gradientAnimationAccumulator) or 0) + (dt or 0)
    local minGradientStep = _isMobile and (1 / 20) or (1 / 30)
    if self._gradientAnimationAccumulator < minGradientStep then
        return
    end
    local resolvedDt = self._gradientAnimationAccumulator
    self._gradientAnimationAccumulator = 0

    local gradientSweepSpeed = 0.9
    self._textGradientAnimationTime = (tonumber(self._textGradientAnimationTime) or 0) + resolvedDt
    local sweepX = ((self._textGradientAnimationTime * gradientSweepSpeed) % 2) - 1
    local animatedOffset = Vector2.new(sweepX, 0)

    for i = #self._gradientObjects, 1, -1 do
        local gradientObj = self._gradientObjects[i]
        if gradientObj and gradientObj.Parent then
            gradientObj.Rotation = 0
            gradientObj.Offset = animatedOffset
        else
            table.remove(self._gradientObjects, i)
        end
    end
end

function _Lib:ApplyFontPreset(index)
    if #self._fontPresets == 0 then
        return
    end
    local normalizedIndex = tonumber(index) or (self._fontPresetIndex + 1)
    if normalizedIndex > #self._fontPresets then
        normalizedIndex = 1
    elseif normalizedIndex < 1 then
        normalizedIndex = #self._fontPresets
    end
    self._fontPresetIndex = normalizedIndex
    local preset = self._fontPresets[self._fontPresetIndex]
    local targetFontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
    if preset.Family then
        local okFont, generatedFont = pcall(function()
            return Font.new(preset.Family, preset.Weight or Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        end)
        if okFont then
            targetFontFace = generatedFont
        end
    elseif preset.EnumFont then
        pcall(function()
            targetFontFace = Font.fromEnum(preset.EnumFont)
        end)
    end
    if self._sgRef and self._sgRef.Parent then
        for _, obj in ipairs(self._sgRef:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                if preset.EnumFont then
                    pcall(function()
                        obj.Font = preset.EnumFont
                    end)
                end
                _applyFont(obj, targetFontFace, preset.EnumFont or _defFont)
            end
        end
    end
    if self.uiSettingsFontValueLabel then
        self.uiSettingsFontValueLabel.Text = preset.Name
    end
end

function _Lib:_RefreshAccentCore()
    local accent = self.config.AccentColor
    if self.mobileToggleIcon then
        self.mobileToggleIcon.ImageColor3 = accent
    end
    if self.mainBackgroundAccentGlow then
        self.mainBackgroundAccentGlow.ImageColor3 = accent
    end
    if self.uiAccentPreviewFrame then
        self.uiAccentPreviewFrame.BackgroundColor3 = accent
    end
    if self.uiSettingsButtonStroke then
        self.uiSettingsButtonStroke.Color = self.uiSettingsOpen and accent:Lerp(_palette.Surface, 0.42) or _palette.Stroke
    end
    if self._curTab and self._curTab.buttonFrame then
        self._curTab.buttonFrame.BackgroundColor3 = accent
    end
    if self._scrollbarRefreshers then
        for index = #self._scrollbarRefreshers, 1, -1 do
            local refresher = self._scrollbarRefreshers[index]
            local okRefresh, keepRefresher = pcall(refresher)
            if not okRefresh or keepRefresher == false then
                table.remove(self._scrollbarRefreshers, index)
            end
        end
    end
    self:_SetTextGradientEnabled(self._uiVisualSettings.TextGradient)
    self:_RefreshMobileToggleVisuals(true)
end

function _Lib:_RefreshMobileToggleVisuals(instant)
    if not self.mobileToggleFrame then
        return
    end

    local accent = self.config.AccentColor or _palette.Text
    local isOpen = self.isToggledOn == true
    local isHovered = self.mobileToggleHovered == true
    local frameColor = isHovered and _palette.SurfaceSoft or _palette.Surface
    local strokeColor = isHovered and _palette.StrokeStrong or _palette.Stroke
    local iconColor = isOpen and accent or _palette.TextMuted
    local glowTransparency = 1

    if self.mobileToggleStateLabel then
        self.mobileToggleStateLabel.Text = ""
    end

    if instant then
        self.mobileToggleFrame.BackgroundColor3 = frameColor
        if self.mobileToggleStroke then
            self.mobileToggleStroke.Color = strokeColor
        end
        if self.mobileToggleStateLabel then
            self.mobileToggleStateLabel.TextColor3 = _palette.TextMuted
        end
        if self.mobileToggleStateDot then
            self.mobileToggleStateDot.Visible = false
        end
        if self.mobileToggleIcon then
            self.mobileToggleIcon.ImageColor3 = iconColor
        end
        if self.mobileToggleGlow then
            self.mobileToggleGlow.ImageColor3 = accent
            self.mobileToggleGlow.ImageTransparency = glowTransparency
        end
        return
    end

    _tween(self.mobileToggleFrame, {BackgroundColor3 = frameColor}, 0.18)
    if self.mobileToggleStroke then
        _tween(self.mobileToggleStroke, {Color = strokeColor}, 0.18)
    end
    if self.mobileToggleStateLabel then
        _tween(self.mobileToggleStateLabel, {TextColor3 = _palette.TextMuted}, 0.18)
    end
    if self.mobileToggleStateDot then
        self.mobileToggleStateDot.Visible = false
    end
    if self.mobileToggleIcon then
        _tween(self.mobileToggleIcon, {ImageColor3 = iconColor}, 0.18)
    end
    if self.mobileToggleGlow then
        _tween(self.mobileToggleGlow, {
            ImageColor3 = accent,
            ImageTransparency = glowTransparency
        }, 0.18)
    end
end

function _Lib:_ApplyOpenCloseVisuals(instant)
    self:_SetBlurActive(self.isToggledOn, instant)
    if self._dimFrame then
        local targetTransparency = (self.isToggledOn and self._uiVisualSettings.Blur) and 0.55 or 1
        if instant then
            self._dimFrame.BackgroundTransparency = targetTransparency
        else
            _tween(self._dimFrame, {
                BackgroundTransparency = targetTransparency
            }, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
    end
    if self._snowFrame then
        self._snowFrame.Visible = self.isToggledOn and self._uiVisualSettings.Snow and self._overlayMode ~= "None"
    end
    if not self.isToggledOn or not self._uiVisualSettings.Snow or self._overlayMode == "None" then
        self._overlayUpdateAccumulator = 0
        self._snowSpawnAccumulator = 0
        self:_ClearSnowflakes()
    end
    self:_RefreshMobileToggleVisuals(instant)
    self:_UpdateESPPreview(0)
end

local function flowPreviewPullValue(sourceTable, keys)
    if type(sourceTable) ~= "table" then
        return nil
    end
    for _, key in ipairs(keys) do
        local value = sourceTable[key]
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function flowPreviewToBool(value)
    if type(value) == "boolean" then
        return value
    end
    if type(value) == "number" then
        return value ~= 0
    end
    if type(value) == "string" then
        local normalized = string.lower(value)
        if normalized == "true" or normalized == "on" or normalized == "enabled" or normalized == "yes" or normalized == "1" then
            return true
        end
        if normalized == "false" or normalized == "off" or normalized == "disabled" or normalized == "no" or normalized == "0" then
            return false
        end
    end
    return nil
end

local function flowPreviewToColor3(value)
    if typeof(value) == "Color3" then
        return value
    end
    if type(value) ~= "table" then
        return nil
    end
    local r = value.r or value.R or value[1]
    local g = value.g or value.G or value[2]
    local b = value.b or value.B or value[3]
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end
    if r > 1 or g > 1 or b > 1 then
        r, g, b = r / 255, g / 255, b / 255
    end
    return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
end

local flowPreviewCoreBodyParts = {
    Head = true,
    UpperTorso = true,
    LowerTorso = true,
    Torso = true,
    LeftUpperArm = true,
    LeftLowerArm = true,
    LeftHand = true,
    RightUpperArm = true,
    RightLowerArm = true,
    RightHand = true,
    LeftUpperLeg = true,
    LeftLowerLeg = true,
    LeftFoot = true,
    RightUpperLeg = true,
    RightLowerLeg = true,
    RightFoot = true,
    ["Left Arm"] = true,
    ["Right Arm"] = true,
    ["Left Leg"] = true,
    ["Right Leg"] = true
}

local flowPreviewBoundingCornerSigns = {
    Vector3.new(-1, -1, -1),
    Vector3.new(-1, -1, 1),
    Vector3.new(-1, 1, -1),
    Vector3.new(-1, 1, 1),
    Vector3.new(1, -1, -1),
    Vector3.new(1, -1, 1),
    Vector3.new(1, 1, -1),
    Vector3.new(1, 1, 1)
}

local function getModelBoundingBoxSafe(model)
    if not model or not model.Parent then
        return nil, nil
    end
    local okBounds, boundsCF, boundsSize = pcall(function()
        return model:GetBoundingBox()
    end)
    if okBounds and typeof(boundsCF) == "CFrame" and typeof(boundsSize) == "Vector3" and boundsSize.Magnitude > 0 then
        return boundsCF, boundsSize
    end
    return nil, nil
end

local function getESPPreviewProjectedPartBounds(model, camera)
    if not model or not model.Parent or not camera then
        return false
    end

    local hasProjectedPart = false
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge

    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" and obj.Transparency < 0.985 and obj.Size.Magnitude > 0.05 then
            local halfSize = obj.Size * 0.5
            for _, cornerSign in ipairs(flowPreviewBoundingCornerSigns) do
                local worldPoint = obj.CFrame:PointToWorldSpace(Vector3.new(
                    halfSize.X * cornerSign.X,
                    halfSize.Y * cornerSign.Y,
                    halfSize.Z * cornerSign.Z
                ))
                local screenPoint = camera:WorldToViewportPoint(worldPoint)
                if screenPoint.Z > 0 then
                    hasProjectedPart = true
                    minX = math.min(minX, screenPoint.X)
                    minY = math.min(minY, screenPoint.Y)
                    maxX = math.max(maxX, screenPoint.X)
                    maxY = math.max(maxY, screenPoint.Y)
                end
            end
        end
    end

    return hasProjectedPart, minX, minY, maxX, maxY
end

function _Lib:_CleanupESPPreviewWorldModel(keepModel)
    local worldModel = self._espPreviewWorldModel
    if not worldModel or not worldModel.Parent then
        return
    end
    for _, child in ipairs(worldModel:GetChildren()) do
        if child:IsA("Model") and child ~= keepModel then
            child:Destroy()
        end
    end
end

function _Lib:SetESPPreviewProvider(providerFn)
    if providerFn ~= nil and type(providerFn) ~= "function" then
        return false, "ESP preview provider must be a function or nil."
    end
    self._espPreviewProvider = providerFn
    self._espPreviewResolveAccumulator = 0.2
    return true
end

function _Lib:SetESPPreviewData(previewData)
    if previewData ~= nil and type(previewData) ~= "table" then
        return false, "ESP preview data must be a table or nil."
    end
    self._espPreviewData = previewData
    self._espPreviewResolveAccumulator = 0.2
    return true
end

function _Lib:SetESPPreviewEnabled(enabled)
    self._uiVisualSettings.ESPSelfPreview = enabled == true
    if not self._uiVisualSettings.ESPSelfPreview then
        self._espPreviewWasShowing = false
        self._espPreviewUpdateAccumulator = 0
        self:_DestroyESPPreviewCharacter()
    else
        self:_InvalidateESPPreviewProjection(true)
    end
    self:_UpdateESPPreview(0)
end

function _Lib:_ResolveESPPreviewWalkAnimationId(sourceCharacter)
    if not sourceCharacter then
        return nil
    end
    local animateScript = sourceCharacter:FindFirstChild("Animate")
    if animateScript then
        local preferredFolders = {"walk", "run"}
        for _, folderName in ipairs(preferredFolders) do
            local folder = animateScript:FindFirstChild(folderName)
            if folder then
                local directAnimation = folder:FindFirstChildWhichIsA("Animation")
                if directAnimation and type(directAnimation.AnimationId) == "string" and directAnimation.AnimationId ~= "" then
                    return directAnimation.AnimationId
                end
                for _, child in ipairs(folder:GetDescendants()) do
                    if child:IsA("Animation") and type(child.AnimationId) == "string" and child.AnimationId ~= "" then
                        return child.AnimationId
                    end
                end
            end
        end
        for _, child in ipairs(animateScript:GetDescendants()) do
            if child:IsA("Animation") then
                local childName = string.lower(child.Name or "")
                if (string.find(childName, "walk", 1, true) or string.find(childName, "run", 1, true))
                    and type(child.AnimationId) == "string"
                    and child.AnimationId ~= "" then
                    return child.AnimationId
                end
            end
        end
    end
    return nil
end

function _Lib:_StartESPPreviewWalkAnimation(sourceCharacter)
    if self._espPreviewStaticMode then
        if self._espPreviewWalkTrack then
            pcall(function()
                self._espPreviewWalkTrack:Stop(0.1)
            end)
            pcall(function()
                self._espPreviewWalkTrack:Destroy()
            end)
            self._espPreviewWalkTrack = nil
        end
        self._espPreviewAnimationId = nil
        return
    end
    if not self._espPreviewCharacter or not self._espPreviewCharacter.Parent then
        return
    end
    if self._espPreviewWalkTrack and self._espPreviewWalkTrack.IsPlaying and self._espPreviewAnimationId then
        pcall(function()
            self._espPreviewWalkTrack:AdjustSpeed(0.95)
        end)
        return
    end
    local previewHumanoid = self._espPreviewCharacter:FindFirstChildOfClass("Humanoid")
    if not previewHumanoid then
        return
    end
    local resolvedId = self:_ResolveESPPreviewWalkAnimationId(sourceCharacter)
    if not resolvedId then
        return
    end
    if self._espPreviewWalkTrack and self._espPreviewAnimationId ~= resolvedId then
        pcall(function()
            self._espPreviewWalkTrack:Stop(0.1)
        end)
        pcall(function()
            self._espPreviewWalkTrack:Destroy()
        end)
        self._espPreviewWalkTrack = nil
    end

    local animator = previewHumanoid:FindFirstChildOfClass("Animator")
    if not animator then
        local okAnimator, newAnimator = pcall(Instance.new, "Animator")
        if not okAnimator or not newAnimator then
            return
        end
        animator = newAnimator
        pcall(function()
            animator.Parent = previewHumanoid
        end)
    end
    if not self._espPreviewWalkTrack then
        local okAnimation, walkAnimation = pcall(Instance.new, "Animation")
        if not okAnimation or not walkAnimation then
            return
        end
        pcall(function()
            walkAnimation.AnimationId = resolvedId
        end)
        local okTrack, track = pcall(function()
            return animator:LoadAnimation(walkAnimation)
        end)
        pcall(function()
            walkAnimation:Destroy()
        end)
        if not okTrack or not track then
            return
        end
        track.Looped = true
        self._espPreviewWalkTrack = track
        self._espPreviewAnimationId = resolvedId
    end
    if self._espPreviewWalkTrack and not self._espPreviewWalkTrack.IsPlaying then
        pcall(function()
            self._espPreviewWalkTrack:Play(0.15, 1, 1)
        end)
    end
    if self._espPreviewWalkTrack then
        pcall(function()
            self._espPreviewWalkTrack:AdjustSpeed(0.95)
        end)
    end
end

function _Lib:_CreateESPPreviewFallbackCharacter()
    local fallbackModel = nil
    local created = false
    local previewUserId, previewImageUrl = resolveAvatar3DUserIdFromRobloxEndpoint(_getPlayerUserId())
    self._espPreviewAvatar3DUserId = previewUserId
    self._espPreviewAvatar3DImageUrl = previewImageUrl

    local createDebugToken = self:_DebugBegin("ESP.CreateHumanoidModelFromUserId")
    local okCreate = pcall(function()
        fallbackModel = _ps:CreateHumanoidModelFromUserId(previewUserId)
    end)
    self:_DebugEnd(createDebugToken, tostring(previewUserId))
    if not okCreate or not fallbackModel then
        local descriptionDebugToken = self:_DebugBegin("ESP.GetHumanoidDescriptionFromUserId")
        local okDescription, humanoidDescription = pcall(function()
            return _ps:GetHumanoidDescriptionFromUserId(previewUserId)
        end)
        self:_DebugEnd(descriptionDebugToken, tostring(previewUserId))
        if okDescription and humanoidDescription then
            local fromDescriptionDebugToken = self:_DebugBegin("ESP.CreateHumanoidModelFromDescription")
            pcall(function()
                fallbackModel = _ps:CreateHumanoidModelFromDescription(humanoidDescription, Enum.HumanoidRigType.R15)
                created = true
            end)
            self:_DebugEnd(fromDescriptionDebugToken, tostring(previewUserId))
        end
    end
    if fallbackModel then
        fallbackModel.Name = _sNames["ESPPreviewAvatar"]
        if created and not fallbackModel:FindFirstChildOfClass("Humanoid") then
            fallbackModel:Destroy()
            return nil
        end
    end
    return fallbackModel
end

function _Lib:_DestroyESPPreviewCharacter()
    if self._espPreviewWalkTrack then
        pcall(function()
            self._espPreviewWalkTrack:Stop(0.1)
        end)
        pcall(function()
            self._espPreviewWalkTrack:Destroy()
        end)
    end
    self._espPreviewWalkTrack = nil
    self._espPreviewAnimationId = nil
    if self._espPreviewHighlight then
        self._espPreviewHighlight.Adornee = nil
        self._espPreviewHighlight.Enabled = false
    end
    self._espPreviewPartDefaults = {}
    self._espPreviewHeadPart = nil
    self._espPreviewRootPart = nil
    self._espPreviewVisualState = nil
    self._espPreviewVisualDirty = false
    self._espPreviewProjectionCache = nil
    self._espPreviewProjectionDirty = true
    if self._espPreviewCharacter and self._espPreviewCharacter.Parent then
        self._espPreviewCharacter:Destroy()
    end
    self:_CleanupESPPreviewWorldModel(nil)
    self._espPreviewCharacter = nil
    self._espPreviewLastCharacter = nil
    self._espPreviewPivotYOffset = -2
end

function _Lib:_EnsureESPPreviewCharacter()
    if not self._espPreviewWorldModel then
        return
    end
    local liveCharacter = _getPlayerCharacter()
    if self._espPreviewCharacter and self._espPreviewCharacter.Parent then
        self:_CleanupESPPreviewWorldModel(self._espPreviewCharacter)
        if liveCharacter and self._espPreviewLastCharacter == liveCharacter then
            return
        end
        if not liveCharacter and self._espPreviewLastCharacter == false then
            return
        end
    end
    self:_DestroyESPPreviewCharacter()

    local function cloneFromLiveCharacter()
        if not liveCharacter then
            return nil
        end
        local previousArchivable = liveCharacter.Archivable
        local cloneCharacter = nil
        local clonedOk = pcall(function()
            liveCharacter.Archivable = true
            cloneCharacter = liveCharacter:Clone()
        end)
        pcall(function()
            liveCharacter.Archivable = previousArchivable
        end)
        if not clonedOk then
            return nil
        end
        return cloneCharacter
    end

    local function preparePreviewCharacter(model)
        if not model then
            return false
        end
        self._espPreviewPartDefaults = {}
        local rootPart = model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChild("Torso")
        local corePartCount = 0
        local visibleCorePartCount = 0
        local visiblePartCount = 0
        for _, obj in ipairs(model:GetDescendants()) do
            if obj:IsA("Script") or obj:IsA("LocalScript") then
                obj:Destroy()
            elseif obj:IsA("BasePart") then
                local isRootPart = obj.Name == "HumanoidRootPart"
                local isCoreBodyPart = flowPreviewCoreBodyParts[obj.Name] == true
                local sanitizedTransparency = math.clamp(tonumber(obj.Transparency) or 0, 0, 1)
                if isRootPart then
                    sanitizedTransparency = 1
                elseif isCoreBodyPart and sanitizedTransparency >= 0.98 then
                    sanitizedTransparency = 0
                end
                self._espPreviewPartDefaults[obj] = {
                    Color = obj.Color,
                    Material = obj.Material,
                    Transparency = sanitizedTransparency
                }
                obj.Transparency = sanitizedTransparency
                pcall(function()
                    obj.LocalTransparencyModifier = 0
                end)
                if isRootPart then
                    pcall(function()
                        obj.LocalTransparencyModifier = 1
                    end)
                end
                obj.CanCollide = false
                pcall(function()
                    obj.CanQuery = false
                end)
                pcall(function()
                    obj.CanTouch = false
                end)
                obj.Massless = true
                obj.CastShadow = false
                if rootPart == nil then
                    rootPart = obj
                end
                obj.Anchored = true

                if sanitizedTransparency < 0.985 and obj.Size.Magnitude > 0.05 then
                    visiblePartCount = visiblePartCount + 1
                end
                if isCoreBodyPart then
                    corePartCount = corePartCount + 1
                    if sanitizedTransparency < 0.985 then
                        visibleCorePartCount = visibleCorePartCount + 1
                    end
                end
            end
        end

        local headPart = model:FindFirstChild("Head")
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChild("Torso")
            or rootPart

        if corePartCount > 0 and visibleCorePartCount < math.min(4, corePartCount) then
            for part, originalData in pairs(self._espPreviewPartDefaults) do
                if part and part.Parent and originalData and flowPreviewCoreBodyParts[part.Name] then
                    originalData.Transparency = 0
                    part.Transparency = 0
                end
            end
            visibleCorePartCount = math.max(visibleCorePartCount, math.min(4, corePartCount))
        end

        if visiblePartCount < 6 then
            for _, obj in ipairs(model:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Transparency >= 0.98 and obj.Name ~= "HumanoidRootPart" then
                    local originalData = self._espPreviewPartDefaults[obj]
                    if originalData then
                        originalData.Transparency = 0
                    end
                    obj.Transparency = 0
                end
            end
            visiblePartCount = 6
        end

        self._espPreviewHeadPart = headPart
        self._espPreviewRootPart = rootPart or headPart
        self._espPreviewVisualDirty = true
        self:_InvalidateESPPreviewProjection(true)
        if rootPart then
            pcall(function()
                model.PrimaryPart = rootPart
            end)
        end

        if corePartCount > 0 and corePartCount < 3 then
            return false
        end
        if corePartCount >= 3 and visibleCorePartCount < 3 then
            return false
        end
        return visiblePartCount >= 6
    end

    local previewCharacter = cloneFromLiveCharacter()
    local hasReliableAvatar = preparePreviewCharacter(previewCharacter)
    if not hasReliableAvatar and previewCharacter and previewCharacter.Parent == nil then
        previewCharacter:Destroy()
        previewCharacter = nil
    end

    if not previewCharacter then
        previewCharacter = self:_CreateESPPreviewFallbackCharacter()
        local hasReliableFallback = preparePreviewCharacter(previewCharacter)
        if not hasReliableFallback and previewCharacter and previewCharacter.Parent == nil then
            previewCharacter:Destroy()
            previewCharacter = nil
        end
    end
    if not previewCharacter then
        return
    end

    self:_CleanupESPPreviewWorldModel(nil)
    previewCharacter.Parent = self._espPreviewWorldModel
    local previewHumanoid = previewCharacter:FindFirstChildOfClass("Humanoid")
    if previewHumanoid then
        previewHumanoid.AutoRotate = false
        previewHumanoid.PlatformStand = false
        pcall(function()
            previewHumanoid.BreakJointsOnDeath = false
        end)
    end
    local previewExtents = Vector3.new(4, 6, 3)
    local okPreviewExtents, calculatedPreviewExtents = pcall(function()
        return previewCharacter:GetExtentsSize()
    end)
    if okPreviewExtents and calculatedPreviewExtents then
        previewExtents = calculatedPreviewExtents
    end
    local pivotYOffset = self._espPreviewStaticMode and 0 or -math.clamp(previewExtents.Y * 0.43, 1.2, 3.2)
    self._espPreviewPivotYOffset = pivotYOffset
    local allowPreviewRotate = self._espPreviewAllowManualRotation == true
    local initialYaw = (self._espPreviewStaticMode and not allowPreviewRotate) and math.rad(180) or (tonumber(self._espPreviewRotationYaw) or tonumber(self._espPreviewRotationTargetYaw) or math.rad(180))
    self._espPreviewRotationYaw = initialYaw
    self._espPreviewRotationTargetYaw = initialYaw
    pcall(function()
        previewCharacter:PivotTo(CFrame.new(0, pivotYOffset, 0) * CFrame.Angles(0, initialYaw, 0))
    end)
    self._espPreviewCharacter = previewCharacter
    self._espPreviewLastCharacter = liveCharacter or false
    if self._espPreviewHighlight then
        self._espPreviewHighlight.Adornee = previewCharacter
    end

    if self._espPreviewCamera then
        if self._espPreviewStaticMode then
            self._espPreviewCamera.FieldOfView = 35
            local boundsCF, boundsSize = getModelBoundingBoxSafe(previewCharacter)
            if boundsCF and boundsSize then
                local boundsCenter = boundsCF.Position
                local viewportSize = self._espPreviewViewport and self._espPreviewViewport.AbsoluteSize or Vector2.new(1, 1)
                local aspectRatio = math.max(0.5, viewportSize.X / math.max(1, viewportSize.Y))
                local verticalHalfFov = math.rad(self._espPreviewCamera.FieldOfView) * 0.5
                local horizontalHalfFov = math.atan(math.tan(verticalHalfFov) * aspectRatio)
                local fitDepthY = (boundsSize.Y * 0.5) / math.max(0.001, math.tan(verticalHalfFov))
                local fitDepthX = (boundsSize.X * 0.5) / math.max(0.001, math.tan(horizontalHalfFov))
                local depth = math.max(fitDepthX, fitDepthY) + boundsSize.Z * 1.18 + 2.45
                depth = math.clamp(depth, 9.4, 23)
                local focus = boundsCenter + Vector3.new(0, math.clamp(boundsSize.Y * 0.02, -0.15, 0.22), 0)
                self._espPreviewCamera.CFrame = CFrame.new(focus + Vector3.new(0, math.clamp(boundsSize.Y * 0.01, -0.08, 0.16), depth), focus)
            else
                local fallbackFocus = Vector3.new(0, 0.45, 0)
                self._espPreviewCamera.CFrame = CFrame.new(Vector3.new(0, fallbackFocus.Y, 9.2), fallbackFocus)
            end
        else
            local focus = Vector3.new(0, math.clamp(previewExtents.Y * 0.36, 1.2, 2.45), 0)
            local depth = math.clamp(math.max(6.8, previewExtents.Y * 1.05 + previewExtents.X * 0.65), 6.8, 18)
            self._espPreviewCamera.FieldOfView = 32
            self._espPreviewCamera.CFrame = CFrame.new(Vector3.new(0, focus.Y, depth), focus)
        end
    end
    if not self._espPreviewStaticMode then
        self:_StartESPPreviewWalkAnimation(liveCharacter)
    end
end

function _Lib:_CreateESPPreviewPanel()
    if self._espPreviewPanel and self._espPreviewPanel.Parent then
        return
    end
    if not self._sgRef or not self._sgRef.Parent then
        return
    end

    local panelWidth = 226 * _mScale
    local panelHeight = 296 * _mScale
    local defaultPanelPosition = UDim2.new(0, 14 * _mScale, 0, 66 * _mScale)
    if self.mainFrameYay and self.mainFrameYay.Parent then
        local mainPos = self.mainFrameYay.Position
        defaultPanelPosition = UDim2.new(
            mainPos.X.Scale,
            mainPos.X.Offset - panelWidth - 12 * _mScale,
            mainPos.Y.Scale,
            mainPos.Y.Offset + 42 * _mScale
        )
    end
    local panel = _mk("Frame", {
        Name = _sNames["ESPPreviewPanel"],
        BackgroundColor3 = Color3.fromRGB(14, 14, 16),
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        Position = defaultPanelPosition,
        Size = UDim2.new(0, panelWidth, 0, panelHeight),
        Visible = false,
        ZIndex = 30,
        Parent = self._sgRef
    })
    _mkCorner(panel, _cornerTk.Panel)
    _mk("UIStroke", {Color = Color3.fromRGB(40, 40, 44), Thickness = 1.1, Parent = panel})
    _mk("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 24)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 14))
        }),
        Rotation = 90,
        Parent = panel
    })
    local panelDragHandle = _mk("TextButton", {
        Name = _sNames["PreviewDragHandle"],
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 24 * _mScale),
        Active = true,
        ZIndex = 36,
        Parent = panel
    })

    _mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10 * _mScale, 0, 8 * _mScale),
        Size = UDim2.new(0, 110 * _mScale, 0, 16 * _mScale),
        Text = "ESP Preview",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
        TextSize = 13 * _mScale,
        ZIndex = 31,
        Parent = panel
    })

    self._espPreviewHeaderTag = _mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.42, 0, 0, 8 * _mScale),
        Size = UDim2.new(0.58, -8 * _mScale, 0, 16 * _mScale),
        Text = "@" .. _getPlayerName(),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Color3.fromRGB(156, 156, 164),
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
        TextSize = 12 * _mScale,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 31,
        Parent = panel
    })

    local card = _mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(11, 11, 13),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 8 * _mScale, 0, 28 * _mScale),
        Size = UDim2.new(1, -16 * _mScale, 1, -34 * _mScale),
        ZIndex = 30,
        Parent = panel
    })
    _mkCorner(card, _cornerTk.Card)
    _mk("UIStroke", {Color = Color3.fromRGB(33, 33, 37), Parent = card})

    local viewport = _mk("ViewportFrame", {
        BackgroundColor3 = Color3.fromRGB(15, 15, 18),
        BackgroundTransparency = 0.08,
        Position = UDim2.new(0, 6 * _mScale, 0, 6 * _mScale),
        Size = UDim2.new(1, -12 * _mScale, 1, -44 * _mScale),
        Active = true,
        LightColor = Color3.new(1, 1, 1),
        LightDirection = Vector3.new(-0.34, -1, -0.22),
        Ambient = Color3.fromRGB(122, 122, 130),
        ZIndex = 31,
        Parent = card
    })
    _mkCorner(viewport, _cornerTk.Card)
    local worldModel = _mk("WorldModel", {Parent = viewport})
    local camera = _mk("Camera", {
        CFrame = CFrame.new(Vector3.new(0, 1.4, 7.2), Vector3.new(0, 1.2, 0)),
        Parent = viewport
    })
    viewport.CurrentCamera = camera

    local rotateCapture = _mk("TextButton", {
        Name = _sNames["PreviewRotateCapture"],
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        Active = self._espPreviewAllowManualRotation == true,
        Selectable = false,
        ZIndex = 35,
        Parent = viewport
    })

    self._espPreviewBox = _mk("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.18, 0, 0.07, 0),
        Size = UDim2.new(0.64, 0, 0.84, 0),
        Visible = false,
        ZIndex = 33,
        Parent = viewport
    })
    self._espPreviewBoxStroke = _mk("UIStroke", {
        Color = self.config.AccentColor,
        Thickness = 1.5,
        Parent = self._espPreviewBox
    })

    self._espPreviewHealthTrack = _mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(28, 28, 32),
        BorderSizePixel = 0,
        Position = UDim2.new(0.15, 0, 0.07, 0),
        Size = UDim2.new(0, 3 * _mScale, 0.84, 0),
        Visible = false,
        ZIndex = 33,
        Parent = viewport
    })
    self._espPreviewHealthFill = _mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(100, 255, 100),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 34,
        Parent = self._espPreviewHealthTrack
    })

    self._espPreviewDot = _mk("Frame", {
        BackgroundColor3 = self.config.AccentColor,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, -3 * _mScale, 0.27, -3 * _mScale),
        Size = UDim2.new(0, 6 * _mScale, 0, 6 * _mScale),
        Visible = false,
        ZIndex = 34,
        Parent = viewport
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = self._espPreviewDot})

    self._espPreviewTracer = _mk("Frame", {
        BackgroundColor3 = self.config.AccentColor,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, -1 * _mScale, 0.58, 0),
        Size = UDim2.new(0, 2 * _mScale, 0.34, 0),
        Visible = false,
        ZIndex = 33,
        Parent = viewport
    })

    self._espPreviewName = _mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 1 * _mScale),
        Size = UDim2.new(1, 0, 0, 15 * _mScale),
        Text = _getPlayerName(),
        TextColor3 = self.config.AccentColor,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
        TextSize = 11 * _mScale,
        Visible = false,
        ZIndex = 34,
        Parent = viewport
    })

    self._espPreviewDistance = _mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 1, -18 * _mScale),
        Size = UDim2.new(1, 0, 0, 14 * _mScale),
        Text = "0m",
        TextColor3 = Color3.fromRGB(186, 186, 192),
        TextXAlignment = Enum.TextXAlignment.Center,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
        TextSize = 11 * _mScale,
        Visible = false,
        ZIndex = 34,
        Parent = card
    })

    self._espPreviewItem = _mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 1, -32 * _mScale),
        Size = UDim2.new(1, 0, 0, 14 * _mScale),
        Text = "None",
        TextColor3 = Color3.fromRGB(206, 206, 212),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
        TextSize = 11 * _mScale,
        Visible = false,
        ZIndex = 34,
        Parent = card
    })

    self._espPreviewHighlight = _mk("Highlight", {
        Enabled = false,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        Parent = worldModel
    })

    self._espPreviewPanel = panel
    self._espPreviewViewport = viewport
    self._espPreviewWorldModel = worldModel
    self._espPreviewCamera = camera
    self._espPreviewRotateCapture = rotateCapture
    self:_TrackConnection(viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        self:_InvalidateESPPreviewProjection(false)
    end))

    if self._espPreviewAllowManualRotation == true then
        local function stopESPPreviewRotate()
            self._espPreviewIsRotating = false
            self._espPreviewRotateInput = nil
        end

        self:_TrackConnection(rotateCapture.InputBegan:Connect(function(input)
            local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
            local isTouch = input.UserInputType == Enum.UserInputType.Touch
            if not isMouse and not isTouch then
                return
            end
            self._espPreviewIsRotating = true
            self._espPreviewRotateInput = isTouch and input or nil
            self._espPreviewRotateLastX = input.Position.X
        end))

        self:_TrackConnection(rotateCapture.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                stopESPPreviewRotate()
                return
            end
            if input.UserInputType == Enum.UserInputType.Touch and (self._espPreviewRotateInput == nil or input == self._espPreviewRotateInput) then
                stopESPPreviewRotate()
            end
        end))

        self:_TrackConnection(_uis.InputChanged:Connect(function(input)
            if not self._espPreviewIsRotating then
                return
            end
            local isMouseMove = input.UserInputType == Enum.UserInputType.MouseMovement and self._espPreviewRotateInput == nil
            local isTouchMove = input.UserInputType == Enum.UserInputType.Touch and (self._espPreviewRotateInput == nil or input == self._espPreviewRotateInput)
            if not isMouseMove and not isTouchMove then
                return
            end

            local previousX = tonumber(self._espPreviewRotateLastX) or input.Position.X
            local deltaX = input.Position.X - previousX
            self._espPreviewRotateLastX = input.Position.X

            local rotationSensitivity = _isMobile and 0.02 or 0.015
            self._espPreviewRotationTargetYaw = (tonumber(self._espPreviewRotationTargetYaw) or math.rad(180)) - deltaX * rotationSensitivity
        end))

        self:_TrackConnection(_uis.InputEnded:Connect(function(input)
            if not self._espPreviewIsRotating then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                stopESPPreviewRotate()
                return
            end
            if input.UserInputType == Enum.UserInputType.Touch and (self._espPreviewRotateInput == nil or input == self._espPreviewRotateInput) then
                stopESPPreviewRotate()
            end
        end))
    else
        self._espPreviewIsRotating = false
        self._espPreviewRotateInput = nil
        self._espPreviewRotateLastX = 0
    end

    _mkDrag(panel, panelDragHandle, self)
    self:_EnsureESPPreviewCharacter()
    self:_UpdateESPPreview(0)
end

function _Lib:_ResolveESPPreviewState()
    local state = {
        Enabled = true,
        ShowBox = false,
        ShowHealth = false,
        ShowName = false,
        UseDisplayName = false,
        ShowItem = false,
        ShowDistance = false,
        ShowTracers = false,
        ShowDot = false,
        ShowChams = false,
        ShowHighlight = false,
        ChamsTransparency = 0.55,
        HighlightFillTransparency = 0.5,
        HighlightOutlineTransparency = 0,
        Color = self.config.AccentColor,
        Name = _getPlayerName(),
        Item = "None",
        DistanceText = "0m",
        HealthPercent = 1
    }

    local liveCharacter = _getPlayerCharacter()
    local liveHumanoid = liveCharacter and liveCharacter:FindFirstChildOfClass("Humanoid")
    if liveHumanoid and liveHumanoid.MaxHealth > 0 then
        state.HealthPercent = math.clamp(liveHumanoid.Health / liveHumanoid.MaxHealth, 0, 1)
    end
    if liveCharacter then
        for _, tool in ipairs(liveCharacter:GetChildren()) do
            if tool:IsA("Tool") then
                state.Item = tool.Name
                break
            end
        end
        local localRoot = liveCharacter:FindFirstChild("HumanoidRootPart")
        local cameraRef = workspace.CurrentCamera
        if localRoot and cameraRef then
            state.DistanceText = string.format("%.0fm", (cameraRef.CFrame.Position - localRoot.Position).Magnitude)
        end
    end

    local function applyStateFromTrackedControls()
        local touched = false
        for flagName, control in pairs(self._trackedControls) do
            if type(control) == "table" and type(control.get) == "function" then
                local okValue, controlValue = pcall(control.get)
                if okValue then
                    local rawFlag = string.lower(tostring(flagName or ""))
                    local compactFlag = rawFlag:gsub("[^%w]", "")
                    local function hasFlagToken(...)
                        local tokens = {...}
                        for _, token in ipairs(tokens) do
                            local rawToken = string.lower(tostring(token))
                            local compactToken = rawToken:gsub("[^%w]", "")
                            if rawToken ~= "" and string.find(rawFlag, rawToken, 1, true) then
                                return true
                            end
                            if compactToken ~= "" and string.find(compactFlag, compactToken, 1, true) then
                                return true
                            end
                        end
                        return false
                    end
                    local boolValue = flowPreviewToBool(controlValue)
                    if boolValue ~= nil then
                        if hasFlagToken("esp enabled", "espenabled", "esp toggle", "toggle esp", "enable esp") then
                            state.Enabled = boolValue
                            touched = true
                        elseif hasFlagToken("show box", "showbox", "box esp", "boxes") then
                            state.ShowBox = boolValue
                            touched = true
                        elseif hasFlagToken("show health", "health bar", "healthesp", "showhealth") then
                            state.ShowHealth = boolValue
                            touched = true
                        elseif hasFlagToken("show name", "name esp", "nametag", "showname") then
                            state.ShowName = boolValue
                            touched = true
                        elseif hasFlagToken("display name", "usedisplayname") then
                            state.UseDisplayName = boolValue
                            touched = true
                        elseif hasFlagToken("show equipped item", "show item", "show weapon", "item esp", "tool esp") then
                            state.ShowItem = boolValue
                            touched = true
                        elseif hasFlagToken("show distance", "distance esp", "showdistance") then
                            state.ShowDistance = boolValue
                            touched = true
                        elseif hasFlagToken("show tracers", "tracers", "tracer esp") then
                            state.ShowTracers = boolValue
                            touched = true
                        elseif hasFlagToken("show dot", "dot esp", "head dot", "headdot") then
                            state.ShowDot = boolValue
                            touched = true
                        elseif hasFlagToken("chams enabled", "chams", "use chams") then
                            state.ShowChams = boolValue
                            touched = true
                        elseif hasFlagToken("highlight enabled", "use highlight", "highlight") then
                            state.ShowHighlight = boolValue
                            touched = true
                        end
                    elseif typeof(controlValue) == "Color3" then
                        if hasFlagToken("esp color", "visual color", "highlight color", "chams color", "espcolour", "visualcolour") then
                            state.Color = controlValue
                            touched = true
                        end
                    elseif type(controlValue) == "number" then
                        if hasFlagToken("chams transparency", "cham transparency") then
                            state.ChamsTransparency = math.clamp(controlValue, 0, 1)
                            touched = true
                        elseif hasFlagToken("fill transparency", "highlight fill transparency") then
                            state.HighlightFillTransparency = math.clamp(controlValue, 0, 1)
                            touched = true
                        elseif hasFlagToken("outline transparency", "highlight outline transparency") then
                            state.HighlightOutlineTransparency = math.clamp(controlValue, 0, 1)
                            touched = true
                        end
                    end
                end
            end
        end
        return touched
    end

    local function applyStateFrom(sourceTable)
        if type(sourceTable) ~= "table" then
            return false
        end
        local touched = false
        local function setBoolField(targetField, keys)
            local rawValue = flowPreviewPullValue(sourceTable, keys)
            local boolValue = flowPreviewToBool(rawValue)
            if boolValue ~= nil then
                state[targetField] = boolValue
                touched = true
            end
        end
        local function setNumberField(targetField, keys, minValue, maxValue)
            local rawValue = flowPreviewPullValue(sourceTable, keys)
            if type(rawValue) == "number" then
                state[targetField] = math.clamp(rawValue, minValue, maxValue)
                touched = true
            end
        end

        setBoolField("Enabled", {"ESPEnabled", "Enabled", "ESP", "MasterEnabled", "MasterSwitch"})
        setBoolField("ShowBox", {"ShowBox", "Boxes", "Box", "BoxESP"})
        setBoolField("ShowHealth", {"ShowHealth", "Health", "HealthBar", "HealthESP"})
        setBoolField("ShowName", {"ShowName", "Names", "NameESP", "Nametags"})
        setBoolField("UseDisplayName", {"UseDisplayName", "DisplayName", "DisplayNames"})
        setBoolField("ShowItem", {"ShowEquippedItem", "ShowItem", "ItemESP", "ShowWeapon", "ShowTool"})
        setBoolField("ShowDistance", {"ShowDistance", "Distance", "DistanceESP"})
        setBoolField("ShowTracers", {"ShowTracers", "Tracers", "TracerESP"})
        setBoolField("ShowDot", {"ShowDot", "Dot", "DotESP", "HeadDot"})
        setBoolField("ShowChams", {"ChamsEnabled", "Chams", "UseChams", "CharacterMaterial"})
        setBoolField("ShowHighlight", {"HighlightEnabled", "Highlight", "UseHighlight"})

        setNumberField("ChamsTransparency", {"ChamsTransparency", "ChamTransparency", "ChamsAlpha"}, 0, 1)
        setNumberField("HighlightFillTransparency", {"HighlightFillTransparency", "HighlightFillAlpha"}, 0, 1)
        setNumberField("HighlightOutlineTransparency", {"HighlightOutlineTransparency", "HighlightOutlineAlpha"}, 0, 1)

        local colorValue = flowPreviewToColor3(flowPreviewPullValue(sourceTable, {
            "VisualColor", "ESPColor", "Color", "Colour", "MainColor", "ChamsColor", "HighlightColor"
        }))
        if colorValue then
            state.Color = colorValue
            touched = true
        end

        local suppliedName = flowPreviewPullValue(sourceTable, {"Name", "PlayerName", "DisplayName", "NameText"})
        if type(suppliedName) == "string" and suppliedName ~= "" then
            state.Name = suppliedName
            touched = true
        end
        local suppliedItem = flowPreviewPullValue(sourceTable, {"Item", "ItemName", "Tool", "ToolName", "Weapon", "WeaponName"})
        if type(suppliedItem) == "string" and suppliedItem ~= "" then
            state.Item = suppliedItem
            touched = true
        end
        local suppliedDistanceText = flowPreviewPullValue(sourceTable, {"DistanceText", "DistanceString", "DistanceLabel"})
        if type(suppliedDistanceText) == "string" and suppliedDistanceText ~= "" then
            state.DistanceText = suppliedDistanceText
            touched = true
        else
            local suppliedDistance = flowPreviewPullValue(sourceTable, {"Distance", "DistanceValue"})
            if type(suppliedDistance) == "number" then
                state.DistanceText = string.format("%.0fm", suppliedDistance)
                touched = true
            end
        end

        local suppliedHealthPercent = flowPreviewPullValue(sourceTable, {"HealthPercent", "HPPercent", "HealthRatio"})
        if type(suppliedHealthPercent) == "number" then
            if suppliedHealthPercent > 1 then
                suppliedHealthPercent = suppliedHealthPercent / 100
            end
            state.HealthPercent = math.clamp(suppliedHealthPercent, 0, 1)
            touched = true
        else
            local suppliedHealth = flowPreviewPullValue(sourceTable, {"Health", "HP"})
            local suppliedMaxHealth = flowPreviewPullValue(sourceTable, {"MaxHealth", "MaxHP", "HealthMax"})
            if type(suppliedHealth) == "number" and type(suppliedMaxHealth) == "number" and suppliedMaxHealth > 0 then
                state.HealthPercent = math.clamp(suppliedHealth / suppliedMaxHealth, 0, 1)
                touched = true
            end
        end

        return touched
    end

    local appliedTracked = applyStateFromTrackedControls()
    local appliedExternal = false
    if type(self._espPreviewData) == "table" then
        appliedExternal = applyStateFrom(self._espPreviewData) or appliedExternal
    end
    if type(self._espPreviewProvider) == "function" then
        local ok, providerResult = pcall(self._espPreviewProvider, self, state)
        if ok and type(providerResult) == "table" then
            appliedExternal = applyStateFrom(providerResult) or appliedExternal
        end
    end

    if not appliedExternal and not appliedTracked then
        local candidates = {}
        local candidateSet = {}
        local function addCandidate(candidate)
            if type(candidate) ~= "table" then
                return
            end
            if candidateSet[candidate] then
                return
            end
            candidateSet[candidate] = true
            table.insert(candidates, candidate)
        end
        local function addFromEnvironment(env)
            if type(env) ~= "table" then
                return
            end
            addCandidate(env.Settings)
            addCandidate(env.settings)
            addCandidate(env.ESPSettings)
            addCandidate(env.VisualSettings)
            addCandidate(env.Visuals)
            addCandidate(env.ESP)
            addCandidate(env.esp)
            addCandidate(env.Flags)
            addCandidate(env.flags)
            if type(env.Config) == "table" then
                addCandidate(env.Config.Settings)
                addCandidate(env.Config.ESP)
                addCandidate(env.Config.Visuals)
            end
        end
        addFromEnvironment(_sharedEnv)

        local knownKeys = {
            "ESPEnabled", "ShowBox", "ShowHealth", "ShowName", "UseDisplayName", "ShowEquippedItem",
            "ShowDistance", "ShowTracers", "ShowDot", "ChamsEnabled", "HighlightEnabled", "VisualColor"
        }
        local bestCandidate = nil
        local bestScore = 0
        for _, candidate in ipairs(candidates) do
            local score = 0
            for _, keyName in ipairs(knownKeys) do
                if candidate[keyName] ~= nil then
                    score = score + 1
                end
            end
            if score > bestScore then
                bestScore = score
                bestCandidate = candidate
            end
        end
        if bestCandidate and bestScore > 0 then
            applyStateFrom(bestCandidate)
        end
    end

    if state.UseDisplayName then
        state.Name = _getPlayerDisplayName()
    elseif state.Name == "" or state.Name == nil then
        state.Name = _getPlayerName()
    end
    return state
end

function _Lib:_ApplyESPPreviewPartVisualState(showChams, previewColor, chamsTransparency)
    local targetShowChams = showChams == true
    local targetChamsTransparency = math.clamp(chamsTransparency or 0.55, 0, 0.92)
    local lastVisualState = self._espPreviewVisualState or {}
    local colorChanged = targetShowChams and lastVisualState.Color ~= previewColor
    local transparencyChanged = targetShowChams and math.abs((lastVisualState.ChamsTransparency or targetChamsTransparency) - targetChamsTransparency) > 0.001

    if not self._espPreviewVisualDirty
        and lastVisualState.ShowChams == targetShowChams
        and not colorChanged
        and not transparencyChanged then
        return
    end

    for part, originalData in pairs(self._espPreviewPartDefaults) do
        if part and part.Parent and originalData then
            local isRootPart = part.Name == "HumanoidRootPart"
            if targetShowChams and not isRootPart then
                if part.Material ~= Enum.Material.ForceField then
                    part.Material = Enum.Material.ForceField
                end
                if part.Color ~= previewColor then
                    part.Color = previewColor
                end
                if math.abs(part.Transparency - targetChamsTransparency) > 0.001 then
                    part.Transparency = targetChamsTransparency
                end
            else
                if part.Material ~= originalData.Material then
                    part.Material = originalData.Material
                end
                if part.Color ~= originalData.Color then
                    part.Color = originalData.Color
                end

                local targetTransparency
                if isRootPart then
                    targetTransparency = 1
                elseif flowPreviewCoreBodyParts[part.Name] and (originalData.Transparency or 0) >= 0.98 then
                    targetTransparency = 0
                else
                    targetTransparency = originalData.Transparency
                end

                if math.abs(part.Transparency - targetTransparency) > 0.001 then
                    part.Transparency = targetTransparency
                end
            end
        end
    end

    self._espPreviewVisualState = {
        ShowChams = targetShowChams,
        Color = previewColor,
        ChamsTransparency = targetChamsTransparency
    }
    self._espPreviewVisualDirty = false
end

function _Lib:_UpdateESPPreview(dt)
    local shouldShow = self.isToggledOn and self._uiVisualSettings.ESPSelfPreview
    if not shouldShow then
        if self._espPreviewPanel then
            self._espPreviewPanel.Visible = false
        end
        if self._espPreviewWasShowing then
            self._espPreviewWasShowing = false
            self._espPreviewUpdateAccumulator = 0
            self:_DestroyESPPreviewCharacter()
        end
        return
    end

    self._espPreviewWasShowing = true

    if not self._espPreviewPanel or not self._espPreviewPanel.Parent then
        self:_CreateESPPreviewPanel()
    end
    if not self._espPreviewPanel then
        return
    end
    self._espPreviewPanel.Visible = true

    local resolvedDt = tonumber(dt) or 0
    if resolvedDt > 0 then
        self._espPreviewUpdateAccumulator = (tonumber(self._espPreviewUpdateAccumulator) or 0) + resolvedDt
        local updateInterval = _isMobile and 0.28 or 0.2
        if self._latestFPSValue > 0 then
            if self._latestFPSValue < _CRIT_FPS then
                updateInterval = _isMobile and 0.45 or 0.34
            elseif self._latestFPSValue < _LOW_FPS then
                updateInterval = _isMobile and 0.36 or 0.28
            elseif self._latestFPSValue < 55 then
                updateInterval = _isMobile and 0.32 or 0.24
            elseif self._latestFPSValue > 95 then
                updateInterval = _isMobile and 0.22 or 0.16
            end
        end
        if self._espPreviewUpdateAccumulator < updateInterval then
            return
        end
        resolvedDt = self._espPreviewUpdateAccumulator
        self._espPreviewUpdateAccumulator = 0
    end

    self._espPreviewResolveAccumulator = self._espPreviewResolveAccumulator + resolvedDt
    if not self._espPreviewState or self._espPreviewResolveAccumulator >= 0.3 then
        self._espPreviewState = self:_ResolveESPPreviewState()
        self._espPreviewResolveAccumulator = 0
    end
    local state = self._espPreviewState or self:_ResolveESPPreviewState()
    local previewColor = state.Color or self.config.AccentColor
    local showMaster = state.Enabled ~= false
    local hidePlayerName = self._uiVisualSettings.HideName == true
    local needsProjection = showMaster and (
        state.ShowBox == true
        or state.ShowHealth == true
        or state.ShowName == true
        or state.ShowDot == true
        or state.ShowTracers == true
    )

    self:_EnsureESPPreviewCharacter()
    if self._espPreviewAllowManualRotation == true and self._espPreviewCharacter and self._espPreviewCharacter.Parent then
        local currentYaw = tonumber(self._espPreviewRotationYaw) or math.rad(180)
        local targetYaw = tonumber(self._espPreviewRotationTargetYaw) or currentYaw
        local yawDelta = math.atan2(math.sin(targetYaw - currentYaw), math.cos(targetYaw - currentYaw))
        local yawAlpha = math.clamp((resolvedDt > 0 and resolvedDt or (1 / 60)) * 14, 0.08, 0.58)
        if math.abs(yawDelta) > 0.0004 then
            currentYaw = currentYaw + yawDelta * yawAlpha
            self._espPreviewRotationYaw = currentYaw
            self:_InvalidateESPPreviewProjection(false)
            local pivotYOffset = tonumber(self._espPreviewPivotYOffset) or -2
            pcall(function()
                self._espPreviewCharacter:PivotTo(CFrame.new(0, pivotYOffset, 0) * CFrame.Angles(0, currentYaw, 0))
            end)
        end
    end
    if not self._espPreviewStaticMode and (not self._espPreviewWalkTrack or not self._espPreviewWalkTrack.IsPlaying) then
        self:_StartESPPreviewWalkAnimation(_getPlayerCharacter())
    end
    if self._espPreviewHeaderTag then
        self._espPreviewHeaderTag.Visible = not hidePlayerName
        if not hidePlayerName then
            self._espPreviewHeaderTag.Text = "@" .. _getPlayerName()
        end
    end
    if not self._espPreviewCharacter then
        if self._espPreviewBox then self._espPreviewBox.Visible = false end
        if self._espPreviewHealthTrack then self._espPreviewHealthTrack.Visible = false end
        if self._espPreviewDot then self._espPreviewDot.Visible = false end
        if self._espPreviewTracer then self._espPreviewTracer.Visible = false end
        if self._espPreviewName then self._espPreviewName.Visible = false end
        if self._espPreviewItem then self._espPreviewItem.Visible = false end
        if self._espPreviewDistance then self._espPreviewDistance.Visible = false end
        if self._espPreviewHighlight then self._espPreviewHighlight.Enabled = false end
        return
    end

    if self._espPreviewBoxStroke then self._espPreviewBoxStroke.Color = previewColor end
    if self._espPreviewDot then self._espPreviewDot.BackgroundColor3 = previewColor end
    if self._espPreviewTracer then self._espPreviewTracer.BackgroundColor3 = previewColor end

    local viewportCamera = self._espPreviewCamera or (self._espPreviewViewport and self._espPreviewViewport.CurrentCamera)
    local viewportSize = self._espPreviewViewport and self._espPreviewViewport.AbsoluteSize or Vector2.new(0, 0)
    local hasProjectedBox = false
    local boxMinX, boxMinY = math.huge, math.huge
    local boxMaxX, boxMaxY = -math.huge, -math.huge
    local headScreenPos = nil
    local rootScreenPos = nil
    local boundsCF = nil
    local boundsSize = nil
    local projectionCache = nil
    local canReuseProjection = false

    if needsProjection and viewportCamera and viewportSize.X > 2 and viewportSize.Y > 2 then
        projectionCache = self._espPreviewProjectionCache
        canReuseProjection = self._espPreviewStaticMode
            and self._espPreviewProjectionDirty ~= true
            and projectionCache ~= nil
            and math.abs((projectionCache.ViewportWidth or 0) - viewportSize.X) < 0.5
            and math.abs((projectionCache.ViewportHeight or 0) - viewportSize.Y) < 0.5

        if canReuseProjection then
            hasProjectedBox = projectionCache.HasProjectedBox == true
            boxMinX = projectionCache.BoxMinX or boxMinX
            boxMinY = projectionCache.BoxMinY or boxMinY
            boxMaxX = projectionCache.BoxMaxX or boxMaxX
            boxMaxY = projectionCache.BoxMaxY or boxMaxY
            if projectionCache.HeadX ~= nil and projectionCache.HeadY ~= nil then
                headScreenPos = Vector2.new(projectionCache.HeadX, projectionCache.HeadY)
            end
            if projectionCache.RootX ~= nil and projectionCache.RootY ~= nil then
                rootScreenPos = Vector2.new(projectionCache.RootX, projectionCache.RootY)
            end
        else
            boundsCF, boundsSize = getModelBoundingBoxSafe(self._espPreviewCharacter)

            if not self._espPreviewStaticMode and boundsCF and boundsSize then
                viewportCamera.FieldOfView = 32
                local boundsCenter = boundsCF.Position
                local verticalFov = math.rad(math.clamp(viewportCamera.FieldOfView, 18, 80))
                local aspectRatio = math.max(0.35, viewportSize.X / viewportSize.Y)
                local horizontalHalfFov = math.atan(math.tan(verticalFov * 0.5) * aspectRatio)
                local fitDepthY = (boundsSize.Y * 0.5) / math.max(0.001, math.tan(verticalFov * 0.5))
                local fitDepthX = (boundsSize.X * 0.5) / math.max(0.001, math.tan(horizontalHalfFov))
                local targetDepth = math.max(fitDepthX, fitDepthY) + boundsSize.Z * 0.85 + 1.35
                targetDepth = math.clamp(targetDepth, 6.8, 19.5)
                local lookTarget = boundsCenter + Vector3.new(0, math.clamp(boundsSize.Y * 0.03, -0.1, 0.45), 0)
                local cameraPos = lookTarget + Vector3.new(0, math.clamp(boundsSize.Y * 0.08, -0.2, 0.6), targetDepth)
                local targetCFrame = CFrame.new(cameraPos, lookTarget)
                local lerpAlpha = math.clamp((resolvedDt > 0 and resolvedDt or (1 / 60)) * 10, 0.12, 0.52)
                viewportCamera.CFrame = viewportCamera.CFrame:Lerp(targetCFrame, lerpAlpha)
            end

            if boundsCF and boundsSize then
                local partBoundsOk, partMinX, partMinY, partMaxX, partMaxY = getESPPreviewProjectedPartBounds(self._espPreviewCharacter, viewportCamera)
                if partBoundsOk then
                    hasProjectedBox = true
                    boxMinX, boxMinY, boxMaxX, boxMaxY = partMinX, partMinY, partMaxX, partMaxY
                else
                    local halfSize = boundsSize * 0.5
                    for _, cornerSign in ipairs(flowPreviewBoundingCornerSigns) do
                        local worldPoint = boundsCF:PointToWorldSpace(Vector3.new(
                            halfSize.X * cornerSign.X,
                            halfSize.Y * cornerSign.Y,
                            halfSize.Z * cornerSign.Z
                        ))
                        local screenPoint = viewportCamera:WorldToViewportPoint(worldPoint)
                        if screenPoint.Z > 0 then
                            hasProjectedBox = true
                            boxMinX = math.min(boxMinX, screenPoint.X)
                            boxMinY = math.min(boxMinY, screenPoint.Y)
                            boxMaxX = math.max(boxMaxX, screenPoint.X)
                            boxMaxY = math.max(boxMaxY, screenPoint.Y)
                        end
                    end
                end
            end

            local headPart = self._espPreviewHeadPart
            if headPart and headPart.Parent then
                local headWorld = headPart.Position + Vector3.new(0, math.max(0.12, headPart.Size.Y * 0.3), 0)
                local headPoint = viewportCamera:WorldToViewportPoint(headWorld)
                if headPoint.Z > 0 then
                    headScreenPos = Vector2.new(headPoint.X, headPoint.Y)
                end
            end

            local rootPart = self._espPreviewRootPart
            if rootPart and rootPart.Parent then
                local rootPoint = viewportCamera:WorldToViewportPoint(rootPart.Position)
                if rootPoint.Z > 0 then
                    rootScreenPos = Vector2.new(rootPoint.X, rootPoint.Y)
                end
            end
        end
    end

    if needsProjection and hasProjectedBox then
        local viewportPad = 3 * _mScale
        boxMinX = math.clamp(boxMinX, viewportPad, math.max(viewportPad, viewportSize.X - viewportPad))
        boxMinY = math.clamp(boxMinY, viewportPad, math.max(viewportPad, viewportSize.Y - viewportPad))
        boxMaxX = math.clamp(boxMaxX, viewportPad, math.max(viewportPad, viewportSize.X - viewportPad))
        boxMaxY = math.clamp(boxMaxY, viewportPad, math.max(viewportPad, viewportSize.Y - viewportPad))
        if boxMaxX - boxMinX < 2 or boxMaxY - boxMinY < 2 then
            hasProjectedBox = false
        end
    end

    if needsProjection and not hasProjectedBox and viewportSize.X > 2 and viewportSize.Y > 2 then
        local fallbackWidth = viewportSize.X * 0.36
        local fallbackHeight = viewportSize.Y * 0.62
        boxMinX = (viewportSize.X - fallbackWidth) * 0.5
        boxMaxX = boxMinX + fallbackWidth
        boxMinY = viewportSize.Y * 0.19
        boxMaxY = boxMinY + fallbackHeight
        hasProjectedBox = true
        if not headScreenPos then
            headScreenPos = Vector2.new((boxMinX + boxMaxX) * 0.5, boxMinY + 8 * _mScale)
        end
        if not rootScreenPos then
            rootScreenPos = Vector2.new((boxMinX + boxMaxX) * 0.5, boxMaxY)
        end
    end

    if needsProjection and self._espPreviewStaticMode and viewportSize.X > 2 and viewportSize.Y > 2 and not canReuseProjection then
        self._espPreviewProjectionCache = {
            ViewportWidth = viewportSize.X,
            ViewportHeight = viewportSize.Y,
            HasProjectedBox = hasProjectedBox == true,
            BoxMinX = hasProjectedBox and boxMinX or nil,
            BoxMinY = hasProjectedBox and boxMinY or nil,
            BoxMaxX = hasProjectedBox and boxMaxX or nil,
            BoxMaxY = hasProjectedBox and boxMaxY or nil,
            HeadX = headScreenPos and headScreenPos.X or nil,
            HeadY = headScreenPos and headScreenPos.Y or nil,
            RootX = rootScreenPos and rootScreenPos.X or nil,
            RootY = rootScreenPos and rootScreenPos.Y or nil
        }
        self._espPreviewProjectionDirty = false
    end
    if self._espPreviewBox then
        local showBox = showMaster and state.ShowBox == true and hasProjectedBox
        self._espPreviewBox.Visible = showBox
        if showBox then
            self._espPreviewBox.Position = UDim2.new(0, boxMinX, 0, boxMinY)
            self._espPreviewBox.Size = UDim2.new(0, boxMaxX - boxMinX, 0, boxMaxY - boxMinY)
        end
    end
    if self._espPreviewDot then
        local showDot = showMaster and state.ShowDot == true and headScreenPos ~= nil
        self._espPreviewDot.Visible = showDot
        if showDot then
            local dotSize = math.max(5 * _mScale, 1)
            self._espPreviewDot.Position = UDim2.new(0, headScreenPos.X - dotSize * 0.5, 0, headScreenPos.Y - dotSize * 0.5)
            self._espPreviewDot.Size = UDim2.new(0, dotSize, 0, dotSize)
        end
    end
    if self._espPreviewTracer then
        local showTracer = showMaster and state.ShowTracers == true and (hasProjectedBox or rootScreenPos ~= nil)
        self._espPreviewTracer.Visible = showTracer
        if showTracer then
            local fromX = viewportSize.X * 0.5
            local fromY = viewportSize.Y - 1
            local toX = rootScreenPos and rootScreenPos.X or (boxMinX + (boxMaxX - boxMinX) * 0.5)
            local toY = rootScreenPos and rootScreenPos.Y or boxMaxY
            local dx = toX - fromX
            local dy = toY - fromY
            local length = math.sqrt(dx * dx + dy * dy)
            if length >= 2 then
                self._espPreviewTracer.Position = UDim2.new(0, fromX, 0, fromY)
                self._espPreviewTracer.Size = UDim2.new(0, 2 * _mScale, 0, length)
                self._espPreviewTracer.Rotation = math.deg(math.atan2(dy, dx)) + 90
            else
                self._espPreviewTracer.Visible = false
            end
        end
    end

    if self._espPreviewName then
        local showName = not hidePlayerName and showMaster and state.ShowName == true and (hasProjectedBox or headScreenPos ~= nil)
        self._espPreviewName.Visible = showName
        if not hidePlayerName then
            self._espPreviewName.Text = tostring(state.Name or _getPlayerName())
        end
        self._espPreviewName.TextColor3 = previewColor
        if showName then
            local nameWidth = hasProjectedBox and (boxMaxX - boxMinX + 30 * _mScale) or (130 * _mScale)
            nameWidth = math.clamp(nameWidth, 80 * _mScale, math.max(1, viewportSize.X - 8 * _mScale))
            local centerX = hasProjectedBox and (boxMinX + (boxMaxX - boxMinX) * 0.5) or headScreenPos.X
            local nameX = math.clamp(centerX - nameWidth * 0.5, 4 * _mScale, math.max(4 * _mScale, viewportSize.X - nameWidth - 4 * _mScale))
            local nameY = hasProjectedBox and (boxMinY - 18 * _mScale) or (headScreenPos.Y - 18 * _mScale)
            nameY = math.clamp(nameY, 4 * _mScale, math.max(4 * _mScale, viewportSize.Y - 18 * _mScale))
            self._espPreviewName.Position = UDim2.new(0, nameX, 0, nameY)
            self._espPreviewName.Size = UDim2.new(0, nameWidth, 0, 16 * _mScale)
        end
    end

    if self._espPreviewItem then
        self._espPreviewItem.Visible = state.ShowItem == true and showMaster
        self._espPreviewItem.Text = tostring(state.Item or "None")
        self._espPreviewItem.TextColor3 = previewColor
        if self._espPreviewItem.Visible then
            local itemY = hasProjectedBox and (boxMaxY + 4 * _mScale) or (viewportSize.Y - 38 * _mScale)
            itemY = math.clamp(itemY, 4 * _mScale, math.max(4 * _mScale, viewportSize.Y - 34 * _mScale))
            self._espPreviewItem.Position = UDim2.new(0, 6 * _mScale, 0, itemY)
            self._espPreviewItem.Size = UDim2.new(1, -12 * _mScale, 0, 16 * _mScale)
        end
    end

    if self._espPreviewDistance then
        self._espPreviewDistance.Visible = state.ShowDistance == true and showMaster
        self._espPreviewDistance.Text = tostring(state.DistanceText or "0m")
        self._espPreviewDistance.TextColor3 = previewColor
        if self._espPreviewDistance.Visible then
            local distanceY = hasProjectedBox and (boxMaxY + ((state.ShowItem == true) and 20 or 6) * _mScale) or (viewportSize.Y - 20 * _mScale)
            distanceY = math.clamp(distanceY, 4 * _mScale, math.max(4 * _mScale, viewportSize.Y - 18 * _mScale))
            self._espPreviewDistance.Position = UDim2.new(0, 6 * _mScale, 0, distanceY)
            self._espPreviewDistance.Size = UDim2.new(1, -12 * _mScale, 0, 16 * _mScale)
        end
    end

    if self._espPreviewHealthTrack then
        local showHealth = state.ShowHealth == true and showMaster and hasProjectedBox
        self._espPreviewHealthTrack.Visible = showHealth
        if showHealth and self._espPreviewHealthFill then
            local trackWidth = math.max(3 * _mScale, 2)
            local trackX = math.clamp(boxMinX - trackWidth - 3 * _mScale, 2 * _mScale, math.max(2 * _mScale, viewportSize.X - trackWidth - 2 * _mScale))
            self._espPreviewHealthTrack.Position = UDim2.new(0, trackX, 0, boxMinY)
            self._espPreviewHealthTrack.Size = UDim2.new(0, trackWidth, 0, boxMaxY - boxMinY)
            local hpPercent = math.clamp(tonumber(state.HealthPercent) or 1, 0, 1)
            self._espPreviewHealthFill.Size = UDim2.new(1, 0, hpPercent, 0)
            self._espPreviewHealthFill.BackgroundColor3 = Color3.new(1 - hpPercent, hpPercent, 0)
        end
    end

    self:_ApplyESPPreviewPartVisualState(state.ShowChams == true and showMaster, previewColor, state.ChamsTransparency)

    if self._espPreviewHighlight then
        self._espPreviewHighlight.FillColor = previewColor
        self._espPreviewHighlight.OutlineColor = previewColor
        self._espPreviewHighlight.FillTransparency = math.clamp(state.HighlightFillTransparency or 0.5, 0, 1)
        self._espPreviewHighlight.OutlineTransparency = math.clamp(state.HighlightOutlineTransparency or 0, 0, 1)
        self._espPreviewHighlight.Enabled = state.ShowHighlight == true and state.Enabled ~= false
    end
end

function _Lib:EnableSmoothScrolling(scrollFrame, smoothSpeed)
    if not scrollFrame or self._smoothScrollFrames[scrollFrame] then return end
    if scrollFrame:GetAttribute("FlowDisableSmoothScroll") == true then
        scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
        scrollFrame.ElasticBehavior = Enum.ElasticBehavior.Never
        scrollFrame.ScrollBarImageTransparency = 0.1
        return
    end
    self._smoothScrollFrames[scrollFrame] = {
        targetY = scrollFrame.CanvasPosition.Y,
        internal = false,
        speed = smoothSpeed or 34
    }
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    scrollFrame.ScrollBarImageTransparency = 0.25
    self:_TrackConnection(scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        local state = self._smoothScrollFrames[scrollFrame]
        if not state or state.internal then return end
        state.targetY = scrollFrame.CanvasPosition.Y
    end))
end

function _Lib:_MotionDuration(normalDuration, reducedDuration)
    local mode = self.config and self.config.Motion or "Normal"
    if mode == "Off" then
        return 0
    elseif mode == "Reduced" then
        return reducedDuration or math.min((normalDuration or 0.2) * 0.45, 0.12)
    end
    return normalDuration or 0.2
end

function _Lib:_Tween(instance, properties, duration, easingStyle, easingDirection, reducedDuration)
    return _tween(instance, properties, self:_MotionDuration(duration, reducedDuration), easingStyle, easingDirection)
end

function _Lib:SetMotionMode(mode)
    self.config.Motion = _normMotion(mode)
end

function _Lib:ApplySearchFilter(rawQuery)
    local query = normalizeSearchText(rawQuery)
    self._searchQuery = query
    local firstVisibleTab = nil
    local function matchesAny(queryText, termList)
        if queryText == "" then return true end
        if type(termList) ~= "table" then return false end
        for _, term in ipairs(termList) do
            local normalized = normalizeSearchText(term)
            if normalized ~= "" and string.find(normalized, queryText, 1, true) ~= nil then
                return true
            end
        end
        return false
    end
    
    for _, section in ipairs(self._sections) do
        local sectionHasVisibleContent = false
        for _, tab in ipairs(section.tabsInSection) do
            local tabMatch = matchesAny(query, tab.searchTerms)
            local groupMatch = false
            
            for _, group in ipairs(tab.groupsInTab) do
                local visible = query == "" or tabMatch or matchesAny(query, group.searchTerms)
                if group.mainFrame then
                    group.mainFrame.Visible = visible
                end
                if visible then
                    groupMatch = true
                end
            end
            
            local tabVisible = query == "" or tabMatch or groupMatch
            tab.isFilteredVisible = tabVisible
            if tab.buttonFrame then
                tab.buttonFrame.Visible = tabVisible
                if tab.defaultButtonSize then
                    tab.buttonFrame.Size = tabVisible and tab.defaultButtonSize or UDim2.new(tab.defaultButtonSize.X.Scale, tab.defaultButtonSize.X.Offset, tab.defaultButtonSize.Y.Scale, 0)
                end
            end
            if tabVisible and not firstVisibleTab then
                firstVisibleTab = tab
            end
            if tabVisible then
                sectionHasVisibleContent = true
            end
        end
        
        if section.containerFrame then
            section.containerFrame.Visible = sectionHasVisibleContent or query == ""
        end
        if type(section.UpdateSize) == "function" then
            section.UpdateSize(false)
        end
    end
    
    if self._curTab and not self._curTab.isFilteredVisible then
        if firstVisibleTab then
            firstVisibleTab:Activate()
        else
            self._curTab:Deactivate()
            self._curTab = nil
        end
    elseif not self._curTab and firstVisibleTab then
        firstVisibleTab:Activate()
    end
    self:_RefreshCommandPalette(rawQuery)
end

function _Lib:_SetCommandPaletteOpen(openState, rawQuery)
    self._commandPaletteOpen = openState == true
    if not self.commandPaletteFrame then
        return
    end

    local paletteWidth = self._commandPaletteWidth or (310 * _mScale)
    local paletteHeight = self._commandPaletteHeight or (236 * _mScale)
    if self._commandPaletteOpen then
        self.commandPaletteFrame.Visible = true
        self:_RefreshCommandPalette(rawQuery or (self.searchBox and self.searchBox.Text) or "")
        self:_Tween(self.commandPaletteFrame, {
            Size = UDim2.new(0, paletteWidth, 0, paletteHeight),
            BackgroundTransparency = 0.02
        }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    else
        self:_Tween(self.commandPaletteFrame, {
            Size = UDim2.new(0, paletteWidth, 0, 0),
            BackgroundTransparency = 0.18
        }, 0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(self:_MotionDuration(0.16, 0.06), function()
            if self.commandPaletteFrame and self.commandPaletteFrame.Parent and not self._commandPaletteOpen then
                self.commandPaletteFrame.Visible = false
            end
        end)
    end
end

function _Lib:_RefreshCommandPalette(rawQuery)
    if not self.commandPaletteListFrame then
        return
    end

    for _, child in ipairs(self.commandPaletteListFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local query = normalizeSearchText(rawQuery)
    local rows = {}
    local function matches(label, detail)
        if query == "" then
            return true
        end
        local haystack = normalizeSearchText(tostring(label or "") .. " " .. tostring(detail or ""))
        return string.find(haystack, query, 1, true) ~= nil
    end

    for _, section in ipairs(self._sections or {}) do
        for _, tab in ipairs(section.tabsInSection or {}) do
            if matches(tab.tabNameForSearch, section.sectionNameForSearch) then
                table.insert(rows, {
                    Kind = "Tab",
                    Name = tab.tabNameForSearch,
                    Detail = section.sectionNameForSearch or "Tab",
                    Tab = tab
                })
            end
            for _, group in ipairs(tab.groupsInTab or {}) do
                if matches(group.groupNameForSearch, tab.tabNameForSearch) then
                    table.insert(rows, {
                        Kind = "Group",
                        Name = group.groupNameForSearch,
                        Detail = tostring(tab.tabNameForSearch or "") .. " / " .. tostring(group.side or "Panel"),
                        Tab = tab,
                        Group = group
                    })
                end
            end
        end
    end

    local maxRows = math.min(#rows, 7)
    local yOffset = 0
    if maxRows == 0 then
        _mkLabel(self.commandPaletteListFrame, self, "No commands found", UDim2.new(0, 10 * _mScale, 0, 10 * _mScale), UDim2.new(1, -20 * _mScale, 0, 18 * _mScale), {
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
            TextColor = _palette.TextSoft,
            TextSize = 12.5 * _mScale,
            ZIndex = 52
        })
        return
    end

    for index = 1, maxRows do
        local entry = rows[index]
        local rowFrame = _mk("Frame", {
            BackgroundColor3 = _palette.SurfaceSoft,
            BackgroundTransparency = index == 1 and 0.08 or 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 6 * _mScale, 0, yOffset),
            Size = UDim2.new(1, -12 * _mScale, 0, 28 * _mScale),
            ZIndex = 51,
            Parent = self.commandPaletteListFrame
        })
    _mkCorner(rowFrame, _cornerTk.Tight)
        _mkLabel(rowFrame, self, entry.Name, UDim2.new(0, 9 * _mScale, 0, 3 * _mScale), UDim2.new(1, -80 * _mScale, 0, 14 * _mScale), {
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
            TextColor = _palette.Text,
            TextSize = 12.5 * _mScale,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 52
        })
        _mkLabel(rowFrame, self, entry.Detail, UDim2.new(0, 9 * _mScale, 0, 15 * _mScale), UDim2.new(1, -80 * _mScale, 0, 12 * _mScale), {
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
            TextColor = _palette.TextSoft,
            TextSize = 10.5 * _mScale,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 52
        })
        _mkLabel(rowFrame, self, entry.Kind, UDim2.new(1, -58 * _mScale, 0, 0), UDim2.new(0, 48 * _mScale, 1, 0), {
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
            TextColor = self.config.AccentColor,
            TextSize = 10.5 * _mScale,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 52
        })

        local rowButton = _mk("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 53,
            Parent = rowFrame
        })
        rowButton.MouseEnter:Connect(function()
            self:_Tween(rowFrame, {BackgroundTransparency = 0.04}, 0.12)
        end)
        rowButton.MouseLeave:Connect(function()
            self:_Tween(rowFrame, {BackgroundTransparency = index == 1 and 0.08 or 1}, 0.12)
        end)
        rowButton.MouseButton1Click:Connect(function()
            if entry.Tab and type(entry.Tab.Activate) == "function" then
                entry.Tab:Activate()
                if entry.Group and entry.Tab.contentScroll then
                    local groupY = entry.Group.mainFrame and entry.Group.mainFrame.Position.Y.Offset or 0
                    entry.Tab.contentScroll.CanvasPosition = Vector2.new(0, math.max(0, groupY - 8 * _mScale))
                end
            end
            self:_SetCommandPaletteOpen(false)
        end)
        yOffset = yOffset + 31 * _mScale
    end
end

function _Lib:SaveConfig(fileName)
    if not _fs.writefile then
        return false, "writefile API is unavailable in this executor."
    end

    local configName = sanitizeConfigName(fileName)
    local payload = {
        version = 1,
        ui = self.config.Name,
        controls = {}
    }
    
    for flag, control in pairs(self._trackedControls) do
        local ok, value = pcall(control.get)
        if ok then
            payload.controls[flag] = serializeConfigValue(value)
        end
    end

    local encoded = _hs:JSONEncode(payload)
    local writableCandidates = {}
    local fileOnlyName = _getConfigFile(configName)
    local okFolder, folderPath = _ensureConfigDir()
    if okFolder then
        table.insert(writableCandidates, folderPath .. "/" .. fileOnlyName)
        table.insert(writableCandidates, folderPath .. "\\" .. fileOnlyName)
    end
    table.insert(writableCandidates, fileOnlyName)

    local visitedPaths = {}
    local lastWriteError = nil
    local savedPath = nil

    for _, candidatePath in ipairs(writableCandidates) do
        if not visitedPaths[candidatePath] then
            visitedPaths[candidatePath] = true
            local okWrite, errWrite = pcall(function()
                _fs.writefile(candidatePath, encoded)
            end)

            if okWrite then
                savedPath = candidatePath
                break
            else
                lastWriteError = errWrite
            end
        end
    end

    if not savedPath then
        return false, "Failed to write config file: " .. tostring(lastWriteError)
    end

    self._configPathHints[configName] = savedPath

    return true, savedPath
end

function _Lib:LoadConfig(fileName)
    if not _fs.readfile then
        return false, "readfile API is unavailable in this executor."
    end

    local configName = sanitizeConfigName(fileName)
    local path = nil
    local rawConfig = nil
    local readableCandidates = _getReadPaths(configName)
    local hintedPath = self._configPathHints and self._configPathHints[configName]

    if type(hintedPath) == "string" and hintedPath ~= "" then
        table.insert(readableCandidates, 1, hintedPath)
    end

    local visitedPaths = {}

    for _, candidatePath in ipairs(readableCandidates) do
        if not visitedPaths[candidatePath] then
            visitedPaths[candidatePath] = true

            local canRead = true
            if _fs.isfile then
                local okExists, exists = pcall(function()
                    return _fs.isfile(candidatePath)
                end)
                canRead = okExists and exists == true
            end

            if canRead then
                local okRead, fileData = pcall(function()
                    return _fs.readfile(candidatePath)
                end)

                if okRead and type(fileData) == "string" then
                    path = candidatePath
                    rawConfig = fileData
                    break
                end
            end
        end
    end
    if not path then
        return false, "Config file not found: " .. _getConfigPath() .. "/" .. _getConfigFile(configName)
    end

    local okDecode, data = pcall(function()
        return _hs:JSONDecode(rawConfig)
    end)
    if not okDecode or type(data) ~= "table" or type(data.controls) ~= "table" then
        return false, "Invalid config JSON format."
    end
    
    for flag, rawValue in pairs(data.controls) do
        local control = self._trackedControls[flag]
        if control then
            local decodedValue = deserializeConfigValue(rawValue)
            pcall(control.set, decodedValue)
        end
    end

    return true, path
end

function _Lib:CreateUI()
    local debugToken = self:_DebugBegin("Library.CreateUI")
    self._sgRef = _mk("ScreenGui", {
        Name = _sgName,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        IgnoreGuiInset = true
    })

    local parented = false
    for _, root in ipairs(_getUiRoots()) do
        local okParent = pcall(function()
            self._sgRef.Parent = root
        end)
        if okParent and self._sgRef.Parent then
            parented = true
            break
        end
    end
    if not parented then
        warn("[FlowUI] no writable UI parent yet; retrying in background")
        task.spawn(function()
            for _ = 1, 120 do
                if self._destroyed or not self._sgRef or self._sgRef.Parent then
                    return
                end
                for _, root in ipairs(_getUiRoots()) do
                    local okParent = pcall(function()
                        self._sgRef.Parent = root
                    end)
                    if okParent and self._sgRef.Parent then
                        self:_RefreshViewportMetrics()
                        self:_ClampMainFrameToViewport()
                        return
                    end
                end
                task.wait(0.25)
            end
        end)
    end

    self:_RefreshViewportMetrics()
    self:_TrackConnection(self._sgRef:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local okResize, resizeErr = pcall(function()
            self:_RefreshViewportMetrics()
            self:_InvalidateESPPreviewProjection(false)
            self:_ClampMainFrameToViewport()
        end)
        if not okResize then
            warn("[FlowUI] resize error: " .. tostring(resizeErr))
        end
    end))

    self._dimFrame = _mk("Frame", {
        Name = _sNames["BackdropDim"],
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 0,
        Parent = self._sgRef
    })

    self._snowFrame = _mk("Frame", {
        Name = _sNames["SnowLayer"],
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 2,
        ClipsDescendants = true,
        Parent = self._sgRef
    })
    
    self.dropdownHolderRef = _mk("Frame", {
        Name = _sNames["DropdownHolder"],
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 9999,
        Parent = self._sgRef
    })
    
    self:CreateMainFrame()

    task.defer(function()
        local okDeferred, deferredErr = pcall(function()
            if self._destroyed then
                return
            end
            local deferredDebugToken = self:_DebugBegin("Deferred.StartupExtras")
            if self._uiVisualSettings.ESPSelfPreview then
                self:_CreateESPPreviewPanel()
            end
            self:CreateNotificationHolder()
            self:CreateMobileToggle()
            self:_SetTextGradientEnabled(self._uiVisualSettings.TextGradient)
            self:_SetBackgroundEffectsEnabled(self._uiVisualSettings.BackgroundEffects)
            self:_SetOverlayMode(self._overlayMode)
            self:_ApplyOpenCloseVisuals(true)
            if not self._hasExplicitKeyDurationText then
                self:RefreshKeyInfo(false)
            end
            self:_PlayBootAnimation()
            self:_DebugEnd(deferredDebugToken, "startup extras")
        end)
        if not okDeferred then
            warn("[FlowUI] startup extras error: " .. tostring(deferredErr))
        end
    end)
    
    self:_TrackConnection(_uis.InputBegan:Connect(function(input, gameProcessed)
        local okInput, inputErr = pcall(function()
            if gameProcessed then return end
            local isPointerClick = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch
            if self._commandPaletteOpen and isPointerClick and self.commandPaletteFrame and self.searchFrame then
                local clickPos = input.Position
                local palettePos = self.commandPaletteFrame.AbsolutePosition
                local paletteSize = self.commandPaletteFrame.AbsoluteSize
                local searchPos = self.searchFrame.AbsolutePosition
                local searchSize = self.searchFrame.AbsoluteSize
                local insidePalette = clickPos.X >= palettePos.X and clickPos.X <= palettePos.X + paletteSize.X and clickPos.Y >= palettePos.Y and clickPos.Y <= palettePos.Y + paletteSize.Y
                local insideSearch = clickPos.X >= searchPos.X and clickPos.X <= searchPos.X + searchSize.X and clickPos.Y >= searchPos.Y and clickPos.Y <= searchPos.Y + searchSize.Y
                if not insidePalette and not insideSearch then
                    self:_SetCommandPaletteOpen(false)
                end
            end
            if input.KeyCode == self.toggleKeyCode then
                self:ToggleUI()
            elseif input.KeyCode == Enum.KeyCode.K and (_uis:IsKeyDown(Enum.KeyCode.LeftControl) or _uis:IsKeyDown(Enum.KeyCode.RightControl)) then
                if self.searchBox then
                    self.searchBox:CaptureFocus()
                end
                self:_SetCommandPaletteOpen(true, self.searchBox and self.searchBox.Text or "")
            elseif input.KeyCode == Enum.KeyCode.Escape then
                self:_SetCommandPaletteOpen(false)
            end
        end)
        if not okInput then
            warn("[FlowUI] input error: " .. tostring(inputErr))
        end
    end))
    
    self:_TrackConnection(_rs.RenderStepped:Connect(function(dt)
        local okStep, stepErr = pcall(function()
        if self._destroyed then return end
        
        local rollingIndex = self._fpsRollingIndex or 1
        local previousDt = self._fpsRollingWindow[rollingIndex] or 0
        if (self._fpsRollingCount or 0) >= self._fpsRollingSize then
            self._fpsRollingTotal = self._fpsRollingTotal - previousDt
        else
            self._fpsRollingCount = (self._fpsRollingCount or 0) + 1
        end
        self._fpsRollingWindow[rollingIndex] = dt
        self._fpsRollingTotal = self._fpsRollingTotal + dt
        rollingIndex = rollingIndex + 1
        if rollingIndex > self._fpsRollingSize then
            rollingIndex = 1
        end
        self._fpsRollingIndex = rollingIndex
        
        self._fpsComputeAccumulator = (self._fpsComputeAccumulator or 0) + dt
        if self._fpsComputeAccumulator >= 0.25 then
            self._fpsComputeAccumulator = 0
            if self._fpsRollingTotal > 0 and (self._fpsRollingCount or 0) > 0 then
                self._latestFPSValue = math.clamp(math.floor(((self._fpsRollingCount or 0) / self._fpsRollingTotal) + 0.5), 1, 360)
            end
        end
        local currentFps = self._latestFPSValue
        if currentFps > 0 and currentFps < _CRIT_FPS then
            self._perfSaverLevel = 2
        elseif currentFps > 0 and currentFps < _LOW_FPS then
            self._perfSaverLevel = 1
        elseif currentFps > 55 then
            self._perfSaverLevel = 0
        end

        local nowClock = os.clock()
        if not self._autoConfigLoadAttempted then
            if next(self._trackedControls) ~= nil and (nowClock - (self._lastControlRegistration or nowClock)) >= 1.25 then
                self:_TryAutoLoadConfig(false)
            end
        elseif self._autoConfigEnabled then
            self._autoConfigAccumulator = (self._autoConfigAccumulator or 0) + dt
            if self._autoConfigAccumulator >= (self._autoConfigInterval or 1.2) then
                self._autoConfigAccumulator = 0
                self:_TryAutoSaveConfig(false)
            end
        else
            self._autoConfigAccumulator = 0
        end
        
        local clampedDt = math.clamp(tonumber(dt) or (1 / 60), 1 / 240, 1 / 20)
        for scrollingFrame, state in pairs(self._smoothScrollFrames) do
            if not scrollingFrame or not scrollingFrame.Parent then
                self._smoothScrollFrames[scrollingFrame] = nil
            else
                local currentY = scrollingFrame.CanvasPosition.Y
                local goalY = state.targetY
                local diff = goalY - currentY
                if math.abs(diff) > 0.35 then
                    state.internal = true
                    local alpha = math.clamp(1 - math.exp(-(state.speed or 34) * clampedDt), 0.16, 1)
                    scrollingFrame.CanvasPosition = Vector2.new(scrollingFrame.CanvasPosition.X, currentY + diff * alpha)
                    state.internal = false
                elseif state.internal then
                    state.internal = false
                end
            end
        end

        if self._uiVisualSettings.ESPSelfPreview or self._espPreviewWasShowing then
            self:_UpdateESPPreview(dt)
        end
        self:_StepRefreshJobs(dt)
        self:_UpdateWatermark(dt)
        self:_UpdateKeyDurationLabel(dt)
        self._statusStripUpdateAccumulator = (self._statusStripUpdateAccumulator or 0) + (tonumber(dt) or 0)
        if self._statusStripUpdateAccumulator >= 0.35 then
            self._statusStripUpdateAccumulator = 0
            self:_UpdateStatusStrip()
        end
        if self._uiVisualSettings.TextGradient and #self._gradientObjects > 0 then
            self:_AnimateTextGradients(dt)
        end

        if self.isToggledOn and self._uiVisualSettings.BackgroundEffects and self.mainBackgroundEffectsFrame and self.mainBackgroundEffectsFrame.Visible then
            self._backgroundFxAccumulator = (self._backgroundFxAccumulator or 0) + dt
            local backgroundStep
            if self._perfSaverLevel >= 2 then
                backgroundStep = _isMobile and (1 / 6) or (1 / 8)
            elseif self._perfSaverLevel == 1 then
                backgroundStep = _isMobile and (1 / 9) or (1 / 12)
            else
                backgroundStep = _isMobile and (1 / 14) or (1 / 20)
            end
            if self._backgroundFxAccumulator >= backgroundStep then
                local backgroundDt = self._backgroundFxAccumulator
                self._backgroundFxAccumulator = 0
                self._backgroundFxTime = self._backgroundFxTime + backgroundDt
                if self.mainBackgroundGradient then
                    self.mainBackgroundGradient.Rotation = (self.mainBackgroundGradient.Rotation + backgroundDt * 8) % 360
                end
                if self.mainBackgroundAccentGlow then
                    local timeNow = self._backgroundFxTime
                    local xPos = 0.5 + math.sin(timeNow * 0.45) * 0.09
                    local yPos = 0.5 + math.cos(timeNow * 0.63) * 0.06
                    self.mainBackgroundAccentGlow.Position = UDim2.new(xPos, 0, yPos, 0)
                    self.mainBackgroundAccentGlow.ImageTransparency = 0.972 - (math.sin(timeNow * 1.6) + 1) * 0.006
                end
            end
        else
            self._backgroundFxAccumulator = 0
        end

        if self.isToggledOn and self._uiVisualSettings.Snow and self._snowFrame and self._snowFrame.Visible and self._overlayMode ~= "None" then
            self._overlayUpdateAccumulator = (self._overlayUpdateAccumulator or 0) + dt
            local overlayStep
            if self._perfSaverLevel >= 2 then
                overlayStep = _isMobile and (1 / 9) or (1 / 12)
            elseif self._perfSaverLevel == 1 then
                overlayStep = _isMobile and (1 / 12) or (1 / 16)
            else
                overlayStep = _isMobile and (1 / 18) or (1 / 26)
            end
            overlayStep = math.max(overlayStep, _MIN_PSTEP)

            if self._overlayUpdateAccumulator >= overlayStep then
                local overlayDt = math.min(self._overlayUpdateAccumulator, 0.12)
                self._overlayUpdateAccumulator = 0

                self._snowSpawnAccumulator = self._snowSpawnAccumulator + overlayDt
                local overlayMode = self._overlayMode
                local spawnInterval
                local maxParticles
                if overlayMode == "Rain" then
                    spawnInterval = _isMobile and 0.04 or 0.026
                    maxParticles = _isMobile and 34 or 72
                elseif overlayMode == "Stars" then
                    spawnInterval = _isMobile and 0.075 or 0.05
                    maxParticles = _isMobile and 34 or 72
                else
                    spawnInterval = _isMobile and 0.28 or 0.18
                    maxParticles = _isMobile and 18 or 36
                end

                local overlayQualityScale = self._cachedViewportAreaScale or 1
                if _isMobile then
                    overlayQualityScale = overlayQualityScale * 0.82
                end
                if currentFps > 0 then
                    if currentFps < _CRIT_FPS then
                        overlayQualityScale = overlayQualityScale * 0.28
                    elseif currentFps < 36 then
                        overlayQualityScale = overlayQualityScale * 0.4
                    elseif currentFps < 45 then
                        overlayQualityScale = overlayQualityScale * 0.55
                    elseif currentFps < 58 then
                        overlayQualityScale = overlayQualityScale * 0.72
                    elseif currentFps > 120 then
                        overlayQualityScale = overlayQualityScale * 1.04
                    end
                end
                overlayQualityScale = math.clamp(overlayQualityScale, _isMobile and 0.18 or 0.24, 0.92)
                spawnInterval = spawnInterval / math.max(overlayQualityScale, 0.35)
                maxParticles = math.max(overlayMode == "Snow" and 10 or 12, math.floor(maxParticles * overlayQualityScale))
                local maxSpawnBurst
                if overlayMode == "Rain" then
                    maxSpawnBurst = self._perfSaverLevel >= 1 and 2 or (_isMobile and 3 or 4)
                elseif overlayMode == "Stars" then
                    maxSpawnBurst = self._perfSaverLevel >= 1 and 1 or (_isMobile and 2 or 3)
                else
                    maxSpawnBurst = _isMobile and 1 or 2
                end
                self._snowSpawnAccumulator = math.min(self._snowSpawnAccumulator, spawnInterval * maxSpawnBurst)

                local spawnedThisStep = 0
                while self._snowSpawnAccumulator >= spawnInterval and #self._snowflakes < maxParticles and spawnedThisStep < maxSpawnBurst do
                    if overlayMode == "Rain" then
                        self:_SpawnRainDrop()
                    elseif overlayMode == "Stars" then
                        self:_SpawnStarParticle()
                    else
                        self:_SpawnSnowflake()
                    end
                    self._snowSpawnAccumulator = self._snowSpawnAccumulator - spawnInterval
                    spawnedThisStep = spawnedThisStep + 1
                end

                local nowTick = os.clock()
                local viewportHeight = self._cachedViewportHeight or 320
                local viewportWidth = self._cachedViewportWidth or 200
                local allowRainSplashes = overlayMode == "Rain" and overlayQualityScale > (_isMobile and 0.52 or 0.38)
                local snowflakes = self._snowflakes
                local i = #snowflakes
                while i >= 1 do
                    local flakeData = snowflakes[i]
                    local flakeObj = flakeData and flakeData.instance
                    if not flakeObj or not flakeObj.Parent then
                        local lastIdx = #snowflakes
                        snowflakes[i] = snowflakes[lastIdx]
                        snowflakes[lastIdx] = nil
                    else
                        local overlayType = flakeData.overlayType or "Snow"
                        if overlayType == "RainDrop" then
                            flakeData.yOffset = flakeData.yOffset + flakeData.velocityY * overlayDt
                            flakeData.xOffset = flakeData.xOffset + flakeData.velocityX * overlayDt
                            local windOffset = math.sin(nowTick * flakeData.driftSpeed + flakeData.phase) * flakeData.windJitter
                            local xPos = flakeData.xOffset + windOffset
                            flakeObj.Position = UDim2.new(0, xPos, 0, flakeData.yOffset)
                            flakeObj.Rotation = flakeData.angle
                            flakeObj.BackgroundTransparency = math.clamp(flakeData.baseTransparency + (math.sin(nowTick * 3.6 + flakeData.phase) * 0.07), 0.08, 0.9)
                            if flakeData.yOffset > viewportHeight + 20 then
                                if allowRainSplashes and xPos > -40 and xPos < viewportWidth + 40 and math.random() < (flakeData.splashChance * overlayQualityScale) then
                                    self:_SpawnRainSplash(xPos, viewportHeight - math.random(1, 8))
                                end
                                flakeObj:Destroy()
                                local lastIdx = #snowflakes
                                snowflakes[i] = snowflakes[lastIdx]
                                snowflakes[lastIdx] = nil
                            end
                        elseif overlayType == "RainSplash" then
                            flakeData.life = flakeData.life - overlayDt
                            if flakeData.life <= 0 then
                                flakeObj:Destroy()
                                local lastIdx = #snowflakes
                                snowflakes[i] = snowflakes[lastIdx]
                                snowflakes[lastIdx] = nil
                            else
                                local progress = 1 - (flakeData.life / flakeData.totalLife)
                                local widthNow = flakeData.startSize + flakeData.endSize * progress
                                local heightNow = math.max(1 * _mScale, flakeData.startThickness * (1 - progress * 0.8))
                                flakeObj.Size = UDim2.new(0, widthNow, 0, heightNow)
                                flakeObj.Position = UDim2.new(0, flakeData.baseX + flakeData.driftX * progress, 0, flakeData.yOffset - progress * 1.2)
                                flakeObj.BackgroundTransparency = math.clamp(flakeData.baseTransparency + progress * 0.55, 0.2, 0.97)
                            end
                        elseif overlayType == "Stars" then
                            flakeData.xOffset = flakeData.xOffset + flakeData.velocityX * overlayDt
                            flakeData.yOffset = flakeData.yOffset + flakeData.velocityY * overlayDt
                            local driftX = math.sin(nowTick * flakeData.driftSpeed + flakeData.phase) * flakeData.driftAmount
                            local driftY = math.cos(nowTick * (flakeData.driftSpeed * 0.72) + flakeData.phase) * flakeData.driftLift
                            local xPos = flakeData.xOffset + driftX
                            local yPos = flakeData.yOffset + driftY
                            if xPos < -16 then
                                flakeData.xOffset = viewportWidth + 16
                                xPos = flakeData.xOffset
                            elseif xPos > viewportWidth + 16 then
                                flakeData.xOffset = -16
                                xPos = flakeData.xOffset
                            end
                            if yPos < -16 then
                                flakeData.yOffset = viewportHeight + 16
                                yPos = flakeData.yOffset
                            elseif yPos > viewportHeight + 16 then
                                flakeData.yOffset = -16
                                yPos = flakeData.yOffset
                            end
                            flakeObj.Position = UDim2.new(0, xPos, 0, yPos)
                            local sparkle = (math.sin(nowTick * flakeData.twinkleSpeed + flakeData.phase) + 1) * 0.5
                            local pulse = 1 + (math.sin(nowTick * (flakeData.twinkleSpeed * 0.75) + flakeData.phase) * flakeData.pulseAmount)
                            local sizeNow = math.max(1 * _mScale, flakeData.baseSize * (0.82 + pulse * 0.36))
                            flakeObj.Size = UDim2.new(0, sizeNow, 0, sizeNow)
                            flakeObj.ImageTransparency = math.clamp(flakeData.baseTransparency - sparkle * 0.5, 0.01, 0.92)
                        else
                            flakeData.yOffset = flakeData.yOffset + flakeData.fallSpeed * overlayDt
                            local driftX = math.sin(nowTick * flakeData.driftSpeed + flakeData.phase) * flakeData.driftAmount
                            local swirlX = math.cos(nowTick * (flakeData.driftSpeed * 0.58) + flakeData.phase) * flakeData.swirlAmount
                            flakeObj.Position = UDim2.new(0, flakeData.baseX + driftX + swirlX, 0, flakeData.yOffset)
                            flakeObj.Rotation = (flakeObj.Rotation + flakeData.spin * overlayDt) % 360
                            local twinkle = (math.sin(nowTick * flakeData.twinkleSpeed + flakeData.phase) + 1) * 0.5
                            flakeObj.ImageTransparency = math.clamp(flakeData.baseTransparency + twinkle * 0.22, 0.08, 0.84)
                            if flakeData.yOffset > viewportHeight + 28 then
                                flakeObj:Destroy()
                                local lastIdx = #snowflakes
                                snowflakes[i] = snowflakes[lastIdx]
                                snowflakes[lastIdx] = nil
                            end
                        end
                    end
                    i = i - 1
                end
            end
        else
            self._overlayUpdateAccumulator = 0
        end
        end)
        if not okStep then
            self._perfSaverLevel = 2
            warn("[FlowUI] render step error: " .. tostring(stepErr))
        end
    end))
    self:_DebugEnd(debugToken, "CreateUI")
end

function _Lib:_PlayBootAnimation()
    if not self.mainFrameYay or not self.mainFrameScale or self.config.Motion == "Off" then
        return
    end
    self.mainFrameScale.Scale = self.config.Motion == "Reduced" and 0.99 or 0.975
    self:_Tween(self.mainFrameScale, {Scale = 1}, 0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.12)
    if self.contentHolderFrame then
        local targetPosition = self.contentHolderFrame.Position
        self.contentHolderFrame.Position = UDim2.new(targetPosition.X.Scale, targetPosition.X.Offset, targetPosition.Y.Scale, targetPosition.Y.Offset + 5 * _mScale)
        self:_Tween(self.contentHolderFrame, {Position = targetPosition}, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.1)
    end
end

function _Lib:ToggleUI()
    self.isToggledOn = not self.isToggledOn
    local openPosition = self._mainFrameOpenPosition or UDim2.new(0.5, -392 * _mScale, 0.5, -262 * _mScale)
    local closedPosition = self._mainFrameClosedPosition or UDim2.new(0.5, openPosition.X.Offset, 1.5, 0)
    self:_Tween(self.mainFrameYay, {
        Position = self.isToggledOn and openPosition or closedPosition
    }, 0.4, Enum.EasingStyle.Quint, self.isToggledOn and Enum.EasingDirection.Out or Enum.EasingDirection.In, 0.16)
    if self.mainFrameScale then
        self:_Tween(self.mainFrameScale, {Scale = self.isToggledOn and 1 or 0.985}, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.08)
    end
    if not self.isToggledOn then
        self:_SetCommandPaletteOpen(false)
    end
    self:_ApplyOpenCloseVisuals(false)
end

function _Lib:_ClampMainFrameToViewport()
    if not self.mainFrameYay or not self.mainFrameYay.Parent then
        return
    end
    local vpWidth = self._cachedViewportWidth or _gs.AbsoluteWindowSize.X
    local vpHeight = self._cachedViewportHeight or _gs.AbsoluteWindowSize.Y
    local desiredWidth = 830 * _mScale
    local desiredHeight = 530 * _mScale
    local newWidth = math.min(desiredWidth, vpWidth - 24)
    local newHeight = math.min(desiredHeight, vpHeight - 24)
    
    local currentSize = self.mainFrameYay.Size
    local currentPos = self.mainFrameYay.Position
    local sizeChanged = false
    
    if currentSize.X.Offset > newWidth or currentSize.Y.Offset > newHeight then
        self.mainFrameYay.Size = UDim2.new(0, newWidth, 0, newHeight)
        sizeChanged = true
    end
    
    local frameWidth = self.mainFrameYay.Size.X.Offset
    local frameHeight = self.mainFrameYay.Size.Y.Offset
    local minX = -vpWidth * currentPos.X.Scale
    local maxX = vpWidth * (1 - currentPos.X.Scale) - frameWidth
    local minY = -vpHeight * currentPos.Y.Scale
    local maxY = vpHeight * (1 - currentPos.Y.Scale) - frameHeight
    local newX = math.clamp(currentPos.X.Offset, minX, maxX)
    local newY = math.clamp(currentPos.Y.Offset, minY, maxY)
    
    if sizeChanged or math.abs(currentPos.X.Offset - newX) > 1 or math.abs(currentPos.Y.Offset - newY) > 1 then
        self.mainFrameYay.Position = UDim2.new(currentPos.X.Scale, newX, currentPos.Y.Scale, newY)
    end
    
    self._mainFrameOpenPosition = UDim2.new(0.5, -frameWidth / 2, 0.5, -frameHeight / 2)
    self._mainFrameClosedPosition = UDim2.new(0.5, -frameWidth / 2, 1.5, 0)
end

function _Lib:SetToggleButtonVisible(visible)
    self.toggleButtonVisible = visible
    if self.mobileToggleFrame then
        self.mobileToggleFrame.Visible = visible
    end
end

function _Lib:SetToggleKey(keyCode)
    self.toggleKeyCode = keyCode
end

function _Lib:_SetResolvedKeyDurationText(text, expiresAt)
    local keyText = tostring(text or "")
    if keyText == "" then
        keyText = "Key: Active"
    end
    self._keyDurationExpiresAt = tonumber(expiresAt)
    self.config.KeyDurationText = keyText
    if self.profileKeyLabel then
        self.profileKeyLabel.Text = keyText
    end
    self:_UpdateStatusStrip()
end

function _Lib:SetKeyDurationText(text)
    local keyText = tostring(text or "")
    if keyText == "" then
        keyText = "Key: Active"
    end
    self._keyDurationExpiresAt = nil
    self.config.KeyDurationText = keyText
    if self.profileKeyLabel then
        self.profileKeyLabel.Text = keyText
    end
end

function _Lib:RefreshKeyInfo(force)
    if self._luarmorKeyCheckInFlight and force ~= true then
        return false, "Key check already running."
    end

    local scriptKey = _resolveLrmKey()
    self._luarmorScriptKey = scriptKey
    local scriptId = tostring(self.config.LuarmorScriptId or self.config.LuarmorScriptID or self.config.ScriptId or self.config.ScriptID or "")

    if not scriptKey then
        local runtimeText, runtimeExpiresAt = _resolveLrmKeyText()
        if runtimeText then
            self:_SetResolvedKeyDurationText(runtimeText, runtimeExpiresAt)
            return true
        end
        self:_SetResolvedKeyDurationText("Key: Missing", nil)
        return false, "No script_key found."
    end

    if scriptId == "" or self.config.LuarmorKeyCheck == false then
        local runtimeText, runtimeExpiresAt = _resolveLrmKeyText()
        self:_SetResolvedKeyDurationText(runtimeText or "Key: Detected", runtimeExpiresAt)
        return true
    end

    if type(loadstring) ~= "function" or type(game.HttpGet) ~= "function" then
        local runtimeText, runtimeExpiresAt = _resolveLrmKeyText()
        self:_SetResolvedKeyDurationText(runtimeText or "Key: Detected", runtimeExpiresAt)
        return false, "Luarmor key check library cannot be loaded in this executor."
    end

    self._luarmorKeyCheckInFlight = true
    self:_SetResolvedKeyDurationText("Key: Checking...", nil)
    task.spawn(function()
        local okLibrary, api = pcall(function()
            return loadstring(game:HttpGet("https://sdkapi-public.luarmor.net/library.lua"))()
        end)
        if not okLibrary or type(api) ~= "table" or type(api.check_key) ~= "function" then
            self._luarmorKeyCheckInFlight = false
            local runtimeText, runtimeExpiresAt = _resolveLrmKeyText()
            self:_SetResolvedKeyDurationText(runtimeText or "Key: Check failed", runtimeExpiresAt)
            return
        end

        api.script_id = scriptId
        local okStatus, status = pcall(function()
            return api.check_key(scriptKey)
        end)
        self._luarmorKeyCheckInFlight = false
        if not okStatus then
            local runtimeText, runtimeExpiresAt = _resolveLrmKeyText()
            self:_SetResolvedKeyDurationText(runtimeText or "Key: Check failed", runtimeExpiresAt)
            return
        end

        self._luarmorKeyStatus = status
        local keyText, expiresAt = _fmtLrmStatus(status)
        self:_SetResolvedKeyDurationText(keyText, expiresAt)
    end)

    return true
end

function _Lib:SetLuarmorScriptId(scriptId, refreshNow)
    self.config.LuarmorScriptId = tostring(scriptId or "")
    if refreshNow ~= false then
        return self:RefreshKeyInfo(true)
    end
    return true
end

function _Lib:SetKeyDurationSeconds(seconds)
    seconds = tonumber(seconds)
    if not seconds then
        return self:SetKeyDurationText("Key: Active")
    end
    return self:SetKeyExpiresAt(os.time() + math.max(0, seconds))
end

function _Lib:SetKeyExpiresAt(unixTimestamp)
    self._keyDurationExpiresAt = tonumber(unixTimestamp)
    if self._keyDurationExpiresAt then
        self.config.KeyDurationText = _fmtKeyDur(self._keyDurationExpiresAt - os.time())
    else
        self.config.KeyDurationText = "Key: Active"
    end
    self:_UpdateKeyDurationLabel(999)
end

function _Lib:CreateMobileToggle()
    local barHeight = 34
    local initialText = self.config.Name .. " | 00:00:00 | 60 FPS"
    local textWidth = howWideIsThisText(initialText, 13.5, Enum.Font.GothamMedium)
    local vpWidth = self._cachedViewportWidth or _gs.AbsoluteWindowSize.X
    local barWidth = math.min(textWidth + 48, math.max(170, vpWidth - 24))
    
    self.mobileToggleFrame, self.mobileToggleStroke = _mkSurface(
        self._sgRef,
        _palette.Surface,
        UDim2.new(0.5, 0, 0, 8),
        UDim2.new(0, barWidth, 0, barHeight),
        {
            CornerRadius = _cornerTk.Card,
            BackgroundTransparency = 0.14,
            StrokeColor = _palette.Stroke,
            StrokeGradient = false
        }
    )
    self.mobileToggleFrame.Name = _sNames["MobileToggle"]
    self.mobileToggleFrame.AnchorPoint = Vector2.new(0.5, 0)
    
    self.mobileToggleGlow = _mk("ImageLabel", {
        Name = _sNames["GlowEffect"],
        BackgroundTransparency = 1,
        Image = _assetUrl("5028857084"),
        ImageColor3 = self.config.AccentColor,
        ImageTransparency = 1,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(1.25, 0, 1.25, 0),
        ZIndex = 0,
        Parent = self.mobileToggleFrame
    })
    
    _mk("ImageLabel", {
        Image = _assetUrl("95109736896642"),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0.5, -8),
        Size = UDim2.new(0, 16, 0, 16),
        Parent = self.mobileToggleFrame
    })
    
    self.mobileToggleBarTextLabel = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        TextColor3 = Color3.new(1, 1, 1),
        Text = initialText,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 0),
        TextSize = 13.5,
        Size = UDim2.new(1, -52, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = self.mobileToggleFrame
    })
    table.insert(self._gradientLabels, self.mobileToggleBarTextLabel)
    
    _mk("ImageLabel", {
        Image = _assetUrl("111626678408582"),
        BackgroundTransparency = 1,
        ImageColor3 = _palette.TextMuted,
        Position = UDim2.new(1, -18, 0.5, -5),
        Size = UDim2.new(0, 10, 0, 10),
        Parent = self.mobileToggleFrame
    })
    
    self.mobileToggleIcon = nil
    self.mobileToggleStateLabel = nil
    self.mobileToggleStateDot = nil
    self.mobileToggleAvatarFrame = nil
    self.mobileToggleAvatarStroke = nil
    self.mobileToggleAvatarImg = nil
    
    local mobileToggleBtn = _mk("TextButton", {
        Name = _sNames["ClickButton"],
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = self.mobileToggleFrame
    })
    
    mobileToggleBtn.MouseButton1Click:Connect(function()
        self:ToggleUI()
        _tween(self.mobileToggleFrame, {Size = UDim2.new(0, barWidth - 6, 0, barHeight - 4)}, 0.08)
        task.delay(0.1, function()
            _tween(self.mobileToggleFrame, {Size = UDim2.new(0, barWidth, 0, barHeight)}, 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end)
    end)
    
    mobileToggleBtn.MouseEnter:Connect(function()
        self.mobileToggleHovered = true
        self:_RefreshMobileToggleVisuals(false)
    end)
    
    mobileToggleBtn.MouseLeave:Connect(function()
        self.mobileToggleHovered = false
        self:_RefreshMobileToggleVisuals(false)
    end)
    
    self:_RefreshMobileToggleVisuals(true)
    _mkDrag(self.mobileToggleFrame, nil, self)
end

function _Lib:CreateWatermark()
    local isFullWatermark = self.config.WatermarkStyle == "Full"
    local watermarkTextSize = (isFullWatermark and 13.6 or 12.1) * _mScale
    local watermarkHeight = (isFullWatermark and 34 or 28) * _mScale
    local watermarkIconSize = (isFullWatermark and 14 or 13) * _mScale
    local initialText = isFullWatermark and (self.config.Name .. " | 00:00:00 | 60 FPS") or (self.config.Name .. " | 60 FPS")
    local initialWidth = howWideIsThisText(initialText, watermarkTextSize, Enum.Font.GothamSemibold) + (isFullWatermark and 42 or 36) * _mScale
    
    self.watermarkFrame = _mk("Frame", {
        Name = _sNames["Watermark"],
        BackgroundColor3 = _palette.Panel,
        BackgroundTransparency = 0.04,
        Position = UDim2.new(0, 4 * _mScale, 0.215, 0),
        BorderSizePixel = 0,
        Size = UDim2.new(0, initialWidth, 0, watermarkHeight),
        Parent = self._sgRef
    })
    
    _mkCorner(self.watermarkFrame, _cornerTk.Card)
    _mk("UIStroke", {Color = _palette.TacticalLine, Transparency = 0.48, Parent = self.watermarkFrame})
    
    _mk("ImageLabel", {
        Image = _brandIcon, BackgroundTransparency = 1,
        Position = UDim2.new(0, (isFullWatermark and 10 or 9) * _mScale, 0.5, -watermarkIconSize * 0.5),
        Size = UDim2.new(0, watermarkIconSize, 0, watermarkIconSize),
        Parent = self.watermarkFrame
    })
    
    self.watermarkTextLabel = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        TextColor3 = Color3.new(1, 1, 1), Text = initialText, BackgroundTransparency = 1,
        Position = UDim2.new(0, (isFullWatermark and 31 or 28) * _mScale, 0, 0),
        TextSize = watermarkTextSize,
        Size = UDim2.new(1, -(isFullWatermark and 38 or 33) * _mScale, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.watermarkFrame
    })
    table.insert(self._gradientLabels, self.watermarkTextLabel)
    
    _mkDrag(self.watermarkFrame, nil, self)
end

function _Lib:_UpdateWatermark(dt)
    local hasWatermark = self.watermarkFrame and self.watermarkFrame.Parent and self.watermarkTextLabel and self.watermarkTextLabel.Parent
    local hasMobileBar = self.mobileToggleFrame and self.mobileToggleFrame.Parent and self.mobileToggleBarTextLabel and self.mobileToggleBarTextLabel.Parent
    
    if not hasWatermark and not hasMobileBar then
        return
    end

    self._watermarkUpdateAccumulator = (self._watermarkUpdateAccumulator or 0) + (tonumber(dt) or 0)
    if self._watermarkUpdateAccumulator < 0.6 then
        return
    end
    self._watermarkUpdateAccumulator = 0

    local timeNow = os.date("%H:%M:%S")
    local fpsCount = self._latestFPSValue > 0 and self._latestFPSValue or 0
    local isFullWatermark = self.config.WatermarkStyle == "Full"
    local watermarkTextSize = (isFullWatermark and 13.6 or 12.1) * _mScale
    local watermarkHeight = (isFullWatermark and 34 or 28) * _mScale
    local newText = isFullWatermark and (self.config.Name .. " | " .. timeNow .. " | " .. fpsCount .. " FPS") or (self.config.Name .. " | " .. fpsCount .. " FPS")
    
    if hasWatermark then
        if self.watermarkTextLabel.Text ~= newText then
            self.watermarkTextLabel.Text = newText
        end
        local newWidth = howWideIsThisText(newText, watermarkTextSize, Enum.Font.GothamSemibold) + (isFullWatermark and 42 or 36) * _mScale
        if math.abs(newWidth - (self._watermarkLastWidth or 0)) > 1 then
            self._watermarkLastWidth = newWidth
            _tween(self.watermarkFrame, {Size = UDim2.new(0, newWidth, 0, watermarkHeight)}, 0.18)
        end
    end
    
    if hasMobileBar then
        if self.mobileToggleBarTextLabel.Text ~= newText then
            self.mobileToggleBarTextLabel.Text = newText
        end
        local textWidth = howWideIsThisText(newText, 13.5, Enum.Font.GothamMedium)
        local desiredWidth = textWidth + 48
        local vpWidth = self._cachedViewportWidth or _gs.AbsoluteWindowSize.X
        local cappedWidth = math.min(desiredWidth, math.max(180, vpWidth - 24))
        if math.abs(cappedWidth - (self._mobileBarLastWidth or 0)) > 1 then
            self._mobileBarLastWidth = cappedWidth
            _tween(self.mobileToggleFrame, {Size = UDim2.new(0, cappedWidth, 0, 34)}, 0.18)
        end
    end
end

function _Lib:_UpdateKeyDurationLabel(dt)
    if not self.profileKeyLabel or not self.profileKeyLabel.Parent or not self._keyDurationExpiresAt then
        return
    end

    self._keyDurationUpdateAccumulator = (self._keyDurationUpdateAccumulator or 0) + (tonumber(dt) or 0)
    if self._keyDurationUpdateAccumulator < 1 then
        return
    end
    self._keyDurationUpdateAccumulator = 0

    local keyText = _fmtKeyDur(self._keyDurationExpiresAt - os.time())
    self.config.KeyDurationText = keyText
    self.profileKeyLabel.Text = keyText
end

function _Lib:_UpdateStatusStrip()
    if not self.statusStripLabel or not self.statusStripLabel.Parent then
        return
    end

    local tabName = self._curTab and self._curTab.tabNameForSearch or "No tab"
    local tabCount = #self._tabs
    local fpsCount = self._latestFPSValue > 0 and self._latestFPSValue or 0
    local keyText = tostring(self.config.KeyDurationText or "Key: Active")
    local newText = "Ready  |  " .. tostring(tabName) .. "  |  " .. tostring(tabCount) .. " tabs  |  " .. tostring(fpsCount) .. " FPS  |  " .. keyText
    if self.statusStripLabel.Text ~= newText then
        self.statusStripLabel.Text = newText
    end
end

function _Lib:CreateMainFrame()
    local debugToken = self:_DebugBegin("Library.CreateMainFrame")
    local vpWidth = self._cachedViewportWidth or _gs.AbsoluteWindowSize.X
    local vpHeight = self._cachedViewportHeight or _gs.AbsoluteWindowSize.Y
    
    local desiredFrameWidth = 830 * _mScale
    local desiredFrameHeight = 530 * _mScale
    local frameWidth = math.min(desiredFrameWidth, vpWidth - 24)
    local frameHeight = math.min(desiredFrameHeight, vpHeight - 24)
    
    local isComfortableDensity = self.config.Density == "Comfortable"
    local headerLeftPadding = (isComfortableDensity and 15 or 13) * _mScale
    local searchWidth = (isComfortableDensity and 224 or 214) * _mScale
    local searchRightPadding = 12 * _mScale
    local headerHeight = (isComfortableDensity and 62 or 58) * _mScale
    local headerControlHeight = (isComfortableDensity and 28 or 26) * _mScale
    local profileCardHeight = 54 * _mScale
    local statusStripHeight = self.config.ShowStatusStrip and (26 * _mScale) or 0
    
    local sectionScrollWidth = math.min(162 * _mScale, math.max(100 * _mScale, frameWidth * 0.22))
    local minContentStartX = 17 + sectionScrollWidth + 6
    local desiredContentStartX = 210 * _mScale
    local contentStartX = math.max(minContentStartX, math.min(desiredContentStartX, frameWidth * 0.32))
    
    local contentRightPadding = 10 * _mScale
    local bodyTop = headerHeight + (isComfortableDensity and 11 or 8) * _mScale
    local sectionScrollHeight = math.max(180 * _mScale, frameHeight - bodyTop - profileCardHeight - 28 * _mScale)
    local contentHeight = frameHeight - bodyTop - 12 * _mScale - statusStripHeight
    self._mainFrameOpenPosition = UDim2.new(0.5, -frameWidth/2, 0.5, -frameHeight/2)
    self._mainFrameClosedPosition = UDim2.new(0.5, -frameWidth/2, 1.5, 0)
    
    self.mainFrameYay = _mk("Frame", {
        Name = _sNames["MainFrame"],
        BackgroundColor3 = self.config.BackgroundColor or _palette.Shell,
        Position = self._mainFrameOpenPosition,
        BorderSizePixel = 0,
        Size = UDim2.new(0, frameWidth, 0, frameHeight),
        ClipsDescendants = true,
        Parent = self._sgRef
    })
    
    _mkCorner(self.mainFrameYay, _cornerTk.Shell)
    self.mainFrameScale = _mk("UIScale", {
        Scale = 1,
        Parent = self.mainFrameYay
    })

    self.mainBackgroundEffectsFrame = _mk("Frame", {
        Name = _sNames["BackgroundEffects"],
        BackgroundColor3 = _palette.Shell,
        BackgroundTransparency = 0.72,
        Size = UDim2.new(1, 0, 1, 0),
        ClipsDescendants = true,
        Visible = self._uiVisualSettings.BackgroundEffects == true,
        ZIndex = 0,
        Parent = self.mainFrameYay
    })
    _mkCorner(self.mainBackgroundEffectsFrame, _cornerTk.Shell)
    self.mainBackgroundGradient = _mk("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, _palette.Shell),
            ColorSequenceKeypoint.new(0.52, _palette.Surface),
            ColorSequenceKeypoint.new(1, _palette.Canvas)
        }),
        Rotation = 215,
        Parent = self.mainBackgroundEffectsFrame
    })
    self.mainBackgroundAccentGlow = _mk("ImageLabel", {
        Name = _sNames["AccentGlow"],
        BackgroundTransparency = 1,
        Image = _assetUrl("5028857084"),
        ImageColor3 = self.config.AccentColor,
        ImageTransparency = 0.975,
        Size = UDim2.new(1.65, 0, 1.65, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 0,
        Parent = self.mainBackgroundEffectsFrame
    })
    
    self.dragBarThing = _mk("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 65 * _mScale), Parent = self.mainFrameYay
    })
    
    _mkDrag(self.mainFrameYay, self.dragBarThing, self)
    
    self.commandHeaderFrame = _mk("Frame", {
        BackgroundColor3 = _palette.Panel,
        BackgroundTransparency = 0,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, headerHeight),
        ZIndex = 1,
        Parent = self.mainFrameYay
    })
    self.commandHeaderDivider = _mk("Frame", {
        BackgroundColor3 = _palette.TacticalLine,
        BackgroundTransparency = 0.42,
        Position = UDim2.new(0, 0, 0, headerHeight),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 2,
        Parent = self.mainFrameYay
    })

    local searchX = frameWidth - searchWidth - searchRightPadding
    local headerBrandIconFrameWidth = 32 * _mScale
    local headerBrandIconFrameHeight = 32 * _mScale
    local headerBrandIconSize = 30 * _mScale
    local headerBrandTextX = headerLeftPadding + headerBrandIconFrameWidth + 8 * _mScale
    local headerNameMaxWidth = math.max(105 * _mScale, contentStartX - headerBrandTextX - 14 * _mScale)
    local tabHeaderX = contentStartX + 16 * _mScale
    local separatorWidth = math.max(120 * _mScale, contentStartX - 28 * _mScale)
    local contentWidth = frameWidth - contentStartX - contentRightPadding
    local headerCenterWidth = math.max(80 * _mScale, searchX - tabHeaderX - 132 * _mScale)
    local mainTextColor = self.config.TextColor or _palette.Text
    local subTextColor = self.config.SubTextColor or _palette.TextMuted

    self.sidebarSurfaceFrame = _mk("Frame", {
        BackgroundColor3 = _palette.Canvas,
        BackgroundTransparency = 0,
        Position = UDim2.new(0, 0, 0, headerHeight + 1),
        Size = UDim2.new(0, contentStartX - 1, 1, -(headerHeight + 1)),
        ZIndex = 0,
        Parent = self.mainFrameYay
    })
    _mkCorner(self.sidebarSurfaceFrame, _cornerTk.Large)
    
    self.hubIconFrame = _mk("Frame", {
        BackgroundColor3 = _palette.Canvas,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Position = UDim2.new(0, headerLeftPadding, 0, math.floor((headerHeight - headerBrandIconFrameHeight) * 0.5)),
        Size = UDim2.new(0, headerBrandIconFrameWidth, 0, headerBrandIconFrameHeight),
        ZIndex = 3,
        Parent = self.mainFrameYay
    })

    local headerBrandIcon = tostring(self.config.Icon or self.config.Logo or self.config.BrandIcon or _brandIcon)
    if headerBrandIcon == "" then
        headerBrandIcon = _brandIcon
    end

    self.hubIconImg = _mk("ImageLabel", {
        Image = headerBrandIcon,
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, -headerBrandIconSize * 0.5, 0.5, -headerBrandIconSize * 0.5),
        Size = UDim2.new(0, headerBrandIconSize, 0, headerBrandIconSize),
        ScaleType = Enum.ScaleType.Fit,
        ResampleMode = Enum.ResamplerMode.Default,
        ZIndex = 5,
        Parent = self.hubIconFrame
    })

    self.hubNameLabel = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        TextColor3 = mainTextColor, Text = self.config.Name, BackgroundTransparency = 1,
        Position = UDim2.new(0, headerBrandTextX, 0, math.floor((headerHeight - 19 * _mScale) * 0.5) - 1), TextSize = 15.2 * _mScale,
        Size = UDim2.new(0, headerNameMaxWidth, 0, 20 * _mScale),
        TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, Parent = self.mainFrameYay
    })
    table.insert(self._gradientLabels, self.hubNameLabel)
    
    local playerName = "@" .. _getPlayerName()
    
    self.lineSeperator = _mk("Frame", {
        BackgroundColor3 = _palette.TacticalLine,
        BackgroundTransparency = 0.55,
        Position = UDim2.new(0, 14 * _mScale, 0, headerHeight),
        Size = UDim2.new(0, separatorWidth, 0, 1), Parent = self.mainFrameYay
    })
    
    self.tabNameLabel = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        TextColor3 = mainTextColor, Text = "tab name", BackgroundTransparency = 1,
        Position = UDim2.new(0, tabHeaderX, 0, 9 * _mScale),
        TextSize = 16.4 * _mScale, Size = UDim2.new(0, headerCenterWidth, 0, 20 * _mScale),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = self.mainFrameYay
    })
    table.insert(self._gradientLabels, self.tabNameLabel)
    
    self.tabDescriptionLabel = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        TextColor3 = subTextColor:Lerp(_palette.TextSoft, 0.25), Text = "tab description", BackgroundTransparency = 1,
        Position = UDim2.new(0, tabHeaderX, 0, 28 * _mScale),
        TextSize = 12.3 * _mScale, Size = UDim2.new(0, headerCenterWidth, 0, 18 * _mScale),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = self.mainFrameYay
    })

    self.searchFrame = _mk("Frame", {
        BackgroundColor3 = _palette.ControlInset,
        Position = UDim2.new(0, searchX, 0, math.floor((headerHeight - headerControlHeight) * 0.5)),
        Size = UDim2.new(0, searchWidth, 0, headerControlHeight),
        Parent = self.mainFrameYay
    })
    _mkCorner(self.searchFrame, _cornerTk.Pill)
    _mk("UIStroke", {Color = _palette.TacticalLine, Transparency = 0.44, Parent = self.searchFrame})
    _mk("ImageLabel", {
        Image = _assetUrl("10734943674"),
        ImageColor3 = _palette.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0.5, -7 * _mScale),
        Size = UDim2.new(0, 14 * _mScale, 0, 14 * _mScale),
        Parent = self.searchFrame
    })
    self.searchBox = _mk("TextBox", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        Text = "",
        PlaceholderText = "Search tabs/groups...",
        PlaceholderColor3 = _palette.FieldPlaceholder,
        TextColor3 = _palette.FieldText,
        TextSize = 13 * _mScale,
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        Position = UDim2.new(0, 28 * _mScale, 0, 0),
        Size = UDim2.new(1, -34 * _mScale, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.searchFrame
    })
    self:_TrackConnection(self.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self:ApplySearchFilter(self.searchBox.Text)
        if self._commandPaletteOpen then
            self:_RefreshCommandPalette(self.searchBox.Text)
        end
    end))
    self:_TrackConnection(self.searchBox.Focused:Connect(function()
        self:_Tween(self.searchFrame, {BackgroundColor3 = _palette.SurfaceSoft}, 0.2)
        self:_Tween(self.searchFrame:FindFirstChildOfClass("UIStroke"), {Color = self.config.AccentColor:Lerp(_palette.StrokeStrong, 0.42), Transparency = 0.12}, 0.2)
        self:_SetCommandPaletteOpen(true, self.searchBox.Text)
    end))
    self:_TrackConnection(self.searchBox.FocusLost:Connect(function()
        self:_Tween(self.searchFrame, {BackgroundColor3 = _palette.ControlInset}, 0.2)
        self:_Tween(self.searchFrame:FindFirstChildOfClass("UIStroke"), {Color = _palette.TacticalLine, Transparency = 0.44}, 0.2)
    end))

    self._commandPaletteWidth = math.min(330 * _mScale, math.max(250 * _mScale, searchWidth + 106 * _mScale))
    self._commandPaletteHeight = 236 * _mScale
    self.commandPaletteFrame = _mk("Frame", {
        BackgroundColor3 = _palette.SurfaceOverlay,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        Position = UDim2.new(0, math.max(contentStartX + 12 * _mScale, searchX + searchWidth - self._commandPaletteWidth), 0, headerHeight + 8 * _mScale),
        Size = UDim2.new(0, self._commandPaletteWidth, 0, 0),
        ZIndex = 50,
        Parent = self.mainFrameYay
    })
    _mkCorner(self.commandPaletteFrame, _cornerTk.Large)
    _mk("UIStroke", {Color = _palette.StrokeStrong, Transparency = 0.2, Parent = self.commandPaletteFrame})
    _mkLabel(self.commandPaletteFrame, self, "Command Palette", UDim2.new(0, 12 * _mScale, 0, 9 * _mScale), UDim2.new(1, -24 * _mScale, 0, 16 * _mScale), {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        TextColor = mainTextColor,
        TextSize = 12.5 * _mScale,
        ZIndex = 51
    })
    self.commandPaletteHintLabel = _mkLabel(self.commandPaletteFrame, self, "Search tabs and groups", UDim2.new(0, 12 * _mScale, 0, 25 * _mScale), UDim2.new(1, -24 * _mScale, 0, 13 * _mScale), {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        TextColor = _palette.TextSoft,
        TextSize = 10.5 * _mScale,
        ZIndex = 51
    })
    self.commandPaletteListFrame = _mk("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 6 * _mScale, 0, 45 * _mScale),
        Size = UDim2.new(1, -12 * _mScale, 1, -52 * _mScale),
        ZIndex = 51,
        Parent = self.commandPaletteFrame
    })
    
    self.sectionHolderScroll = _mk("ScrollingFrame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 17, 0, bodyTop),
        Size = UDim2.new(0, sectionScrollWidth, 0, sectionScrollHeight),
        BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ClipsDescendants = true, ZIndex = 3, Parent = self.mainFrameYay
    })
    _attachScrollbar(self, self.sectionHolderScroll, self.mainFrameYay, {
        TrackWidth = 7 * _mScale,
        ThumbWidth = 3 * _mScale,
        EdgeInset = 3 * _mScale,
        VerticalInset = 5 * _mScale,
        IdleThumbHeight = 42 * _mScale,
        AlwaysShowTrack = false,
        ZIndex = 6
    })
    
    _mk("UIPadding", {
        PaddingLeft = UDim.new(0, 4 * _mScale),
        PaddingRight = UDim.new(0, 4 * _mScale),
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 8 * _mScale),
        Parent = self.sectionHolderScroll
    })
    self.sectionLayoutThing = _mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = self.sectionHolderScroll})
    --self:EnableSmoothScrolling(self.sectionHolderScroll, 34)

    local profileCardWidth = math.max(120 * _mScale, contentStartX - 30 * _mScale)
    local profileAvatarSize = 26 * _mScale
    self.sidebarProfileFrame = _mk("Frame", {
        BackgroundColor3 = _palette.Canvas,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 15 * _mScale, 1, -(profileCardHeight + 11 * _mScale)),
        Size = UDim2.new(0, profileCardWidth, 0, profileCardHeight),
        ZIndex = 4,
        Parent = self.mainFrameYay
    })
    _mkCorner(self.sidebarProfileFrame, _cornerTk.Card)
    self.sidebarProfileStroke = _mk("UIStroke", {Color = _palette.TacticalLine, Transparency = 0.72, Parent = self.sidebarProfileFrame})
    self.sidebarProfileScale = _mk("UIScale", {Scale = 1, Parent = self.sidebarProfileFrame})

    self.playerAvatarImg = _mk("ImageLabel", {
        Image = _defAvatar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8 * _mScale, 0, 9 * _mScale),
        Size = UDim2.new(0, profileAvatarSize, 0, profileAvatarSize),
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 5,
        Parent = self.sidebarProfileFrame
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = self.playerAvatarImg})
    loadPlayerAvatarAsync(self.playerAvatarImg, _getPlayerUserId())

    self.profileUserNameLabel = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        TextColor3 = mainTextColor,
        Text = playerName,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 42 * _mScale, 0, 8 * _mScale),
        Size = UDim2.new(1, -50 * _mScale, 0, 16 * _mScale),
        TextSize = 12.2 * _mScale,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
        Parent = self.sidebarProfileFrame
    })
    self.profileKeyLabel = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
        TextColor3 = _palette.TextSoft,
        Text = self.config.KeyDurationText,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 42 * _mScale, 0, 27 * _mScale),
        Size = UDim2.new(1, -50 * _mScale, 0, 15 * _mScale),
        TextSize = 11.1 * _mScale,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
        Parent = self.sidebarProfileFrame
    })
    local profileHoverButton = _mk("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 6,
        Parent = self.sidebarProfileFrame
    })
    profileHoverButton.MouseEnter:Connect(function()
        self:_Tween(self.sidebarProfileFrame, {BackgroundColor3 = _palette.SurfaceAlt}, 0.14)
        self:_Tween(self.sidebarProfileStroke, {Transparency = 0.52}, 0.14)
    end)
    profileHoverButton.MouseLeave:Connect(function()
        self:_Tween(self.sidebarProfileFrame, {BackgroundColor3 = _palette.Canvas}, 0.14)
        self:_Tween(self.sidebarProfileStroke, {Transparency = 0.72}, 0.14)
    end)
    self:_SetNameHidden(self._uiVisualSettings.HideName)
    
    self.sidebarDivider = _mk("Frame", {
        BackgroundColor3 = _palette.TacticalLine,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        Position = UDim2.new(0, contentStartX - 1, 0, headerHeight + 1),
        Size = UDim2.new(0, 1, 1, -(headerHeight + 1)),
        Parent = self.mainFrameYay
    })
    
    self.contentHolderFrame = _mk("Frame", {
        BackgroundColor3 = _palette.Canvas,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.new(0, contentStartX, 0, bodyTop),
        Size = UDim2.new(0, contentWidth, 0, contentHeight),
        ClipsDescendants = true, Parent = self.mainFrameYay
    })
    _mkCorner(self.contentHolderFrame, _cornerTk.Large)
    self.contentHolderStroke = _mk("UIStroke", {
        Color = _palette.TacticalLine,
        Transparency = 0.76,
        Thickness = 1,
        Parent = self.contentHolderFrame
    })
    _mk("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, _palette.Canvas),
            ColorSequenceKeypoint.new(0.72, _palette.Surface),
            ColorSequenceKeypoint.new(1, _palette.SurfaceAlt)
        }),
        Rotation = 90,
        Parent = self.contentHolderFrame
    })
    self.contentWidth = contentWidth
    self.sectionScrollWidth = sectionScrollWidth

    if self.config.ShowStatusStrip then
        self.statusStripFrame = _mk("Frame", {
            BackgroundColor3 = _palette.SurfaceAlt,
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0,
            Position = UDim2.new(0, contentStartX, 1, -(statusStripHeight + 8 * _mScale)),
            Size = UDim2.new(0, contentWidth, 0, statusStripHeight),
            Parent = self.mainFrameYay
        })
        _mkCorner(self.statusStripFrame, _cornerTk.Card)
        _mk("UIStroke", {Color = _palette.Stroke, Transparency = 0.3, Parent = self.statusStripFrame})
        self.statusStripLabel = _mkLabel(self.statusStripFrame, self, "Ready", UDim2.new(0, 10 * _mScale, 0, 0), UDim2.new(1, -20 * _mScale, 1, 0), {
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
            TextColor = _palette.TextMuted,
            TextSize = 11.5 * _mScale,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
    end

    local settingsPanelWidth = math.max(160 * _mScale, contentStartX - 28 * _mScale)
    local settingsPanelY = headerHeight + 10 * _mScale
    local settingsPanelAvailableHeight = frameHeight - settingsPanelY - profileCardHeight - 24 * _mScale
    local settingsPanelHeight = math.max(180 * _mScale, math.min(292 * _mScale, settingsPanelAvailableHeight))
    local settingsButtonWidth = 94 * _mScale
    local settingsButtonX = searchX - settingsButtonWidth - 12 * _mScale
    local settingsPanelX = 14 * _mScale
    local settingsPanelOpenPosition = UDim2.new(0, settingsPanelX, 0, settingsPanelY)
    local settingsPanelClosedPosition = UDim2.new(0, settingsPanelX - 10 * _mScale, 0, settingsPanelY)
    self.uiSettingsOpen = false

    self.uiSettingsButtonFrame = _mk("Frame", {
        BackgroundColor3 = _palette.SurfaceSoft,
        Position = UDim2.new(0, settingsButtonX, 0, math.floor((headerHeight - headerControlHeight) * 0.5)),
        Size = UDim2.new(0, settingsButtonWidth, 0, headerControlHeight),
        BorderSizePixel = 0,
        ZIndex = 12,
        Parent = self.mainFrameYay
    })
    _mkCorner(self.uiSettingsButtonFrame, _cornerTk.Pill)
    self.uiSettingsButtonStroke = _mk("UIStroke", {Color = _palette.Stroke, Transparency = 0.18, Parent = self.uiSettingsButtonFrame})

    _mk("ImageLabel", {
        Image = _assetUrl("10734950309"),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8 * _mScale, 0.5, -7 * _mScale),
        Size = UDim2.new(0, 14 * _mScale, 0, 14 * _mScale),
        ImageColor3 = _palette.TextMuted,
        Parent = self.uiSettingsButtonFrame
    })
    _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        Text = "Settings",
        TextColor3 = _palette.TextMuted,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 29 * _mScale, 0, 0),
        Size = UDim2.new(1, -35 * _mScale, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 12.5 * _mScale,
        Parent = self.uiSettingsButtonFrame
    })
    local settingsToggleButton = _mk("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = self.uiSettingsButtonFrame
    })

    task.defer(function()
        if self._destroyed or not self.mainFrameYay or not self.mainFrameYay.Parent then
            return
        end
        local settingsDebugToken = self:_DebugBegin("Deferred.SettingsPanel")

    self.uiSettingsPanelFrame = _mk("Frame", {
        BackgroundColor3 = _palette.SurfaceAlt,
        AnchorPoint = Vector2.new(0, 0),
        Position = settingsPanelClosedPosition,
        Size = UDim2.new(0, settingsPanelWidth, 0, 0),
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 40,
        Parent = self.mainFrameYay
    })
    _mkCorner(self.uiSettingsPanelFrame, _cornerTk.Large)
    _mk("UIStroke", {Color = _palette.Stroke, Transparency = 0.14, Parent = self.uiSettingsPanelFrame})

    _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        Text = "Interface",
        TextColor3 = mainTextColor,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 8 * _mScale),
        Size = UDim2.new(0.7, 0, 0, 16 * _mScale),
        TextSize = 13 * _mScale,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.uiSettingsPanelFrame
    })

    self.uiAccentPreviewFrame = _mk("Frame", {
        BackgroundColor3 = self.config.AccentColor,
        Position = UDim2.new(1, -22 * _mScale, 0, 11 * _mScale),
        Size = UDim2.new(0, 10 * _mScale, 0, 10 * _mScale),
        Parent = self.uiSettingsPanelFrame
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = self.uiAccentPreviewFrame})

    local rowY = 30 * _mScale
    local rowStep = 24 * _mScale
    local function createSettingsToggle(labelText, initial, callback)
        local rowFrame = _mk("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, rowY),
            Size = UDim2.new(1, -20, 0, 20 * _mScale),
            Parent = self.uiSettingsPanelFrame
        })
        _mk("TextLabel", {
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
            Text = labelText,
            TextColor3 = Color3.fromRGB(150, 150, 150),
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -46 * _mScale, 1, 0),
            TextSize = 12 * _mScale,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = rowFrame
        })
        local switchFrame = _mk("Frame", {
            BackgroundColor3 = initial and self.config.AccentColor or Color3.fromRGB(14, 14, 14),
            Position = UDim2.new(1, -34 * _mScale, 0.5, -8 * _mScale),
            Size = UDim2.new(0, 34 * _mScale, 0, 16 * _mScale),
            Parent = rowFrame
        })
        _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = switchFrame})
        local knob = _mk("Frame", {
            BackgroundColor3 = initial and Color3.new(1, 1, 1) or Color3.fromRGB(80, 80, 80),
            Position = initial and UDim2.new(0.5, 0, 0.5, -6 * _mScale) or UDim2.new(0, 2 * _mScale, 0.5, -6 * _mScale),
            Size = UDim2.new(0, 12 * _mScale, 0, 12 * _mScale),
            Parent = switchFrame
        })
        _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})

        local state = initial == true
        local function setState(nextState, skipCallback)
            state = nextState == true
            _tween(switchFrame, {BackgroundColor3 = state and self.config.AccentColor or Color3.fromRGB(14, 14, 14)}, 0.16)
            _tween(knob, {
                Position = state and UDim2.new(0.5, 0, 0.5, -6 * _mScale) or UDim2.new(0, 2 * _mScale, 0.5, -6 * _mScale),
                BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(80, 80, 80)
            }, 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            if not skipCallback then
                _safeCallback(callback, state)
            end
        end

        local toggleButton = _mk("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Parent = rowFrame
        })
        toggleButton.MouseButton1Click:Connect(function()
            setState(not state, false)
        end)

        rowY = rowY + rowStep
        return {
            Set = setState,
            Get = function()
                return state
            end
        }
    end

    local blurToggleRef = createSettingsToggle("Blur Background", self._uiVisualSettings.Blur, function(enabled)
        self._uiVisualSettings.Blur = enabled
        self:_ApplyOpenCloseVisuals(false)
    end)
    local overlayToggleRef = createSettingsToggle("Overlay FX", self._uiVisualSettings.Snow, function(enabled)
        self:_SetSnowEnabled(enabled)
    end)
    local bgFxToggleRef = createSettingsToggle("Background FX", self._uiVisualSettings.BackgroundEffects, function(enabled)
        self:_SetBackgroundEffectsEnabled(enabled)
    end)
    local gradientToggleRef = createSettingsToggle("Text Gradient", self._uiVisualSettings.TextGradient, function(enabled)
        self:_SetTextGradientEnabled(enabled)
    end)
    local espPreviewToggleRef = createSettingsToggle("ESP Preview", self._uiVisualSettings.ESPSelfPreview, function(enabled)
        self:SetESPPreviewEnabled(enabled)
    end)
    local hideNameToggleRef = createSettingsToggle("Hide Name", self._uiVisualSettings.HideName, function(enabled)
        self:_SetNameHidden(enabled)
    end)
    local autoSaveToggleRef = nil
    if self.config.ShowAutoSaveToggle ~= false then
        autoSaveToggleRef = createSettingsToggle("Auto Save Config", self._autoConfigEnabled, function(enabled)
            self._autoConfigEnabled = enabled == true
            if self._autoConfigEnabled then
                self._autoConfigLoadAttempted = false
                self._autoConfigAccumulator = self._autoConfigInterval or 1.2
                self:_TryAutoSaveConfig(true)
            else
                self._autoConfigAccumulator = 0
            end
        end)
    end

    self.uiSettingsToggleRefs = {blurToggleRef, overlayToggleRef, bgFxToggleRef, gradientToggleRef, espPreviewToggleRef, hideNameToggleRef}
    if autoSaveToggleRef then
        table.insert(self.uiSettingsToggleRefs, autoSaveToggleRef)
    end

    local overlayRow = _mk("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, rowY + 2 * _mScale),
        Size = UDim2.new(1, -20, 0, 20 * _mScale),
        Parent = self.uiSettingsPanelFrame
    })
    _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        Text = "Overlay",
        TextColor3 = Color3.fromRGB(150, 150, 150),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 52 * _mScale, 1, 0),
        TextSize = 12 * _mScale,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = overlayRow
    })

    local overlayPickerFrame = _mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        Position = UDim2.new(1, -84 * _mScale, 0, 0),
        Size = UDim2.new(0, 84 * _mScale, 1, 0),
        Parent = overlayRow
    })
    _mkCorner(overlayPickerFrame, _cornerTk.Pill)
    _mk("UIStroke", {Color = Color3.fromRGB(24, 24, 24), Parent = overlayPickerFrame})

    self.uiOverlayModeValueLabel = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        Text = self._overlayMode,
        TextColor3 = Color3.fromRGB(210, 210, 210),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8 * _mScale, 0, 0),
        Size = UDim2.new(1, -24 * _mScale, 1, 0),
        TextSize = 11.5 * _mScale,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = overlayPickerFrame
    })

    local overlayArrowImage = _mk("ImageLabel", {
        Image = _assetUrl("111626678408582"),
        ImageColor3 = Color3.fromRGB(132, 132, 132),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -18 * _mScale, 0.5, -6 * _mScale),
        Size = UDim2.new(0, 12 * _mScale, 0, 12 * _mScale),
        Parent = overlayPickerFrame
    })

    local overlayDropdownWidth = 102 * _mScale
    local overlayDropdownRowHeight = 21 * _mScale
    local overlayDropdownFrame = _mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        Size = UDim2.new(0, overlayDropdownWidth, 0, 0),
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 9999,
        Parent = self.dropdownHolderRef
    })
    _mkCorner(overlayDropdownFrame, _cornerTk.Card)
    _mk("UIStroke", {Color = Color3.fromRGB(18, 18, 18), Parent = overlayDropdownFrame})

    local overlayDropdownContainer = _mk("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 4 * _mScale, 0, 4 * _mScale),
        Size = UDim2.new(1, -8 * _mScale, 0, 0),
        ZIndex = 10000,
        Parent = overlayDropdownFrame
    })

    local overlayDropdownOpen = false
    local overlayDropdownPositionConn = nil
    local overlayDropdownOutsideConn = nil

    local function updateOverlayDropdownPosition()
        local pickerAbsPos = overlayPickerFrame.AbsolutePosition
        local pickerAbsSize = overlayPickerFrame.AbsoluteSize
        overlayDropdownFrame.Position = UDim2.new(0, pickerAbsPos.X + pickerAbsSize.X - overlayDropdownWidth, 0, pickerAbsPos.Y + pickerAbsSize.Y + 5)
    end

    local function closeOverlayDropdown(isInstant)
        overlayDropdownOpen = false
        if overlayDropdownPositionConn then
            overlayDropdownPositionConn()
            overlayDropdownPositionConn = nil
        end
        if overlayDropdownOutsideConn then
            overlayDropdownOutsideConn:Disconnect()
            overlayDropdownOutsideConn = nil
        end
        _tween(overlayArrowImage, {Rotation = 0}, 0.16)
        _tween(overlayPickerFrame, {BackgroundColor3 = Color3.fromRGB(10, 10, 10)}, 0.16)
        if isInstant then
            overlayDropdownFrame.Size = UDim2.new(0, overlayDropdownWidth, 0, 0)
            overlayDropdownFrame.Visible = false
            return
        end
        _tween(overlayDropdownFrame, {Size = UDim2.new(0, overlayDropdownWidth, 0, 0)}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.18, function()
            if overlayDropdownFrame and overlayDropdownFrame.Parent and not overlayDropdownOpen then
                overlayDropdownFrame.Visible = false
            end
        end)
    end

    local rebuildOverlayDropdownOptions
    rebuildOverlayDropdownOptions = function()
        for _, child in ipairs(overlayDropdownContainer:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextButton") then
                child:Destroy()
            end
        end
        local optionY = 0
        for _, modeName in ipairs(self._overlayModes) do
            local isSelected = modeName == self._overlayMode
            local optionFrame = _mk("Frame", {
                BackgroundColor3 = isSelected and Color3.fromRGB(14, 14, 14) or Color3.fromRGB(8, 8, 8),
                Position = UDim2.new(0, 0, 0, optionY),
                Size = UDim2.new(1, 0, 0, overlayDropdownRowHeight - 2 * _mScale),
                ZIndex = 10001,
                Parent = overlayDropdownContainer
            })
            _mkCorner(optionFrame, _cornerTk.Micro)
            local optionLabel = _mk("TextLabel", {
                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                Text = modeName,
                TextColor3 = isSelected and Color3.new(1, 1, 1) or Color3.fromRGB(138, 138, 138),
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -8 * _mScale, 1, 0),
                Position = UDim2.new(0, 8 * _mScale, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = 11.5 * _mScale,
                ZIndex = 10002,
                Parent = optionFrame
            })
            local optionButton = _mk("TextButton", {
                Text = "",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 10003,
                Parent = optionFrame
            })
            optionButton.MouseButton1Click:Connect(function()
                self:_SetOverlayMode(modeName)
                self.uiOverlayModeValueLabel.Text = self._overlayMode
                rebuildOverlayDropdownOptions()
                closeOverlayDropdown(false)
            end)
            optionButton.MouseEnter:Connect(function()
                if self._overlayMode ~= modeName then
                    _tween(optionFrame, {BackgroundColor3 = Color3.fromRGB(12, 12, 12)}, 0.12)
                    _tween(optionLabel, {TextColor3 = Color3.fromRGB(188, 188, 188)}, 0.12)
                end
            end)
            optionButton.MouseLeave:Connect(function()
                if self._overlayMode ~= modeName then
                    _tween(optionFrame, {BackgroundColor3 = Color3.fromRGB(8, 8, 8)}, 0.12)
                    _tween(optionLabel, {TextColor3 = Color3.fromRGB(138, 138, 138)}, 0.12)
                end
            end)
            optionY = optionY + overlayDropdownRowHeight
        end
        overlayDropdownContainer.Size = UDim2.new(1, -8 * _mScale, 0, optionY)
    end

    local function openOverlayDropdown()
        overlayDropdownOpen = true
        rebuildOverlayDropdownOptions()
        updateOverlayDropdownPosition()
        overlayDropdownFrame.Visible = true
        _tween(overlayDropdownFrame, {Size = UDim2.new(0, overlayDropdownWidth, 0, #self._overlayModes * overlayDropdownRowHeight + 8 * _mScale)}, 0.2)
        _tween(overlayArrowImage, {Rotation = 180}, 0.16)
        _tween(overlayPickerFrame, {BackgroundColor3 = Color3.fromRGB(14, 14, 14)}, 0.16)
        if overlayDropdownPositionConn then
            overlayDropdownPositionConn()
            overlayDropdownPositionConn = nil
        end
        overlayDropdownPositionConn = startFloatingPositionTracker(self, overlayPickerFrame, function()
            if overlayDropdownOpen then
                updateOverlayDropdownPosition()
            end
        end)
        if overlayDropdownOutsideConn then
            overlayDropdownOutsideConn:Disconnect()
            overlayDropdownOutsideConn = nil
        end
        overlayDropdownOutsideConn = self:_TrackConnection(_uis.InputBegan:Connect(function(input)
            if not overlayDropdownOpen then
                return
            end
            local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.Touch
            if not isClick then
                return
            end
            local clickPos = input.Position
            local menuPos = overlayDropdownFrame.AbsolutePosition
            local menuSize = overlayDropdownFrame.AbsoluteSize
            local pickerPos = overlayPickerFrame.AbsolutePosition
            local pickerSize = overlayPickerFrame.AbsoluteSize
            local insideMenu = clickPos.X >= menuPos.X and clickPos.X <= menuPos.X + menuSize.X and clickPos.Y >= menuPos.Y and clickPos.Y <= menuPos.Y + menuSize.Y
            local insidePicker = clickPos.X >= pickerPos.X and clickPos.X <= pickerPos.X + pickerSize.X and clickPos.Y >= pickerPos.Y and clickPos.Y <= pickerPos.Y + pickerSize.Y
            if not insideMenu and not insidePicker then
                closeOverlayDropdown(false)
            end
        end))
    end

    local overlayPickerButton = _mk("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = overlayPickerFrame
    })
    overlayPickerButton.MouseButton1Click:Connect(function()
        if overlayDropdownOpen then
            closeOverlayDropdown(false)
        else
            openOverlayDropdown()
        end
    end)
    overlayPickerButton.MouseEnter:Connect(function()
        if not overlayDropdownOpen then
            _tween(overlayPickerFrame, {BackgroundColor3 = Color3.fromRGB(14, 14, 14)}, 0.12)
        end
    end)
    overlayPickerButton.MouseLeave:Connect(function()
        if not overlayDropdownOpen then
            _tween(overlayPickerFrame, {BackgroundColor3 = Color3.fromRGB(10, 10, 10)}, 0.12)
        end
    end)

    rowY = rowY + rowStep

    local fontRow = _mk("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, rowY + 2 * _mScale),
        Size = UDim2.new(1, -20, 0, 20 * _mScale),
        Parent = self.uiSettingsPanelFrame
    })
    _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        Text = "Font",
        TextColor3 = Color3.fromRGB(150, 150, 150),
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 34 * _mScale, 1, 0),
        TextSize = 12 * _mScale,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = fontRow
    })
    self.uiSettingsFontValueLabel = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        Text = self._fontPresets[self._fontPresetIndex].Name,
        TextColor3 = Color3.fromRGB(210, 210, 210),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 36 * _mScale, 0, 0),
        Size = UDim2.new(0, 82 * _mScale, 1, 0),
        TextSize = 12 * _mScale,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = fontRow
    })
    local fontCycleFrame = _mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        Position = UDim2.new(1, -44 * _mScale, 0, 0),
        Size = UDim2.new(0, 44 * _mScale, 1, 0),
        Parent = fontRow
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fontCycleFrame})
    _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        Text = "Next",
        TextColor3 = Color3.fromRGB(190, 190, 190),
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextSize = 11 * _mScale,
        Parent = fontCycleFrame
    })
    local fontCycleButton = _mk("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = fontCycleFrame
    })
    fontCycleButton.MouseButton1Click:Connect(function()
        self:ApplyFontPreset(self._fontPresetIndex + 1)
    end)

    local accentRowY = rowY + 28 * _mScale
    _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        Text = "Accent",
        TextColor3 = Color3.fromRGB(150, 150, 150),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, accentRowY),
        Size = UDim2.new(0, 46 * _mScale, 0, 16 * _mScale),
        TextSize = 12 * _mScale,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.uiSettingsPanelFrame
    })
    local accentColors = {
        Color3.fromRGB(0, 116, 215),
        Color3.fromRGB(42, 166, 104),
        Color3.fromRGB(205, 80, 80),
        Color3.fromRGB(218, 145, 58),
        Color3.fromRGB(142, 102, 205)
    }
    for index, color in ipairs(accentColors) do
        local swatch = _mk("Frame", {
            BackgroundColor3 = color,
            Position = UDim2.new(0, (58 + (index - 1) * 22) * _mScale, 0, accentRowY - 1 * _mScale),
            Size = UDim2.new(0, 16 * _mScale, 0, 16 * _mScale),
            Parent = self.uiSettingsPanelFrame
        })
        _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = swatch})
        local swatchClick = _mk("TextButton", {
            Text = "",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Parent = swatch
        })
        swatchClick.MouseButton1Click:Connect(function()
            self:SetAccentColor(color)
            blurToggleRef:Set(self._uiVisualSettings.Blur, true)
            overlayToggleRef:Set(self._uiVisualSettings.Snow, true)
            bgFxToggleRef:Set(self._uiVisualSettings.BackgroundEffects, true)
            gradientToggleRef:Set(self._uiVisualSettings.TextGradient, true)
        end)
    end

    local function setSettingsPanelOpen(openState)
        self.uiSettingsOpen = openState == true
        if self.uiSettingsOpen then
            self.uiSettingsPanelFrame.Visible = true
            self.uiSettingsPanelFrame.Position = settingsPanelClosedPosition
            if self.sectionHolderScroll then
                self.sectionHolderScroll.Visible = false
            end
            self:_Tween(self.uiSettingsPanelFrame, {Size = UDim2.new(0, settingsPanelWidth, 0, settingsPanelHeight), Position = settingsPanelOpenPosition}, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.09)
            self:_Tween(self.uiSettingsButtonFrame, {BackgroundColor3 = _palette.SurfaceHover}, 0.2)
            self:_Tween(self.uiSettingsButtonStroke, {Color = self.config.AccentColor:Lerp(Color3.fromRGB(6, 6, 6), 0.45)}, 0.2)
            local staggerIndex = 0
            for _, child in ipairs(self.uiSettingsPanelFrame:GetChildren()) do
                if child:IsA("GuiObject") and child ~= self.uiSettingsPanelFrame then
                    local targetPosition = child.Position
                    child.Position = UDim2.new(targetPosition.X.Scale, targetPosition.X.Offset - 4 * _mScale, targetPosition.Y.Scale, targetPosition.Y.Offset)
                    staggerIndex = staggerIndex + 1
                    task.delay(self:_MotionDuration(staggerIndex * 0.012, 0), function()
                        if child and child.Parent and self.uiSettingsOpen then
                            self:_Tween(child, {Position = targetPosition}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.06)
                        end
                    end)
                end
            end
        else
            closeOverlayDropdown(true)
            self:_Tween(self.uiSettingsPanelFrame, {Size = UDim2.new(0, settingsPanelWidth, 0, 0), Position = settingsPanelClosedPosition}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0.07)
            self:_Tween(self.uiSettingsButtonFrame, {BackgroundColor3 = _palette.SurfaceSoft}, 0.2)
            self:_Tween(self.uiSettingsButtonStroke, {Color = _palette.Stroke}, 0.2)
            task.delay(self:_MotionDuration(0.18, 0.07), function()
                if self.uiSettingsPanelFrame and self.uiSettingsPanelFrame.Parent and not self.uiSettingsOpen then
                    self.uiSettingsPanelFrame.Visible = false
                end
                if self.sectionHolderScroll and self.sectionHolderScroll.Parent and not self.uiSettingsOpen then
                    self.sectionHolderScroll.Visible = true
                end
            end)
        end
    end

    settingsToggleButton.MouseButton1Click:Connect(function()
        setSettingsPanelOpen(not self.uiSettingsOpen)
    end)
    settingsToggleButton.MouseEnter:Connect(function()
        _tween(self.uiSettingsButtonFrame, {BackgroundColor3 = _palette.SurfaceHover}, 0.15)
    end)
    settingsToggleButton.MouseLeave:Connect(function()
        if not self.uiSettingsOpen then
            _tween(self.uiSettingsButtonFrame, {BackgroundColor3 = _palette.SurfaceSoft}, 0.15)
        end
    end)
    self:_DebugEnd(settingsDebugToken, "settings panel")
    end)
    self:_DebugEnd(debugToken, "CreateMainFrame")
end

function _Lib:CreateNotificationHolder()
    if self.notificationHolderFrame and self.notificationHolderFrame.Parent then
        return self.notificationHolderFrame
    end
    self.notificationHolderFrame = _mk("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 300 * _mScale, 0, 400),
        Parent = self._sgRef
    })
    _mk("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = self.notificationHolderFrame})
    return self.notificationHolderFrame
end

function _Lib:Notify(config)
    config = config or {}
    config.Title = tostring(config.Title or "Notification")
    config.Description = tostring(config.Description or "")
    config.Duration = tonumber(config.Duration) or 3
    config.Duration = math.max(0.8, config.Duration)
    config.Icon = config.Icon or _assetUrl("10747361219")

    if self._destroyed or self._isApplyingConfig then
        return nil
    end
    if not self.notificationHolderFrame or not self.notificationHolderFrame.Parent then
        self:CreateNotificationHolder()
    end

    local notificationKey = config.Title .. "\31" .. config.Description
    local nowClock = os.clock()
    if nowClock - (self._lastNotificationAnyAt or 0) < 0.08 then
        return nil
    end
    self._lastNotificationAnyAt = nowClock
    local lastNotificationAt = self._notificationTimestamps[notificationKey]
    if lastNotificationAt and (nowClock - lastNotificationAt) < 0.85 then
        return nil
    end
    self._notificationTimestamps[notificationKey] = nowClock
    
    local hasDescription = normalizeSearchText(config.Description) ~= ""
    local titleBounds = _txs:GetTextSize(
        config.Title,
        15 * _mScale,
        Enum.Font.GothamSemibold,
        Vector2.new(210 * _mScale, math.huge)
    )
    local descBounds = Vector2.new(0, 0)
    if hasDescription then
        descBounds = _txs:GetTextSize(
            config.Description,
            13 * _mScale,
            Enum.Font.GothamSemibold,
            Vector2.new(220 * _mScale, math.huge)
        )
    end
    
    local notifWidth = math.max(190 * _mScale, math.min(310 * _mScale, math.max(titleBounds.X, descBounds.X) + 84 * _mScale))
    local notifHeight = hasDescription and (66 * _mScale) or (52 * _mScale)
    
    local notificationFrame = _mk("Frame", {
        BackgroundColor3 = _palette.Surface,
        Position = UDim2.new(-1.25, 0, 0, 0),
        Size = UDim2.new(0, notifWidth, 0, notifHeight),
        BackgroundTransparency = 0.18,
        ClipsDescendants = true,
        Parent = self.notificationHolderFrame
    })
    _mkCorner(notificationFrame, _cornerTk.Large)
    local notificationStroke = _mk("UIStroke", {
        Color = Color3.fromRGB(28, 28, 28),
        Thickness = 1.1,
        Parent = notificationFrame
    })
    _mk("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, _palette.SurfaceAlt),
            ColorSequenceKeypoint.new(1, _palette.Surface)
        }),
        Rotation = 22,
        Parent = notificationFrame
    })
    local uiScaleRef = _mk("UIScale", {Scale = 0.88, Parent = notificationFrame})
    
    local glowEffect = _mk("ImageLabel", {
        Name = _sNames["NotifGlow"],
        BackgroundTransparency = 1,
        Image = _assetUrl("5028857084"),
        ImageColor3 = self.config.AccentColor,
        ImageTransparency = 0.96,
        Position = UDim2.new(0.25, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(1.8, 0, 2, 0),
        ZIndex = 0,
        Parent = notificationFrame
    })
    
    local accentBar = _mk("Frame", {
        BackgroundColor3 = self.config.AccentColor,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0, 4 * _mScale, 1, 0),
        Parent = notificationFrame
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = accentBar})
    
    local iconHolder = _mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(8, 8, 8),
        Position = UDim2.new(0, 12 * _mScale, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 28 * _mScale, 0, 28 * _mScale),
        Parent = notificationFrame
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = iconHolder})
    _mk("UIStroke", {
        Color = self.config.AccentColor:Lerp(Color3.fromRGB(0, 0, 0), 0.55),
        Thickness = 1.1,
        Parent = iconHolder
    })
    
    local notifImageLabel = _mk("ImageLabel", {
        Image = config.Icon,
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 17 * _mScale, 0, 17 * _mScale),
        ImageTransparency = 1,
        Parent = iconHolder
    })
    
    local textStartX = 48 * _mScale
    local notifTitle = _mk("TextLabel", {
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
        TextColor3 = Color3.new(1, 1, 1),
        Text = config.Title,
        BackgroundTransparency = 1,
        Position = hasDescription and UDim2.new(0, textStartX, 0, 8 * _mScale) or UDim2.new(0, textStartX, 0.5, -9 * _mScale),
        TextSize = 15 * _mScale,
        Size = UDim2.new(1, -textStartX - 12 * _mScale, 0, 18 * _mScale),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextTransparency = 1,
        Parent = notificationFrame
    })
    
    local notifDescription = nil
    if hasDescription then
        notifDescription = _mk("TextLabel", {
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
            TextColor3 = Color3.fromRGB(170, 170, 170),
            Text = config.Description,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, textStartX, 0, 28 * _mScale),
            TextSize = 12.5 * _mScale,
            Size = UDim2.new(1, -textStartX - 12 * _mScale, 0, 16 * _mScale),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextTransparency = 1,
            Parent = notificationFrame
        })
    end
    
    local progressTrack = _mk("Frame", {
        BackgroundColor3 = Color3.fromRGB(12, 12, 12),
        Position = UDim2.new(0, 10 * _mScale, 1, -6 * _mScale),
        Size = UDim2.new(1, -20 * _mScale, 0, 2 * _mScale),
        BorderSizePixel = 0,
        Parent = notificationFrame
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = progressTrack})
    
    local progressFill = _mk("Frame", {
        BackgroundColor3 = self.config.AccentColor,
        Size = UDim2.new(1, 0, 1, 0),
        BorderSizePixel = 0,
        Parent = progressTrack
    })
    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = progressFill})
    
    local progressTween = nil

    table.insert(self._notifs, notificationFrame)
    while #self._notifs > 5 do
        local oldestNotification = table.remove(self._notifs, 1)
        if oldestNotification and oldestNotification.Parent then
            oldestNotification:Destroy()
        end
    end
    
    task.defer(function()
        if not notificationFrame or not notificationFrame.Parent then return end
        _tween(notificationFrame, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.05}, 0.44, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        _tween(uiScaleRef, {Scale = 1}, 0.44, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        _tween(glowEffect, {ImageTransparency = 0.8}, 0.3)
        _tween(notificationStroke, {Color = self.config.AccentColor:Lerp(Color3.fromRGB(8, 8, 8), 0.65)}, 0.3)
        _tween(notifImageLabel, {ImageTransparency = 0}, 0.24)
        _tween(notifTitle, {TextTransparency = 0}, 0.24)
        if notifDescription then
            _tween(notifDescription, {TextTransparency = 0}, 0.24)
        end
        progressTween = _tween(progressFill, {Size = UDim2.new(0, 0, 1, 0)}, config.Duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    end)
    
    task.delay(config.Duration, function()
        if notificationFrame and notificationFrame.Parent then
            if progressTween then
                pcall(function()
                    progressTween:Cancel()
                end)
            end
            _tween(glowEffect, {ImageTransparency = 1}, 0.2)
            _tween(notifImageLabel, {ImageTransparency = 1}, 0.2)
            _tween(notifTitle, {TextTransparency = 1}, 0.2)
            if notifDescription then
                _tween(notifDescription, {TextTransparency = 1}, 0.2)
            end
            _tween(notificationFrame, {Position = UDim2.new(-1.25, 0, 0, 0), BackgroundTransparency = 1}, 0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            _tween(uiScaleRef, {Scale = 0.9}, 0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            task.delay(0.4, function()
                if notificationFrame and notificationFrame.Parent then
                    notificationFrame:Destroy()
                end
            end)
        end
        for index = #self._notifs, 1, -1 do
            if self._notifs[index] == notificationFrame then
                table.remove(self._notifs, index)
                break
            end
        end
    end)
    return notificationFrame
end

function _Lib:CreateSection(config)
    config = config or {}
    config.Name = config.Name or "Section"
    config.Icon = config.Icon or _assetUrl("98092584632154")
    local sectionDebugToken = self:_DebugBegin("CreateSection")
    self:_DebugCount("Sections", 1)
    
    local sectionObj = {}
    sectionObj.tabsInSection = {}
    sectionObj.isExpanded = true
    sectionObj.Library = self
    
    local ssw = sectionObj.Library.sectionScrollWidth or (162 * _mScale)
    local containerWidth = ssw - 8 * _mScale
    local mainFrameWidth = ssw - 20 * _mScale
    local headerHeight = 27 * _mScale
    local tabHolderWidth = math.max(80 * _mScale, mainFrameWidth - 11 * _mScale)
    local tabButtonHeight = 27 * _mScale
    local tabButtonPadding = 3 * _mScale
    local tabTopOffset = 36 * _mScale
    local sectionLabelWidth = math.max(20, mainFrameWidth - 62 * _mScale)
    local cleanSidebar = sectionObj.Library.config.SidebarStyle ~= "Classic"
    sectionObj.containerWidth = containerWidth
    sectionObj.tabHolderWidth = tabHolderWidth
    
    sectionObj.containerFrame = _mk("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(0, containerWidth, 0, headerHeight + 4 * _mScale),
        ClipsDescendants = true, LayoutOrder = #self._sections + 1, Parent = self.sectionHolderScroll
    })
    
    sectionObj.mainFrame = _mkSurface(
        sectionObj.containerFrame,
        cleanSidebar and _palette.Canvas or _palette.Surface,
        UDim2.new(0, 2 * _mScale, 0, 2 * _mScale),
        UDim2.new(0, mainFrameWidth, 0, headerHeight),
        {
            CornerRadius = _cornerTk.Panel,
            StrokeColor = cleanSidebar and _palette.TacticalLine or _palette.Stroke,
            StrokeGradient = false,
            BackgroundTransparency = cleanSidebar and 1 or 0
        }
    )
    local sectionMainStroke = sectionObj.mainFrame:FindFirstChildOfClass("UIStroke")
    if sectionMainStroke and cleanSidebar then
        sectionMainStroke.Transparency = 1
    end
    
    _mkIcon(
        sectionObj.mainFrame,
        config.Icon,
        sectionObj.Library.config.AccentColor:Lerp(_getSubClr(sectionObj.Library), 0.18),
        UDim2.new(0, 9 * _mScale, 0.5, -7.5 * _mScale),
        UDim2.new(0, 15 * _mScale, 0, 15 * _mScale),
        {FallbackImage = config.FallbackIcon or _assetUrl("7734053495")}
    )
    
    _mkLabel(
        sectionObj.mainFrame,
        sectionObj.Library,
        config.Name,
        UDim2.new(0, 31 * _mScale, 0.5, -8.5 * _mScale),
        UDim2.new(0, sectionLabelWidth, 0, 17 * _mScale),
        {
            TextColor = _getTextClr(sectionObj.Library),
            TextSize = 13.4 * _mScale,
            TextTruncate = Enum.TextTruncate.AtEnd
        }
    )
    
    local expandButtonImg = _mkIcon(
        sectionObj.mainFrame,
        _assetUrl("7733723321"),
        _getSubClr(sectionObj.Library):Lerp(_palette.Canvas, 0.16),
        UDim2.new(1, -22 * _mScale, 0.5, -7 * _mScale),
        UDim2.new(0, 14 * _mScale, 0, 14 * _mScale),
        {FallbackImage = _assetUrl("7734053495")}
    )
    
    sectionObj.tabHolderFrame = _mk("Frame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 11 * _mScale, 0, tabTopOffset),
        Size = UDim2.new(0, tabHolderWidth, 0, 0), ClipsDescendants = true, Parent = sectionObj.containerFrame
    })
    
    sectionObj.tabLayoutThing = _mk("UIListLayout", {Padding = UDim.new(0, tabButtonPadding), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sectionObj.tabHolderFrame})
    
    -- Do not depend on UIListLayout.AbsoluteContentSize for first paint; some games delay layout updates under load.
    local function getImmediateTabsHeight()
        local totalHeight = 0
        local visibleTabs = 0
        for _, tab in ipairs(sectionObj.tabsInSection) do
            local buttonFrame = tab and tab.buttonFrame
            if buttonFrame and buttonFrame.Visible ~= false then
                visibleTabs = visibleTabs + 1
                local buttonSize = tab.defaultButtonSize or buttonFrame.Size
                totalHeight = totalHeight + math.max(0, buttonSize.Y.Offset)
            end
        end
        if visibleTabs > 1 then
            totalHeight = totalHeight + ((visibleTabs - 1) * tabButtonPadding)
        end
        return totalHeight
    end

    local function updateContainerSizeYay(animate)
        local tabsHeight = getImmediateTabsHeight()
        if tabsHeight <= 0 and sectionObj.tabLayoutThing then
            tabsHeight = sectionObj.tabLayoutThing.AbsoluteContentSize.Y
        end
        sectionObj.tabHolderFrame.Size = UDim2.new(0, tabHolderWidth, 0, tabsHeight)
        local targetHeight = sectionObj.isExpanded and (tabTopOffset + tabsHeight + 8 * _mScale) or (headerHeight + 4 * _mScale)
        local targetSize = UDim2.new(0, containerWidth, 0, targetHeight)
        if animate == false then
            sectionObj.containerFrame.Size = targetSize
        else
            _tween(sectionObj.containerFrame, {Size = targetSize}, 0.25)
        end
    end
    sectionObj.UpdateSize = updateContainerSizeYay
    
    self:_TrackConnection(sectionObj.tabLayoutThing:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateContainerSizeYay))
    
    local sectionHeaderButton = _mk("TextButton", {
        Text = "",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = sectionObj.mainFrame
    })
    sectionHeaderButton.MouseEnter:Connect(function()
        _tween(sectionObj.mainFrame, {BackgroundColor3 = _palette.SurfaceSoft, BackgroundTransparency = cleanSidebar and 0.82 or 0}, 0.18)
    end)
    sectionHeaderButton.MouseLeave:Connect(function()
        _tween(sectionObj.mainFrame, {BackgroundColor3 = cleanSidebar and _palette.Canvas or _palette.Surface, BackgroundTransparency = cleanSidebar and 1 or 0}, 0.18)
    end)
    self:_TrackConnection(sectionHeaderButton.MouseButton1Click:Connect(function()
        sectionObj.isExpanded = not sectionObj.isExpanded
        _tween(expandButtonImg, {
            Rotation = sectionObj.isExpanded and 0 or -90,
            ImageTransparency = sectionObj.isExpanded and 0 or 0.34
        }, 0.25)
        updateContainerSizeYay(true)
    end))

    function sectionObj:AddTab(tabConfig)
        if type(tabConfig) == "string" then
            tabConfig = {Name = tabConfig}
        end
        tabConfig = tabConfig or {}
        tabConfig.Name = tabConfig.Name or "Tab"
        tabConfig.Description = tabConfig.Description or "Tab description"
        tabConfig.Icon = tabConfig.Icon or _assetUrl("94219370057308")
        local tabDebugToken = sectionObj.Library:_DebugBegin("AddTab")
        sectionObj.Library:_DebugCount("Tabs", 1)
        
        local tabObj = {}
        tabObj.tabNameForSearch = tabConfig.Name
        tabObj.searchTerms = {tabConfig.Name, tabConfig.Description}
        tabObj.groupsInTab = {}
        tabObj.groupPositions = {Left = 0, Right = 0}
        tabObj.isActive = false
        tabObj.Library = sectionObj.Library
        local tabSsw = sectionObj.Library.sectionScrollWidth or (162 * _mScale)
        local tabButtonWidth = tabHolderWidth
        local tabLabelWidth = math.max(20, tabButtonWidth - 46 * _mScale)
        local tabListIndex = #sectionObj.tabsInSection + 1
        local immediateTabY = getImmediateTabsHeight()
        tabObj.defaultButtonSize = UDim2.new(0, tabButtonWidth, 0, tabButtonHeight)
        
        tabObj.buttonFrame = _mk("Frame", {
            BackgroundColor3 = _palette.SurfaceSoft,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, immediateTabY),
            Size = tabObj.defaultButtonSize,
            ClipsDescendants = true,
            LayoutOrder = tabListIndex,
            Parent = sectionObj.tabHolderFrame
        })
        _mkCorner(tabObj.buttonFrame, _cornerTk.Card)
        
        tabObj.leftAccentBar = _mk("Frame", {
            BackgroundColor3 = sectionObj.Library.config.AccentColor,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 5 * _mScale),
            Size = UDim2.new(0, 0, 1, 0),
            Parent = tabObj.buttonFrame
        })
        
        tabObj.iconImg = _mkIcon(
            tabObj.buttonFrame,
            tabConfig.Icon or _assetUrl("10709812396"),
            _getSubClr(sectionObj.Library):Lerp(_palette.TextSoft, 0.28),
            UDim2.new(0, 14 * _mScale, 0.5, -7 * _mScale),
            UDim2.new(0, 14 * _mScale, 0, 14 * _mScale),
            {FallbackImage = tabConfig.FallbackIcon or _assetUrl("10734950309")}
        )
        
        tabObj.nameLabel = _mkLabel(
            tabObj.buttonFrame,
            sectionObj.Library,
            tabConfig.Name,
            UDim2.new(0, 38 * _mScale, 0.5, -8.5 * _mScale),
            UDim2.new(0, tabLabelWidth, 0, 17 * _mScale),
            {
                FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
                TextColor = _getSubClr(sectionObj.Library):Lerp(_palette.TextSoft, 0.45),
                TextSize = 13.2 * _mScale,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ClipsDescendants = true
            }
        )
        
        local tabClickButton = _mk("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = tabObj.buttonFrame})
        
        tabObj.contentScroll = _mk("ScrollingFrame", {
            BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 7 * _mScale),
            Size = UDim2.new(1, -14 * _mScale, 1, -12 * _mScale), BorderSizePixel = 0, ScrollBarThickness = 0,
            CanvasSize = UDim2.new(0, 540 * _mScale, 0, 0), Visible = false,
            Parent = sectionObj.Library.contentHolderFrame
        })
        _attachScrollbar(sectionObj.Library, tabObj.contentScroll, sectionObj.Library.contentHolderFrame, {
            TrackWidth = 7 * _mScale,
            ThumbWidth = 3 * _mScale,
            EdgeInset = 2 * _mScale,
            VerticalInset = 4 * _mScale,
            IdleThumbHeight = 46 * _mScale,
            AlwaysShowTrack = false,
            ZIndex = 6
        })
        --sectionObj.Library:EnableSmoothScrolling(tabObj.contentScroll, 38)
        
        local contentWidth = sectionObj.Library.contentWidth or (540 * _mScale)
        local contentInnerWidth = math.max(160 * _mScale, contentWidth - 18 * _mScale)
        local columnGap = 12 * _mScale
        local twoColumnMinWidth = 540 * _mScale
        local useSingleColumn = contentWidth < twoColumnMinWidth
        local columnWidth = useSingleColumn and math.min(420 * _mScale, math.max(140 * _mScale, contentInnerWidth - 8 * _mScale)) or math.floor((contentInnerWidth - columnGap) / 2)
        local singleColumnX = useSingleColumn and math.max(0, math.floor((contentInnerWidth - columnWidth) / 2)) or 0
        
        tabObj.leftColumnFrame = _mk("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, singleColumnX, 0, 0), Size = UDim2.new(0, columnWidth, 0, 1000), Parent = tabObj.contentScroll})
        if useSingleColumn then
            tabObj.rightColumnFrame = _mk("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, singleColumnX, 0, 0), Size = UDim2.new(0, columnWidth, 0, 1000), Parent = tabObj.contentScroll})
            tabObj.leftColumnFrame.Size = UDim2.new(0, columnWidth, 0, 1000)
        else
            tabObj.rightColumnFrame = _mk("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, columnWidth + columnGap, 0, 0), Size = UDim2.new(0, columnWidth, 0, 1000), Parent = tabObj.contentScroll})
        end
        
        local groupSpacingY = 12 * _mScale
        local function relayoutGroupsYay()
            if useSingleColumn then
                local globalYOffset = 0
                for _, group in ipairs(tabObj.groupsInTab) do
                    if group.mainFrame and group.mainFrame.Parent then
                        group.mainFrame.Position = UDim2.new(0, 1, 0, globalYOffset + 1)
                        globalYOffset = globalYOffset + group.mainFrame.Size.Y.Offset + groupSpacingY
                    end
                end
                tabObj.contentScroll.CanvasSize = UDim2.new(0, math.max(0, contentInnerWidth), 0, globalYOffset)
            else
                local sideOffsets = {Left = 0, Right = 0}
                for _, group in ipairs(tabObj.groupsInTab) do
                    if group.mainFrame and group.mainFrame.Parent then
                        local side = group.side == "Right" and "Right" or "Left"
                        local nextY = sideOffsets[side]
                        group.mainFrame.Position = UDim2.new(0, 1, 0, nextY + 1)
                        sideOffsets[side] = nextY + group.mainFrame.Size.Y.Offset + groupSpacingY
                    end
                end
                tabObj.groupPositions.Left = sideOffsets.Left
                tabObj.groupPositions.Right = sideOffsets.Right
                local maxHeight = math.max(sideOffsets.Left, sideOffsets.Right)
                tabObj.contentScroll.CanvasSize = UDim2.new(0, contentInnerWidth, 0, maxHeight)
            end
        end

        local function requestRelayoutGroupsYay()
            relayoutGroupsYay()
        end
        
        function tabObj:Activate()
            if tabObj.isActive then
                return
            end
            local previousTab = sectionObj.Library._curTab
            if previousTab and previousTab ~= tabObj then
                previousTab:Deactivate(true)
            end
            sectionObj.Library._curTab = tabObj
            tabObj.isActive = true
            tabObj.contentScroll.Position = UDim2.new(0, 14 * _mScale, 0, 7 * _mScale)
            tabObj.contentScroll.Visible = true
            sectionObj.Library:_Tween(tabObj.contentScroll, {Position = UDim2.new(0, 6 * _mScale, 0, 7 * _mScale)}, 0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.08)
            sectionObj.Library:_Tween(tabObj.buttonFrame, {BackgroundColor3 = sectionObj.Library.config.AccentColor:Lerp(_palette.SurfaceSoft, 0.9), BackgroundTransparency = 0.34}, 0.18)
            sectionObj.Library:_Tween(tabObj.leftAccentBar, {Size = UDim2.new(0, 2 * _mScale, 1, -8 * _mScale)}, 0.22)
            sectionObj.Library:_Tween(tabObj.iconImg, {ImageColor3 = sectionObj.Library.config.AccentColor}, 0.22)
            sectionObj.Library:_Tween(tabObj.nameLabel, {TextColor3 = Color3.new(1, 1, 1)}, 0.22)
            if sectionObj.Library.config.Motion ~= "Off" then
                for groupIndex, group in ipairs(tabObj.groupsInTab) do
                    if group.mainFrame and group.mainFrame.Parent and group.mainFrame.Visible then
                        local targetPosition = group.mainFrame.Position
                        group.mainFrame.Position = UDim2.new(targetPosition.X.Scale, targetPosition.X.Offset + 4 * _mScale, targetPosition.Y.Scale, targetPosition.Y.Offset + 2 * _mScale)
                        task.delay(sectionObj.Library:_MotionDuration((groupIndex - 1) * 0.018, 0), function()
                            if tabObj.isActive and group.mainFrame and group.mainFrame.Parent then
                                sectionObj.Library:_Tween(group.mainFrame, {Position = targetPosition}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.07)
                            end
                        end)
                    end
                end
            end
            sectionObj.Library.tabNameLabel.Text = tabConfig.Name
            sectionObj.Library.tabDescriptionLabel.Text = tabConfig.Description
            sectionObj.Library:_UpdateStatusStrip()
        end
        
        function tabObj:Deactivate(skipAnimation)
            tabObj.isActive = false
            for _, group in ipairs(tabObj.groupsInTab) do
                for _, element in ipairs(group.elementsInGroup) do
                    if type(element) == "table" and type(element.Close) == "function" then
                        pcall(function()
                            element:Close()
                        end)
                    end
                end
            end
            if skipAnimation then
                tabObj.contentScroll.Visible = false
                tabObj.contentScroll.Position = UDim2.new(0, 6 * _mScale, 0, 7 * _mScale)
            else
                sectionObj.Library:_Tween(tabObj.contentScroll, {Position = UDim2.new(0, -8 * _mScale, 0, 7 * _mScale)}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.06)
                task.delay(sectionObj.Library:_MotionDuration(0.18, 0.06), function()
                    if not tabObj.isActive and tabObj.contentScroll and tabObj.contentScroll.Parent then
                        tabObj.contentScroll.Visible = false
                        tabObj.contentScroll.Position = UDim2.new(0, 6 * _mScale, 0, 7 * _mScale)
                    end
                end)
            end
            sectionObj.Library:_Tween(tabObj.buttonFrame, {BackgroundColor3 = _palette.SurfaceSoft, BackgroundTransparency = 1}, 0.18)
            sectionObj.Library:_Tween(tabObj.leftAccentBar, {Size = UDim2.new(0, 0, 1, 0)}, 0.18)
            sectionObj.Library:_Tween(tabObj.iconImg, {ImageColor3 = sectionObj.Library.config.SubTextColor or _palette.TextSoft}, 0.18)
            sectionObj.Library:_Tween(tabObj.nameLabel, {TextColor3 = sectionObj.Library.config.SubTextColor or _palette.TextSoft}, 0.18)
        end
        
        tabClickButton.MouseButton1Click:Connect(function() if not tabObj.isActive then tabObj:Activate() end end)
        tabClickButton.MouseEnter:Connect(function()
            if not tabObj.isActive then
                _tween(tabObj.buttonFrame, {BackgroundColor3 = _palette.SurfaceSoft, BackgroundTransparency = 0.82}, 0.18)
                _tween(tabObj.nameLabel, {TextColor3 = _palette.TextMuted}, 0.2)
                _tween(tabObj.iconImg, {ImageColor3 = _palette.TextMuted}, 0.2)
            end
        end)
        tabClickButton.MouseLeave:Connect(function()
            if not tabObj.isActive then
                _tween(tabObj.buttonFrame, {BackgroundColor3 = _palette.SurfaceSoft, BackgroundTransparency = 1}, 0.18)
                _tween(tabObj.nameLabel, {TextColor3 = sectionObj.Library.config.SubTextColor or _palette.TextSoft}, 0.2)
                _tween(tabObj.iconImg, {ImageColor3 = sectionObj.Library.config.SubTextColor or _palette.TextSoft}, 0.2)
            end
        end)

        function tabObj:AddGroup(groupConfig)
            if type(groupConfig) == "string" then
                groupConfig = {Name = groupConfig}
            end
            groupConfig = groupConfig or {}
            groupConfig.Name = groupConfig.Name or "Group"
            groupConfig.Side = groupConfig.Side or "Left"
            groupConfig.Icon = groupConfig.Icon or nil
            local groupDebugToken = tabObj.Library:_DebugBegin("AddGroup")
            tabObj.Library:_DebugCount("Groups", 1)
            if string.lower(tostring(groupConfig.Side)) == "right" then
                groupConfig.Side = "Right"
            else
                groupConfig.Side = "Left"
            end
            local isComfortableGroup = tabObj.Library.config.Density == "Comfortable"
            local cleanCards = tabObj.Library.config.CleanCards ~= false
            local segmentedGroupTabs = tabObj.Library.config.GroupTabStyle ~= "Classic"
            local precisionControls = tabObj.Library.config.ControlStyle ~= "Classic"
            local groupHeaderHeight = (isComfortableGroup and 39 or 34) * _mScale
            local groupTabStripHeight = (isComfortableGroup and 40 or 36) * _mScale
            local controlPadX = 12 * _mScale
            local controlRightPad = 12 * _mScale
            local controlValueGap = 10 * _mScale
            
            local groupObj = {}
            groupObj.groupNameForSearch = groupConfig.Name
            groupObj.searchTerms = {groupConfig.Name}
            groupObj.elementsInGroup = {}
            groupObj.Library = tabObj.Library
            groupObj.side = groupConfig.Side
            groupObj.elementYPos = groupHeaderHeight
            groupObj.contentStartY = groupObj.elementYPos
            groupObj.groupTabs = {}
            groupObj.activeGroupTab = nil
            groupObj.tabStripFrame = nil
            groupObj.tabStripSquareFill = nil
            groupObj.tabStripBottomLine = nil
            local function createAutoFlag(elementName)
                return tostring(tabObj.tabNameForSearch) .. "." .. tostring(groupObj.groupNameForSearch) .. "." .. tostring(elementName or "Value")
            end
            local function addSearchTerm(term)
                local normalized = normalizeSearchText(term)
                if normalized ~= "" then
                    table.insert(groupObj.searchTerms, tostring(term))
                end
            end
            
            local parentColumn = useSingleColumn and tabObj.leftColumnFrame or (groupObj.side == "Left" and tabObj.leftColumnFrame or tabObj.rightColumnFrame)
            local groupWidth = columnWidth
            
            groupObj.mainFrame = _mk("Frame", {
                BackgroundColor3 = cleanCards and _palette.Surface or _palette.SurfaceAlt,
                BackgroundTransparency = 0,
                Position = UDim2.new(0, 1, 0, 1),
                Size = UDim2.new(0, groupWidth, 0, 54 * _mScale),
                ClipsDescendants = true,
                Parent = parentColumn
            })
            _mkCorner(groupObj.mainFrame, _cornerTk.Large)
            groupObj.panelStroke = _mk("UIStroke", {
                Color = cleanCards and _palette.TacticalLine or _palette.Stroke,
                Transparency = cleanCards and 0.8 or 0.22,
                Thickness = 1,
                Parent = groupObj.mainFrame
            })
            
            groupObj.headerDivider = _mk("Frame", {
                BackgroundColor3 = _palette.TacticalLine,
                BackgroundTransparency = cleanCards and 0.94 or 0.46,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 12 * _mScale, 0, groupHeaderHeight - 8 * _mScale),
                Size = UDim2.new(1, -24 * _mScale, 0, 1),
                Parent = groupObj.mainFrame
            })
            
            groupObj.bottomDivider = _mk("Frame", {
                BackgroundColor3 = _palette.TacticalLine,
                BackgroundTransparency = cleanCards and 0.96 or 0.5,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 12 * _mScale, 0, 0),
                Size = UDim2.new(1, -24 * _mScale, 0, 1),
                Parent = groupObj.mainFrame
            })
            
            groupObj.titleLabel = _mkLabel(
                groupObj.mainFrame,
                groupObj.Library,
                groupConfig.Name,
                UDim2.new(0, 12 * _mScale, 0, (isComfortableGroup and 9 or 8) * _mScale),
                UDim2.new(1, -24 * _mScale, 0, 14 * _mScale),
                {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                    TextColor = _getTextClr(groupObj.Library):Lerp(_palette.TextMuted, 0.06),
                    TextSize = (isComfortableGroup and 14.7 or 13.8) * _mScale,
                    TextTruncate = Enum.TextTruncate.AtEnd
                }
            )
            
            local function updateGroupSizeYay()
                local minHeight = math.max(56 * _mScale, (groupObj.contentStartY or groupHeaderHeight) + 22 * _mScale)
                local newHeight = math.max(minHeight, groupObj.elementYPos + (cleanCards and 8 or 10) * _mScale)
                groupObj.mainFrame.Size = UDim2.new(0, groupWidth, 0, newHeight)
                if groupObj.bottomDivider then
                    groupObj.bottomDivider.Position = UDim2.new(0, 12 * _mScale, 0, newHeight - 1)
                end
                requestRelayoutGroupsYay()
            end

            function groupObj:AddToggle(toggleConfig)
                toggleConfig = toggleConfig or {}
                toggleConfig.Name = toggleConfig.Name or "Toggle"
                toggleConfig.Default = toggleConfig.Default or false
                toggleConfig.Callback = toggleConfig.Callback or function() end
                toggleConfig.Flag = toggleConfig.Flag or createAutoFlag(toggleConfig.Name)
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddToggle")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddToggle", 1)
                addSearchTerm(toggleConfig.Name)
                
                local toggleObj = {}
                toggleObj.value = toggleConfig.Default
                local yPosition = groupObj.elementYPos
                local toggleW = (_isMobile and 48 or 38) * _mScale
                local toggleH = (_isMobile and 28 or 20) * _mScale
                local knobSize = (_isMobile and 20 or 14) * _mScale
                local knobInset = 3 * _mScale
                local knobOffPos = UDim2.new(0, knobInset, 0, (toggleH - knobSize) / 2)
                local knobOnPos = UDim2.new(0, toggleW - knobSize - knobInset, 0, (toggleH - knobSize) / 2)
                local activeToggleColor = groupObj.Library.config.AccentColor:Lerp(_palette.ControlInset, 0.12)
                
                toggleObj.labelText = _mkLabel(
                    groupObj.mainFrame,
                    groupObj.Library,
                    toggleConfig.Name,
                    UDim2.new(0, controlPadX, 0, yPosition),
                    UDim2.new(1, -(toggleW + controlPadX + controlRightPad + controlValueGap), 0, 20 * _mScale),
                    {
                        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
                        TextSize = 13.8 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )

                toggleObj.switchFrame = _mk("Frame", {
                    BackgroundColor3 = toggleObj.value and activeToggleColor or _palette.ToggleOff,
                    Position = UDim2.new(1, -(toggleW + controlRightPad), 0, yPosition),
                    Size = UDim2.new(0, toggleW, 0, toggleH), Parent = groupObj.mainFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = toggleObj.switchFrame})
                toggleObj.switchStroke = _mk("UIStroke", {
                    Color = toggleObj.value and groupObj.Library.config.AccentColor:Lerp(_palette.StrokeStrong, 0.28) or _palette.TacticalLine,
                    Transparency = toggleObj.value and 0.42 or 0.7,
                    Thickness = 1,
                    Parent = toggleObj.switchFrame
                })
                
                toggleObj.circleFrame = _mk("Frame", {
                    BackgroundColor3 = toggleObj.value and Color3.new(1, 1, 1) or _palette.ToggleKnobOff,
                    Position = toggleObj.value and knobOnPos or knobOffPos,
                    Size = UDim2.new(0, knobSize, 0, knobSize), Parent = toggleObj.switchFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = toggleObj.circleFrame})
                _mk("UIStroke", {
                    Color = _palette.StrokeStrong,
                    Transparency = toggleObj.value and 0.28 or 0.58,
                    Thickness = 1,
                    Parent = toggleObj.circleFrame
                })
                
                local toggleClickButton = _mk("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = toggleObj.switchFrame})
                
                function toggleObj:Set(value, silent)
                    toggleObj.value = value == true
                    if toggleObj.value then
                        _tween(toggleObj.switchFrame, {BackgroundColor3 = activeToggleColor}, 0.2)
                        _tween(toggleObj.switchStroke, {Color = groupObj.Library.config.AccentColor:Lerp(_palette.StrokeStrong, 0.28), Transparency = 0.42}, 0.2)
                        _tween(toggleObj.circleFrame, {Position = knobOnPos, BackgroundColor3 = Color3.new(1, 1, 1)}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                    else
                        _tween(toggleObj.switchFrame, {BackgroundColor3 = _palette.ToggleOff}, 0.2)
                        _tween(toggleObj.switchStroke, {Color = _palette.TacticalLine, Transparency = 0.7}, 0.2)
                        _tween(toggleObj.circleFrame, {Position = knobOffPos, BackgroundColor3 = _palette.ToggleKnobOff}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                    end
                    if not silent then
                        _safeCallback(toggleConfig.Callback, toggleObj.value)
                    end
                end

                function toggleObj:Get()
                    return toggleObj.value
                end
                
                toggleClickButton.MouseButton1Click:Connect(function() toggleObj:Set(not toggleObj.value, false) end)
                groupObj.Library:RegisterControl(toggleConfig.Flag, function()
                    return toggleObj:Get()
                end, function(value)
                    toggleObj:Set(value == true, true)
                end)
                
                groupObj.elementYPos = groupObj.elementYPos + 28 * _mScale
                updateGroupSizeYay()
                table.insert(groupObj.elementsInGroup, toggleObj)
                groupObj.Library:_DebugEnd(controlDebugToken, toggleConfig.Name)
                return toggleObj
            end

            function groupObj:AddSlider(sliderConfig)
                sliderConfig = sliderConfig or {}
                sliderConfig.Name = sliderConfig.Name or "Slider"
                sliderConfig.Min = tonumber(sliderConfig.Min) or 0
                sliderConfig.Max = tonumber(sliderConfig.Max) or 100
                if sliderConfig.Max < sliderConfig.Min then
                    sliderConfig.Min, sliderConfig.Max = sliderConfig.Max, sliderConfig.Min
                end
                sliderConfig.Default = tonumber(sliderConfig.Default)
                if sliderConfig.Default == nil then
                    sliderConfig.Default = sliderConfig.Min
                end
                sliderConfig.Increment = math.abs(tonumber(sliderConfig.Increment) or 1)
                if sliderConfig.Increment < 1e-6 then
                    sliderConfig.Increment = 1
                end
                sliderConfig.Suffix = tostring(sliderConfig.Suffix or "")
                sliderConfig.ShowMax = sliderConfig.ShowMax == true
                sliderConfig.Callback = sliderConfig.Callback or function() end
                sliderConfig.Flag = sliderConfig.Flag or createAutoFlag(sliderConfig.Name)
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddSlider")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddSlider", 1)
                addSearchTerm(sliderConfig.Name)
                
                local sliderPrecision = resolveSliderPrecision(sliderConfig.Min, sliderConfig.Max, sliderConfig.Increment, sliderConfig.Default)
                local sliderRange = sliderConfig.Max - sliderConfig.Min
                local function getSliderPercentage(value)
                    if sliderRange <= 0 then
                        return 0
                    end
                    return math.clamp((value - sliderConfig.Min) / sliderRange, 0, 1)
                end
                local function formatDisplayValue(value)
                    local text = formatSliderValue(value, sliderPrecision) .. sliderConfig.Suffix
                    if sliderConfig.ShowMax then
                        return text .. " / " .. formatSliderValue(sliderConfig.Max, sliderPrecision) .. sliderConfig.Suffix
                    end
                    return text
                end
                
                local sliderObj = {}
                sliderObj.value = normalizeSliderValue(sliderConfig.Default, sliderConfig.Min, sliderConfig.Max, sliderConfig.Increment, sliderPrecision)
                local yPosition = groupObj.elementYPos
                local sliderWidth = groupWidth - controlPadX - controlRightPad
                local valueLabelWidth = (sliderConfig.ShowMax and 104 or 86) * _mScale
                local sliderHitHeight = (_isMobile and 30 or 22) * _mScale
                local sliderTrackHeight = (precisionControls and 6 or 9) * _mScale
                local sliderKnobWidth = (_isMobile and 13 or (precisionControls and 8 or 10)) * _mScale
                local sliderKnobHeight = (_isMobile and 24 or (precisionControls and 17 or 19)) * _mScale
                local sliderKnobHalfWidth = sliderKnobWidth * 0.5
                
                sliderObj.labelText = _mkLabel(
                    groupObj.mainFrame,
                    groupObj.Library,
                    sliderConfig.Name,
                    UDim2.new(0, controlPadX, 0, yPosition),
                    UDim2.new(0, sliderWidth - valueLabelWidth - controlValueGap, 0, 19 * _mScale),
                    {
                        TextSize = 13.7 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                sliderObj.backgroundFrame = _mk("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, controlPadX, 0, yPosition + 20 * _mScale),
                    Size = UDim2.new(0, sliderWidth, 0, sliderHitHeight),
                    Parent = groupObj.mainFrame
                })

                sliderObj.trackFrame = _mk("Frame", {
                    BackgroundColor3 = _palette.SliderTrack,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 0.5, -sliderTrackHeight * 0.5),
                    Size = UDim2.new(0, sliderWidth, 0, sliderTrackHeight),
                    Parent = sliderObj.backgroundFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = sliderObj.trackFrame})

                local percentage = getSliderPercentage(sliderObj.value)
                sliderObj.fillFrame = _mk("Frame", {
                    BackgroundColor3 = groupObj.Library.config.AccentColor,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0, sliderWidth * percentage, 1, 0),
                    Parent = sliderObj.trackFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = sliderObj.fillFrame})

                sliderObj.knobFrame = _mk("Frame", {
                    BackgroundColor3 = Color3.fromRGB(244, 244, 248),
                    BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0, math.clamp(sliderWidth * percentage, sliderKnobHalfWidth, sliderWidth - sliderKnobHalfWidth), 0.5, 0),
                    Size = UDim2.new(0, sliderKnobWidth, 0, sliderKnobHeight),
                    ZIndex = 2,
                    Parent = sliderObj.backgroundFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(0, 2 * _mScale), Parent = sliderObj.knobFrame})
                _mk("UIStroke", {
                    Color = _palette.StrokeStrong,
                    Transparency = 0.26,
                    Thickness = 1,
                    Parent = sliderObj.knobFrame
                })
                
                sliderObj.valueLabelText = _mkLabel(
                    groupObj.mainFrame,
                    groupObj.Library,
                    formatDisplayValue(sliderObj.value),
                    UDim2.new(1, -valueLabelWidth - controlRightPad, 0, yPosition),
                    UDim2.new(0, valueLabelWidth, 0, 19 * _mScale),
                    {
                        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                        TextColor = _palette.FieldText,
                        TextSize = 12.9 * _mScale,
                        TextXAlignment = Enum.TextXAlignment.Right
                    }
                )
                
                local sliderClickButton = _mk("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = sliderObj.backgroundFrame})

                local function updateSliderVisuals(animate)
                    local currentPercentage = getSliderPercentage(sliderObj.value)
                    local fillTarget = {Size = UDim2.new(0, sliderWidth * currentPercentage, 1, 0)}
                    local knobTarget = {
                        Position = UDim2.new(0, math.clamp(sliderWidth * currentPercentage, sliderKnobHalfWidth, sliderWidth - sliderKnobHalfWidth), 0.5, 0)
                    }
                    if animate then
                        _tween(sliderObj.fillFrame, fillTarget, 0.12)
                        _tween(sliderObj.knobFrame, knobTarget, 0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                    else
                        sliderObj.fillFrame.Size = fillTarget.Size
                        sliderObj.knobFrame.Position = knobTarget.Position
                    end
                    sliderObj.valueLabelText.Text = formatDisplayValue(sliderObj.value)
                end

                function sliderObj:Set(value, instant, silent)
                    value = normalizeSliderValue(value, sliderConfig.Min, sliderConfig.Max, sliderConfig.Increment, sliderPrecision)
                    sliderObj.value = value
                    updateSliderVisuals(instant ~= true)
                    if not silent then
                        _safeCallback(sliderConfig.Callback, value)
                    end
                end

                function sliderObj:Get()
                    return sliderObj.value
                end
                
                local isDraggingSlider = false
                local activeSliderInput = nil
                local function setSliderFromInput(input, instant)
                    if not input then
                        return
                    end
                    local percentageNow = math.clamp((input.Position.X - sliderObj.backgroundFrame.AbsolutePosition.X) / math.max(1, sliderObj.backgroundFrame.AbsoluteSize.X), 0, 1)
                    local value = sliderConfig.Min + sliderRange * percentageNow
                    sliderObj:Set(value, instant, false)
                end
                sliderClickButton.InputBegan:Connect(function(input)
                    local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
                    local isTouch = input.UserInputType == Enum.UserInputType.Touch
                    if not isMouse and not isTouch then
                        return
                    end
                    isDraggingSlider = true
                    activeSliderInput = isTouch and input or nil
                    setSliderFromInput(input, true)
                end)
                groupObj.Library:_TrackConnection(_uis.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or (input.UserInputType == Enum.UserInputType.Touch and (activeSliderInput == nil or input == activeSliderInput)) then
                        isDraggingSlider = false
                        activeSliderInput = nil
                    end
                end))
                groupObj.Library:_TrackConnection(_uis.InputChanged:Connect(function(input)
                    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or (input.UserInputType == Enum.UserInputType.Touch and (activeSliderInput == nil or input == activeSliderInput))) then
                        setSliderFromInput(input, true)
                    end
                end))

                updateSliderVisuals(false)
                groupObj.Library:RegisterControl(sliderConfig.Flag, function()
                    return sliderObj:Get()
                end, function(value)
                    sliderObj:Set(tonumber(value) or sliderConfig.Min, true, true)
                end)
                groupObj.elementYPos = groupObj.elementYPos + 48 * _mScale
                updateGroupSizeYay()
                table.insert(groupObj.elementsInGroup, sliderObj)
                groupObj.Library:_DebugEnd(controlDebugToken, sliderConfig.Name)
                return sliderObj
            end

            function groupObj:AddButton(buttonConfig)
                buttonConfig = buttonConfig or {}
                buttonConfig.Name = buttonConfig.Name or "Button"
                buttonConfig.Icon = buttonConfig.Icon
                buttonConfig.Locked = buttonConfig.Locked or false
                buttonConfig.Callback = buttonConfig.Callback or function() end
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddButton")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddButton", 1)
                addSearchTerm(buttonConfig.Name)
                
                local buttonObj = {}
                buttonObj.isLocked = buttonConfig.Locked
                local yPosition = groupObj.elementYPos
                local buttonWidth = groupWidth - 24 * _mScale
                
                buttonObj.mainFrame = _mk("Frame", {
                    BackgroundColor3 = buttonObj.isLocked and _palette.SurfaceAlt or _palette.Button,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 12 * _mScale, 0, yPosition),
                    Size = UDim2.new(0, buttonWidth, 0, (_isMobile and 32 or 28) * _mScale),
                    Parent = groupObj.mainFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = buttonObj.mainFrame})
                
                local textXPos = 8
                if buttonConfig.Icon then
                    _mkIcon(
                        buttonObj.mainFrame,
                        buttonConfig.Icon,
                        buttonObj.isLocked and _palette.TextSoft or _getSubClr(groupObj.Library),
                        UDim2.new(0, 8, 0.5, -8 * _mScale),
                        UDim2.new(0, 16 * _mScale, 0, 16 * _mScale)
                    )
                    textXPos = 30
                end
                
                buttonObj.labelText = _mkLabel(
                    buttonObj.mainFrame,
                    groupObj.Library,
                    buttonConfig.Name .. (buttonObj.isLocked and " (locked)" or ""),
                    UDim2.new(0, textXPos * _mScale, 0, 0),
                    UDim2.new(1, -textXPos * _mScale - 10, 1, 0),
                    {
                        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
                        TextColor = buttonObj.isLocked and _palette.TextSoft or _getSubClr(groupObj.Library),
                        TextSize = 14 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                local buttonClickButton = _mk("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = buttonObj.mainFrame})
                buttonClickButton.MouseButton1Click:Connect(function() if not buttonObj.isLocked then _safeCallback(buttonConfig.Callback) end end)
                buttonClickButton.MouseEnter:Connect(function() if not buttonObj.isLocked then _tween(buttonObj.mainFrame, {BackgroundColor3 = _palette.ButtonHover, Position = UDim2.new(0, 12 * _mScale, 0, yPosition - 1)}, 0.2) end end)
                buttonClickButton.MouseLeave:Connect(function() if not buttonObj.isLocked then _tween(buttonObj.mainFrame, {BackgroundColor3 = _palette.Button, Position = UDim2.new(0, 12 * _mScale, 0, yPosition)}, 0.2) end end)
                
                groupObj.elementYPos = groupObj.elementYPos + 36 * _mScale
                updateGroupSizeYay()
                table.insert(groupObj.elementsInGroup, buttonObj)
                groupObj.Library:_DebugEnd(controlDebugToken, buttonConfig.Name)
                return buttonObj
            end

            function groupObj:AddKeybind(keybindConfig)
                keybindConfig = keybindConfig or {}
                keybindConfig.Name = keybindConfig.Name or "Keybind"
                keybindConfig.Default = keybindConfig.Default or Enum.KeyCode.Unknown
                keybindConfig.Callback = keybindConfig.Callback or function() end
                keybindConfig.ChangedCallback = keybindConfig.ChangedCallback or function() end
                keybindConfig.ModeChangedCallback = keybindConfig.ModeChangedCallback or function() end
                keybindConfig.Mode = tostring(keybindConfig.Mode or "Toggle")
                keybindConfig.Flag = keybindConfig.Flag or createAutoFlag(keybindConfig.Name)
                keybindConfig.ModeFlag = keybindConfig.ModeFlag or createAutoFlag(keybindConfig.Name .. ".Mode")
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddKeybind")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddKeybind", 1)
                addSearchTerm(keybindConfig.Name)
                addSearchTerm("hold")
                addSearchTerm("toggle")
                
                local keybindObj = {}
                keybindObj.value = keybindConfig.Default
                keybindObj.mode = string.lower(keybindConfig.Mode) == "hold" and "Hold" or "Toggle"
                keybindObj.isListening = false
                keybindObj.holdActive = false
                local yPosition = groupObj.elementYPos
                
                keybindObj.labelText = _mkLabel(
                    groupObj.mainFrame,
                    groupObj.Library,
                    keybindConfig.Name,
                    UDim2.new(0, controlPadX, 0, yPosition),
                    UDim2.new(1, -(90 * _mScale), 0, 20 * _mScale),
                    {
                        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
                        TextSize = 13.7 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                local function normalizeMode(modeValue)
                    return string.lower(tostring(modeValue or "toggle")) == "hold" and "Hold" or "Toggle"
                end
                
                local function getKeyText()
                    return keybindObj.value == Enum.KeyCode.Unknown and "None" or keybindObj.value.Name
                end
                
                local keyText = getKeyText()
                local keyWidth = math.max(48 * _mScale, howWideIsThisText(keyText, 12 * _mScale) + 30 * _mScale)
                
                local keybindBtnHeight = (_isMobile and 30 or 23) * _mScale
                keybindObj.buttonFrame = _mk("Frame", {
                    BackgroundColor3 = _palette.ControlInset, Position = UDim2.new(1, -keyWidth - controlRightPad, 0, yPosition),
                    Size = UDim2.new(0, keyWidth, 0, keybindBtnHeight), Active = true, Parent = groupObj.mainFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = keybindObj.buttonFrame})
                
                local keybindStrokeThing = _mk("UIStroke", {Color = _palette.TacticalLine, Transparency = 0.56, Parent = keybindObj.buttonFrame})
                
                keybindObj.keyLabelText = _mk("TextLabel", {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
                    TextColor3 = _palette.FieldText, Text = keyText, BackgroundTransparency = 1,
                    Position = UDim2.new(0, 2, 0, 0), TextSize = 12.5 * _mScale,
                    Size = UDim2.new(1, -24 * _mScale, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = keybindObj.buttonFrame
                })
                _mk("UIPadding", {PaddingLeft = UDim.new(0, 2), Parent = keybindObj.keyLabelText})
                
                keybindObj.keyboardIconImg = _mk("ImageLabel", {
                    ImageColor3 = Color3.fromRGB(76, 76, 76), Image = _assetUrl("10723416765"), BackgroundTransparency = 1,
                    Position = UDim2.new(1, -18 * _mScale, 0.5, -7.5 * _mScale),
                    Size = UDim2.new(0, 15 * _mScale, 0, 15 * _mScale), Parent = keybindObj.buttonFrame
                })
                
                local keybindClickButton = _mk("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Active = true, Parent = keybindObj.buttonFrame})
                
                local modeMenuWidth = 120 * _mScale
                local modeMenuHeight = 78 * _mScale
                local modeMenuPositionConn = nil
                local modeMenuOutsideConn = nil
                keybindObj.isModeMenuOpen = false
                
                keybindObj.modeMenuFrame = _mk("Frame", {
                    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                    Size = UDim2.new(0, modeMenuWidth, 0, 0),
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 9999,
                    Parent = groupObj.Library.dropdownHolderRef
                })
            _mkCorner(keybindObj.modeMenuFrame, _cornerTk.Card)
                _mk("UIStroke", {Color = Color3.fromRGB(28, 28, 28), Parent = keybindObj.modeMenuFrame})
                
                _mk("TextLabel", {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                    Text = "Keybind Mode",
                    TextColor3 = Color3.new(1, 1, 1),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 8, 0, 5 * _mScale),
                    Size = UDim2.new(1, -16, 0, 16 * _mScale),
                    TextSize = 12 * _mScale,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 10000,
                    Parent = keybindObj.modeMenuFrame
                })
                
                local                 toggleModeFrame = _mk("Frame", {
                    BackgroundColor3 = Color3.fromRGB(18, 18, 18),
                    Position = UDim2.new(0, 8, 0, 26 * _mScale),
                    Size = UDim2.new(1, -16, 0, (_isMobile and 26 or 20) * _mScale),
                    ZIndex = 10000,
                    Parent = keybindObj.modeMenuFrame
                })
            _mkCorner(toggleModeFrame, _cornerTk.Micro)
                
                local toggleModeLabel = _mk("TextLabel", {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                    Text = "Toggle",
                    TextColor3 = Color3.fromRGB(140, 140, 140),
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    TextSize = 12 * _mScale,
                    ZIndex = 10001,
                    Parent = toggleModeFrame
                })
                
                local                 holdModeFrame = _mk("Frame", {
                    BackgroundColor3 = Color3.fromRGB(18, 18, 18),
                    Position = UDim2.new(0, 8, 0, (_isMobile and 58 or 50) * _mScale),
                    Size = UDim2.new(1, -16, 0, (_isMobile and 26 or 20) * _mScale),
                    ZIndex = 10000,
                    Parent = keybindObj.modeMenuFrame
                })
            _mkCorner(holdModeFrame, _cornerTk.Micro)
                
                local holdModeLabel = _mk("TextLabel", {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                    Text = "Hold",
                    TextColor3 = Color3.fromRGB(140, 140, 140),
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    TextSize = 12 * _mScale,
                    ZIndex = 10001,
                    Parent = holdModeFrame
                })
                
                local toggleModeClickButton = _mk("TextButton", {
                    Text = "",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    ZIndex = 10002,
                    Parent = toggleModeFrame
                })
                
                local holdModeClickButton = _mk("TextButton", {
                    Text = "",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    ZIndex = 10002,
                    Parent = holdModeFrame
                })
                
                local function updateKeybindSizeYay(text)
                    local newWidth = math.max(48 * _mScale, howWideIsThisText(text, 12 * _mScale) + 30 * _mScale)
                    _tween(keybindObj.buttonFrame, {Size = UDim2.new(0, newWidth, 0, keybindBtnHeight), Position = UDim2.new(1, -newWidth - controlRightPad, 0, yPosition)}, 0.15)
                end
                
                local function updateModeVisuals()
                    local selectedBg = groupObj.Library.config.AccentColor:Lerp(_palette.Surface, 0.45)
                    local idleBg = _palette.SurfaceSoft
                    local selectedText = Color3.new(1, 1, 1)
                    local idleText = Color3.fromRGB(140, 140, 140)
                    local isToggleSelected = keybindObj.mode == "Toggle"
                    
                    _tween(toggleModeFrame, {BackgroundColor3 = isToggleSelected and selectedBg or idleBg}, 0.12)
                    _tween(toggleModeLabel, {TextColor3 = isToggleSelected and selectedText or idleText}, 0.12)
                    _tween(holdModeFrame, {BackgroundColor3 = isToggleSelected and idleBg or selectedBg}, 0.12)
                    _tween(holdModeLabel, {TextColor3 = isToggleSelected and idleText or selectedText}, 0.12)
                end
                
                local function updateModeMenuPositionYay()
                    local buttonAbsPos = keybindObj.buttonFrame.AbsolutePosition
                    local buttonAbsSize = keybindObj.buttonFrame.AbsoluteSize
                    keybindObj.modeMenuFrame.Position = UDim2.new(0, buttonAbsPos.X + buttonAbsSize.X - modeMenuWidth, 0, buttonAbsPos.Y + buttonAbsSize.Y + 5)
                end
                
                local function closeModeMenu(isInstant)
                    keybindObj.isModeMenuOpen = false
                    if modeMenuPositionConn then
                        modeMenuPositionConn()
                        modeMenuPositionConn = nil
                    end
                    if modeMenuOutsideConn then
                        modeMenuOutsideConn:Disconnect()
                        modeMenuOutsideConn = nil
                    end
                    if isInstant then
                        keybindObj.modeMenuFrame.Size = UDim2.new(0, modeMenuWidth, 0, 0)
                        keybindObj.modeMenuFrame.Visible = false
                        return
                    end
                    _tween(keybindObj.modeMenuFrame, {Size = UDim2.new(0, modeMenuWidth, 0, 0)}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                    task.delay(0.18, function()
                        if keybindObj.modeMenuFrame and keybindObj.modeMenuFrame.Parent and not keybindObj.isModeMenuOpen then
                            keybindObj.modeMenuFrame.Visible = false
                        end
                    end)
                end
                
                local function openModeMenu()
                    if keybindObj.isListening then return end
                    keybindObj.isModeMenuOpen = true
                    updateModeVisuals()
                    updateModeMenuPositionYay()
                    keybindObj.modeMenuFrame.Visible = true
                    _tween(keybindObj.modeMenuFrame, {Size = UDim2.new(0, modeMenuWidth, 0, modeMenuHeight)}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                    
                    if modeMenuPositionConn then modeMenuPositionConn() end
                    modeMenuPositionConn = startFloatingPositionTracker(groupObj.Library, keybindObj.buttonFrame, function()
                        if keybindObj.isModeMenuOpen then
                            updateModeMenuPositionYay()
                        end
                    end)
                    
                    if modeMenuOutsideConn then modeMenuOutsideConn:Disconnect() end
                    modeMenuOutsideConn = groupObj.Library:_TrackConnection(_uis.InputBegan:Connect(function(input)
                        if not keybindObj.isModeMenuOpen then return end
                        local isPress = input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.MouseButton2
                            or input.UserInputType == Enum.UserInputType.Touch
                        if not isPress then return end
                        
                        local mousePos = input.Position
                        local menuPos = keybindObj.modeMenuFrame.AbsolutePosition
                        local menuSize = keybindObj.modeMenuFrame.AbsoluteSize
                        local buttonPos = keybindObj.buttonFrame.AbsolutePosition
                        local buttonSize = keybindObj.buttonFrame.AbsoluteSize
                        
                        local insideMenu = mousePos.X >= menuPos.X and mousePos.X <= (menuPos.X + menuSize.X)
                            and mousePos.Y >= menuPos.Y and mousePos.Y <= (menuPos.Y + menuSize.Y)
                        local insideButton = mousePos.X >= buttonPos.X and mousePos.X <= (buttonPos.X + buttonSize.X)
                            and mousePos.Y >= buttonPos.Y and mousePos.Y <= (buttonPos.Y + buttonSize.Y)
                        
                        if not insideMenu and not insideButton then
                            closeModeMenu(false)
                        end
                    end))
                end
                
                local function toggleModeMenu()
                    if keybindObj.isModeMenuOpen then
                        closeModeMenu(false)
                    else
                        openModeMenu()
                    end
                end
                
                local function setMode(modeValue, silent)
                    local newMode = normalizeMode(modeValue)
                    if newMode == keybindObj.mode then
                        updateModeVisuals()
                        return
                    end
                    if keybindObj.holdActive then
                        keybindObj.holdActive = false
                        _safeCallback(keybindConfig.Callback, false)
                    end
                    keybindObj.mode = newMode
                    updateModeVisuals()
                    if not silent then
                        _safeCallback(keybindConfig.ModeChangedCallback, newMode)
                    end
                    if not silent then
                        groupObj.Library:Notify({
                            Title = keybindConfig.Name .. " mode updated",
                            Description = "Now using " .. newMode .. " input",
                            Duration = 2.2,
                            Icon = _assetUrl("6031075938")
                        })
                    end
                end
                
                function keybindObj:Set(key, silent)
                    if keybindObj.holdActive then
                        keybindObj.holdActive = false
                        _safeCallback(keybindConfig.Callback, false)
                    end
                    keybindObj.value = key
                    local newKeyText = getKeyText()
                    keybindObj.keyLabelText.Text = newKeyText
                    updateKeybindSizeYay(newKeyText)
                    if not silent then
                        _safeCallback(keybindConfig.ChangedCallback, key)
                    end
                end

                function keybindObj:Get()
                    return keybindObj.value
                end
                
                function keybindObj:SetMode(modeValue, silent)
                    setMode(modeValue, silent)
                end
                
                function keybindObj:GetMode()
                    return keybindObj.mode
                end
                
                function keybindObj:Close()
                    keybindObj.isListening = false
                    if keybindObj.holdActive then
                        keybindObj.holdActive = false
                        _safeCallback(keybindConfig.Callback, false)
                    end
                    closeModeMenu(true)
                end
                
                keybindClickButton.MouseButton1Click:Connect(function()
                    closeModeMenu(true)
                    keybindObj.isListening = true
                    keybindObj.keyLabelText.Text = "..."
                    updateKeybindSizeYay("...")
                    _tween(keybindObj.buttonFrame, {BackgroundColor3 = _palette.ButtonHover}, 0.2)
                end)
                
                local modeMenuToggleDebounceAt = 0
                local function toggleModeMenuFromRightClick()
                    if keybindObj.isListening then
                        return
                    end
                    local now = os.clock()
                    if now - modeMenuToggleDebounceAt < 0.12 then
                        return
                    end
                    modeMenuToggleDebounceAt = now
                    toggleModeMenu()
                end
                
                keybindClickButton.MouseButton2Click:Connect(toggleModeMenuFromRightClick)
                keybindClickButton.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
                        return
                    end
                    toggleModeMenuFromRightClick()
                end)
                
                toggleModeClickButton.MouseButton1Click:Connect(function()
                    setMode("Toggle", false)
                    closeModeMenu(false)
                end)
                
                holdModeClickButton.MouseButton1Click:Connect(function()
                    setMode("Hold", false)
                    closeModeMenu(false)
                end)
                
                groupObj.Library:_TrackConnection(_uis.InputBegan:Connect(function(input, gameProcessed)
                    if keybindObj.isListening then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            keybindObj.isListening = false
                            local pickedKey = input.KeyCode
                            if pickedKey == Enum.KeyCode.Backspace or pickedKey == Enum.KeyCode.Delete then
                                pickedKey = Enum.KeyCode.Unknown
                            end
                            keybindObj:Set(pickedKey, false)
                            _tween(keybindObj.buttonFrame, {BackgroundColor3 = _palette.ControlInset}, 0.2)
                        end
                    elseif not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard then
                        if input.KeyCode == keybindObj.value and keybindObj.value ~= Enum.KeyCode.Unknown then
                            if keybindObj.mode == "Hold" then
                                if not keybindObj.holdActive then
                                    keybindObj.holdActive = true
                                    _safeCallback(keybindConfig.Callback, true)
                                end
                            else
                                _safeCallback(keybindConfig.Callback)
                            end
                        end
                    end
                end))
                
                groupObj.Library:_TrackConnection(_uis.InputEnded:Connect(function(input)
                    if keybindObj.mode == "Hold" and keybindObj.holdActive and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == keybindObj.value then
                        keybindObj.holdActive = false
                        _safeCallback(keybindConfig.Callback, false)
                    end
                end))
                
                keybindClickButton.MouseEnter:Connect(function()
                    if not keybindObj.isListening then _tween(keybindObj.buttonFrame, {BackgroundColor3 = _palette.ButtonHover}, 0.2) end
                end)
                keybindClickButton.MouseLeave:Connect(function()
                    if not keybindObj.isListening then _tween(keybindObj.buttonFrame, {BackgroundColor3 = _palette.ControlInset}, 0.2) end
                end)
                
                toggleModeClickButton.MouseEnter:Connect(function()
                    if keybindObj.mode ~= "Toggle" then
                        _tween(toggleModeFrame, {BackgroundColor3 = Color3.fromRGB(18, 18, 18)}, 0.12)
                    end
                end)
                toggleModeClickButton.MouseLeave:Connect(function()
                    updateModeVisuals()
                end)
                holdModeClickButton.MouseEnter:Connect(function()
                    if keybindObj.mode ~= "Hold" then
                        _tween(holdModeFrame, {BackgroundColor3 = Color3.fromRGB(18, 18, 18)}, 0.12)
                    end
                end)
                holdModeClickButton.MouseLeave:Connect(function()
                    updateModeVisuals()
                end)
                
                groupObj.Library:RegisterControl(keybindConfig.Flag, function()
                    return keybindObj:Get()
                end, function(value)
                    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
                        keybindObj:Set(value, true)
                    end
                end)
                groupObj.Library:RegisterControl(keybindConfig.ModeFlag, function()
                    return keybindObj:GetMode()
                end, function(value)
                    keybindObj:SetMode(value, true)
                end)
                
                groupObj.elementYPos = groupObj.elementYPos + 32 * _mScale
                updateGroupSizeYay()
                table.insert(groupObj.elementsInGroup, keybindObj)
                groupObj.Library:_DebugEnd(controlDebugToken, keybindConfig.Name)
                return keybindObj
            end

            function groupObj:AddKeybindToggle(keybindToggleConfig)
                keybindToggleConfig = keybindToggleConfig or {}
                keybindToggleConfig.Name = keybindToggleConfig.Name or "Keybind Toggle"
                keybindToggleConfig.Default = keybindToggleConfig.Default or Enum.KeyCode.Unknown
                keybindToggleConfig.ToggleDefault = keybindToggleConfig.ToggleDefault or false
                keybindToggleConfig.Callback = keybindToggleConfig.Callback or function() end
                keybindToggleConfig.ToggleCallback = keybindToggleConfig.ToggleCallback or function() end
                keybindToggleConfig.ChangedCallback = keybindToggleConfig.ChangedCallback or function() end
                keybindToggleConfig.Flag = keybindToggleConfig.Flag or createAutoFlag(keybindToggleConfig.Name .. ".Key")
                keybindToggleConfig.ToggleFlag = keybindToggleConfig.ToggleFlag or createAutoFlag(keybindToggleConfig.Name .. ".Enabled")
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddKeybindToggle")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddKeybindToggle", 1)
                addSearchTerm(keybindToggleConfig.Name)
                
                local keybindToggleObj = {}
                keybindToggleObj.keyValue = keybindToggleConfig.Default
                keybindToggleObj.toggleValue = keybindToggleConfig.ToggleDefault
                keybindToggleObj.isListening = false
                local yPosition = groupObj.elementYPos
                
                keybindToggleObj.labelText = _mkLabel(
                    groupObj.mainFrame,
                    groupObj.Library,
                    keybindToggleConfig.Name,
                    UDim2.new(0, controlPadX, 0, yPosition),
                    UDim2.new(1, -(144 * _mScale), 0, 20 * _mScale),
                    {
                        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
                        TextSize = 13.7 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                local keyText = keybindToggleObj.keyValue == Enum.KeyCode.Unknown and "None" or keybindToggleObj.keyValue.Name
                local keyWidth = math.max(48 * _mScale, howWideIsThisText(keyText, 12 * _mScale) + 30 * _mScale)
                
                local kbtBtnHeight = (_isMobile and 28 or 21) * _mScale
                keybindToggleObj.keybindButtonFrame = _mk("Frame", {
                    BackgroundColor3 = _palette.ControlInset, Position = UDim2.new(1, -keyWidth - controlRightPad, 0, yPosition),
                    Size = UDim2.new(0, keyWidth, 0, kbtBtnHeight), Parent = groupObj.mainFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = keybindToggleObj.keybindButtonFrame})
                
                local keybindStrokeThing = _mk("UIStroke", {Color = _palette.TacticalLine, Transparency = 0.56, Parent = keybindToggleObj.keybindButtonFrame})
                
                keybindToggleObj.keyLabelText = _mk("TextLabel", {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                    TextColor3 = _palette.FieldText, Text = keyText, BackgroundTransparency = 1,
                    Position = UDim2.new(0, 6, 0, 0), TextSize = 12.2 * _mScale,
                    Size = UDim2.new(1, -24 * _mScale, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = keybindToggleObj.keybindButtonFrame
                })
                
                keybindToggleObj.keyboardIconImg = _mk("ImageLabel", {
                    ImageColor3 = Color3.fromRGB(76, 76, 76), Image = _assetUrl("10723416765"), BackgroundTransparency = 1,
                    Position = UDim2.new(1, -18 * _mScale, 0.5, -7.5 * _mScale),
                    Size = UDim2.new(0, 15 * _mScale, 0, 15 * _mScale), Parent = keybindToggleObj.keybindButtonFrame
                })
                
                local kbtToggleW = (_isMobile and 46 or 34) * _mScale
                local kbtToggleH = (_isMobile and 26 or 19) * _mScale
                local kbtKnobSize = (_isMobile and 18 or 13) * _mScale
                local kbtKnobInset = 3 * _mScale
                local kbtKnobOff = UDim2.new(0, kbtKnobInset, 0, (kbtToggleH - kbtKnobSize) / 2)
                local kbtKnobOn = UDim2.new(0, kbtToggleW - kbtKnobSize - kbtKnobInset, 0, (kbtToggleH - kbtKnobSize) / 2)
                local activeKeybindToggleColor = groupObj.Library.config.AccentColor:Lerp(_palette.ControlInset, 0.12)

                keybindToggleObj.toggleSwitchFrame = _mk("Frame", {
                    BackgroundColor3 = keybindToggleObj.toggleValue and activeKeybindToggleColor or _palette.ToggleOff,
                    Position = UDim2.new(1, -keyWidth - kbtToggleW - controlRightPad - 8 * _mScale, 0, yPosition),
                    Size = UDim2.new(0, kbtToggleW, 0, kbtToggleH), Parent = groupObj.mainFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = keybindToggleObj.toggleSwitchFrame})
                keybindToggleObj.toggleSwitchStroke = _mk("UIStroke", {
                    Color = keybindToggleObj.toggleValue and groupObj.Library.config.AccentColor:Lerp(_palette.StrokeStrong, 0.28) or _palette.TacticalLine,
                    Transparency = keybindToggleObj.toggleValue and 0.34 or 0.62,
                    Thickness = 1,
                    Parent = keybindToggleObj.toggleSwitchFrame
                })
                
                keybindToggleObj.toggleCircleFrame = _mk("Frame", {
                    BackgroundColor3 = keybindToggleObj.toggleValue and Color3.new(1, 1, 1) or _palette.ToggleKnobOff,
                    Position = keybindToggleObj.toggleValue and kbtKnobOn or kbtKnobOff,
                    Size = UDim2.new(0, kbtKnobSize, 0, kbtKnobSize), Parent = keybindToggleObj.toggleSwitchFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = keybindToggleObj.toggleCircleFrame})
                
                local toggleClickButton = _mk("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = keybindToggleObj.toggleSwitchFrame})
                local keybindClickButton = _mk("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = keybindToggleObj.keybindButtonFrame})
                
                function keybindToggleObj:SetToggle(value, silent)
                    keybindToggleObj.toggleValue = value == true
                    if value then
                        _tween(keybindToggleObj.toggleSwitchFrame, {BackgroundColor3 = activeKeybindToggleColor}, 0.2)
                        _tween(keybindToggleObj.toggleSwitchStroke, {Color = groupObj.Library.config.AccentColor:Lerp(_palette.StrokeStrong, 0.28), Transparency = 0.34}, 0.2)
                        _tween(keybindToggleObj.toggleCircleFrame, {Position = kbtKnobOn, BackgroundColor3 = Color3.new(1, 1, 1)}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                    else
                        _tween(keybindToggleObj.toggleSwitchFrame, {BackgroundColor3 = _palette.ToggleOff}, 0.2)
                        _tween(keybindToggleObj.toggleSwitchStroke, {Color = _palette.TacticalLine, Transparency = 0.62}, 0.2)
                        _tween(keybindToggleObj.toggleCircleFrame, {Position = kbtKnobOff, BackgroundColor3 = _palette.ToggleKnobOff}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                    end
                    if not silent then
                        _safeCallback(keybindToggleConfig.ToggleCallback, keybindToggleObj.toggleValue)
                    end
                end
                
                local function updateKeybindSizeYay(text)
                    local newWidth = math.max(48 * _mScale, howWideIsThisText(text, 12 * _mScale) + 30 * _mScale)
                    _tween(keybindToggleObj.keybindButtonFrame, {Size = UDim2.new(0, newWidth, 0, kbtBtnHeight), Position = UDim2.new(1, -newWidth - controlRightPad, 0, yPosition)}, 0.15)
                    _tween(keybindToggleObj.toggleSwitchFrame, {Position = UDim2.new(1, -newWidth - kbtToggleW - controlRightPad - 8 * _mScale, 0, yPosition)}, 0.15)
                end
                
                function keybindToggleObj:SetKey(key, silent)
                    keybindToggleObj.keyValue = key
                    local keyText = key == Enum.KeyCode.Unknown and "None" or key.Name
                    keybindToggleObj.keyLabelText.Text = keyText
                    updateKeybindSizeYay(keyText)
                    if not silent then
                        _safeCallback(keybindToggleConfig.ChangedCallback, key)
                    end
                end

                function keybindToggleObj:GetKey()
                    return keybindToggleObj.keyValue
                end

                function keybindToggleObj:GetToggle()
                    return keybindToggleObj.toggleValue
                end
                
                toggleClickButton.MouseButton1Click:Connect(function() keybindToggleObj:SetToggle(not keybindToggleObj.toggleValue, false) end)
                keybindClickButton.MouseButton1Click:Connect(function()
                    keybindToggleObj.isListening = true
                    keybindToggleObj.keyLabelText.Text = "..."
                    updateKeybindSizeYay("...")
                    _tween(keybindToggleObj.keybindButtonFrame, {BackgroundColor3 = _palette.ButtonHover}, 0.2)
                end)
                
                groupObj.Library:_TrackConnection(_uis.InputBegan:Connect(function(input, gameProcessed)
                    if keybindToggleObj.isListening then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            keybindToggleObj.isListening = false
                            keybindToggleObj:SetKey(input.KeyCode, false)
                            _tween(keybindToggleObj.keybindButtonFrame, {BackgroundColor3 = _palette.ControlInset}, 0.2)
                        end
                    elseif not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard then
                        if input.KeyCode == keybindToggleObj.keyValue and keybindToggleObj.toggleValue then
                            _safeCallback(keybindToggleConfig.Callback)
                        end
                    end
                end))
                
                keybindClickButton.MouseEnter:Connect(function() if not keybindToggleObj.isListening then _tween(keybindToggleObj.keybindButtonFrame, {BackgroundColor3 = _palette.ButtonHover}, 0.2) end end)
                keybindClickButton.MouseLeave:Connect(function() if not keybindToggleObj.isListening then _tween(keybindToggleObj.keybindButtonFrame, {BackgroundColor3 = _palette.ControlInset}, 0.2) end end)
                
                groupObj.Library:RegisterControl(keybindToggleConfig.Flag, function()
                    return keybindToggleObj:GetKey()
                end, function(value)
                    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
                        keybindToggleObj:SetKey(value, true)
                    end
                end)
                groupObj.Library:RegisterControl(keybindToggleConfig.ToggleFlag, function()
                    return keybindToggleObj:GetToggle()
                end, function(value)
                    keybindToggleObj:SetToggle(value == true, true)
                end)
                groupObj.elementYPos = groupObj.elementYPos + 31 * _mScale
                updateGroupSizeYay()
                table.insert(groupObj.elementsInGroup, keybindToggleObj)
                groupObj.Library:_DebugEnd(controlDebugToken, keybindToggleConfig.Name)
                return keybindToggleObj
            end

            function groupObj:AddDropdown(dropdownConfig)
                dropdownConfig = dropdownConfig or {}
                dropdownConfig.Name = dropdownConfig.Name or "Dropdown"
                dropdownConfig.Options = dropdownConfig.Options or {"Option 1", "Option 2", "Option 3"}
                dropdownConfig.OptionsProvider = dropdownConfig.OptionsProvider or dropdownConfig.GetOptions
                local dropdownHasProvider = type(dropdownConfig.OptionsProvider) == "function"
                if dropdownConfig.AutoRefresh == nil then
                    dropdownConfig.AutoRefresh = dropdownHasProvider
                else
                    dropdownConfig.AutoRefresh = dropdownConfig.AutoRefresh == true
                end
                dropdownConfig.RefreshInterval = math.max(tonumber(dropdownConfig.RefreshInterval) or 0.85, 0.35)
                dropdownConfig.Callback = dropdownConfig.Callback or function() end
                dropdownConfig.Flag = dropdownConfig.Flag or createAutoFlag(dropdownConfig.Name)
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddDropdown")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddDropdown", 1)
                local dropdownOptionsSource = dropdownConfig.Options
                if type(dropdownConfig.OptionsProvider) == "function" then
                    local providerDebugToken = groupObj.Library:_DebugBegin("Dropdown.OptionsProvider.Initial")
                    local ok, providedOptions = pcall(dropdownConfig.OptionsProvider)
                    groupObj.Library:_DebugEnd(providerDebugToken, dropdownConfig.Name)
                    if ok and type(providedOptions) == "table" then
                        dropdownOptionsSource = providedOptions
                    end
                end
                dropdownConfig.Options = normalizeDropdownOptions(dropdownOptionsSource)
                dropdownConfig.Default = dropdownConfig.Default or dropdownConfig.Options[1] or "None"
                if not table.find(dropdownConfig.Options, dropdownConfig.Default) then
                    dropdownConfig.Default = dropdownConfig.Options[1] or "None"
                end
                addSearchTerm(dropdownConfig.Name)
                for _, option in ipairs(dropdownConfig.Options) do
                    addSearchTerm(tostring(option))
                end
                
                local dropdownObj = {}
                dropdownObj.value = dropdownConfig.Default
                dropdownObj.isOpen = false
                dropdownObj._optionsSignature = getDropdownOptionsSignature(dropdownOptionsSource)
                if dropdownObj._optionsSignature == "0" then
                    dropdownObj._optionsSignature = getDropdownOptionsSignature(dropdownConfig.Options)
                end
                local yPosition = groupObj.elementYPos
                local displayText = tostring(dropdownObj.value or "None")
                local buttonWidth = math.clamp(howWideIsThisText(displayText, 12 * _mScale) + 30 * _mScale, 78 * _mScale, 118 * _mScale)
                
                dropdownObj.labelText = _mkLabel(
                    groupObj.mainFrame,
                    groupObj.Library,
                    dropdownConfig.Name,
                    UDim2.new(0, controlPadX, 0, yPosition),
                    UDim2.new(1, -(buttonWidth + controlPadX + controlRightPad + controlValueGap), 0, 20 * _mScale),
                    {
                        TextSize = 13.8 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                local ddBtnHeight = (_isMobile and 28 or 23) * _mScale
                
                dropdownObj.buttonFrame, dropdownObj.strokeThing = _mkSurface(
                    groupObj.mainFrame,
                    _palette.ControlInset,
                    UDim2.new(1, -buttonWidth - controlRightPad, 0, yPosition),
                    UDim2.new(0, buttonWidth, 0, ddBtnHeight),
                    {
                        CornerRadius = UDim.new(1, 0),
                        StrokeColor = _palette.TacticalLine
                    }
                )
                
                local dropdownStrokeThing = dropdownObj.strokeThing
                if dropdownStrokeThing then
                    dropdownStrokeThing.Transparency = 0.42
                end
                
                dropdownObj.selectedLabelText = _mkLabel(
                    dropdownObj.buttonFrame,
                    groupObj.Library,
                    displayText,
                    UDim2.new(0, 8, 0, 0),
                    UDim2.new(1, -28 * _mScale, 1, 0),
                    {
                        TextColor = _palette.FieldText,
                        TextSize = 12.4 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                dropdownObj.arrowImg = _mkIcon(
                    dropdownObj.buttonFrame,
                    _assetUrl("111626678408582"),
                    _getSubClr(groupObj.Library):Lerp(_palette.TextSoft, 0.45),
                    UDim2.new(1, -20 * _mScale, 0.5, -7.5 * _mScale),
                    UDim2.new(0, 15 * _mScale, 0, 15 * _mScale)
                )
                
                dropdownObj.optionHolderFrame = _mkSurface(
                    groupObj.Library.dropdownHolderRef,
                    _palette.Panel,
                    UDim2.new(0, 0, 0, 0),
                    UDim2.new(0, 152 * _mScale, 0, 0),
                    {
                        ClipsDescendants = true,
            CornerRadius = _cornerTk.Tight,
                        StrokeColor = _palette.TacticalLine,
                        ZIndex = 9999
                    }
                )
                dropdownObj.optionHolderFrame.Visible = false
                
                _mkLabel(
                    dropdownObj.optionHolderFrame,
                    groupObj.Library,
                    dropdownConfig.Name,
                    UDim2.new(0, 12, 0, 8 * _mScale),
                    UDim2.new(1, -44 * _mScale, 0, 20 * _mScale),
                    {
                        TextColor = _getTextClr(groupObj.Library),
                        TextSize = 14 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        ZIndex = 10000
                    }
                )

                local dropdownCloseButton = _mk("TextButton", {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                    Text = "X", TextColor3 = _palette.TextMuted, TextSize = 13 * _mScale,
                    BackgroundColor3 = _palette.ControlInset, AutoButtonColor = false,
                    Position = UDim2.new(1, -25 * _mScale, 0, 5 * _mScale),
                    Size = UDim2.new(0, 18 * _mScale, 0, 18 * _mScale),
                    ZIndex = 10002, Parent = dropdownObj.optionHolderFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = dropdownCloseButton})
                
                dropdownObj.optionScrollFrame = _mk("ScrollingFrame", {
                    BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 30 * _mScale),
                    Size = UDim2.new(1, 0, 1, -35 * _mScale), BorderSizePixel = 0, ScrollBarThickness = 0,
                    ScrollBarImageColor3 = Color3.fromRGB(50, 50, 50), CanvasSize = UDim2.new(0, 0, 0, 0),
                    ZIndex = 10000, Parent = dropdownObj.optionHolderFrame
                })
                _attachScrollbar(groupObj.Library, dropdownObj.optionScrollFrame, dropdownObj.optionHolderFrame, {
                    TrackWidth = 7 * _mScale,
                    ThumbWidth = 3 * _mScale,
                    EdgeInset = 2 * _mScale,
                    VerticalInset = 4 * _mScale,
                    ZIndex = 10002
                })
                dropdownObj.optionScrollFrame:SetAttribute("FlowDisableSmoothScroll", true)
                --groupObj.Library:EnableSmoothScrolling(dropdownObj.optionScrollFrame, 22)
                
                dropdownObj.optionContainerFrame = _mk("Frame", {
                    BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 0),
                    ZIndex = 10000, Parent = dropdownObj.optionScrollFrame
                })
                
                local dropdownPopupWidth = 152 * _mScale
                local maxDropdownHeight = 200 * _mScale
                local dropdownPositionUpdateConn = nil

                local function closeDropdown(isInstant)
                    dropdownObj.isOpen = false
                    if dropdownPositionUpdateConn then
                        dropdownPositionUpdateConn()
                        dropdownPositionUpdateConn = nil
                    end
                    if isInstant then
                        dropdownObj.optionHolderFrame.Size = UDim2.new(0, dropdownPopupWidth, 0, 0)
                        dropdownObj.optionHolderFrame.Visible = false
                        dropdownObj.arrowImg.Rotation = 0
                        dropdownObj.buttonFrame.BackgroundColor3 = _palette.ControlInset
                        dropdownStrokeThing.Color = _palette.TacticalLine
                        dropdownStrokeThing.Transparency = 0.42
                        return
                    end
                    _tween(dropdownObj.optionHolderFrame, {Size = UDim2.new(0, dropdownPopupWidth, 0, 0)}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                    _tween(dropdownObj.arrowImg, {Rotation = 0}, 0.2)
                    _tween(dropdownObj.buttonFrame, {BackgroundColor3 = _palette.ControlInset}, 0.18)
                    _tween(dropdownStrokeThing, {Color = _palette.TacticalLine, Transparency = 0.42}, 0.18)
                    task.delay(0.22, function()
                        if dropdownObj.optionHolderFrame.Parent and not dropdownObj.isOpen then
                            dropdownObj.optionHolderFrame.Visible = false
                        end
                    end)
                end

                dropdownCloseButton.MouseButton1Click:Connect(function()
                    closeDropdown(false)
                end)
                dropdownCloseButton.MouseEnter:Connect(function()
                    _tween(dropdownCloseButton, {BackgroundColor3 = _palette.SurfaceHover, TextColor3 = _palette.Text}, 0.12)
                end)
                dropdownCloseButton.MouseLeave:Connect(function()
                    _tween(dropdownCloseButton, {BackgroundColor3 = _palette.SurfaceSoft, TextColor3 = _palette.TextMuted}, 0.12)
                end)
                
                local function createOptionsYay()
                    for _, child in pairs(dropdownObj.optionContainerFrame:GetChildren()) do
                        if child:IsA("TextLabel") or child:IsA("TextButton") then child:Destroy() end
                    end
                    local optY = 0
                    for _, option in ipairs(dropdownConfig.Options) do
                        local isSelected = dropdownObj.value == option
                        local optionLabelText = _mk("TextLabel", {
                            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                            TextColor3 = isSelected and groupObj.Library.config.AccentColor or (groupObj.Library.config.SubTextColor or _palette.TextMuted),
                            Text = tostring(option), BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, optY),
                            TextSize = 13 * _mScale, Size = UDim2.new(1, -24, 0, 18 * _mScale),
                            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                            ZIndex = 10001, Parent = dropdownObj.optionContainerFrame
                        })
                        local optionRowH = (_isMobile and 26 or 20) * _mScale
                        local optionClickButton = _mk("TextButton", {
                            Text = "", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, optY),
                            Size = UDim2.new(1, 0, 0, optionRowH), ZIndex = 10002, Parent = dropdownObj.optionContainerFrame
                        })
                        optionClickButton.MouseButton1Click:Connect(function()
                            dropdownObj.value = option
                            closeDropdown(false)
                            local optionText = tostring(option)
                            dropdownObj.selectedLabelText.Text = optionText
                            local newWidth = math.clamp(howWideIsThisText(optionText, 12 * _mScale) + 30 * _mScale, 78 * _mScale, 118 * _mScale)
                            _tween(dropdownObj.buttonFrame, {Size = UDim2.new(0, newWidth, 0, ddBtnHeight), Position = UDim2.new(1, -newWidth - controlRightPad, 0, yPosition)}, 0.15)
                            createOptionsYay()
                            _safeCallback(dropdownConfig.Callback, option)
                        end)
                        optionClickButton.MouseEnter:Connect(function() if dropdownObj.value ~= option then _tween(optionLabelText, {TextColor3 = _palette.TextMuted}, 0.2) end end)
                        optionClickButton.MouseLeave:Connect(function() if dropdownObj.value ~= option then _tween(optionLabelText, {TextColor3 = groupObj.Library.config.SubTextColor or _palette.TextMuted}, 0.2) end end)
                        optY = optY + (_isMobile and 30 or 22) * _mScale
                    end
                    dropdownObj.optionContainerFrame.Size = UDim2.new(1, -6, 0, optY)
                    dropdownObj.optionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, optY)
                end
                createOptionsYay()
                
                local dropdownClickButton = _mk("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = dropdownObj.buttonFrame})
                
                local function updateDropdownPositionYay(openHeight)
                    local buttonAbsPos = dropdownObj.buttonFrame.AbsolutePosition
                    local buttonAbsSize = dropdownObj.buttonFrame.AbsoluteSize
                    local viewportWidth = groupObj.Library._cachedViewportWidth or 1280
                    local viewportHeight = groupObj.Library._cachedViewportHeight or 720
                    local popupHeight = tonumber(openHeight) or dropdownObj.optionHolderFrame.AbsoluteSize.Y
                    local xPos = math.clamp(buttonAbsPos.X + buttonAbsSize.X - dropdownPopupWidth, 8, math.max(8, viewportWidth - dropdownPopupWidth - 8))
                    local yPos = buttonAbsPos.Y + buttonAbsSize.Y + 6
                    if popupHeight > 0 and yPos + popupHeight > viewportHeight - 8 then
                        yPos = math.max(8, buttonAbsPos.Y - popupHeight - 6)
                    end
                    dropdownObj.optionHolderFrame.Position = UDim2.new(0, xPos, 0, yPos)
                end
                
                dropdownClickButton.MouseButton1Click:Connect(function()
                    dropdownObj.isOpen = not dropdownObj.isOpen
                    if dropdownObj.isOpen then
                        local contentHeight = (35 + (#dropdownConfig.Options * (_isMobile and 30 or 22))) * _mScale
                        local height = math.min(contentHeight, maxDropdownHeight)
                        updateDropdownPositionYay(height)
                        dropdownObj.optionHolderFrame.Visible = true
                        _tween(dropdownObj.optionHolderFrame, {Size = UDim2.new(0, dropdownPopupWidth, 0, height)}, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        _tween(dropdownObj.arrowImg, {Rotation = 180}, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        if dropdownPositionUpdateConn then dropdownPositionUpdateConn() end
                        dropdownPositionUpdateConn = startFloatingPositionTracker(groupObj.Library, dropdownObj.buttonFrame, function()
                            if dropdownObj.isOpen then
                                updateDropdownPositionYay()
                            end
                        end)
                    else
                        closeDropdown(false)
                    end
                end)
                
                dropdownClickButton.MouseEnter:Connect(function()
                    _tween(dropdownObj.buttonFrame, {BackgroundColor3 = _palette.ButtonHover}, 0.2)
                    _tween(dropdownStrokeThing, {Color = _palette.StrokeStrong, Transparency = 0.18}, 0.2)
                end)
                dropdownClickButton.MouseLeave:Connect(function()
                    if not dropdownObj.isOpen then
                        _tween(dropdownObj.buttonFrame, {BackgroundColor3 = _palette.ControlInset}, 0.2)
                        _tween(dropdownStrokeThing, {Color = _palette.TacticalLine, Transparency = 0.42}, 0.2)
                    end
                end)
                
                function dropdownObj:Set(value, silent)
                    if value == nil then return end
                    dropdownObj.value = value
                    local displayValue = tostring(value)
                    dropdownObj.selectedLabelText.Text = displayValue
                    local newWidth = math.clamp(howWideIsThisText(displayValue, 12 * _mScale) + 30 * _mScale, 78 * _mScale, 118 * _mScale)
                    dropdownObj.buttonFrame.Size = UDim2.new(0, newWidth, 0, ddBtnHeight)
                    dropdownObj.buttonFrame.Position = UDim2.new(1, -newWidth - controlRightPad, 0, yPosition)
                    createOptionsYay()
                    if not silent then
                        _safeCallback(dropdownConfig.Callback, value)
                    end
                end

                function dropdownObj:Get()
                    return dropdownObj.value
                end
                
                function dropdownObj:UpdateOptions(newOptions)
                    if type(newOptions) ~= "table" then
                        return
                    end
                    dropdownOptionsSource = newOptions
                    dropdownObj._optionsSignature = getDropdownOptionsSignature(newOptions)
                    dropdownConfig.Options = normalizeDropdownOptions(newOptions)
                    for _, option in ipairs(dropdownConfig.Options) do
                        addSearchTerm(tostring(option))
                    end
                    if not table.find(dropdownConfig.Options, dropdownObj.value) then
                        dropdownObj.value = dropdownConfig.Options[1] or "None"
                    end
                    local displayValue = tostring(dropdownObj.value or "None")
                    dropdownObj.selectedLabelText.Text = displayValue
                    local newWidth = math.clamp(howWideIsThisText(displayValue, 12 * _mScale) + 30 * _mScale, 78 * _mScale, 118 * _mScale)
                    dropdownObj.buttonFrame.Size = UDim2.new(0, newWidth, 0, ddBtnHeight)
                    dropdownObj.buttonFrame.Position = UDim2.new(1, -newWidth - controlRightPad, 0, yPosition)
                    createOptionsYay()
                    if groupObj.Library._searchQuery ~= "" then
                        groupObj.Library:ApplySearchFilter(groupObj.Library._searchQuery)
                    end
                end

                if dropdownConfig.AutoRefresh then
                    groupObj.Library:_RegisterRefreshJob(dropdownConfig.RefreshInterval, function()
                        return not groupObj.Library._destroyed and dropdownObj.buttonFrame and dropdownObj.buttonFrame.Parent
                    end, function()
                        local latestOptions = dropdownOptionsSource
                        if type(dropdownConfig.OptionsProvider) == "function" then
                            local providerDebugToken = groupObj.Library:_DebugBegin("Dropdown.OptionsProvider.Refresh")
                            local ok, providedOptions = pcall(dropdownConfig.OptionsProvider)
                            groupObj.Library:_DebugEnd(providerDebugToken, dropdownConfig.Name)
                            if ok and type(providedOptions) == "table" then
                                latestOptions = providedOptions
                            end
                        end
                        local latestSignature = getDropdownOptionsSignature(latestOptions)
                        if latestSignature ~= dropdownObj._optionsSignature then
                            dropdownObj:UpdateOptions(latestOptions)
                        end
                        return true
                    end)
                end

                function dropdownObj:Close()
                    closeDropdown(true)
                end
                groupObj.Library:RegisterControl(dropdownConfig.Flag, function()
                    return dropdownObj:Get()
                end, function(value)
                    if value ~= nil then
                        dropdownObj:Set(value, true)
                    end
                end)
                
                groupObj.elementYPos = groupObj.elementYPos + 32 * _mScale
                updateGroupSizeYay()
                table.insert(groupObj.elementsInGroup, dropdownObj)
                groupObj.Library:_DebugEnd(controlDebugToken, dropdownConfig.Name)
                return dropdownObj
            end

            function groupObj:AddMultiDropdown(multiDropdownConfig)
                multiDropdownConfig = multiDropdownConfig or {}
                multiDropdownConfig.Name = multiDropdownConfig.Name or "Multi Dropdown"
                multiDropdownConfig.Options = multiDropdownConfig.Options or {"Option 1", "Option 2", "Option 3"}
                multiDropdownConfig.OptionsProvider = multiDropdownConfig.OptionsProvider or multiDropdownConfig.GetOptions
                local multiDropdownHasProvider = type(multiDropdownConfig.OptionsProvider) == "function"
                if multiDropdownConfig.AutoRefresh == nil then
                    multiDropdownConfig.AutoRefresh = multiDropdownHasProvider
                else
                    multiDropdownConfig.AutoRefresh = multiDropdownConfig.AutoRefresh == true
                end
                multiDropdownConfig.RefreshInterval = math.max(tonumber(multiDropdownConfig.RefreshInterval) or 0.85, 0.35)
                multiDropdownConfig.Default = multiDropdownConfig.Default or {}
                multiDropdownConfig.Callback = multiDropdownConfig.Callback or function() end
                multiDropdownConfig.Flag = multiDropdownConfig.Flag or createAutoFlag(multiDropdownConfig.Name)
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddMultiDropdown")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddMultiDropdown", 1)
                local multiDropdownOptionsSource = multiDropdownConfig.Options
                if type(multiDropdownConfig.OptionsProvider) == "function" then
                    local providerDebugToken = groupObj.Library:_DebugBegin("MultiDropdown.OptionsProvider.Initial")
                    local ok, providedOptions = pcall(multiDropdownConfig.OptionsProvider)
                    groupObj.Library:_DebugEnd(providerDebugToken, multiDropdownConfig.Name)
                    if ok and type(providedOptions) == "table" then
                        multiDropdownOptionsSource = providedOptions
                    end
                end
                multiDropdownConfig.Options = normalizeDropdownOptions(multiDropdownOptionsSource)
                addSearchTerm(multiDropdownConfig.Name)
                for _, option in ipairs(multiDropdownConfig.Options) do
                    addSearchTerm(tostring(option))
                end
                
                local multiDropdownObj = {}
                multiDropdownObj.selectedValues = {}
                for _, v in ipairs(multiDropdownConfig.Default) do
                    if table.find(multiDropdownConfig.Options, v) then
                        multiDropdownObj.selectedValues[v] = true
                    end
                end
                multiDropdownObj.isOpen = false
                multiDropdownObj._optionsSignature = getDropdownOptionsSignature(multiDropdownOptionsSource)
                if multiDropdownObj._optionsSignature == "0" then
                    multiDropdownObj._optionsSignature = getDropdownOptionsSignature(multiDropdownConfig.Options)
                end
                local yPosition = groupObj.elementYPos
                
                local function getDisplayText()
                    local selected = {}
                    for option, isSelected in pairs(multiDropdownObj.selectedValues) do
                        if isSelected then table.insert(selected, option) end
                    end
                    table.sort(selected, function(a, b)
                        return tostring(a) < tostring(b)
                    end)
                    if #selected == 0 then return "None"
                    elseif #selected == 1 then return selected[1]
                    elseif #selected <= 2 then return table.concat(selected, ", ")
                    else return #selected .. " selected" end
                end
                
                local function getSelectedArray()
                    local arr = {}
                    for option, isSelected in pairs(multiDropdownObj.selectedValues) do
                        if isSelected then table.insert(arr, option) end
                    end
                    table.sort(arr, function(a, b)
                        return tostring(a) < tostring(b)
                    end)
                    return arr
                end
                
                local displayText = getDisplayText()
                local buttonWidth = math.clamp(howWideIsThisText(displayText, 12 * _mScale) + 35 * _mScale, 88 * _mScale, 126 * _mScale)
                
                local mddBtnHeight = (_isMobile and 28 or 21) * _mScale
                multiDropdownObj.labelText = _mkLabel(
                    groupObj.mainFrame,
                    groupObj.Library,
                    multiDropdownConfig.Name,
                    UDim2.new(0, controlPadX, 0, yPosition),
                    UDim2.new(1, -(buttonWidth + controlPadX + controlRightPad + controlValueGap), 0, 20 * _mScale),
                    {
                        TextSize = 13.8 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                multiDropdownObj.buttonFrame, multiDropdownObj.strokeThing = _mkSurface(
                    groupObj.mainFrame,
                    _palette.ControlInset,
                    UDim2.new(1, -buttonWidth - controlRightPad, 0, yPosition),
                    UDim2.new(0, buttonWidth, 0, mddBtnHeight),
                    {
                        CornerRadius = UDim.new(1, 0),
                        StrokeColor = _palette.TacticalLine
                    }
                )
                
                local dropdownStrokeThing = multiDropdownObj.strokeThing
                if dropdownStrokeThing then
                    dropdownStrokeThing.Transparency = 0.42
                end
                
                multiDropdownObj.selectedLabelText = _mkLabel(
                    multiDropdownObj.buttonFrame,
                    groupObj.Library,
                    displayText,
                    UDim2.new(0, 8, 0, 0),
                    UDim2.new(1, -28 * _mScale, 1, 0),
                    {
                        TextColor = _palette.FieldText,
                        TextSize = 12 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                multiDropdownObj.arrowImg = _mkIcon(
                    multiDropdownObj.buttonFrame,
                    _assetUrl("111626678408582"),
                    _getSubClr(groupObj.Library):Lerp(_palette.TextSoft, 0.45),
                    UDim2.new(1, -20 * _mScale, 0.5, -7 * _mScale),
                    UDim2.new(0, 14 * _mScale, 0, 14 * _mScale)
                )
                
                multiDropdownObj.optionHolderFrame = _mkSurface(
                    groupObj.Library.dropdownHolderRef,
                    _palette.Panel,
                    UDim2.new(0, 0, 0, 0),
                    UDim2.new(0, 176 * _mScale, 0, 0),
                    {
                        ClipsDescendants = true,
            CornerRadius = _cornerTk.Tight,
                        StrokeColor = _palette.TacticalLine,
                        ZIndex = 9999
                    }
                )
                multiDropdownObj.optionHolderFrame.Visible = false
                
                _mkLabel(
                    multiDropdownObj.optionHolderFrame,
                    groupObj.Library,
                    multiDropdownConfig.Name,
                    UDim2.new(0, 12, 0, 8 * _mScale),
                    UDim2.new(1, -44 * _mScale, 0, 20 * _mScale),
                    {
                        TextColor = _getTextClr(groupObj.Library),
                        TextSize = 14 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        ZIndex = 10000
                    }
                )

                local multiDropdownCloseButton = _mk("TextButton", {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                    Text = "X", TextColor3 = _palette.TextMuted, TextSize = 13 * _mScale,
                    BackgroundColor3 = _palette.ControlInset, AutoButtonColor = false,
                    Position = UDim2.new(1, -25 * _mScale, 0, 5 * _mScale),
                    Size = UDim2.new(0, 18 * _mScale, 0, 18 * _mScale),
                    ZIndex = 10002, Parent = multiDropdownObj.optionHolderFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = multiDropdownCloseButton})
                
                multiDropdownObj.optionScrollFrame = _mk("ScrollingFrame", {
                    BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 30 * _mScale),
                    Size = UDim2.new(1, 0, 1, -35 * _mScale), BorderSizePixel = 0, ScrollBarThickness = 0,
                    ScrollBarImageColor3 = Color3.fromRGB(50, 50, 50), CanvasSize = UDim2.new(0, 0, 0, 0),
                    ZIndex = 10000, Parent = multiDropdownObj.optionHolderFrame
                })
                _attachScrollbar(groupObj.Library, multiDropdownObj.optionScrollFrame, multiDropdownObj.optionHolderFrame, {
                    TrackWidth = 7 * _mScale,
                    ThumbWidth = 3 * _mScale,
                    EdgeInset = 2 * _mScale,
                    VerticalInset = 4 * _mScale,
                    ZIndex = 10002
                })
                multiDropdownObj.optionScrollFrame:SetAttribute("FlowDisableSmoothScroll", true)
                --groupObj.Library:EnableSmoothScrolling(multiDropdownObj.optionScrollFrame, 22)
                
                multiDropdownObj.optionContainerFrame = _mk("Frame", {
                    BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 0),
                    ZIndex = 10000, Parent = multiDropdownObj.optionScrollFrame
                })
                
                local multiDropdownPopupWidth = 176 * _mScale
                local maxMultiDropdownHeight = 220 * _mScale
                local multiDropdownPositionConn = nil

                local function closeMultiDropdown(isInstant)
                    multiDropdownObj.isOpen = false
                    if multiDropdownPositionConn then
                        multiDropdownPositionConn()
                        multiDropdownPositionConn = nil
                    end
                    if isInstant then
                        multiDropdownObj.optionHolderFrame.Size = UDim2.new(0, multiDropdownPopupWidth, 0, 0)
                        multiDropdownObj.optionHolderFrame.Visible = false
                        multiDropdownObj.arrowImg.Rotation = 0
                        multiDropdownObj.buttonFrame.BackgroundColor3 = _palette.ControlInset
                        dropdownStrokeThing.Color = _palette.TacticalLine
                        dropdownStrokeThing.Transparency = 0.42
                        return
                    end
                    _tween(multiDropdownObj.optionHolderFrame, {Size = UDim2.new(0, multiDropdownPopupWidth, 0, 0)}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                    _tween(multiDropdownObj.arrowImg, {Rotation = 0}, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                    _tween(multiDropdownObj.buttonFrame, {BackgroundColor3 = _palette.ControlInset}, 0.18)
                    _tween(dropdownStrokeThing, {Color = _palette.TacticalLine, Transparency = 0.42}, 0.18)
                    task.delay(0.22, function()
                        if multiDropdownObj.optionHolderFrame.Parent and not multiDropdownObj.isOpen then
                            multiDropdownObj.optionHolderFrame.Visible = false
                        end
                    end)
                end

                multiDropdownCloseButton.MouseButton1Click:Connect(function()
                    closeMultiDropdown(false)
                end)
                multiDropdownCloseButton.MouseEnter:Connect(function()
                    _tween(multiDropdownCloseButton, {BackgroundColor3 = _palette.SurfaceHover, TextColor3 = _palette.Text}, 0.12)
                end)
                multiDropdownCloseButton.MouseLeave:Connect(function()
                    _tween(multiDropdownCloseButton, {BackgroundColor3 = _palette.SurfaceSoft, TextColor3 = _palette.TextMuted}, 0.12)
                end)

                local function createMultiOptionsYay()
                    for _, child in pairs(multiDropdownObj.optionContainerFrame:GetChildren()) do
                        if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
                    end
                    local optY = 0
                    for _, option in ipairs(multiDropdownConfig.Options) do
                        local isSelected = multiDropdownObj.selectedValues[option] == true
                        
                        local mddRowH = (_isMobile and 28 or 22) * _mScale
                        local mddCheckSize = (_isMobile and 20 or 16) * _mScale
                        local optionFrame = _mk("Frame", {
                            BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, optY),
                            Size = UDim2.new(1, 0, 0, mddRowH), ZIndex = 10001,
                            Parent = multiDropdownObj.optionContainerFrame
                        })
                        
                        local checkboxFrame = _mk("Frame", {
                            BackgroundColor3 = isSelected and groupObj.Library.config.AccentColor or _palette.ControlInset,
                            Position = UDim2.new(0, 12, 0.5, -mddCheckSize / 2),
                            Size = UDim2.new(0, mddCheckSize, 0, mddCheckSize),
                            ZIndex = 10002, Parent = optionFrame
                        })
                        _mk("UICorner", {CornerRadius = UDim.new(0, 4), Parent = checkboxFrame})
                        
                        local checkmarkImg = _mk("ImageLabel", {
                            Image = _assetUrl("10709790644"), ImageColor3 = Color3.new(1, 1, 1),
                            ImageTransparency = isSelected and 0 or 1, BackgroundTransparency = 1,
                            Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
                            Size = UDim2.new(0, (_isMobile and 16 or 12) * _mScale, 0, (_isMobile and 16 or 12) * _mScale),
                            ZIndex = 10003, Parent = checkboxFrame
                        })
                        
                        local optionLabelText = _mkLabel(
                            optionFrame,
                            groupObj.Library,
                            tostring(option),
                            UDim2.new(0, 34, 0, 0),
                            UDim2.new(1, -46, 1, 0),
                            {
                                TextColor = isSelected and groupObj.Library.config.AccentColor or _getSubClr(groupObj.Library),
                                TextSize = 14 * _mScale,
                                ZIndex = 10002
                            }
                        )
                        
                        local optionClickButton = _mk("TextButton", {
                            Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                            ZIndex = 10004, Parent = optionFrame
                        })
                        
                        optionClickButton.MouseButton1Click:Connect(function()
                            multiDropdownObj.selectedValues[option] = not multiDropdownObj.selectedValues[option]
                            local nowSelected = multiDropdownObj.selectedValues[option]
                            
                            _tween(checkboxFrame, {BackgroundColor3 = nowSelected and groupObj.Library.config.AccentColor or _palette.ControlInset}, 0.15)
                            _tween(checkmarkImg, {ImageTransparency = nowSelected and 0 or 1}, 0.15)
                            _tween(optionLabelText, {TextColor3 = nowSelected and groupObj.Library.config.AccentColor or _getSubClr(groupObj.Library)}, 0.15)
                            
                            local newDisplayText = getDisplayText()
                            multiDropdownObj.selectedLabelText.Text = newDisplayText
                            local newWidth = math.clamp(howWideIsThisText(newDisplayText, 12 * _mScale) + 35 * _mScale, 88 * _mScale, 126 * _mScale)
                            _tween(multiDropdownObj.buttonFrame, {Size = UDim2.new(0, newWidth, 0, mddBtnHeight), Position = UDim2.new(1, -newWidth - controlRightPad, 0, yPosition)}, 0.15)
                            
                            _safeCallback(multiDropdownConfig.Callback, getSelectedArray())
                        end)
                        
                        optionClickButton.MouseEnter:Connect(function()
                            if not multiDropdownObj.selectedValues[option] then
                                _tween(optionLabelText, {TextColor3 = _palette.TextMuted}, 0.15)
                                _tween(checkboxFrame, {BackgroundColor3 = _palette.ButtonHover}, 0.15)
                            end
                        end)
                        optionClickButton.MouseLeave:Connect(function()
                            if not multiDropdownObj.selectedValues[option] then
                                _tween(optionLabelText, {TextColor3 = _getSubClr(groupObj.Library)}, 0.15)
                                _tween(checkboxFrame, {BackgroundColor3 = _palette.ControlInset}, 0.15)
                            end
                        end)
                        
                        optY = optY + (_isMobile and 32 or 24) * _mScale
                    end
                    multiDropdownObj.optionContainerFrame.Size = UDim2.new(1, -6, 0, optY)
                    multiDropdownObj.optionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, optY)
                end
                createMultiOptionsYay()
                
                local dropdownClickButton = _mk("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = multiDropdownObj.buttonFrame})
                
                local function updateDropdownPositionYay(openHeight)
                    local buttonAbsPos = multiDropdownObj.buttonFrame.AbsolutePosition
                    local buttonAbsSize = multiDropdownObj.buttonFrame.AbsoluteSize
                    local viewportWidth = groupObj.Library._cachedViewportWidth or 1280
                    local viewportHeight = groupObj.Library._cachedViewportHeight or 720
                    local popupHeight = tonumber(openHeight) or multiDropdownObj.optionHolderFrame.AbsoluteSize.Y
                    local xPos = math.clamp(buttonAbsPos.X + buttonAbsSize.X - multiDropdownPopupWidth, 8, math.max(8, viewportWidth - multiDropdownPopupWidth - 8))
                    local yPos = buttonAbsPos.Y + buttonAbsSize.Y + 6
                    if popupHeight > 0 and yPos + popupHeight > viewportHeight - 8 then
                        yPos = math.max(8, buttonAbsPos.Y - popupHeight - 6)
                    end
                    multiDropdownObj.optionHolderFrame.Position = UDim2.new(0, xPos, 0, yPos)
                end
                
                dropdownClickButton.MouseButton1Click:Connect(function()
                    multiDropdownObj.isOpen = not multiDropdownObj.isOpen
                    if multiDropdownObj.isOpen then
                        local contentHeight = (38 + (#multiDropdownConfig.Options * (_isMobile and 32 or 24))) * _mScale
                        local height = math.min(contentHeight, maxMultiDropdownHeight)
                        updateDropdownPositionYay(height)
                        multiDropdownObj.optionHolderFrame.Visible = true
                        _tween(multiDropdownObj.optionHolderFrame, {Size = UDim2.new(0, multiDropdownPopupWidth, 0, height)}, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        _tween(multiDropdownObj.arrowImg, {Rotation = 180}, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        if multiDropdownPositionConn then multiDropdownPositionConn() end
                        multiDropdownPositionConn = startFloatingPositionTracker(groupObj.Library, multiDropdownObj.buttonFrame, function()
                            if multiDropdownObj.isOpen then
                                updateDropdownPositionYay()
                            end
                        end)
                    else
                        closeMultiDropdown(false)
                    end
                end)
                
                dropdownClickButton.MouseEnter:Connect(function()
                    _tween(multiDropdownObj.buttonFrame, {BackgroundColor3 = _palette.ButtonHover}, 0.2)
                    _tween(dropdownStrokeThing, {Color = _palette.StrokeStrong, Transparency = 0.18}, 0.2)
                end)
                dropdownClickButton.MouseLeave:Connect(function()
                    if not multiDropdownObj.isOpen then
                        _tween(multiDropdownObj.buttonFrame, {BackgroundColor3 = _palette.ControlInset}, 0.2)
                        _tween(dropdownStrokeThing, {Color = _palette.TacticalLine, Transparency = 0.42}, 0.2)
                    end
                end)
                
                function multiDropdownObj:Set(values, silent)
                    if type(values) ~= "table" then
                        values = {}
                    end
                    multiDropdownObj.selectedValues = {}
                    for _, v in ipairs(values) do
                        if table.find(multiDropdownConfig.Options, v) then
                            multiDropdownObj.selectedValues[v] = true
                        end
                    end
                    local newDisplayText = getDisplayText()
                    multiDropdownObj.selectedLabelText.Text = newDisplayText
                    local newWidth = math.clamp(howWideIsThisText(newDisplayText, 12 * _mScale) + 35 * _mScale, 88 * _mScale, 126 * _mScale)
                    multiDropdownObj.buttonFrame.Size = UDim2.new(0, newWidth, 0, mddBtnHeight)
                    multiDropdownObj.buttonFrame.Position = UDim2.new(1, -newWidth - controlRightPad, 0, yPosition)
                    createMultiOptionsYay()
                    if not silent then
                        _safeCallback(multiDropdownConfig.Callback, getSelectedArray())
                    end
                end
                
                function multiDropdownObj:UpdateOptions(newOptions)
                    if type(newOptions) ~= "table" then
                        return
                    end
                    multiDropdownOptionsSource = newOptions
                    multiDropdownObj._optionsSignature = getDropdownOptionsSignature(newOptions)
                    multiDropdownConfig.Options = normalizeDropdownOptions(newOptions)
                    for _, option in ipairs(multiDropdownConfig.Options) do
                        addSearchTerm(tostring(option))
                    end
                    local filteredSelectedValues = {}
                    for option, isSelected in pairs(multiDropdownObj.selectedValues) do
                        if isSelected and table.find(multiDropdownConfig.Options, option) then
                            filteredSelectedValues[option] = true
                        end
                    end
                    multiDropdownObj.selectedValues = filteredSelectedValues
                    local newDisplayText = getDisplayText()
                    multiDropdownObj.selectedLabelText.Text = newDisplayText
                    local newWidth = math.clamp(howWideIsThisText(newDisplayText, 12 * _mScale) + 35 * _mScale, 88 * _mScale, 126 * _mScale)
                    multiDropdownObj.buttonFrame.Size = UDim2.new(0, newWidth, 0, mddBtnHeight)
                    multiDropdownObj.buttonFrame.Position = UDim2.new(1, -newWidth - controlRightPad, 0, yPosition)
                    createMultiOptionsYay()
                    if groupObj.Library._searchQuery ~= "" then
                        groupObj.Library:ApplySearchFilter(groupObj.Library._searchQuery)
                    end
                end

                if multiDropdownConfig.AutoRefresh then
                    groupObj.Library:_RegisterRefreshJob(multiDropdownConfig.RefreshInterval, function()
                        return not groupObj.Library._destroyed and multiDropdownObj.buttonFrame and multiDropdownObj.buttonFrame.Parent
                    end, function()
                        local latestOptions = multiDropdownOptionsSource
                        if type(multiDropdownConfig.OptionsProvider) == "function" then
                            local providerDebugToken = groupObj.Library:_DebugBegin("MultiDropdown.OptionsProvider.Refresh")
                            local ok, providedOptions = pcall(multiDropdownConfig.OptionsProvider)
                            groupObj.Library:_DebugEnd(providerDebugToken, multiDropdownConfig.Name)
                            if ok and type(providedOptions) == "table" then
                                latestOptions = providedOptions
                            end
                        end
                        local latestSignature = getDropdownOptionsSignature(latestOptions)
                        if latestSignature ~= multiDropdownObj._optionsSignature then
                            multiDropdownObj:UpdateOptions(latestOptions)
                        end
                        return true
                    end)
                end
                
                function multiDropdownObj:Get() return getSelectedArray() end

                function multiDropdownObj:Close()
                    closeMultiDropdown(true)
                end
                groupObj.Library:RegisterControl(multiDropdownConfig.Flag, function()
                    return multiDropdownObj:Get()
                end, function(value)
                    if type(value) == "table" then
                        multiDropdownObj:Set(value, true)
                    end
                end)

                groupObj.elementYPos = groupObj.elementYPos + 31 * _mScale
                updateGroupSizeYay()
                table.insert(groupObj.elementsInGroup, multiDropdownObj)
                groupObj.Library:_DebugEnd(controlDebugToken, multiDropdownConfig.Name)
                return multiDropdownObj
            end

            function groupObj:AddDivider()
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddDivider")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddDivider", 1)
                local yPosition = groupObj.elementYPos
                local dividerFrame = _mk("Frame", {
                    BackgroundColor3 = Color3.fromRGB(36, 36, 36),
                    Position = UDim2.new(0, 10, 0, yPosition + 4 * _mScale),
                    Size = UDim2.new(0.92, 0, 0, 1), Parent = groupObj.mainFrame
                })
                _mk("UIGradient", {
                    Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(108, 108, 108)), ColorSequenceKeypoint.new(0.514, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(108, 108, 108))}),
                    Parent = dividerFrame
                })
                groupObj.elementYPos = groupObj.elementYPos + 12 * _mScale
                updateGroupSizeYay()
                groupObj.Library:_DebugEnd(controlDebugToken, "Divider")
                return dividerFrame
            end
            
            function groupObj:AddLabel(labelConfig)
                labelConfig = labelConfig or {}
                labelConfig.Text = labelConfig.Text or "Label"
                labelConfig.Wrap = labelConfig.Wrap == true
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddLabel")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddLabel", 1)
                addSearchTerm(labelConfig.Text)
                local yPosition = groupObj.elementYPos
                local labelMaxWidth = 238 * _mScale
                local labelTextSize = 14 * _mScale
                local measureDebugToken = groupObj.Library:_DebugBegin("TextService.GetTextSize(label)")
                local measuredBounds = _txs:GetTextSize(
                    tostring(labelConfig.Text),
                    labelTextSize,
                    Enum.Font.GothamSemibold,
                    Vector2.new(labelMaxWidth, labelConfig.Wrap and math.huge or (labelTextSize + 4))
                )
                groupObj.Library:_DebugEnd(measureDebugToken, tostring(labelConfig.Text):sub(1, 80))
                local labelHeight = labelConfig.Wrap and math.max(20 * _mScale, measuredBounds.Y) or (20 * _mScale)
                local labelText = _mk("TextLabel", {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                    TextColor3 = Color3.fromRGB(140, 140, 140), Text = labelConfig.Text, BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, yPosition), TextSize = labelTextSize,
                    Size = UDim2.new(0, labelMaxWidth, 0, labelHeight), TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = labelConfig.Wrap,
                    TextTruncate = labelConfig.Wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
                    ClipsDescendants = true,
                    Parent = groupObj.mainFrame
                })
                groupObj.elementYPos = groupObj.elementYPos + labelHeight + 6 * _mScale
                updateGroupSizeYay()
                groupObj.Library:_DebugEnd(controlDebugToken, tostring(labelConfig.Text):sub(1, 80))
                return labelText
            end
            
            function groupObj:AddTextInput(textInputConfig)
                textInputConfig = textInputConfig or {}
                textInputConfig.Name = textInputConfig.Name or "Input"
                textInputConfig.Placeholder = textInputConfig.Placeholder or "Enter text..."
                textInputConfig.Default = tostring(textInputConfig.Default or "")
                textInputConfig.Callback = textInputConfig.Callback or function() end
                textInputConfig.Flag = textInputConfig.Flag or createAutoFlag(textInputConfig.Name)
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddTextInput")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddTextInput", 1)
                addSearchTerm(textInputConfig.Name)
                addSearchTerm(textInputConfig.Placeholder)
                
                local textInputObj = {}
                textInputObj.value = textInputConfig.Default
                textInputObj.Flag = textInputConfig.Flag
                textInputObj.Name = textInputConfig.Name
                local yPosition = groupObj.elementYPos
                
                textInputObj.labelText = _mkLabel(
                    groupObj.mainFrame,
                    groupObj.Library,
                    textInputConfig.Name,
                    UDim2.new(0, controlPadX, 0, yPosition),
                    UDim2.new(1, -(controlPadX + controlRightPad), 0, 20 * _mScale),
                    {
                        TextSize = 13.7 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                textInputObj.inputFrame = _mkSurface(
                    groupObj.mainFrame,
                    _palette.ControlInset,
                    UDim2.new(0, controlPadX, 0, yPosition + 22 * _mScale),
                    UDim2.new(1, -(controlPadX + controlRightPad), 0, 26 * _mScale),
                    {
            CornerRadius = _cornerTk.Tight,
                        StrokeColor = _palette.TacticalLine
                    }
                )
                
                textInputObj.textBox = _mk("TextBox", {
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold),
                    PlaceholderText = textInputConfig.Placeholder,
                    PlaceholderColor3 = _palette.FieldPlaceholder,
                    Text = textInputConfig.Default,
                    TextColor3 = _palette.FieldText,
                    TextSize = 13.1 * _mScale,
                    BackgroundTransparency = 1,
                    ClearTextOnFocus = false,
                    Position = UDim2.new(0, 8, 0, 0),
                    Size = UDim2.new(1, -16, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = textInputObj.inputFrame
                })
                
                textInputObj.textBox.Focused:Connect(function()
                    _tween(textInputObj.inputFrame, {BackgroundColor3 = _palette.ButtonHover}, 0.2)
                end)
                
                textInputObj.textBox.FocusLost:Connect(function(enterPressed)
                    _tween(textInputObj.inputFrame, {BackgroundColor3 = _palette.ControlInset}, 0.2)
                    textInputObj.value = textInputObj.textBox.Text
                    _safeCallback(textInputConfig.Callback, textInputObj.value, enterPressed)
                end)
                
                function textInputObj:Set(text)
                    local asString = tostring(text or "")
                    textInputObj.value = asString
                    textInputObj.textBox.Text = asString
                end
                
                function textInputObj:Get()
                    return textInputObj.value
                end

                function textInputObj:GetValue()
                    return textInputObj:Get()
                end

                function textInputObj:SetValue(text, silent)
                    textInputObj:Set(tostring(text or ""))
                    if not silent then
                        _safeCallback(textInputConfig.Callback, textInputObj.value, false)
                    end
                end

                function textInputObj:ResetValue()
                    textInputObj:Set(textInputConfig.Default)
                end

                groupObj.Library:RegisterControl(textInputConfig.Flag, function()
                    return textInputObj:Get()
                end, function(value)
                    textInputObj:Set(tostring(value or ""))
                end)
                
                groupObj.elementYPos = groupObj.elementYPos + 54 * _mScale
                updateGroupSizeYay()
                table.insert(groupObj.elementsInGroup, textInputObj)
                groupObj.Library:_DebugEnd(controlDebugToken, textInputConfig.Name)
                return textInputObj
            end

            function groupObj:AddTextbox(textboxConfig)
                textboxConfig = textboxConfig or {}

                local primaryCallback = textboxConfig.Callback
                if type(primaryCallback) ~= "function" then
                    primaryCallback = textboxConfig.Function
                end
                if type(primaryCallback) ~= "function" then
                    primaryCallback = function() end
                end

                local changedCallback = textboxConfig.ChangedCallback or textboxConfig.OnChanged
                local signalCallback = textboxConfig.OnPressed or textboxConfig.Signal
                local enterOnly = textboxConfig.EnterOnly == true
                local defaultText = tostring(textboxConfig.Default or textboxConfig.Value or "")

                local function fireTextboxCallbacks(value, enterPressed)
                    if enterOnly and not enterPressed then
                        return
                    end
                    _safeCallback(primaryCallback, value, enterPressed)
                    if type(changedCallback) == "function" then
                        _safeCallback(changedCallback, value, enterPressed)
                    end
                    if type(signalCallback) == "function" then
                        _safeCallback(signalCallback, value, enterPressed)
                    end
                end

                local function fireTextboxCallbacksForced(value, enterPressed)
                    _safeCallback(primaryCallback, value, enterPressed)
                    if type(changedCallback) == "function" then
                        _safeCallback(changedCallback, value, enterPressed)
                    end
                    if type(signalCallback) == "function" then
                        _safeCallback(signalCallback, value, enterPressed)
                    end
                end

                local textInputObj = groupObj:AddTextInput({
                    Name = textboxConfig.Name or textboxConfig.Title or textboxConfig.Text or "Textbox",
                    Placeholder = textboxConfig.Placeholder or textboxConfig.PlaceholderText or textboxConfig.Hint or "Enter text...",
                    Default = defaultText,
                    Callback = fireTextboxCallbacks,
                    Flag = textboxConfig.Flag or textboxConfig.ConfigId
                })

                textInputObj.Title = textboxConfig.Title or textboxConfig.Text or textboxConfig.Name or "Textbox"
                textInputObj.ConfigId = tostring(textboxConfig.ConfigId or textInputObj.Flag or textInputObj.Title)
                textInputObj.Box = textInputObj.textBox

                local baseSetValue = textInputObj.SetValue
                function textInputObj:SetValue(text, silent)
                    baseSetValue(self, text, true)
                    if not silent then
                        fireTextboxCallbacksForced(self:Get(), false)
                    end
                end

                return textInputObj
            end

            function groupObj:AddTextBox(textboxConfig)
                return groupObj:AddTextbox(textboxConfig)
            end
            
            function groupObj:AddColorPicker(colorPickerConfig)
                colorPickerConfig = colorPickerConfig or {}
                colorPickerConfig.Name = colorPickerConfig.Name or "Color"
                colorPickerConfig.Default = colorPickerConfig.Default or Color3.fromRGB(255, 100, 150)
                colorPickerConfig.Callback = colorPickerConfig.Callback or function() end
                colorPickerConfig.Flag = colorPickerConfig.Flag or createAutoFlag(colorPickerConfig.Name)
                local controlDebugToken = groupObj.Library:_DebugBegin("Control.AddColorPicker")
                groupObj.Library:_DebugCount("Controls", 1)
                groupObj.Library:_DebugCount("Control.AddColorPicker", 1)
                addSearchTerm(colorPickerConfig.Name)
                
                local colorPickerObj = {}
                colorPickerObj.value = colorPickerConfig.Default
                colorPickerObj.isOpen = false
                local yPosition = groupObj.elementYPos
                
                -- Convert Color3 to HSV
                local function rgbToHsv(color)
                    local r, g, b = color.R, color.G, color.B
                    local max, min = math.max(r, g, b), math.min(r, g, b)
                    local h, s, v = 0, 0, max
                    local d = max - min
                    s = max == 0 and 0 or d / max
                    if max ~= min then
                        if max == r then h = (g - b) / d + (g < b and 6 or 0)
                        elseif max == g then h = (b - r) / d + 2
                        elseif max == b then h = (r - g) / d + 4 end
                        h = h / 6
                    end
                    return h, s, v
                end
                
                local currentH, currentS, currentV = rgbToHsv(colorPickerConfig.Default)
                
                colorPickerObj.labelText = _mkLabel(
                    groupObj.mainFrame,
                    groupObj.Library,
                    colorPickerConfig.Name,
                    UDim2.new(0, controlPadX, 0, yPosition),
                    UDim2.new(1, -(52 * _mScale), 0, 20 * _mScale),
                    {
                        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
                        TextSize = 13.7 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }
                )
                
                -- Color preview button
                colorPickerObj.colorPreview = _mk("Frame", {
                    BackgroundColor3 = colorPickerObj.value,
                    Position = UDim2.new(1, -(38 * _mScale), 0, yPosition),
                    Size = UDim2.new(0, 26 * _mScale, 0, 20 * _mScale),
                    Parent = groupObj.mainFrame
                })
    _mkCorner(colorPickerObj.colorPreview, _cornerTk.Tight)
                _mk("UIStroke", {Color = _palette.TacticalLine, Transparency = 0.32, Parent = colorPickerObj.colorPreview})
                
                -- Picker popup holder
                colorPickerObj.pickerHolder = _mk("Frame", {
                    BackgroundColor3 = _palette.Panel,
                    Size = UDim2.new(0, 200 * _mScale, 0, 0),
                    ClipsDescendants = true, Visible = false, ZIndex = 9999,
                    Parent = groupObj.Library.dropdownHolderRef
                })
    _mkCorner(colorPickerObj.pickerHolder, _cornerTk.Large)
                _mk("UIStroke", {Color = _palette.TacticalLine, Transparency = 0.28, Parent = colorPickerObj.pickerHolder})
                
                -- Saturation/Value gradient box
                colorPickerObj.svBox = _mk("Frame", {
                    BackgroundColor3 = Color3.fromHSV(currentH, 1, 1),
                    Position = UDim2.new(0, 10, 0, 10),
                    Size = UDim2.new(1, -20, 0, 100 * _mScale),
                    ZIndex = 10000, Parent = colorPickerObj.pickerHolder
                })
    _mkCorner(colorPickerObj.svBox, _cornerTk.Tight)
                
                -- White to transparent gradient (saturation)
                _mk("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
                    }),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 1)
                    }), Parent = colorPickerObj.svBox
                })
                
                -- Black overlay for value
                local valueOverlay = _mk("Frame", {
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    Size = UDim2.new(1, 0, 1, 0), ZIndex = 10001, Parent = colorPickerObj.svBox
                })
    _mkCorner(valueOverlay, _cornerTk.Tight)
                _mk("UIGradient", {
                    Color = ColorSequence.new(Color3.new(0, 0, 0)),
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0)
                    }),
                    Rotation = 90, Parent = valueOverlay
                })
                
                -- SV cursor
                colorPickerObj.svCursor = _mk("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(currentS, -6, 1 - currentV, -6),
                    Size = UDim2.new(0, 12, 0, 12), ZIndex = 10003, Parent = colorPickerObj.svBox
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = colorPickerObj.svCursor})
                _mk("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 2, Parent = colorPickerObj.svCursor})
                
                -- Hue slider
                colorPickerObj.hueSlider = _mk("Frame", {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Position = UDim2.new(0, 10, 0, 120 * _mScale),
                    Size = UDim2.new(1, -20, 0, 14 * _mScale),
                    ZIndex = 10000, Parent = colorPickerObj.pickerHolder
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = colorPickerObj.hueSlider})
                _mk("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
                        ColorSequenceKeypoint.new(0.167, Color3.fromHSV(0.167, 1, 1)),
                        ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
                        ColorSequenceKeypoint.new(0.667, Color3.fromHSV(0.667, 1, 1)),
                        ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
                    }), Parent = colorPickerObj.hueSlider
                })
                
                -- Hue cursor
                colorPickerObj.hueCursor = _mk("Frame", {
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Position = UDim2.new(currentH, -7, 0.5, -7),
                    Size = UDim2.new(0, 14, 0, 14), ZIndex = 10001, Parent = colorPickerObj.hueSlider
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = colorPickerObj.hueCursor})
                _mk("UIStroke", {Color = _palette.Canvas, Thickness = 2, Parent = colorPickerObj.hueCursor})
                
                -- Preset colors
                local presetColors = {
                    Color3.fromRGB(38, 70, 83), Color3.fromRGB(42, 157, 143), 
                    Color3.fromRGB(233, 196, 106), Color3.fromRGB(244, 162, 97),
                    Color3.fromRGB(231, 111, 81), Color3.fromRGB(190, 49, 49),
                    Color3.fromRGB(40, 55, 114), Color3.fromRGB(68, 114, 196),
                    Color3.fromRGB(78, 166, 206), Color3.fromRGB(108, 225, 226)
                }
                
                local presetY = 145 * _mScale
                for i, preset in ipairs(presetColors) do
                    local col = (i - 1) % 5
                    local row = math.floor((i - 1) / 5)
                    local presetBtn = _mk("Frame", {
                        BackgroundColor3 = preset,
                        Position = UDim2.new(0, 10 + col * 38 * _mScale, 0, presetY + row * 28 * _mScale),
                        Size = UDim2.new(0, 32 * _mScale, 0, 22 * _mScale),
                        ZIndex = 10000, Parent = colorPickerObj.pickerHolder
                    })
                    _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = presetBtn})
                    
                    local presetClick = _mk("TextButton", {
                        Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                        ZIndex = 10001, Parent = presetBtn
                    })
                    presetClick.MouseButton1Click:Connect(function()
                        currentH, currentS, currentV = rgbToHsv(preset)
                        colorPickerObj.value = preset
                        colorPickerObj.colorPreview.BackgroundColor3 = preset
                        colorPickerObj.svBox.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)
                        colorPickerObj.svCursor.Position = UDim2.new(currentS, -6, 1 - currentV, -6)
                        colorPickerObj.hueCursor.Position = UDim2.new(currentH, -7, 0.5, -7)
                        _safeCallback(colorPickerConfig.Callback, preset)
                    end)
                end
                
                local function updateColor()
                    colorPickerObj.value = Color3.fromHSV(currentH, currentS, currentV)
                    colorPickerObj.colorPreview.BackgroundColor3 = colorPickerObj.value
                    colorPickerObj.svBox.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)
                    _safeCallback(colorPickerConfig.Callback, colorPickerObj.value)
                end
                
                -- SV box interaction
                local svClickBtn = _mk("TextButton", {
                    Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                    ZIndex = 10002, Parent = colorPickerObj.svBox
                })
                
                local svDragging = false
                svClickBtn.MouseButton1Down:Connect(function() svDragging = true end)
                groupObj.Library:_TrackConnection(_uis.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        svDragging = false
                    end
                end))
                groupObj.Library:_TrackConnection(_uis.InputChanged:Connect(function(input)
                    if svDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local absPos, absSize = colorPickerObj.svBox.AbsolutePosition, colorPickerObj.svBox.AbsoluteSize
                        currentS = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)
                        currentV = math.clamp(1 - (input.Position.Y - absPos.Y) / absSize.Y, 0, 1)
                        colorPickerObj.svCursor.Position = UDim2.new(currentS, -6, 1 - currentV, -6)
                        updateColor()
                    end
                end))
                
                -- Hue slider interaction
                local hueClickBtn = _mk("TextButton", {
                    Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                    ZIndex = 10002, Parent = colorPickerObj.hueSlider
                })
                
                local hueDragging = false
                hueClickBtn.MouseButton1Down:Connect(function() hueDragging = true end)
                groupObj.Library:_TrackConnection(_uis.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        hueDragging = false
                    end
                end))
                groupObj.Library:_TrackConnection(_uis.InputChanged:Connect(function(input)
                    if hueDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local absPos, absSize = colorPickerObj.hueSlider.AbsolutePosition, colorPickerObj.hueSlider.AbsoluteSize
                        currentH = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)
                        colorPickerObj.hueCursor.Position = UDim2.new(currentH, -7, 0.5, -7)
                        updateColor()
                    end
                end))
                
                -- Open/close picker
                local pickerClickBtn = _mk("TextButton", {
                    Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                    Parent = colorPickerObj.colorPreview
                })
                
                local colorPickerPositionConn = nil
                local function closeColorPicker(isInstant)
                    colorPickerObj.isOpen = false
                    if colorPickerPositionConn then
                        colorPickerPositionConn()
                        colorPickerPositionConn = nil
                    end
                    if isInstant then
                        colorPickerObj.pickerHolder.Size = UDim2.new(0, 200 * _mScale, 0, 0)
                        colorPickerObj.pickerHolder.Visible = false
                        return
                    end
                    _tween(colorPickerObj.pickerHolder, {
                        Size = UDim2.new(0, 200 * _mScale, 0, 0)
                    }, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                    task.delay(0.2, function()
                        if colorPickerObj.pickerHolder.Parent and not colorPickerObj.isOpen then
                            colorPickerObj.pickerHolder.Visible = false
                        end
                    end)
                end

                local function updatePickerPosition()
                    local absPos = colorPickerObj.colorPreview.AbsolutePosition
                    local absSize = colorPickerObj.colorPreview.AbsoluteSize
                    colorPickerObj.pickerHolder.Position = UDim2.new(0, absPos.X - 160 * _mScale, 0, absPos.Y + absSize.Y + 5)
                end
                
                pickerClickBtn.MouseButton1Click:Connect(function()
                    colorPickerObj.isOpen = not colorPickerObj.isOpen
                    if colorPickerObj.isOpen then
                        updatePickerPosition()
                        colorPickerObj.pickerHolder.Visible = true
                        _tween(colorPickerObj.pickerHolder, {
                            Size = UDim2.new(0, 200 * _mScale, 0, 210 * _mScale)
                        }, 0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        if colorPickerPositionConn then colorPickerPositionConn() end
                        colorPickerPositionConn = startFloatingPositionTracker(groupObj.Library, colorPickerObj.colorPreview, function()
                            if colorPickerObj.isOpen then
                                updatePickerPosition()
                            end
                        end)
                    else
                        closeColorPicker(false)
                    end
                end)
                
                function colorPickerObj:Set(color, silent)
                    colorPickerObj.value = color
                    currentH, currentS, currentV = rgbToHsv(color)
                    colorPickerObj.colorPreview.BackgroundColor3 = color
                    colorPickerObj.svBox.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)
                    colorPickerObj.svCursor.Position = UDim2.new(currentS, -6, 1 - currentV, -6)
                    colorPickerObj.hueCursor.Position = UDim2.new(currentH, -7, 0.5, -7)
                    if not silent then
                        _safeCallback(colorPickerConfig.Callback, color)
                    end
                end
                
                function colorPickerObj:Get() return colorPickerObj.value end

                function colorPickerObj:Close()
                    closeColorPicker(true)
                end
                groupObj.Library:RegisterControl(colorPickerConfig.Flag, function()
                    return colorPickerObj:Get()
                end, function(value)
                    if typeof(value) == "Color3" then
                        colorPickerObj:Set(value, true)
                    end
                end)

                groupObj.elementYPos = groupObj.elementYPos + 31 * _mScale
                updateGroupSizeYay()
                table.insert(groupObj.elementsInGroup, colorPickerObj)
                groupObj.Library:_DebugEnd(controlDebugToken, colorPickerConfig.Name)
                return colorPickerObj
            end

            local function collectGroupDirectChildren()
                local map = {}
                for _, child in ipairs(groupObj.mainFrame:GetChildren()) do
                    map[child] = true
                end
                return map
            end

            local function refreshGroupTabVisual(tabRef, isActive)
                if not tabRef or not tabRef.ButtonFrame then
                    return
                end

                local activeBg = segmentedGroupTabs and groupObj.Library.config.AccentColor:Lerp(_palette.ControlInset, 0.9) or (cleanCards and _palette.SurfaceSoft or _palette.Surface)
                local idleBg = segmentedGroupTabs and _palette.ControlInset or _palette.SurfaceSoft
                local targetBg = isActive and activeBg or idleBg
                local targetTransparency = segmentedGroupTabs and (isActive and 0.32 or 1) or (cleanCards and (isActive and 0.08 or 0.42) or 0)
                local idleText = _getSubClr(groupObj.Library)
                _tween(tabRef.ButtonFrame, {BackgroundColor3 = targetBg, BackgroundTransparency = targetTransparency}, 0.16)
                if tabRef.ButtonSquareFill then
                    _tween(tabRef.ButtonSquareFill, {BackgroundColor3 = targetBg, BackgroundTransparency = targetTransparency}, 0.16)
                end
                if tabRef.Stroke then
                    _tween(tabRef.Stroke, {Color = isActive and groupObj.Library.config.AccentColor:Lerp(_palette.TacticalLine, 0.25) or _palette.TacticalLine, Transparency = segmentedGroupTabs and 1 or (cleanCards and (isActive and 0.4 or 1) or 1)}, 0.16)
                end
                if tabRef.IconImage then
                    _tween(tabRef.IconImage, {ImageColor3 = isActive and groupObj.Library.config.AccentColor or idleText}, 0.16)
                end
                if tabRef.Label then
                    _tween(tabRef.Label, {TextColor3 = isActive and groupObj.Library.config.AccentColor or idleText}, 0.16)
                end
                if tabRef.ActiveLine then
                    _tween(tabRef.ActiveLine, {BackgroundTransparency = isActive and 0.08 or 1}, 0.16)
                end
            end

            local function layoutGroupTabButtons()
                local count = #groupObj.groupTabs
                if count <= 0 then
                    return
                end

                local tabStripHeight = groupTabStripHeight
                local availableWidth = math.max(40 * _mScale, groupWidth - 2)
                local tabButtonWidth = math.max(30 * _mScale, math.floor(availableWidth / count))
                local tabButtonHeight = tabStripHeight

                for index, groupTab in ipairs(groupObj.groupTabs) do
                    local buttonX = (index - 1) * tabButtonWidth
                    local widthCorrection = index == count and (availableWidth - tabButtonWidth * count) or 0
                    groupTab.ButtonFrame.Position = UDim2.new(0, buttonX, 0, 0)
                    groupTab.ButtonFrame.Size = UDim2.new(0, tabButtonWidth + widthCorrection, 0, tabButtonHeight)

                    local hasIcon = groupTab.IconImage ~= nil
                    local iconSize = 18 * _mScale
                    if groupTab.IconImage then
                        groupTab.IconImage.Position = UDim2.new(0.5, -iconSize * 0.5, 0.5, -iconSize * 0.5)
                        groupTab.IconImage.Size = UDim2.new(0, iconSize, 0, iconSize)
                    end
                    if groupTab.Label then
                        groupTab.Label.Position = UDim2.new(0, 6 * _mScale, 0.5, -8 * _mScale)
                        groupTab.Label.Size = UDim2.new(1, -12 * _mScale, 0, 16 * _mScale)
                        groupTab.Label.Visible = not hasIcon and tabButtonWidth >= 44 * _mScale
                    end
                    if groupTab.Divider then
                        groupTab.Divider.Visible = index > 1
                        groupTab.Divider.Position = UDim2.new(0, 0, 0, 8 * _mScale)
                        groupTab.Divider.Size = UDim2.new(0, 1, 1, -16 * _mScale)
                    end
                    if groupTab.ActiveLine then
                        groupTab.ActiveLine.Position = UDim2.new(0, 14 * _mScale, 1, -6 * _mScale)
                        groupTab.ActiveLine.Size = UDim2.new(1, -28 * _mScale, 0, 2 * _mScale)
                    end

                    refreshGroupTabVisual(groupTab, groupObj.activeGroupTab == groupTab)
                end
            end

            local function applyGroupTabsLayout()
                local hasTabs = #groupObj.groupTabs > 0
                groupObj.contentStartY = hasTabs and (groupTabStripHeight + 8 * _mScale) or groupHeaderHeight
                if groupObj.titleLabel then
                    groupObj.titleLabel.Visible = not hasTabs
                end
                if groupObj.tabStripFrame then
                    groupObj.tabStripFrame.Visible = hasTabs
                    groupObj.tabStripFrame.Position = UDim2.new(0, 0, 0, 0)
                    groupObj.tabStripFrame.Size = UDim2.new(1, 0, 0, groupTabStripHeight)
                end
                if groupObj.tabStripSquareFill then
                    groupObj.tabStripSquareFill.Visible = hasTabs
                    groupObj.tabStripSquareFill.Position = UDim2.new(0, 0, 0, 16 * _mScale)
                    groupObj.tabStripSquareFill.Size = UDim2.new(1, 0, 1, -16 * _mScale)
                end
                if groupObj.tabStripBottomLine then
                    groupObj.tabStripBottomLine.Visible = hasTabs
                    groupObj.tabStripBottomLine.Position = UDim2.new(0, 0, 1, -1)
                    groupObj.tabStripBottomLine.Size = UDim2.new(1, 0, 0, 1)
                    groupObj.tabStripBottomLine.BackgroundTransparency = segmentedGroupTabs and 0.9 or (cleanCards and 0.72 or 0.36)
                end
                if groupObj.headerDivider then
                    groupObj.headerDivider.Position = UDim2.new(0, 12 * _mScale, 0, hasTabs and (groupTabStripHeight + 4 * _mScale) or (groupHeaderHeight - 8 * _mScale))
                    groupObj.headerDivider.Size = UDim2.new(1, -24 * _mScale, 0, 1)
                    groupObj.headerDivider.BackgroundTransparency = cleanCards and 0.84 or (hasTabs and 0.72 or 0.42)
                end
                for _, groupTab in ipairs(groupObj.groupTabs) do
                    groupTab.ElementYPos = math.max(groupTab.ElementYPos or groupObj.contentStartY, groupObj.contentStartY)
                end
                if groupObj.activeGroupTab then
                    groupObj.elementYPos = groupObj.activeGroupTab.ElementYPos
                else
                    groupObj.elementYPos = groupObj.contentStartY
                end
                layoutGroupTabButtons()
                updateGroupSizeYay()
            end

            local function setGroupTabActive(groupTab, instant)
                if not groupTab then
                    return
                end

                local previousTab = groupObj.activeGroupTab
                if previousTab and previousTab ~= groupTab then
                    for _, control in ipairs(previousTab.Controls) do
                        if type(control) == "table" and type(control.Close) == "function" then
                            pcall(function()
                                control:Close()
                            end)
                        end
                    end
                end

                groupObj.activeGroupTab = groupTab
                for _, tabRef in ipairs(groupObj.groupTabs) do
                    local isActive = tabRef == groupTab
                    for _, child in ipairs(tabRef.Instances) do
                        if child and child.Parent then
                            child.Visible = isActive
                        end
                    end
                    if instant then
                        local targetBg = isActive and (segmentedGroupTabs and groupObj.Library.config.AccentColor:Lerp(_palette.ControlInset, 0.9) or (cleanCards and _palette.SurfaceSoft or _palette.Surface)) or (segmentedGroupTabs and _palette.ControlInset or _palette.SurfaceSoft)
                        local targetTransparency = segmentedGroupTabs and (isActive and 0.32 or 1) or (cleanCards and (isActive and 0.08 or 0.42) or 0)
                        tabRef.ButtonFrame.BackgroundColor3 = targetBg
                        tabRef.ButtonFrame.BackgroundTransparency = targetTransparency
                        if tabRef.ButtonSquareFill then
                            tabRef.ButtonSquareFill.BackgroundColor3 = targetBg
                            tabRef.ButtonSquareFill.BackgroundTransparency = targetTransparency
                        end
                        if tabRef.Stroke then
                            tabRef.Stroke.Color = isActive and groupObj.Library.config.AccentColor:Lerp(_palette.TacticalLine, 0.25) or _palette.TacticalLine
                            tabRef.Stroke.Transparency = segmentedGroupTabs and 1 or (cleanCards and (isActive and 0.4 or 1) or 1)
                        end
                        if tabRef.IconImage then
                            tabRef.IconImage.ImageColor3 = isActive and groupObj.Library.config.AccentColor or _getSubClr(groupObj.Library)
                        end
                        if tabRef.Label then
                            tabRef.Label.TextColor3 = isActive and groupObj.Library.config.AccentColor or _getSubClr(groupObj.Library)
                        end
                        if tabRef.ActiveLine then
                            tabRef.ActiveLine.BackgroundTransparency = isActive and 0.08 or 1
                        end
                    else
                        refreshGroupTabVisual(tabRef, isActive)
                    end
                end

                groupObj.elementYPos = groupTab.ElementYPos
                updateGroupSizeYay()
            end

            local function addControlToGroupTab(groupTab, methodName, config)
                local addMethod = groupObj[methodName]
                if type(addMethod) ~= "function" then
                    return nil
                end

                local previousActiveTab = groupObj.activeGroupTab
                local beforeChildren = collectGroupDirectChildren()
                groupObj.elementYPos = groupTab.ElementYPos
                local controlObj = addMethod(groupObj, config)
                groupTab.ElementYPos = groupObj.elementYPos
                if type(controlObj) == "table" then
                    table.insert(groupTab.Controls, controlObj)
                end

                local isActive = groupObj.activeGroupTab == groupTab
                for _, child in ipairs(groupObj.mainFrame:GetChildren()) do
                    if not beforeChildren[child] and child ~= groupTab.ButtonFrame then
                        child.Visible = isActive
                        table.insert(groupTab.Instances, child)
                    end
                end

                if previousActiveTab and previousActiveTab ~= groupTab then
                    groupObj.activeGroupTab = previousActiveTab
                    groupObj.elementYPos = previousActiveTab.ElementYPos
                    updateGroupSizeYay()
                end

                return controlObj
            end

            function groupObj:AddTab(groupTabConfig)
                if type(groupTabConfig) == "string" then
                    groupTabConfig = {Name = groupTabConfig}
                end
                groupTabConfig = groupTabConfig or {}
                groupTabConfig.Name = groupTabConfig.Name or ("Tab " .. tostring(#groupObj.groupTabs + 1))
                groupTabConfig.Icon = groupTabConfig.Icon
                addSearchTerm(groupTabConfig.Name)

                if not groupObj.tabStripFrame then
                    groupObj.tabStripFrame = _mk("Frame", {
                        BackgroundColor3 = segmentedGroupTabs and _palette.ControlInset or _palette.SurfaceSoft,
                        BackgroundTransparency = segmentedGroupTabs and 0.62 or (cleanCards and 0.18 or 0),
                        Position = UDim2.new(0, 0, 0, 0),
                        Size = UDim2.new(1, 0, 0, groupTabStripHeight),
                        ClipsDescendants = true,
                        Parent = groupObj.mainFrame
                    })
                    _mkCorner(groupObj.tabStripFrame, _cornerTk.Large)
                    groupObj.tabStripSquareFill = _mk("Frame", {
                        BackgroundColor3 = segmentedGroupTabs and _palette.ControlInset or _palette.SurfaceSoft,
                        BackgroundTransparency = segmentedGroupTabs and 0.62 or (cleanCards and 0.18 or 0),
                        BorderSizePixel = 0,
                        Position = UDim2.new(0, 0, 0, 16 * _mScale),
                        Size = UDim2.new(1, 0, 1, -16 * _mScale),
                        Parent = groupObj.tabStripFrame
                    })
                    groupObj.tabStripBottomLine = _mk("Frame", {
                        BackgroundColor3 = _palette.TacticalLine,
                        BackgroundTransparency = segmentedGroupTabs and 0.96 or (cleanCards and 0.72 or 0.36),
                        BorderSizePixel = 0,
                        Position = UDim2.new(0, 0, 1, -1),
                        Size = UDim2.new(1, 0, 0, 1),
                        Parent = groupObj.tabStripFrame
                    })
                end

                local groupTab = {
                    Name = groupTabConfig.Name,
                    Icon = groupTabConfig.Icon,
                    ElementYPos = groupObj.contentStartY,
                    Controls = {},
                    Instances = {}
                }

                groupTab.ButtonFrame = _mk("Frame", {
                    BackgroundColor3 = segmentedGroupTabs and _palette.ControlInset or _palette.SurfaceSoft,
                    BackgroundTransparency = segmentedGroupTabs and 1 or (cleanCards and 0.42 or 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, 64 * _mScale, 0, groupTabStripHeight),
                    ClipsDescendants = true,
                    ZIndex = 2,
                    Parent = groupObj.tabStripFrame
                })
                _mkCorner(groupTab.ButtonFrame, _cornerTk.Large)
                groupTab.ButtonSquareFill = _mk("Frame", {
                    BackgroundColor3 = segmentedGroupTabs and _palette.ControlInset or _palette.SurfaceSoft,
                    BackgroundTransparency = segmentedGroupTabs and 1 or (cleanCards and 0.42 or 0),
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 0, 16 * _mScale),
                    Size = UDim2.new(1, 0, 1, -16 * _mScale),
                    ZIndex = 3,
                    Parent = groupTab.ButtonFrame
                })
                groupTab.Stroke = _mk("UIStroke", {
                    Color = _palette.TacticalLine,
                    Transparency = 1,
                    Thickness = 1,
                    Parent = groupTab.ButtonFrame
                })
                groupTab.Divider = _mk("Frame", {
                    BackgroundColor3 = _palette.TacticalLine,
                    BackgroundTransparency = segmentedGroupTabs and 0.78 or 0.52,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 0, 8 * _mScale),
                    Size = UDim2.new(0, 1, 1, -16 * _mScale),
                    ZIndex = 3,
                    Parent = groupTab.ButtonFrame
                })
                groupTab.ActiveLine = _mk("Frame", {
                    BackgroundColor3 = groupObj.Library.config.AccentColor,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 14 * _mScale, 1, -6 * _mScale),
                    Size = UDim2.new(1, -28 * _mScale, 0, 2 * _mScale),
                    ZIndex = 4,
                    Parent = groupTab.ButtonFrame
                })
                _mk("UICorner", {CornerRadius = UDim.new(1, 0), Parent = groupTab.ActiveLine})

                if groupTabConfig.Icon then
                    groupTab.IconImage = _mkIcon(
                        groupTab.ButtonFrame,
                        groupTabConfig.Icon,
                        _getSubClr(groupObj.Library),
                        UDim2.new(0.5, -9 * _mScale, 0.5, -9 * _mScale),
                        UDim2.new(0, 18 * _mScale, 0, 18 * _mScale),
                        {ZIndex = 4, FallbackImage = groupTabConfig.FallbackIcon or _assetUrl("7734053495")}
                    )
                end

                groupTab.Label = _mkLabel(
                    groupTab.ButtonFrame,
                    groupObj.Library,
                    groupTabConfig.Name,
                    UDim2.new(0, 6 * _mScale, 0.5, -8 * _mScale),
                    UDim2.new(1, -12 * _mScale, 0, 16 * _mScale),
                    {
                        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
                        TextColor = _getSubClr(groupObj.Library),
                        TextSize = 12.5 * _mScale,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        Visible = groupTabConfig.Icon == nil,
                        ZIndex = 4
                    }
                )

                local tabClickButton = _mk("TextButton", {
                    Text = "",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Parent = groupTab.ButtonFrame
                })
                tabClickButton.MouseButton1Click:Connect(function()
                    setGroupTabActive(groupTab, false)
                end)
                tabClickButton.MouseEnter:Connect(function()
                    if groupObj.activeGroupTab ~= groupTab then
                        _tween(groupTab.ButtonFrame, {BackgroundColor3 = _palette.SurfaceHover, BackgroundTransparency = segmentedGroupTabs and 0.78 or 0.14}, 0.14)
                        if groupTab.ButtonSquareFill then
                            _tween(groupTab.ButtonSquareFill, {BackgroundColor3 = _palette.SurfaceHover, BackgroundTransparency = segmentedGroupTabs and 0.78 or 0.14}, 0.14)
                        end
                    end
                end)
                tabClickButton.MouseLeave:Connect(function()
                    if groupObj.activeGroupTab ~= groupTab then
                        _tween(groupTab.ButtonFrame, {BackgroundColor3 = segmentedGroupTabs and _palette.ControlInset or _palette.SurfaceSoft, BackgroundTransparency = segmentedGroupTabs and 1 or (cleanCards and 0.42 or 0)}, 0.14)
                        if groupTab.ButtonSquareFill then
                            _tween(groupTab.ButtonSquareFill, {BackgroundColor3 = segmentedGroupTabs and _palette.ControlInset or _palette.SurfaceSoft, BackgroundTransparency = segmentedGroupTabs and 1 or (cleanCards and 0.42 or 0)}, 0.14)
                        end
                    end
                end)

                local methodsToProxy = {
                    "AddToggle",
                    "AddSlider",
                    "AddButton",
                    "AddKeybind",
                    "AddKeybindToggle",
                    "AddDropdown",
                    "AddMultiDropdown",
                    "AddDivider",
                    "AddLabel",
                    "AddTextInput",
                    "AddTextbox",
                    "AddTextBox",
                    "AddColorPicker"
                }
                for _, methodName in ipairs(methodsToProxy) do
                    local proxiedMethodName = methodName
                    groupTab[methodName] = function(_, config)
                        return addControlToGroupTab(groupTab, proxiedMethodName, config)
                    end
                end

                function groupTab:Activate()
                    setGroupTabActive(groupTab, false)
                end

                table.insert(groupObj.groupTabs, groupTab)
                if not groupObj.activeGroupTab or groupTabConfig.Default == true then
                    groupObj.activeGroupTab = groupTab
                end
                applyGroupTabsLayout()
                setGroupTabActive(groupObj.activeGroupTab, true)
                return groupTab
            end

            function groupObj:AddTabs(groupTabConfigs)
                local createdTabs = {}
                if type(groupTabConfigs) ~= "table" then
                    return createdTabs
                end
                for _, groupTabConfig in ipairs(groupTabConfigs) do
                    local createdTab = groupObj:AddTab(groupTabConfig)
                    if createdTab then
                        table.insert(createdTabs, createdTab)
                        if type(createdTab.Name) == "string" and createdTab.Name ~= "" then
                            createdTabs[createdTab.Name] = createdTab
                        end
                    end
                end
                return createdTabs
            end

            groupObj.AddPage = groupObj.AddTab
            groupObj.AddSubTab = groupObj.AddTab
            groupObj.CreateTab = groupObj.AddTab
            groupObj.AddPages = groupObj.AddTabs
            
            table.insert(tabObj.groupsInTab, groupObj)
            updateGroupSizeYay()
            tabObj.Library:_DebugEnd(groupDebugToken, groupConfig.Name)
            return groupObj
        end
        
        table.insert(sectionObj.tabsInSection, tabObj)
        table.insert(sectionObj.Library._tabs, tabObj)
        updateContainerSizeYay(false)
        
        if #sectionObj.Library._tabs == 1 then tabObj:Activate() end
        
        if sectionObj.Library._searchQuery ~= "" then
            sectionObj.Library:ApplySearchFilter(sectionObj.Library._searchQuery)
        end
        
        sectionObj.Library:_DebugEnd(tabDebugToken, tabConfig.Name)
        return tabObj
    end
    
    table.insert(self._sections, sectionObj)
    self:_DebugEnd(sectionDebugToken, config.Name)
    return sectionObj
end

function _Lib:SetAccentColor(color)
    if typeof(color) ~= "Color3" then
        return
    end
    self.config.AccentColor = color
    for _, section in ipairs(self._sections) do
        for _, tab in ipairs(section.tabsInSection or {}) do
            if tab.isActive and tab.buttonFrame then
                tab.buttonFrame.BackgroundColor3 = color
            end
            for _, group in ipairs(tab.groupsInTab or {}) do
                for _, groupTab in ipairs(group.groupTabs or {}) do
                    local isGroupTabActive = group.activeGroupTab == groupTab
                    if groupTab.ActiveLine then
                        groupTab.ActiveLine.BackgroundColor3 = color
                    end
                    if groupTab.IconImage and isGroupTabActive then
                        groupTab.IconImage.ImageColor3 = color
                    end
                    if groupTab.Label and isGroupTabActive then
                        groupTab.Label.TextColor3 = color
                    end
                    if groupTab.Stroke and isGroupTabActive then
                        groupTab.Stroke.Color = color:Lerp(_palette.Stroke, 0.25)
                    end
                end
                for _, element in ipairs(group.elementsInGroup or {}) do
                    if type(element) == "table" then
                        if element.switchFrame and element.value == true then
                            element.switchFrame.BackgroundColor3 = color:Lerp(_palette.Surface, 0.18)
                        end
                        if element.fillFrame then
                            element.fillFrame.BackgroundColor3 = color
                        end
                        if element.knobCore then
                            element.knobCore.BackgroundColor3 = color
                        end
                        if element.knobGlow then
                            element.knobGlow.BackgroundColor3 = color
                        end
                        if element.knobStroke then
                            element.knobStroke.Color = color:Lerp(Color3.fromRGB(26, 26, 28), 0.2)
                        end
                        if element.toggleSwitchFrame and element.toggleValue == true then
                            element.toggleSwitchFrame.BackgroundColor3 = color:Lerp(_palette.Surface, 0.18)
                        end
                    end
                end
            end
        end
    end
    self:_RefreshAccentCore()
    if self.uiSettingsToggleRefs then
        for _, toggleRef in ipairs(self.uiSettingsToggleRefs) do
            if toggleRef and type(toggleRef.Get) == "function" and type(toggleRef.Set) == "function" then
                toggleRef:Set(toggleRef:Get(), true)
            end
        end
    end
    self:_UpdateESPPreview(0)
end

function _Lib:Destroy()
    if self._destroyed then return end

    if self._debugBuildEnabled then
        pcall(function()
            self:DumpBuildDebug("destroy")
        end)
    end

    pcall(function()
        self:_TryAutoSaveConfig(true)
    end)

    self._destroyed = true

    for _, section in ipairs(self._sections) do
        for _, tab in ipairs(section.tabsInSection or {}) do
            for _, group in ipairs(tab.groupsInTab or {}) do
                for _, element in ipairs(group.elementsInGroup or {}) do
                    if type(element) == "table" and type(element.Close) == "function" then
                        pcall(function()
                            element:Close()
                        end)
                    end
                end
            end
        end
    end

    if self._curTab and type(self._curTab.Deactivate) == "function" then
        pcall(function()
            self._curTab:Deactivate()
        end)
        self._curTab = nil
    end

    for i = #self._connections, 1, -1 do
        _dcConn(self._connections[i])
        self._connections[i] = nil
    end

    self._smoothScrollFrames = {}
    self._refreshJobs = {}
    self._trackedControls = {}
    if _dbgProf == self._debugBuildProfiler then
        _dbgProf = nil
    end
    self:_ClearSnowflakes()
    self:_DestroyESPPreviewCharacter()
    self._fpsRollingWindow = table.create and table.create(self._fpsRollingSize or 60, 0) or {}
    self._fpsRollingTotal = 0
    self._fpsRollingIndex = 1
    self._fpsRollingCount = 0
    self._latestFPSValue = 0
    self._cachedViewportSize = Vector2.new(1280, 720)
    self._cachedViewportWidth = 1280
    self._cachedViewportHeight = 720
    self._cachedViewportAreaScale = 1
    self._espPreviewState = nil
    self._espPreviewProvider = nil
    self._espPreviewData = nil
    self._espPreviewWalkTrack = nil
    self._espPreviewAnimationId = nil
    self._espPreviewAvatar3DUserId = nil
    self._espPreviewAvatar3DImageUrl = nil
    self._espPreviewRotationYaw = nil
    self._espPreviewRotationTargetYaw = nil
    self._espPreviewAllowManualRotation = nil
    self._espPreviewPivotYOffset = nil
    self._espPreviewRotateCapture = nil
    self._espPreviewIsRotating = false
    self._espPreviewRotateInput = nil
    self._espPreviewRotateLastX = nil
    self._textGradientAnimationTime = nil
    self._gradientAnimationAccumulator = 0
    self._backgroundFxAccumulator = 0
    self._overlayUpdateAccumulator = 0
    self._watermarkUpdateAccumulator = 0
    self._watermarkLastWidth = 0
    self._snowSpawnAccumulator = 0
    self._gradientObjects = {}
    self._espPreviewProjectionCache = nil
    self._espPreviewProjectionDirty = true

    if self._blurEffectRef and self._blurEffectRef.Parent then
        self._blurEffectRef:Destroy()
    end
    self._blurEffectRef = nil

    if self._espPreviewPanel and self._espPreviewPanel.Parent then
        self._espPreviewPanel:Destroy()
    end
    self._espPreviewPanel = nil
    self._espPreviewViewport = nil
    self._espPreviewWorldModel = nil
    self._espPreviewCamera = nil
    self._espPreviewHighlight = nil
    self._espPreviewHeaderTag = nil
    self._espPreviewBox = nil
    self._espPreviewBoxStroke = nil
    self._espPreviewHealthTrack = nil
    self._espPreviewHealthFill = nil
    self._espPreviewDot = nil
    self._espPreviewTracer = nil
    self._espPreviewName = nil
    self._espPreviewItem = nil
    self._espPreviewDistance = nil
    self._espPreviewRotateCapture = nil

    if self._sgRef and self._sgRef.Parent then
        self._sgRef:Destroy()
    end

    local sharedEnv = _getSharedEnv()
    if rawget(sharedEnv, _rtKey) == self then
        rawset(sharedEnv, _rtKey, nil)
    end
end

local _exportEnv = _getSharedEnv()
rawset(_exportEnv, "__" .. _localRngName(12) .. "_EXPORT", _Lib)

return _Lib
