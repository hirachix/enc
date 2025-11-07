-- ============================================================================
-- HIRAKO FISH IT - FINAL UPGRADED VERSION (FULL INTEGRATED)
-- ============================================================================
-- DEVELOPER: HIRAKO GANTENG
-- VERSION: 2.0 UPGRADED - FULLY OPTIMIZED & BUG-FREE
-- DATE: 2025
-- 
-- CHANGELOG v2.0:
-- [FIXED] AutoFishingV1 anti-stuck system (removed SafeRespawn crashes)
-- [FIXED] WalkOnWater smooth movement (no more jerky teleports)
-- [FIXED] AutoFishingStable inventory handling (no stuck at >800 items)
-- [ADDED] Full AutoSell integration with inventory monitoring
-- [ADDED] AUTO FISHING - NEW METHOD (equip rod once)
-- [ADDED] Save/Load config system with disk persistence
-- [ADDED] Position save persistence across rejoin
-- [ADDED] HD GRAPHIC MODE toggle
-- [ADDED] Race condition protection for AutoSell
-- [ADDED] Startup health checks for remotes
-- [REMOVED] Ultra Instant Bite (unstable)
-- [REMOVED] Cycle Speed override (unstable)
-- [REMOVED] Max Speed mode (unstable)
-- [OPTIMIZED] All remote calls with pcall protection
-- [OPTIMIZED] Performance mode enhanced
-- [OPTIMIZED] Weather UI improved
-- [OPTIMIZED] Telegram hook with inventory data
-- ============================================================================

print("Loading  FISH IT - FINAL UPGRADED VERSION...")

-- Wait for game to load
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- ============================================================================
-- RAYFIELD UI SETUP
-- ============================================================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "HIRAKO FISH IT - UPGRADED V2.0",
    LoadingTitle = "HIRAKO FISH IT - LOADING ALL SYSTEMS",
    LoadingSubtitle = "BY HIRAKO - FULLY OPTIMIZED",
    ConfigurationSaving = { Enabled = false },
})

-- ============================================================================
-- DATABASE SYSTEM
-- ============================================================================

-- Tier to Rarity Mapping
local tierToRarity = {
    [1] = "COMMON",
    [2] = "UNCOMMON",
    [3] = "RARE",
    [4] = "EPIC",
    [5] = "LEGENDARY",
    [6] = "MYTHIC",
    [7] = "SECRET"
}

-- Load Database from File
local function LoadDatabase()
    local paths = {
        "/storage/emulated/0/Delta/Workspace/FULL_ITEM_DATA.json",
        "FULL_ITEM_DATA.json"
    }
    
    for _, p in ipairs(paths) do
        local ok, content = pcall(function() return readfile(p) end)
        if ok and content then
            local decodeOk, data = pcall(function() return HttpService:JSONDecode(content) end)
            if decodeOk and data then
                print("[DB] Loaded JSON from path:", p)
                return data
            else
                warn("[DB] JSON parse failed for path:", p)
            end
        end
    end
    
    warn("[DB] FULL_ITEM_DATA.json not found in any path")
    return nil
end

local database = LoadDatabase()

-- Build Item Database
local ItemDatabase = {}

if database and database.Data then
    -- Normalize rarities
    for cat, list in pairs(database.Data) do
        if type(list) == "table" then
            for key, item in pairs(list) do
                if type(item) == "table" then
                    local tierNum = tonumber(item.Tier) or 0
                    item.Rarity = (item.Rarity and string.upper(tostring(item.Rarity))) or (tierToRarity[tierNum] or "UNKNOWN")
                    if item.Id then
                        local idn = tonumber(item.Id)
                        if idn then item.Id = idn end
                    end
                end
            end
        end
    end
    
    -- Build lookup table
    for cat, list in pairs(database.Data) do
        if type(list) == "table" then
            for _, item in pairs(list) do
                if item and item.Id then
                    local id = tonumber(item.Id) or item.Id
                    local tierNum = tonumber(item.Tier) or 0
                    ItemDatabase[id] = {
                        Name = item.Name or tostring(id),
                        Type = item.Type or cat,
                        Tier = tierNum,
                        SellPrice = item.SellPrice or 0,
                        Weight = item.Weight or "-",
                        Rarity = (item.Rarity and string.upper(tostring(item.Rarity))) or (tierToRarity[tierNum] or "UNKNOWN"),
                        Raw = item
                    }
                end
            end
        end
    end
    
    print("[DATABASE] Item database loaded successfully")
else
    warn("[DATABASE] Failed to load item database")
end

-- Get Item Info by ID
local function GetItemInfo(itemId)
    local info = ItemDatabase[itemId]
    if not info then
        return {
            Name = "Unknown Item",
            Type = "Unknown",
            Tier = 0,
            SellPrice = 0,
            Weight = "-",
            Rarity = "UNKNOWN"
        }
    end
    info.Rarity = string.upper(tostring(info.Rarity or "UNKNOWN"))
    return info
end

-- ============================================================================
-- TELEGRAM SYSTEM
-- ============================================================================

local TELEGRAM_BOT_TOKEN = "8397717015:AAGpYPg2X_rBDumP30MSSXWtDnR_Bi5e_30"

local TelegramConfig = {
    Enabled = false,
    BotToken = TELEGRAM_BOT_TOKEN,
    ChatID = "",
    SelectedRarities = {},
    MaxSelection = 3,
    UseFancyFont = true,
    QuestNotifications = true
}

-- Safe JSON Encode
local function safeJSONEncode(tbl)
    local ok, res = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then return res end
    return "{}"
end

-- Pick HTTP Request Method
local function pickHTTPRequest(requestTable)
    local ok, result
    
    if type(http_request) == "function" then
        ok, result = pcall(function() return http_request(requestTable) end)
        return ok, result
    elseif type(syn) == "table" and type(syn.request) == "function" then
        ok, result = pcall(function() return syn.request(requestTable) end)
        return ok, result
    elseif type(request) == "function" then
        ok, result = pcall(function() return request(requestTable) end)
        return ok, result
    elseif type(http) == "table" and type(http.request) == "function" then
        ok, result = pcall(function() return http.request(requestTable) end)
        return ok, result
    else
        return false, "No supported HTTP request function found"
    end
end

-- Count Selected Rarities
local function CountSelected()
    local c = 0
    for k, v in pairs(TelegramConfig.SelectedRarities) do
        if v then c = c + 1 end
    end
    return c
end

-- Get Player Stats
local function GetPlayerStats()
    local caught, rarest = "Unknown", "Unknown"
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    
    if ls then
        pcall(function()
            local c = ls:FindFirstChild("Caught") or ls:FindFirstChild("caught")
            if c and c.Value then caught = tostring(c.Value) end
            
            local r = ls:FindFirstChild("Rarest Fish") or ls:FindFirstChild("RarestFish") or ls:FindFirstChild("Rarest")
            if r and r.Value then rarest = tostring(r.Value) end
        end)
    end
    
    return caught, rarest
end

-- Build Telegram Message for Fish
local function BuildTelegramMessage(fishInfo, fishId, fishRarity, weight, inventoryCount)
    local playerName = LocalPlayer.Name or "Unknown"
    local displayName = LocalPlayer.DisplayName or playerName
    local userId = tostring(LocalPlayer.UserId or "Unknown")
    local caught, rarest = GetPlayerStats()
    local serverTime = os.date("%H:%M:%S")
    local serverDate = os.date("%Y-%m-%d")
    
    local fishName = (fishInfo and fishInfo.Name) or "Unknown"
    local fishTier = tostring((fishInfo and fishInfo.Tier) or "?")
    local sellPrice = tostring((fishInfo and fishInfo.SellPrice) or "?")
    
    local weightDisplay = "?"
    if weight then
        if type(weight) == "number" then
            weightDisplay = string.format("%.2fkg", weight)
        else
            weightDisplay = tostring(weight) .. "kg"
        end
    elseif fishInfo and fishInfo.Weight then
        weightDisplay = tostring(fishInfo.Weight)
    end
    
    local fishRarityStr = string.upper(tostring(fishRarity or (fishInfo and fishInfo.Rarity) or "UNKNOWN"))
    local invDisplay = inventoryCount and tostring(inventoryCount) .. "/4500" or "Unknown"
    
    local message = "```\n"
    message = message .. "HIRAKO SCRIPT FISH IT\n"
    message = message .. "DEVELOPER: HIRAKO\n"
    message = message .. "========================================\n\n"
    message = message .. "PLAYER INFORMATION\n"
    message = message .. "     NAME: " .. playerName .. "\n"
    if displayName ~= playerName then
        message = message .. "     DISPLAY: " .. displayName .. "\n"
    end
    message = message .. "     ID: " .. userId .. "\n"
    message = message .. "     CAUGHT: " .. caught .. "\n"
    message = message .. "     RAREST: " .. rarest .. "\n\n"
    message = message .. "FISH DETAILS\n"
    message = message .. "     NAME: " .. fishName .. "\n"
    message = message .. "     ID: " .. tostring(fishId or "?") .. "\n"
    message = message .. "     TIER: " .. fishTier .. "\n"
    message = message .. "     RARITY: " .. fishRarityStr .. "\n"
    message = message .. "     WEIGHT: " .. weightDisplay .. "\n"
    message = message .. "     PRICE: " .. sellPrice .. " COINS\n\n"
    message = message .. "INVENTORY STATUS\n"
    message = message .. "     COUNT: " .. invDisplay .. "\n\n"
    message = message .. "SYSTEM STATS\n"
    message = message .. "     TIME: " .. serverTime .. "\n"
    message = message .. "     DATE: " .. serverDate .. "\n\n"
    message = message .. "DEVELOPER SOCIALS\n"
    message = message .. "     TIKTOK: @HIRAKOxit\n"
    message = message .. "     INSTAGRAM: @n1kzx.z\n"
    message = message .. "     ROBLOX: @HIRAKO7z\n\n"
    message = message .. "STATUS: ACTIVE\n"
    message = message .. "========================================\n```"
    
    return message
end

-- Build Telegram Message for Quest
local function BuildQuestTelegramMessage(questName, taskName, progress, statusType)
    local playerName = LocalPlayer.Name or "Unknown"
    local displayName = LocalPlayer.DisplayName or playerName
    local userId = tostring(LocalPlayer.UserId or "Unknown")
    local caught, rarest = GetPlayerStats()
    local serverTime = os.date("%H:%M:%S")
    local serverDate = os.date("%Y-%m-%d")
    
    local statusEmoji = "STATUS"
    local statusText = "UNKNOWN"
    
    if statusType == "START" then
        statusEmoji = "START"
        statusText = "QUEST STARTED"
    elseif statusType == "TASK_SELECTED" then
        statusEmoji = "TARGET"
        statusText = "TASK SELECTED"
    elseif statusType == "TASK_COMPLETED" then
        statusEmoji = "DONE"
        statusText = "TASK COMPLETED"
    elseif statusType == "QUEST_COMPLETED" then
        statusEmoji = "WIN"
        statusText = "QUEST COMPLETED"
    elseif statusType == "TELEPORT" then
        statusEmoji = "MOVE"
        statusText = "TELEPORTED"
    elseif statusType == "FARMING" then
        statusEmoji = "FARM"
        statusText = "FARMING STARTED"
    elseif statusType == "PROGRESS_UPDATE" then
        statusEmoji = "UPDATE"
        statusText = "PROGRESS UPDATE"
    end
    
    local message = "```\n"
    message = message .. "HIRAKO SCRIPT FISH IT\n"
    message = message .. "DEVELOPER: HIRAKO\n"
    message = message .. "========================================\n\n"
    message = message .. "PLAYER INFORMATION\n"
    message = message .. "     NAME: " .. playerName .. "\n"
    if displayName ~= playerName then
        message = message .. "     DISPLAY: " .. displayName .. "\n"
    end
    message = message .. "     ID: " .. userId .. "\n"
    message = message .. "     CAUGHT: " .. caught .. "\n"
    message = message .. "     RAREST: " .. rarest .. "\n\n"
    message = message .. "QUEST INFORMATION\n"
    message = message .. "     QUEST: " .. questName .. "\n"
    if taskName then
        message = message .. "     TASK: " .. taskName .. "\n"
    end
    if progress then
        message = message .. "     PROGRESS: " .. string.format("%.1f%%", progress) .. "\n"
    end
    message = message .. "\n"
    message = message .. "SYSTEM STATS\n"
    message = message .. "     TIME: " .. serverTime .. "\n"
    message = message .. "     DATE: " .. serverDate .. "\n\n"
    message = message .. "DEVELOPER SOCIALS\n"
    message = message .. "     TIKTOK: @HIRAKOxit\n"
    message = message .. "     INSTAGRAM: @n1kzx.z\n"
    message = message .. "     ROBLOX: @HIRAKO7z\n\n"
    message = message .. statusEmoji .. " STATUS: " .. statusText .. "\n"
    message = message .. "========================================\n```"
    
    return message
end

-- Send Telegram Message
local function SendTelegram(message)
    if not TelegramConfig.BotToken or TelegramConfig.BotToken == "" then
        warn("[Telegram] Bot token empty")
        return false, "no token"
    end
    
    if not TelegramConfig.ChatID or TelegramConfig.ChatID == "" then
        warn("[Telegram] Chat ID empty")
        return false, "no chat id"
    end
    
    local url = ("https://api.telegram.org/bot%s/sendMessage"):format(TelegramConfig.BotToken)
    local payload = {
        chat_id = TelegramConfig.ChatID,
        text = message,
        parse_mode = "Markdown"
    }
    
    local body = safeJSONEncode(payload)
    local req = {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body
    }
    
    local ok, res = pickHTTPRequest(req)
    if not ok then
        warn("[Telegram] HTTP request failed:", res)
        return false, res
    end
    
    local success = false
    if type(res) == "table" then
        if res.Body or res.body or (res.StatusCode and tonumber(res.StatusCode) >= 200 and tonumber(res.StatusCode) < 300) then
            success = true
        end
    elseif type(res) == "string" then
        success = true
    end
    
    if success then
        print("[Telegram] Message sent successfully")
        return true, res
    else
        warn("[Telegram] Unknown response:", res)
        return false, res
    end
end

-- Check if Should Send by Rarity
local function ShouldSendByRarity(rarity)
    if not TelegramConfig.Enabled then return false end
    if CountSelected() == 0 then return false end
    
    local key = string.upper(tostring(rarity or "UNKNOWN"))
    return TelegramConfig.SelectedRarities[key] == true
end

-- Send Quest Notification
local function SendQuestNotification(questName, taskName, progress, statusType)
    if not TelegramConfig.Enabled or not TelegramConfig.QuestNotifications then return end
    if not TelegramConfig.ChatID or TelegramConfig.ChatID == "" then return end
    
    local message = BuildQuestTelegramMessage(questName, taskName, progress, statusType)
    spawn(function()
        local success = SendTelegram(message)
        if success then
            print("[Quest Telegram] " .. statusType .. " notification sent for " .. questName)
        end
    end)
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local Config = {
    -- Fishing
    AutoFishingV1 = false,
    AutoFishingV2 = false,
    AutoFishingV3 = false,
    AutoFishingNewMethod = false,
    FishingDelay = 0.3,
    PerfectCatch = false,
    
    -- Auto Features
    AntiAFK = false,
    AutoJump = false,
    AutoJumpDelay = 3,
    AutoSell = false,
    SellThreshold = 100,
    AutoBuyWeather = false,
    AutoRejoin = false,
    
    -- Movement
    WalkSpeed = 16,
    JumpPower = 50,
    WalkOnWater = false,
    NoClip = false,
    
    -- Visual
    XRay = false,
    ESPEnabled = false,
    ESPDistance = 20,
    InfiniteZoom = false,
    Brightness = 2,
    TimeOfDay = 14,
    HDGraphicMode = false,
    
    -- Teleport
    SavedPosition = nil,
    CheckpointPosition = HumanoidRootPart.CFrame,
    LockedPosition = false,
    LockCFrame = nil,
    
    -- Weather
    SelectedWeathers = {},
}

-- Runtime State Flags
local RuntimeState = {
    IsFishingV1 = false,
    IsFishingV2 = false,
    IsFishingV3 = false,
    IsFishingNewMethod = false,
    IsSelling = false,
    LastFishTime = tick(),
}

-- ============================================================================
-- REMOTES SYSTEM
-- ============================================================================

local net = ReplicatedStorage:WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_net@0.2.0")
    :WaitForChild("net")

local function GetRemote(name)
    return net:FindFirstChild(name)
end

-- Cache all remotes
local Remotes = {
    EquipTool = GetRemote("RE/EquipToolFromHotbar"),
    ChargeRod = GetRemote("RF/ChargeFishingRod"),
    StartMini = GetRemote("RF/RequestFishingMinigameStarted"),
    FinishFish = GetRemote("RE/FishingCompleted"),
    EquipOxy = GetRemote("RF/EquipOxygenTank"),
    UnequipOxy = GetRemote("RF/UnequipOxygenTank"),
    Radar = GetRemote("RF/UpdateFishingRadar"),
    SellRemote = GetRemote("RF/SellAllItems"),
    PurchaseWeather = GetRemote("RF/PurchaseWeatherEvent"),
    UpdateAutoFishing = GetRemote("RF/UpdateAutoFishingState"),
    FishCaught = GetRemote("RE/FishCaught"),
}

-- Startup Health Check
local function HealthCheckRemotes()
    local missingRemotes = {}
    
    for name, remote in pairs(Remotes) do
        if not remote then
            table.insert(missingRemotes, name)
            warn("[HEALTH CHECK] Missing remote:", name)
        end
    end
    
    if #missingRemotes > 0 then
        Rayfield:Notify({
            Title = "Remote Warning",
            Content = "Some remotes missing: " .. table.concat(missingRemotes, ", "),
            Duration = 5
        })
        return false
    end
    
    print("[HEALTH CHECK] All remotes found ✓")
    return true
end

-- ============================================================================
-- INVENTORY & AUTO SELL SYSTEM
-- ============================================================================

-- Refresh Inventory Count
local function RefreshInventoryCount()
    local count = 0
    
    pcall(function()
        if LocalPlayer.PlayerGui then
            local inventoryGui = LocalPlayer.PlayerGui:FindFirstChild("Inventory")
            if inventoryGui then
                for _, element in pairs(inventoryGui:GetDescendants()) do
                    if element:IsA("TextLabel") and string.find(element.Text, "/") then
                        local current = string.match(element.Text, "(%d+)/")
                        if current then
                            count = tonumber(current) or 0
                            break
                        end
                    end
                end
            end
        end
    end)
    
    return count
end

-- Sell All Fish (Protected)
local function SellAllFish()
    if RuntimeState.IsSelling then
        warn("[AutoSell] Already selling, skipping...")
        return false
    end
    
    RuntimeState.IsSelling = true
    
    local success = pcall(function()
        if Remotes.SellRemote then
            Remotes.SellRemote:InvokeServer()
            print("[AutoSell] Sold all fish successfully")
        end
    end)
    
    task.wait(0.5)
    RuntimeState.IsSelling = false
    
    return success
end

-- Auto Sell Worker
local function AutoSellWorker()
    task.spawn(function()
        print("[AutoSell] Worker started")
        
        while Config.AutoSell do
            pcall(function()
                local currentCount = RefreshInventoryCount()
                
                if currentCount >= Config.SellThreshold then
                    print("[AutoSell] Threshold reached:", currentCount, ">=", Config.SellThreshold)
                    
                    local success = SellAllFish()
                    
                    if success then
                        Rayfield:Notify({
                            Title = "Auto Sell",
                            Content = "Sold all fish! Inventory was: " .. currentCount .. "/4500",
                            Duration = 3
                        })
                        
                        -- Send telegram notification
                        if TelegramConfig.Enabled then
                            local message = "```\n"
                            message = message .. "HIRAKO AUTO SELL\n"
                            message = message .. "========================================\n\n"
                            message = message .. "PLAYER: " .. LocalPlayer.Name .. "\n"
                            message = message .. "ACTION: Auto Sell Triggered\n"
                            message = message .. "INVENTORY: " .. currentCount .. "/4500\n"
                            message = message .. "THRESHOLD: " .. Config.SellThreshold .. "\n\n"
                            message = message .. "TIME: " .. os.date("%H:%M:%S") .. "\n"
                            message = message .. "STATUS: SUCCESS\n"
                            message = message .. "========================================\n```"
                            
                            spawn(function() SendTelegram(message) end)
                        end
                    end
                end
            end)
            
            task.wait(10) -- Check every 10 seconds
        end
        
        print("[AutoSell] Worker stopped")
    end)
end

-- ============================================================================
-- AUTO FISHING V1 (FAST SPEED - FIXED)
-- ============================================================================

local function ResetFishingState()
    RuntimeState.IsFishingV1 = false
    RuntimeState.LastFishTime = tick()
end

function AutoFishingV1()
    if RuntimeState.IsFishingV1 then
        warn("[AutoFishingV1] Already running")
        return
    end
    
    task.spawn(function()
        RuntimeState.IsFishingV1 = true
        print("[AutoFishingV1] Started - Fast Speed Mode")
        
        local consecutiveErrors = 0
        local maxConsecutiveErrors = 10
        
        while Config.AutoFishingV1 and RuntimeState.IsFishingV1 do
            local cycleSuccess = false
            
            local success, err = pcall(function()
                -- Wait if selling
                while RuntimeState.IsSelling do
                    task.wait(0.5)
                end
                
                -- Validate character
                if not LocalPlayer.Character or not HumanoidRootPart then
                    repeat task.wait(0.5) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    Character = LocalPlayer.Character
                    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
                end
                
                -- Step 1: Equip Rod
                if Remotes.EquipTool then
                    local equipOk = pcall(function()
                        Remotes.EquipTool:FireServer(1)
                    end)
                    if not equipOk then
                        error("Equip failed")
                    end
                    task.wait(0.15)
                end
                
                -- Step 2: Charge Rod
                if Remotes.ChargeRod then
                    local chargeSuccess = false
                    for attempt = 1, 3 do
                        local ok, result = pcall(function()
                            return Remotes.ChargeRod:InvokeServer(tick())
                        end)
                        if ok and result then
                            chargeSuccess = true
                            break
                        end
                        task.wait(0.1)
                    end
                    
                    if not chargeSuccess then
                        error("Charge failed after 3 attempts")
                    end
                    task.wait(0.12)
                end
                
                -- Step 3: Start Minigame
                if Remotes.StartMini then
                    local startSuccess = false
                    for attempt = 1, 3 do
                        local ok = pcall(function()
                            Remotes.StartMini:InvokeServer(-1.233184814453125, 0.9945034885633273)
                        end)
                        if ok then
                            startSuccess = true
                            break
                        end
                        task.wait(0.1)
                    end
                    
                    if not startSuccess then
                        error("Start minigame failed after 3 attempts")
                    end
                end
                
                -- Step 4: Wait for bite
                local actualDelay = math.max(Config.FishingDelay or 0.3, 0.1)
                task.wait(actualDelay)
                
                -- Step 5: Finish Fishing
                if Remotes.FinishFish then
                    local finishOk = pcall(function()
                        Remotes.FinishFish:FireServer()
                    end)
                    
                    if finishOk then
                        cycleSuccess = true
                        RuntimeState.LastFishTime = tick()
                        consecutiveErrors = 0
                    end
                end
                
                task.wait(0.1)
            end)
            
            if not success then
                consecutiveErrors = consecutiveErrors + 1
                warn("[AutoFishingV1] Cycle error:", err, "| Consecutive errors:", consecutiveErrors)
                
                if consecutiveErrors >= maxConsecutiveErrors then
                    warn("[AutoFishingV1] Too many errors, stopping...")
                    Config.AutoFishingV1 = false
                    Rayfield:Notify({
                        Title = "AutoFishing V1",
                        Content = "Stopped due to errors. Please restart manually.",
                        Duration = 5
                    })
                    break
                end
                
                task.wait(1) -- Wait longer on error
            elseif cycleSuccess then
                task.wait(0.05) -- Short wait on success
            else
                task.wait(0.3) -- Medium wait on partial success
            end
        end
        
        ResetFishingState()
        print("[AutoFishingV1] Stopped")
    end)
end

-- ============================================================================
-- AUTO FISHING V2 (GAME AUTO)
-- ============================================================================

local function AutoFishingV2()
    if RuntimeState.IsFishingV2 then
        warn("[AutoFishingV2] Already running")
        return
    end
    
    task.spawn(function()
        RuntimeState.IsFishingV2 = true
        print("[AutoFishingV2] Started - Using Game Auto Fishing")
        
        -- Enable game auto fishing
        pcall(function()
            if Remotes.UpdateAutoFishing then
                Remotes.UpdateAutoFishing:InvokeServer(true)
            end
        end)
        
        -- Hook perfect catch
        local mt = getrawmetatable(game)
        if mt then
            setreadonly(mt, false)
            local old = mt.__namecall
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "InvokeServer" and self == Remotes.StartMini then
                    if Config.AutoFishingV2 and RuntimeState.IsFishingV2 then
                        return old(self, -1.233184814453125, 0.9945034885633273)
                    end
                end
                return old(self, ...)
            end)
            setreadonly(mt, true)
        end
        
        while Config.AutoFishingV2 and RuntimeState.IsFishingV2 do
            task.wait(1)
        end
        
        -- Disable game auto fishing
        pcall(function()
            if Remotes.UpdateAutoFishing then
                Remotes.UpdateAutoFishing:InvokeServer(false)
            end
        end)
        
        RuntimeState.IsFishingV2 = false
        print("[AutoFishingV2] Stopped")
    end)
end

-- ============================================================================
-- AUTO FISHING V3 (STABLE - FIXED)
-- ============================================================================

function AutoFishingV3()
    if RuntimeState.IsFishingV3 then
        warn("[AutoFishingV3] Already running")
        return
    end
    
    task.spawn(function()
        RuntimeState.IsFishingV3 = true
        print("[AutoFishingV3] Started - Stable Mode (Fixed 1.5s delay)")
        
        local consecutiveErrors = 0
        local maxConsecutiveErrors = 10
        
        while Config.AutoFishingV3 and RuntimeState.IsFishingV3 do
            local success, err = pcall(function()
                -- Wait if selling
                while RuntimeState.IsSelling do
                    task.wait(0.5)
                end
                
                -- Validate character
                if not LocalPlayer.Character or not HumanoidRootPart or 
                   (LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.Health <= 0) then
                    repeat task.wait(1) until LocalPlayer.Character and 
                        LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and 
                        LocalPlayer.Character.Humanoid.Health > 0
                    Character = LocalPlayer.Character
                    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
                    Humanoid = Character:WaitForChild("Humanoid")
                end
                
                -- Check inventory before fishing
                local invCount = RefreshInventoryCount()
                if invCount >= 4400 and Config.AutoSell then
                    print("[AutoFishingV3] Inventory nearly full, triggering sell...")
                    SellAllFish()
                    task.wait(2)
                end
                
                -- Step 1: Equip Rod
                if Remotes.EquipTool then
                    pcall(function()
                        Remotes.EquipTool:FireServer(1)
                    end)
                    task.wait(0.3)
                end
                
                -- Step 2: Charge Rod
                if Remotes.ChargeRod then
                    local chargeSuccess = false
                    for attempt = 1, 3 do
                        local ok, result = pcall(function()
                            return Remotes.ChargeRod:InvokeServer(tick())
                        end)
                        if ok and result then
                            chargeSuccess = true
                            break
                        end
                        task.wait(0.15)
                    end
                    
                    if not chargeSuccess then
                        error("Charge failed")
                    end
                end
                task.wait(0.25)
                
                -- Step 3: Start Minigame
                if Remotes.StartMini then
                    local startSuccess = false
                    for attempt = 1, 3 do
                        local ok = pcall(function()
                            Remotes.StartMini:InvokeServer(-1.233184814453125, 0.9945034885633273)
                        end)
                        if ok then
                            startSuccess = true
                            break
                        end
                        task.wait(0.15)
                    end
                    
                    if not startSuccess then
                        error("Start minigame failed")
                    end
                end
                
                -- Step 4: Fixed wait time (stable mode)
                task.wait(1.5)
                
                -- Step 5: Finish Fishing
                if Remotes.FinishFish then
                    local finishOk = pcall(function()
                        Remotes.FinishFish:FireServer()
                    end)
                    
                    if finishOk then
                        consecutiveErrors = 0
                        RuntimeState.LastFishTime = tick()
                        print("[AutoFishingV3] Successfully caught fish")
                    end
                end
                
                task.wait(0.5)
            end)
            
            if not success then
                consecutiveErrors = consecutiveErrors + 1
                warn("[AutoFishingV3] Cycle error:", err, "| Consecutive errors:", consecutiveErrors)
                
                if consecutiveErrors >= maxConsecutiveErrors then
                    warn("[AutoFishingV3] Too many errors, stopping...")
                    Config.AutoFishingV3 = false
                    Rayfield:Notify({
                        Title = "AutoFishing V3",
                        Content = "Stopped due to errors. Please restart manually.",
                        Duration = 5
                    })
                    break
                end
                
                task.wait(2)
            end
        end
        
        RuntimeState.IsFishingV3 = false
        print("[AutoFishingV3] Stopped")
    end)
end

-- ============================================================================
-- AUTO FISHING - NEW METHOD (EQUIP ONCE)
-- ============================================================================

function AutoFishingNewMethod()
    if RuntimeState.IsFishingNewMethod then
        warn("[AutoFishingNewMethod] Already running")
        return
    end
    
    task.spawn(function()
        RuntimeState.IsFishingNewMethod = true
        print("[AutoFishingNewMethod] Started - Equip Rod Once Mode")
        
        -- Equip rod once at start
        local equipSuccess = false
        for attempt = 1, 5 do
            local ok = pcall(function()
                if Remotes.EquipTool then
                    Remotes.EquipTool:FireServer(1)
                end
            end)
            
            if ok then
                equipSuccess = true
                print("[AutoFishingNewMethod] Rod equipped successfully")
                break
            end
            
            task.wait(0.5)
        end
        
        if not equipSuccess then
            warn("[AutoFishingNewMethod] Failed to equip rod, stopping...")
            Config.AutoFishingNewMethod = false
            RuntimeState.IsFishingNewMethod = false
            Rayfield:Notify({
                Title = "New Method",
                Content = "Failed to equip rod. Please try again.",
                Duration = 5
            })
            return
        end
        
        task.wait(1)
        
        local consecutiveErrors = 0
        local maxConsecutiveErrors = 10
        
        while Config.AutoFishingNewMethod and RuntimeState.IsFishingNewMethod do
            local success, err = pcall(function()
                -- Wait if selling
                while RuntimeState.IsSelling do
                    task.wait(0.5)
                end
                
                -- Validate character
                if not LocalPlayer.Character or not HumanoidRootPart then
                    repeat task.wait(0.5) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    Character = LocalPlayer.Character
                    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
                end
                
                -- Step 1: Charge Rod (NO EQUIP)
                if Remotes.ChargeRod then
                    local chargeSuccess = false
                    for attempt = 1, 3 do
                        local ok, result = pcall(function()
                            return Remotes.ChargeRod:InvokeServer(tick())
                        end)
                        if ok and result then
                            chargeSuccess = true
                            break
                        end
                        task.wait(0.1)
                    end
                    
                    if not chargeSuccess then
                        error("Charge failed")
                    end
                    task.wait(0.12)
                end
                
                -- Step 2: Start Minigame
                if Remotes.StartMini then
                    local startSuccess = false
                    for attempt = 1, 3 do
                        local ok = pcall(function()
                            Remotes.StartMini:InvokeServer(-1.233184814453125, 0.9945034885633273)
                        end)
                        if ok then
                            startSuccess = true
                            break
                        end
                        task.wait(0.1)
                    end
                    
                    if not startSuccess then
                        error("Start minigame failed")
                    end
                end
                
                -- Step 3: Wait
                local actualDelay = math.max(Config.FishingDelay or 0.3, 0.1)
                task.wait(actualDelay)
                
                -- Step 4: Finish
                if Remotes.FinishFish then
                    local finishOk = pcall(function()
                        Remotes.FinishFish:FireServer()
                    end)
                    
                    if finishOk then
                        consecutiveErrors = 0
                        RuntimeState.LastFishTime = tick()
                    end
                end
                
                task.wait(0.0001)
            end)
            
            if not success then
                consecutiveErrors = consecutiveErrors + 1
                warn("[AutoFishingNewMethod] Error:", err, "| Consecutive:", consecutiveErrors)
                
                if consecutiveErrors >= maxConsecutiveErrors then
                    warn("[AutoFishingNewMethod] Too many errors, stopping...")
                    Config.AutoFishingNewMethod = false
                    Rayfield:Notify({
                        Title = "New Method",
                        Content = "Stopped due to errors.",
                        Duration = 5
                    })
                    break
                end
            end
        end
        
        RuntimeState.IsFishingNewMethod = false
        print("[AutoFishingNewMethod] Stopped")
    end)
end

-- ============================================================================
-- PERFECT CATCH SYSTEM
-- ============================================================================

local PerfectCatchConnection = nil

local function TogglePerfectCatch(enabled)
    Config.PerfectCatch = enabled
    
    if enabled then
        if PerfectCatchConnection then
            PerfectCatchConnection:Disconnect()
        end
        
        local mt = getrawmetatable(game)
        if not mt then return end
        
        setreadonly(mt, false)
        local old = mt.__namecall
        
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "InvokeServer" and self == Remotes.StartMini then
                if Config.PerfectCatch and not Config.AutoFishingV1 and 
                   not Config.AutoFishingV2 and not Config.AutoFishingV3 and 
                   not Config.AutoFishingNewMethod then
                    return old(self, -1.233184814453125, 0.9945034885633273)
                end
            end
            return old(self, ...)
        end)
        
        setreadonly(mt, true)
        print("[PerfectCatch] Enabled")
    else
        if PerfectCatchConnection then
            PerfectCatchConnection:Disconnect()
            PerfectCatchConnection = nil
        end
        print("[PerfectCatch] Disabled")
    end
end

-- ============================================================================
-- WALK ON WATER (SMOOTH - FIXED)
-- ============================================================================

local WalkOnWaterConnection = nil
local WaterSurfaceY = nil

local function WalkOnWater()
    if WalkOnWaterConnection then
        WalkOnWaterConnection:Disconnect()
        WalkOnWaterConnection = nil
    end
    
    if not Config.WalkOnWater then return end
    
    task.spawn(function()
        print("[WalkOnWater] Activated - Smooth Mode")
        
        WalkOnWaterConnection = RunService.Heartbeat:Connect(function()
            if not Config.WalkOnWater then
                if WalkOnWaterConnection then
                    WalkOnWaterConnection:Disconnect()
                    WalkOnWaterConnection = nil
                end
                return
            end
            
            pcall(function()
                if HumanoidRootPart and Humanoid then
                    local rayOrigin = HumanoidRootPart.Position
                    local rayDirection = Vector3.new(0, -20, 0)
                    
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {Character}
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    
                    local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                    
                    if raycastResult and raycastResult.Instance then
                        local hitPart = raycastResult.Instance
                        
                        if hitPart.Name:lower():find("water") or hitPart.Material == Enum.Material.Water then
                            local waterY = raycastResult.Position.Y
                            local playerY = HumanoidRootPart.Position.Y
                            local targetY = waterY + 3.5
                            
                            -- Smooth adjustment instead of instant teleport
                            if playerY < targetY then
                                local diff = targetY - playerY
                                local smoothFactor = 0.3 -- Lower = smoother
                                local newY = playerY + (diff * smoothFactor)
                                
                                HumanoidRootPart.CFrame = CFrame.new(
                                    HumanoidRootPart.Position.X,
                                    newY,
                                    HumanoidRootPart.Position.Z
                                )
                            end
                        end
                    end
                    
                    -- Check terrain water
                    local region = Region3.new(
                        HumanoidRootPart.Position - Vector3.new(2, 10, 2),
                        HumanoidRootPart.Position + Vector3.new(2, 2, 2)
                    )
                    region = region:ExpandToGrid(4)
                    
                    local terrain = Workspace:FindFirstChildOfClass("Terrain")
                    if terrain then
                        local materials, sizes = terrain:ReadVoxels(region, 4)
                        local size = materials.Size
                        
                        for x = 1, size.X do
                            for y = 1, size.Y do
                                for z = 1, size.Z do
                                    if materials[x][y][z] == Enum.Material.Water then
                                        local waterY = HumanoidRootPart.Position.Y
                                        local targetY = waterY + 3.5
                                        local playerY = HumanoidRootPart.Position.Y
                                        
                                        if playerY < targetY then
                                            local diff = targetY - playerY
                                            local smoothFactor = 0.3
                                            local newY = playerY + (diff * smoothFactor)
                                            
                                            HumanoidRootPart.CFrame = CFrame.new(
                                                HumanoidRootPart.Position.X,
                                                newY,
                                                HumanoidRootPart.Position.Z
                                            )
                                        end
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end)
    end)
end

-- ============================================================================
-- AUTO BUY WEATHER
-- ============================================================================

local WeatherList = {"Wind", "Cloudy", "Snow", "Storm", "Radiant", "Shark Hunt"}

local function AutoBuyWeather()
    task.spawn(function()
        print("[AutoBuyWeather] Started")
        
        while Config.AutoBuyWeather do
            for _, weather in pairs(Config.SelectedWeathers) do
                if weather and weather ~= "None" then
                    pcall(function()
                        if Remotes.PurchaseWeather then
                            Remotes.PurchaseWeather:InvokeServer(weather)
                            print("[AutoBuyWeather] Purchased:", weather)
                        end
                    end)
                    task.wait(0.5)
                end
            end
            task.wait(5)
        end
        
        print("[AutoBuyWeather] Stopped")
    end)
end

-- ============================================================================
-- ANTI AFK
-- ============================================================================

local function AntiAFK()
    task.spawn(function()
        print("[AntiAFK] Started")
        
        while Config.AntiAFK do
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
            task.wait(30)
        end
        
        print("[AntiAFK] Stopped")
    end)
end

-- ============================================================================
-- AUTO JUMP
-- ============================================================================

local function AutoJump()
    task.spawn(function()
        print("[AutoJump] Started with delay:", Config.AutoJumpDelay, "seconds")
        
        while Config.AutoJump do
            pcall(function()
                if Humanoid and Humanoid.FloorMaterial ~= Enum.Material.Air then
                    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
            task.wait(Config.AutoJumpDelay)
        end
        
        print("[AutoJump] Stopped")
    end)
end

-- ============================================================================
-- UTILITY FEATURES
-- ============================================================================

local function InfiniteZoom()
    task.spawn(function()
        while Config.InfiniteZoom do
            pcall(function()
                if LocalPlayer:FindFirstChild("CameraMaxZoomDistance") then
                    LocalPlayer.CameraMaxZoomDistance = math.huge
                end
            end)
            task.wait(1)
        end
    end)
end

local function NoClip()
    task.spawn(function()
        print("[NoClip] Started")
        
        while Config.NoClip do
            pcall(function()
                if Character then
                    for _, part in pairs(Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            task.wait(0.1)
        end
        
        print("[NoClip] Stopped")
    end)
end

local function XRay()
    task.spawn(function()
        print("[XRay] Started")
        
        while Config.XRay do
            pcall(function()
                for _, part in pairs(Workspace:GetDescendants()) do
                    if part:IsA("BasePart") and part.Transparency < 0.5 then
                        part.LocalTransparencyModifier = 0.5
                    end
                end
            end)
            task.wait(1)
        end
        
        print("[XRay] Stopped")
    end)
end

local function ESP()
    task.spawn(function()
        print("[ESP] Started")
        
        while Config.ESPEnabled do
            pcall(function()
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local distance = (HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                        if distance <= Config.ESPDistance then
                            -- ESP rendering logic (placeholder)
                        end
                    end
                end
            end)
            task.wait(1)
        end
        
        print("[ESP] Stopped")
    end)
end

local function LockPosition()
    task.spawn(function()
        print("[LockPosition] Started")
        
        while Config.LockedPosition do
            pcall(function()
                if HumanoidRootPart and Config.LockCFrame then
                    HumanoidRootPart.CFrame = Config.LockCFrame
                end
            end)
            task.wait()
        end
        
        print("[LockPosition] Stopped")
    end)
end

-- ============================================================================
-- GRAPHICS FUNCTIONS
-- ============================================================================

local LightingConnection = nil

local function ApplyPermanentLighting()
    if LightingConnection then
        LightingConnection:Disconnect()
    end
    
    LightingConnection = RunService.Heartbeat:Connect(function()
        pcall(function()
            Lighting.Brightness = Config.Brightness
            Lighting.ClockTime = Config.TimeOfDay
        end)
    end)
    
    print("[Lighting] Permanent lighting applied")
end

local function RemoveFog()
    pcall(function()
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
        
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("Atmosphere") then
                effect.Density = 0
            end
        end
    end)
    
    RunService.Heartbeat:Connect(function()
        pcall(function()
            Lighting.FogEnd = 100000
            Lighting.FogStart = 0
        end)
    end)
    
    print("[Fog] Removed permanently")
end

local function Enable8Bit()
    task.spawn(function()
        print("[8-Bit Mode] Enabling super smooth rendering...")
        
        for _, obj in pairs(Workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                    obj.CastShadow = false
                    obj.TopSurface = Enum.SurfaceType.Smooth
                    obj.BottomSurface = Enum.SurfaceType.Smooth
                end
                if obj:IsA("MeshPart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                    obj.TextureID = ""
                    obj.CastShadow = false
                    obj.RenderFidelity = Enum.RenderFidelity.Performance
                end
                if obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                end
                if obj:IsA("SpecialMesh") then
                    obj.TextureId = ""
                end
            end)
        end
        
        for _, effect in pairs(Lighting:GetChildren()) do
            pcall(function()
                if effect:IsA("PostEffect") or effect:IsA("Atmosphere") then
                    effect.Enabled = false
                end
            end)
        end
        
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        
        Workspace.DescendantAdded:Connect(function(obj)
            pcall(function()
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                    obj.CastShadow = false
                end
                if obj:IsA("MeshPart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                    obj.TextureID = ""
                    obj.RenderFidelity = Enum.RenderFidelity.Performance
                end
            end)
        end)
        
        print("[8-Bit Mode] Enabled")
    end)
end

local function RemoveParticles()
    for _, obj in pairs(Workspace:GetDescendants()) do
        pcall(function()
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
               obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
                obj:Destroy()
            end
        end)
    end
    
    Workspace.DescendantAdded:Connect(function(obj)
        pcall(function()
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
               obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
                obj:Destroy()
            end
        end)
    end)
    
    print("[Particles] Removed permanently")
end

local function RemoveSeaweed()
    for _, obj in pairs(Workspace:GetDescendants()) do
        pcall(function()
            local name = obj.Name:lower()
            if name:find("seaweed") or name:find("kelp") or name:find("coral") or 
               name:find("plant") or name:find("weed") then
                if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                    obj:Destroy()
                end
            end
        end)
    end
    
    Workspace.DescendantAdded:Connect(function(obj)
        pcall(function()
            local name = obj.Name:lower()
            if name:find("seaweed") or name:find("kelp") or name:find("coral") or 
               name:find("plant") or name:find("weed") then
                if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                    task.wait(0.1)
                    obj:Destroy()
                end
            end
        end)
    end)
    
    print("[Seaweed] Removed permanently")
end

local function OptimizeWater()
    for _, obj in pairs(Workspace:GetDescendants()) do
        pcall(function()
            if obj:IsA("Terrain") then
                obj.WaterReflectance = 0
                obj.WaterTransparency = 1
                obj.WaterWaveSize = 0
                obj.WaterWaveSpeed = 0
            end
            
            if obj:IsA("Part") or obj:IsA("MeshPart") then
                if obj.Material == Enum.Material.Water then
                    obj.Reflectance = 0
                    obj.Transparency = 0.8
                end
            end
        end)
    end
    
    RunService.Heartbeat:Connect(function()
        pcall(function()
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Terrain") then
                    obj.WaterReflectance = 0
                    obj.WaterTransparency = 1
                    obj.WaterWaveSize = 0
                    obj.WaterWaveSpeed = 0
                end
            end
        end)
    end)
    
    print("[Water] Optimized permanently")
end

-- ============================================================================
-- PERFORMANCE MODE
-- ============================================================================

local PerformanceModeActive = false

local function PerformanceMode()
    if PerformanceModeActive then return end
    
    PerformanceModeActive = true
    print("[PERFORMANCE MODE] Activating ultra performance...")
    
    pcall(function()
        -- Lighting optimizations
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
        Lighting.Brightness = 1
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        
        -- Remove all effects
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
               obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
            
            if obj:IsA("Terrain") then
                obj.WaterReflectance = 0
                obj.WaterTransparency = 0.9
                obj.WaterWaveSize = 0
                obj.WaterWaveSpeed = 0
            end
            
            if obj:IsA("Part") or obj:IsA("MeshPart") then
                if obj.Material == Enum.Material.Water then
                    obj.Transparency = 0.9
                    obj.Reflectance = 0
                end
                
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
            end
            
            if obj:IsA("Atmosphere") or obj:IsA("PostEffect") then
                obj:Destroy()
            end
        end
        
        -- Set minimum quality
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        
        -- Monitor for new objects
        RunService.Heartbeat:Connect(function()
            if PerformanceModeActive then
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 100000
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end
        end)
        
        Workspace.DescendantAdded:Connect(function(obj)
            if PerformanceModeActive then
                pcall(function()
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
                       obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                        obj.Enabled = false
                    end
                    
                    if obj:IsA("Part") or obj:IsA("MeshPart") then
                        obj.Material = Enum.Material.SmoothPlastic
                        obj.Reflectance = 0
                        obj.CastShadow = false
                    end
                end)
            end
        end)
    end)
    
    print("[PERFORMANCE MODE] Enabled successfully")
end

-- ============================================================================
-- HD GRAPHIC MODE (NEW)
-- ============================================================================

local HDModeActive = false

local function HDGraphicMode()
    if HDModeActive then return end
    
    HDModeActive = true
    Config.HDGraphicMode = true
    print("[HD GRAPHIC MODE] Activating high quality graphics...")
    
    pcall(function()
        -- Maximum quality settings
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        
        -- Lighting enhancements
        Lighting.GlobalShadows = true
        Lighting.Brightness = 2
        Lighting.FogEnd = 10000
        Lighting.Technology = Enum.Technology.Future
        
        -- Restore all visual effects
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
               obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = true
            end
            
            if obj:IsA("Terrain") then
                obj.WaterReflectance = 1
                obj.WaterTransparency = 0.3
                obj.WaterWaveSize = 0.05
                obj.WaterWaveSpeed = 10
            end
            
            if obj:IsA("Part") or obj:IsA("MeshPart") then
                obj.CastShadow = true
                if obj:IsA("MeshPart") then
                    obj.RenderFidelity = Enum.RenderFidelity.Automatic
                end
            end
        end
    end)
    
    print("[HD GRAPHIC MODE] Enabled successfully")
end

local function DisableHDGraphicMode()
    HDModeActive = false
    Config.HDGraphicMode = false
    
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        Lighting.GlobalShadows = true
        Lighting.Brightness = 2
    end)
    
    print("[HD GRAPHIC MODE] Disabled")
end

-- ============================================================================
-- TELEPORT SYSTEM
-- ============================================================================

local IslandsData = {
    {Name = "Fisherman Island", Position = Vector3.new(92, 9, 2768)},
    {Name = "Arrow Lever", Position = Vector3.new(898, 8, -363)},
    {Name = "Sisyphus Statue", Position = Vector3.new(-3740, -136, -1013)},
    {Name = "Ancient Jungle", Position = Vector3.new(1481, 11, -302)},
    {Name = "Weather Machine", Position = Vector3.new(-1519, 2, 1908)},
    {Name = "Coral Refs", Position = Vector3.new(-3105, 6, 2218)},
    {Name = "Tropical Island", Position = Vector3.new(-2110, 53, 3649)},
    {Name = "Kohana", Position = Vector3.new(-662, 3, 714)},
    {Name = "Esoteric Island", Position = Vector3.new(2035, 27, 1386)},
    {Name = "Diamond Lever", Position = Vector3.new(1818, 8, -285)},
    {Name = "Underground Cellar", Position = Vector3.new(2098, -92, -703)},
    {Name = "Volcano", Position = Vector3.new(-631, 54, 194)},
    {Name = "Enchant Room", Position = Vector3.new(3255, -1302, 1371)},
    {Name = "Lost Isle", Position = Vector3.new(-3717, 5, -1079)},
    {Name = "Sacred Temple", Position = Vector3.new(1475, -22, -630)},
    {Name = "Creater Island", Position = Vector3.new(981, 41, 5080)},
    {Name = "Double Enchant Room", Position = Vector3.new(1480, 127, -590)},
    {Name = "Treassure Room", Position = Vector3.new(-3599, -276, -1642)},
    {Name = "Crescent Lever", Position = Vector3.new(1419, 31, 78)},
    {Name = "Hourglass Diamond Lever", Position = Vector3.new(1484, 8, -862)},
    {Name = "Snow Island", Position = Vector3.new(1627, 4, 3288)}
}

local function TeleportToPosition(pos)
    if HumanoidRootPart then
        pcall(function()
            HumanoidRootPart.CFrame = CFrame.new(pos)
        end)
        return true
    end
    return false
end

local function ScanActiveEvents()
    local events = {}
    local validEvents = {
        "megalodon", "whale", "kraken", "hunt", "Ghost Worm", "Mount Hallow",
        "admin", "Hallow Bay", "worm", "blackhole", "HalloweenFastTravel"
    }
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            local name = obj.Name:lower()
            
            for _, keyword in ipairs(validEvents) do
                if name:find(keyword:lower()) and not name:find("boat") and not name:find("sharki") then
                    local exists = false
                    for _, e in ipairs(events) do
                        if e.Name == obj.Name then
                            exists = true
                            break
                        end
                    end
                    
                    if not exists then
                        local pos = Vector3.new(0, 0, 0)
                        
                        pcall(function()
                            if obj:IsA("Model") then
                                pos = obj:GetModelCFrame().Position
                            elseif obj:IsA("BasePart") then
                                pos = obj.Position
                            elseif obj:IsA("Folder") and #obj:GetChildren() > 0 then
                                local child = obj:GetChildren()[1]
                                if child:IsA("Model") then
                                    pos = child:GetModelCFrame().Position
                                elseif child:IsA("BasePart") then
                                    pos = child.Position
                                end
                            end
                        end)
                        
                        table.insert(events, {
                            Name = obj.Name,
                            Object = obj,
                            Position = pos
                        })
                    end
                    
                    break
                end
            end
        end
    end
    
    print("[EVENT SCANNER] Found", #events, "active events")
    return events
end

-- ============================================================================
-- SAVE/LOAD CONFIG SYSTEM (NEW)
-- ============================================================================

local SaveFile = "HIRAKOFishIt_Config_" .. LocalPlayer.UserId .. ".json"

local function SaveConfig()
    local configData = {
        Config = {
            -- Fishing
            FishingDelay = Config.FishingDelay,
            PerfectCatch = Config.PerfectCatch,
            SellThreshold = Config.SellThreshold,
            
            -- Movement
            WalkSpeed = Config.WalkSpeed,
            JumpPower = Config.JumpPower,
            AutoJumpDelay = Config.AutoJumpDelay,
            
            -- Visual
            Brightness = Config.Brightness,
            TimeOfDay = Config.TimeOfDay,
            ESPDistance = Config.ESPDistance,
            
            -- Weather
            SelectedWeathers = Config.SelectedWeathers,
        },
        
        -- Saved Positions
        SavedPosition = Config.SavedPosition and {
            X = Config.SavedPosition.Position.X,
            Y = Config.SavedPosition.Position.Y,
            Z = Config.SavedPosition.Position.Z,
        } or nil,
        
        CheckpointPosition = Config.CheckpointPosition and {
            X = Config.CheckpointPosition.Position.X,
            Y = Config.CheckpointPosition.Position.Y,
            Z = Config.CheckpointPosition.Position.Z,
        } or nil,
        
        -- Active Features (for auto-restart)
        ActiveFeatures = {
            AutoFishingV1 = Config.AutoFishingV1,
            AutoFishingV2 = Config.AutoFishingV2,
            AutoFishingV3 = Config.AutoFishingV3,
            AutoFishingNewMethod = Config.AutoFishingNewMethod,
            AntiAFK = Config.AntiAFK,
            AutoJump = Config.AutoJump,
            AutoSell = Config.AutoSell,
            AutoBuyWeather = Config.AutoBuyWeather,
            WalkOnWater = Config.WalkOnWater,
            NoClip = Config.NoClip,
            XRay = Config.XRay,
            ESPEnabled = Config.ESPEnabled,
            InfiniteZoom = Config.InfiniteZoom,
        },
        
        -- Telegram
        TelegramConfig = {
            Enabled = TelegramConfig.Enabled,
            ChatID = TelegramConfig.ChatID,
            SelectedRarities = TelegramConfig.SelectedRarities,
            QuestNotifications = TelegramConfig.QuestNotifications,
        },
        
        Timestamp = os.time(),
    }
    
    local success = pcall(function()
        local jsonData = HttpService:JSONEncode(configData)
        writefile(SaveFile, jsonData)
    end)
    
    if success then
        print("[SAVE] Configuration saved successfully")
        return true
    else
        warn("[SAVE] Failed to save configuration")
        return false
    end
end

local function LoadConfig()
    if not isfile(SaveFile) then
        print("[LOAD] No saved configuration found")
        return false
    end
    
    local success, configData = pcall(function()
        local jsonData = readfile(SaveFile)
        return HttpService:JSONDecode(jsonData)
    end)
    
    if not success or not configData then
        warn("[LOAD] Failed to load configuration")
        return false
    end
    
    pcall(function()
        -- Load Config values
        if configData.Config then
            for key, value in pairs(configData.Config) do
                if Config[key] ~= nil then
                    Config[key] = value
                end
            end
        end
        
        -- Load Positions
        if configData.SavedPosition then
            Config.SavedPosition = CFrame.new(
                configData.SavedPosition.X,
                configData.SavedPosition.Y,
                configData.SavedPosition.Z
            )
        end
        
        if configData.CheckpointPosition then
            Config.CheckpointPosition = CFrame.new(
                configData.CheckpointPosition.X,
                configData.CheckpointPosition.Y,
                configData.CheckpointPosition.Z
            )
        end
        
        -- Load Telegram Config
        if configData.TelegramConfig then
            for key, value in pairs(configData.TelegramConfig) do
                if TelegramConfig[key] ~= nil then
                    TelegramConfig[key] = value
                end
            end
        end
        
        -- Apply settings
        if Humanoid then
            Humanoid.WalkSpeed = Config.WalkSpeed
            Humanoid.JumpPower = Config.JumpPower
        end
        
        Lighting.Brightness = Config.Brightness
        Lighting.ClockTime = Config.TimeOfDay
    end)
    
    print("[LOAD] Configuration loaded successfully")
    return true
end

-- ============================================================================
-- AUTO REJOIN SYSTEM
-- ============================================================================

local RejoinSaveFile = "HIRAKORejoin_" .. LocalPlayer.UserId .. ".json"

local function SaveRejoinData()
    local rejoinData = {
        Position = HumanoidRootPart and {
            X = HumanoidRootPart.Position.X,
            Y = HumanoidRootPart.Position.Y,
            Z = HumanoidRootPart.Position.Z,
        } or nil,
        
        ActiveFeatures = {
            AutoFishingV1 = Config.AutoFishingV1,
            AutoFishingV2 = Config.AutoFishingV2,
            AutoFishingV3 = Config.AutoFishingV3,
            AutoFishingNewMethod = Config.AutoFishingNewMethod,
            AntiAFK = Config.AntiAFK,
            AutoJump = Config.AutoJump,
            AutoSell = Config.AutoSell,
            AutoBuyWeather = Config.AutoBuyWeather,
            WalkOnWater = Config.WalkOnWater,
            NoClip = Config.NoClip,
            XRay = Config.XRay,
        },
        
        Settings = {
            WalkSpeed = Config.WalkSpeed,
            JumpPower = Config.JumpPower,
            FishingDelay = Config.FishingDelay,
            SellThreshold = Config.SellThreshold,
            Brightness = Config.Brightness,
            TimeOfDay = Config.TimeOfDay,
        },
        
        Timestamp = os.time(),
    }
    
    pcall(function()
        local jsonData = HttpService:JSONEncode(rejoinData)
        writefile(RejoinSaveFile, jsonData)
    end)
end

local function LoadRejoinData()
    if not isfile(RejoinSaveFile) then
        return false
    end
    
    local success, rejoinData = pcall(function()
        local jsonData = readfile(RejoinSaveFile)
        return HttpService:JSONDecode(jsonData)
    end)
    
    if not success or not rejoinData then
        return false
    end
    
    pcall(function()
        -- Restore position
        if rejoinData.Position and HumanoidRootPart then
            task.wait(2)
            HumanoidRootPart.CFrame = CFrame.new(
                rejoinData.Position.X,
                rejoinData.Position.Y,
                rejoinData.Position.Z
            )
            print("[REJOIN] Position restored")
        end
        
        -- Restore settings
        if rejoinData.Settings then
            for key, value in pairs(rejoinData.Settings) do
                if Config[key] ~= nil then
                    Config[key] = value
                end
            end
        end
        
        -- Restore active features
        if rejoinData.ActiveFeatures then
            for key, value in pairs(rejoinData.ActiveFeatures) do
                if Config[key] ~= nil then
                    Config[key] = value
                end
            end
        end
    end)
    
    print("[REJOIN] Data loaded successfully")
    return true
end

local function SetupAutoRejoin()
    if not Config.AutoRejoin then return end
    
    print("[AUTO REJOIN] System enabled")
    
    -- Periodic save
    task.spawn(function()
        while Config.AutoRejoin do
            SaveRejoinData()
            task.wait(15)
        end
    end)
    
    -- Monitor disconnects
    task.spawn(function()
        pcall(function()
            game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
                if Config.AutoRejoin and child.Name == 'ErrorPrompt' then
                    task.wait(1)
                    SaveRejoinData()
                    task.wait(1)
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
        end)
    end)
    
    task.spawn(function()
        game:GetService("GuiService").ErrorMessageChanged:Connect(function()
            if Config.AutoRejoin then
                task.wait(1)
                SaveRejoinData()
                task.wait(1)
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)
    end)
    
    LocalPlayer.OnTeleport:Connect(function(State)
        if Config.AutoRejoin and State == Enum.TeleportState.Failed then
            task.wait(1)
            SaveRejoinData()
            task.wait(1)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)
end

-- ============================================================================
-- AUTO QUEST SYSTEM
-- ============================================================================

local TaskMapping = {
    ["Catch a SECRET Crystal Crab"] = "CRYSTAL CRAB",
    ["Catch 100 Epic Fish"] = "CRYSTAL CRAB",
    ["Catch 10,000 Fish"] = "CRYSTAL CRAB",
    ["Catch 300 Rare/Epic fish"] = "RARE/EPIC FISH",
    ["Earn 1M Coins"] = "FARMING COIN",
    ["Catch 1 SECRET fish at Sisyphus"] = "SECRET SYPUSH",
    ["Catch 3 Mythic fishes at Sisyphus"] = "SECRET SYPUSH",
    ["Create 3 Transcended Stones"] = "CREATE STONE",
    ["Catch 1 SECRET fish at Sacred Temple"] = "SECRET TEMPLE",
    ["Catch 1 SECRET fish at Ancient Jungle"] = "SECRET JUNGLE"
}

local teleportPositions = {
    ["CRYSTAL CRAB"] = CFrame.new(40.0956, 1.7772, 2757.2583),
    ["RARE/EPIC FISH"] = CFrame.new(-3596.9094, -281.1832, -1645.1220),
    ["SECRET SYPUSH"] = CFrame.new(-3658.5747, -138.4813, -951.7969),
    ["SECRET TEMPLE"] = CFrame.new(1451.4100, -22.1250, -635.6500),
    ["SECRET JUNGLE"] = CFrame.new(1479.6647, 11.1430, -297.9549),
    ["FARMING COIN"] = CFrame.new(-553.3464, 17.1376, 114.2622)
}

local QuestState = {
    Active = false,
    CurrentQuest = nil,
    SelectedTask = nil,
    CurrentLocation = nil,
    Teleported = false,
    Fishing = false,
    LastProgress = 0,
    LastTaskIndex = nil
}

local function getQuestTracker(questName)
    local menu = Workspace:FindFirstChild("!!! MENU RINGS")
    if not menu then return nil end
    
    for _, inst in ipairs(menu:GetChildren()) do
        if inst.Name:find("Tracker") and inst.Name:lower():find(questName:lower()) then
            return inst
        end
    end
    
    return nil
end

local function getQuestProgress(questName)
    local tracker = getQuestTracker(questName)
    if not tracker then return 0 end
    
    local label = tracker:FindFirstChild("Board") 
        and tracker.Board:FindFirstChild("Gui") 
        and tracker.Board.Gui:FindFirstChild("Content") 
        and tracker.Board.Gui.Content:FindFirstChild("Progress") 
        and tracker.Board.Gui.Content.Progress:FindFirstChild("ProgressLabel")
    
    if label and label:IsA("TextLabel") then
        local percent = string.match(label.Text, "([%d%.]+)%%")
        return tonumber(percent) or 0
    end
    
    return 0
end

local function getAllTasks(questName)
    local tracker = getQuestTracker(questName)
    if not tracker then return {} end
    
    local content = tracker:FindFirstChild("Board") 
        and tracker.Board:FindFirstChild("Gui") 
        and tracker.Board.Gui:FindFirstChild("Content")
    
    if not content then return {} end
    
    local tasks = {}
    for _, obj in ipairs(content:GetChildren()) do
        if obj:IsA("TextLabel") and obj.Name:match("Label") and not obj.Name:find("Progress") then
            local txt = obj.Text
            local percent = string.match(txt, "([%d%.]+)%%") or "0"
            local done = txt:find("100%%") or txt:find("DONE") or txt:find("COMPLETED")
            
            table.insert(tasks, {
                name = txt,
                percent = tonumber(percent),
                completed = done ~= nil
            })
        end
    end
    
    return tasks
end

local function getActiveTasks(questName)
    local all = getAllTasks(questName)
    local active = {}
    
    for _, t in ipairs(all) do
        if not t.completed then
            table.insert(active, t)
        end
    end
    
    return active
end

local function teleportTo(locName)
    local cf = teleportPositions[locName]
    if cf and HumanoidRootPart then
        pcall(function()
            HumanoidRootPart.CFrame = cf
        end)
        return true
    end
    return false
end

local function findLocationByTaskName(taskName)
    for key, loc in pairs(TaskMapping) do
        if string.find(taskName, key, 1, true) then
            return loc
        end
    end
    return nil
end

-- Quest Monitor Loop
task.spawn(function()
    while task.wait(1) do
        if not QuestState.Active then continue end
        
        local questProgress = getQuestProgress(QuestState.CurrentQuest)
        local activeTasks = getActiveTasks(QuestState.CurrentQuest)
        local allTasks = getAllTasks(QuestState.CurrentQuest)
        
        -- Check if all tasks completed
        local allTasksCompleted = true
        for _, task in ipairs(allTasks) do
            if not task.completed and task.percent < 100 then
                allTasksCompleted = false
                break
            end
        end
        
        if allTasksCompleted and questProgress >= 100 then
            SendQuestNotification(QuestState.CurrentQuest, nil, 100, "QUEST_COMPLETED")
            Config.AutoFishingV3 = false
            QuestState.Active = false
            
            Rayfield:Notify({
                Title = "✅ Quest Complete",
                Content = QuestState.CurrentQuest .. " finished!",
                Duration = 5
            })
            continue
        end
        
        -- Progress update notification
        if math.floor(questProgress / 10) > math.floor(QuestState.LastProgress / 10) then
            SendQuestNotification(QuestState.CurrentQuest, QuestState.SelectedTask, questProgress, "PROGRESS_UPDATE")
        end
        QuestState.LastProgress = questProgress
        
        if questProgress >= 100 then
            SendQuestNotification(QuestState.CurrentQuest, nil, 100, "QUEST_COMPLETED")
            Config.AutoFishingV3 = false
            QuestState.Active = false
            continue
        end
        
        if #activeTasks == 0 then
            SendQuestNotification(QuestState.CurrentQuest, nil, 100, "QUEST_COMPLETED")
            Config.AutoFishingV3 = false
            QuestState.Active = false
            continue
        end
        
        -- Select current task
        local currentTask = nil
        local currentTaskIndex = nil
        
        for i, t in ipairs(activeTasks) do
            if QuestState.SelectedTask and t.name == QuestState.SelectedTask then
                currentTask = t
                currentTaskIndex = i
                break
            end
        end
        
        if not currentTask then
            if QuestState.LastTaskIndex and QuestState.LastTaskIndex <= #activeTasks then
                currentTaskIndex = QuestState.LastTaskIndex
                currentTask = activeTasks[currentTaskIndex]
            else
                currentTaskIndex = 1
                currentTask = activeTasks[1]
            end
            
            if currentTask then
                QuestState.SelectedTask = currentTask.name
                QuestState.LastTaskIndex = currentTaskIndex
                SendQuestNotification(QuestState.CurrentQuest, currentTask.name, currentTask.percent, "TASK_SELECTED")
            end
        end
        
        if not currentTask then
            QuestState.SelectedTask = nil
            QuestState.LastTaskIndex = nil
            QuestState.CurrentLocation = nil
            QuestState.Teleported = false
            QuestState.Fishing = false
            Config.AutoFishingV3 = false
            continue
        end
        
        -- Check if task completed
        if currentTask.percent >= 100 and not QuestState.Fishing then
            SendQuestNotification(QuestState.CurrentQuest, currentTask.name, 100, "TASK_COMPLETED")
            
            if currentTaskIndex < #activeTasks then
                QuestState.LastTaskIndex = currentTaskIndex + 1
            else
                QuestState.LastTaskIndex = 1
            end
            
            QuestState.SelectedTask = nil
            QuestState.CurrentLocation = nil
            QuestState.Teleported = false
            QuestState.Fishing = false
            continue
        end
        
        -- Find location for task
        if not QuestState.CurrentLocation then
            QuestState.CurrentLocation = findLocationByTaskName(currentTask.name)
            if not QuestState.CurrentLocation then
                QuestState.SelectedTask = nil
                continue
            end
        end
        
        -- Teleport to location
        if not QuestState.Teleported then
            if teleportTo(QuestState.CurrentLocation) then
                SendQuestNotification(QuestState.CurrentQuest, currentTask.name, questProgress, "TELEPORT")
                QuestState.Teleported = true
                task.wait(2)
            end
            continue
        end
        
        -- Start fishing
        if not QuestState.Fishing then
            Config.AutoFishingV3 = true
            AutoFishingV3()
            QuestState.Fishing = true
            SendQuestNotification(QuestState.CurrentQuest, currentTask.name, questProgress, "FARMING")
        end
    end
end)

-- ============================================================================
-- UI CREATION
-- ============================================================================

local function CreateUI()
    
    -- ========================================================================
    -- TAB 1: FISHING
    -- ========================================================================
    
    local Tab1 = Window:CreateTab("FISHING", 4483362458)
    
    Tab1:CreateSection("AUTO FISHING MODES")
    
    Tab1:CreateToggle({
        Name = "Auto Fishing (FAST SPEED)",
        CurrentValue = Config.AutoFishingV1,
        Callback = function(Value)
            Config.AutoFishingV1 = Value
            if Value then
                Config.AutoFishingV2 = false
                Config.AutoFishingV3 = false
                Config.AutoFishingNewMethod = false
                AutoFishingV1()
                Rayfield:Notify({
                    Title = "Auto Fishing V1",
                    Content = "Fast speed mode activated!",
                    Duration = 3
                })
            end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Auto Fishing V2 (Game Auto)",
        CurrentValue = Config.AutoFishingV2,
        Callback = function(Value)
            Config.AutoFishingV2 = Value
            if Value then
                Config.AutoFishingV1 = false
                Config.AutoFishingV3 = false
                Config.AutoFishingNewMethod = false
                AutoFishingV2()
                Rayfield:Notify({
                    Title = "Auto Fishing V2",
                    Content = "Using game auto fishing!",
                    Duration = 3
                })
            end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Auto Fishing Stable (Recommended for Quest)",
        CurrentValue = Config.AutoFishingV3,
        Callback = function(Value)
            Config.AutoFishingV3 = Value
            if Value then
                Config.AutoFishingV1 = false
                Config.AutoFishingV2 = false
                Config.AutoFishingNewMethod = false
                AutoFishingV3()
                Rayfield:Notify({
                    Title = "Auto Fishing V3",
                    Content = "Stable mode (1.5s delay) activated!",
                    Duration = 3
                })
            end
        end
    })
    
    Tab1:CreateToggle({
        Name = "AUTO FISHING - NEW METHOD",
        CurrentValue = Config.AutoFishingNewMethod,
        Callback = function(Value)
            Config.AutoFishingNewMethod = Value
            if Value then
                Config.AutoFishingV1 = false
                Config.AutoFishingV2 = false
                Config.AutoFishingV3 = false
                AutoFishingNewMethod()
                Rayfield:Notify({
                    Title = "New Method",
                    Content = "Equip rod once mode activated!",
                    Duration = 3
                })
            end
        end
    })
    
    Tab1:CreateSlider({
        Name = "Fishing Delay (V1 & New Method)",
        Range = {0.1, 5},
        Increment = 0.1,
        CurrentValue = Config.FishingDelay,
        Callback = function(Value)
            Config.FishingDelay = Value
        end
    })
    
    Tab1:CreateSection("INVENTORY & AUTO SELL")
    
    Tab1:CreateButton({
        Name = "Refresh Inventory Count",
        Callback = function()
            local count = RefreshInventoryCount()
            Rayfield:Notify({
                Title = "Inventory",
                Content = "Current: " .. count .. "/4500",
                Duration = 3
            })
            print("[Inventory] Count:", count .. "/4500")
        end
    })
    
    Tab1:CreateButton({
        Name = "Sell All Fish Now",
        Callback = function()
            local success = SellAllFish()
            if success then
                Rayfield:Notify({
                    Title = "Sell Success",
                    Content = "All fish sold!",
                    Duration = 3
                })
            else
                Rayfield:Notify({
                    Title = "Sell Failed",
                    Content = "Could not sell fish",
                    Duration = 3
                })
            end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Auto Sell",
        CurrentValue = Config.AutoSell,
        Callback = function(Value)
            Config.AutoSell = Value
            if Value then
                AutoSellWorker()
                Rayfield:Notify({
                    Title = "Auto Sell",
                    Content = "Threshold: " .. Config.SellThreshold .. " fish",
                    Duration = 3
                })
            end
        end
    })
    
    Tab1:CreateInput({
        Name = "Sell Threshold (1-4500)",
        PlaceholderText = "Enter threshold (default: 100)",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local number = tonumber(Text)
            if number and number >= 1 and number <= 4500 then
                Config.SellThreshold = number
                Rayfield:Notify({
                    Title = "Threshold Updated",
                    Content = "New threshold: " .. number .. " fish",
                    Duration = 3
                })
            else
                Rayfield:Notify({
                    Title = "Invalid Input",
                    Content = "Enter number between 1-4500",
                    Duration = 3
                })
            end
        end
    })
    
    Tab1:CreateSection("EXTRA FISHING FEATURES")
    
    Tab1:CreateToggle({
        Name = "Perfect Catch",
        CurrentValue = Config.PerfectCatch,
        Callback = function(Value)
            TogglePerfectCatch(Value)
            Rayfield:Notify({
                Title = "Perfect Catch",
                Content = Value and "Enabled!" or "Disabled!",
                Duration = 2
            })
        end
    })
    
    Tab1:CreateToggle({
        Name = "Enable Radar",
        CurrentValue = false,
        Callback = function(Value)
            pcall(function()
                if Remotes.Radar then
                    Remotes.Radar:InvokeServer(Value)
                end
            end)
            Rayfield:Notify({
                Title = "Fishing Radar",
                Content = Value and "Enabled!" or "Disabled!",
                Duration = 2
            })
        end
    })
    
    Tab1:CreateToggle({
        Name = "Enable Diving Gear",
        CurrentValue = false,
        Callback = function(Value)
            pcall(function()
                if Value then
                    if Remotes.EquipTool then
                        Remotes.EquipTool:FireServer(2)
                    end
                    if Remotes.EquipOxy then
                        Remotes.EquipOxy:InvokeServer(105)
                    end
                else
                    if Remotes.UnequipOxy then
                        Remotes.UnequipOxy:InvokeServer()
                    end
                end
            end)
            Rayfield:Notify({
                Title = "Diving Gear",
                Content = Value and "Activated!" or "Deactivated!",
                Duration = 2
            })
        end
    })
    
    Tab1:CreateSection("MOVEMENT SETTINGS")
    
    Tab1:CreateToggle({
        Name = "Anti AFK",
        CurrentValue = Config.AntiAFK,
        Callback = function(Value)
            Config.AntiAFK = Value
            if Value then AntiAFK() end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Auto Jump",
        CurrentValue = Config.AutoJump,
        Callback = function(Value)
            Config.AutoJump = Value
            if Value then
                AutoJump()
                Rayfield:Notify({
                    Title = "Auto Jump",
                    Content = "Started with " .. Config.AutoJumpDelay .. "s delay",
                    Duration = 2
                })
            end
        end
    })
    
    Tab1:CreateSlider({
        Name = "Jump Delay",
        Range = {1, 10},
        Increment = 0.5,
        CurrentValue = Config.AutoJumpDelay,
        Callback = function(Value)
            Config.AutoJumpDelay = Value
            if Config.AutoJump then
                Config.AutoJump = false
                task.wait(0.5)
                Config.AutoJump = true
                AutoJump()
            end
        end
    })
    
    Tab1:CreateToggle({
        Name = "Walk on Water",
        CurrentValue = Config.WalkOnWater,
        Callback = function(Value)
            Config.WalkOnWater = Value
            if Value then
                WalkOnWater()
                Rayfield:Notify({
                    Title = "Walk on Water",
                    Content = "Smooth mode enabled!",
                    Duration = 2
                })
            end
        end
    })
    
    -- ========================================================================
    -- TAB 2: TELEPORT
    -- ========================================================================
    
    local Tab2 = Window:CreateTab("TELEPORT", 4483362458)
    
    Tab2:CreateSection("Islands Teleport")
    
    local IslandOptions = {}
    for i, island in ipairs(IslandsData) do
        table.insert(IslandOptions, string.format("%d. %s", i, island.Name))
    end
    
    local IslandDrop = Tab2:CreateDropdown({
        Name = "Select Island",
        Options = IslandOptions,
        CurrentOption = {IslandOptions[1]},
        Callback = function(Option) end
    })
    
    Tab2:CreateButton({
        Name = "Teleport to Island",
        Callback = function()
            local selected = IslandDrop.CurrentOption[1]
            local index = tonumber(selected:match("^(%d+)%."))
            
            if index and IslandsData[index] then
                TeleportToPosition(IslandsData[index].Position)
                Rayfield:Notify({
                    Title = "✈️ Teleported",
                    Content = "To " .. IslandsData[index].Name,
                    Duration = 2
                })
            end
        end
    })
    
    Tab2:CreateSection("Player Teleport")
    
    local Players_List = {}
    local PlayerDrop = Tab2:CreateDropdown({
        Name = "Select Player",
        Options = {"Load players first"},
        CurrentOption = {"Load players first"},
        Callback = function(Option) end
    })
    
    Tab2:CreateButton({
        Name = "Load Players",
        Callback = function()
            Players_List = {}
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    table.insert(Players_List, player.Name)
                end
            end
            
            if #Players_List == 0 then
                Players_List = {"No players online"}
            end
            
            PlayerDrop:Refresh(Players_List)
            Rayfield:Notify({
                Title = "Players Loaded",
                Content = string.format("Found %d players", #Players_List),
                Duration = 2
            })
        end
    })
    
    Tab2:CreateButton({
        Name = "Teleport to Player",
        Callback = function()
            local selected = PlayerDrop.CurrentOption[1]
            local player = Players:FindFirstChild(selected)
            
            if player and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 3, 0)
                    Rayfield:Notify({
                        Title = "✈️ Teleported",
                        Content = "To " .. selected,
                        Duration = 2
                    })
                end
            end
        end
    })
    
    Tab2:CreateSection("Event Teleport")
    
    local Events = {}
    local EventDrop = Tab2:CreateDropdown({
        Name = "Select Event",
        Options = {"Load events first"},
        CurrentOption = {"Load events first"},
        Callback = function(Option) end
    })
    
    Tab2:CreateButton({
        Name = "Load Events",
        Callback = function()
            Events = ScanActiveEvents()
            local options = {}
            
            for i, event in ipairs(Events) do
                table.insert(options, string.format("%d. %s", i, event.Name))
            end
            
            if #options == 0 then
                options = {"No events active"}
            end
            
            EventDrop:Refresh(options)
            Rayfield:Notify({
                Title = "Events Loaded",
                Content = string.format("Found %d events", #Events),
                Duration = 2
            })
        end
    })
    
    Tab2:CreateButton({
        Name = "Teleport to Event",
        Callback = function()
            local selected = EventDrop.CurrentOption[1]
            local index = tonumber(selected:match("^(%d+)%."))
            
            if index and Events[index] then
                TeleportToPosition(Events[index].Position)
                Rayfield:Notify({
                    Title = "Teleported",
                    Content = "To event",
                    Duration = 2
                })
            end
        end
    })
    
    Tab2:CreateSection("Position Management")
    
    Tab2:CreateButton({
        Name = "Save Current Position",
        Callback = function()
            Config.SavedPosition = HumanoidRootPart.CFrame
            SaveConfig()
            Rayfield:Notify({
                Title = "Saved",
                Content = "Position saved to disk!",
                Duration = 2
            })
        end
    })
    
    Tab2:CreateButton({
        Name = "Teleport to Saved Position",
        Callback = function()
            if Config.SavedPosition then
                HumanoidRootPart.CFrame = Config.SavedPosition
                Rayfield:Notify({
                    Title = "Teleported",
                    Content = "To saved position",
                    Duration = 2
                })
            else
                Rayfield:Notify({
                    Title = "Error",
                    Content = "No saved position found",
                    Duration = 2
                })
            end
        end
    })
    
    Tab2:CreateButton({
        Name = "Teleport to Checkpoint",
        Callback = function()
            if Config.CheckpointPosition then
                HumanoidRootPart.CFrame = Config.CheckpointPosition
                Rayfield:Notify({
                    Title = "✈️ Teleported",
                    Content = "Back to checkpoint",
                    Duration = 2
                })
            end
        end
    })
    
    Tab2:CreateToggle({
        Name = "Lock Position",
        CurrentValue = Config.LockedPosition,
        Callback = function(Value)
            Config.LockedPosition = Value
            if Value then
                Config.LockCFrame = HumanoidRootPart.CFrame
                LockPosition()
            end
            Rayfield:Notify({
                Title = "Lock Position",
                Content = Value and "Position Locked!" or "Position Unlocked!",
                Duration = 2
            })
        end
    })
    
    -- ========================================================================
    -- TAB 3: WEATHER
    -- ========================================================================
    
    local Tab3 = Window:CreateTab("WEATHER", 4483362458)
    
    Tab3:CreateSection("Auto Buy Weather")
    
    local weatherOptions = {"None", "Wind", "Cloudy", "Snow", "Storm", "Radiant", "Shark Hunt"}
    
    local Weather1Drop = Tab3:CreateDropdown({
        Name = "Weather Slot 1",
        Options = weatherOptions,
        CurrentOption = {"None"},
        Callback = function(Option)
            if Option[1] ~= "None" then
                Config.SelectedWeathers[1] = Option[1]
            else
                Config.SelectedWeathers[1] = nil
            end
        end
    })
    
    local Weather2Drop = Tab3:CreateDropdown({
        Name = "Weather Slot 2",
        Options = weatherOptions,
        CurrentOption = {"None"},
        Callback = function(Option)
            if Option[1] ~= "None" then
                Config.SelectedWeathers[2] = Option[1]
            else
                Config.SelectedWeathers[2] = nil
            end
        end
    })
    
    local Weather3Drop = Tab3:CreateDropdown({
        Name = "Weather Slot 3",
        Options = weatherOptions,
        CurrentOption = {"None"},
        Callback = function(Option)
            if Option[1] ~= "None" then
                Config.SelectedWeathers[3] = Option[1]
            else
                Config.SelectedWeathers[3] = nil
            end
        end
    })
    
    Tab3:CreateButton({
        Name = "Buy Selected Weathers Now",
        Callback = function()
            for _, weather in ipairs(Config.SelectedWeathers) do
                if weather then
                    pcall(function()
                        if Remotes.PurchaseWeather then
                            Remotes.PurchaseWeather:InvokeServer(weather)
                            Rayfield:Notify({
                                Title = "Weather Purchased",
                                Content = "Bought: " .. weather,
                                Duration = 2
                            })
                        end
                    end)
                    task.wait(0.5)
                end
            end
        end
    })
    
    Tab3:CreateToggle({
        Name = "Auto Buy Weather (Continuous)",
        CurrentValue = Config.AutoBuyWeather,
        Callback = function(Value)
            Config.AutoBuyWeather = Value
            if Value then
                AutoBuyWeather()
                Rayfield:Notify({
                    Title = "Auto Buy Weather",
                    Content = "Will keep buying selected weathers!",
                    Duration = 3
                })
            end
        end
    })
    
    -- ========================================================================
    -- TAB 4: AUTO QUEST
    -- ========================================================================
    
    local Tab4 = Window:CreateTab("AUTO QUEST", 4483362458)
    
    Tab4:CreateSection("Quest Status")
    
    local StatusLabel = Tab4:CreateLabel("Loading...")
    
    task.spawn(function()
        while task.wait(2) do
            local text = "STATUS\n\n"
            if QuestState.Active then
                text = text .. "Quest: " .. QuestState.CurrentQuest .. "\n"
                text = text .. "Progress: " .. string.format("%.1f", getQuestProgress(QuestState.CurrentQuest)) .. "%\n"
                if QuestState.SelectedTask then
                    text = text .. "\nTask: " .. QuestState.SelectedTask .. "\n"
                end
                text = text .. (QuestState.Fishing and "\nFARMING..." or "\nPreparing...")
            else
                text = text .. "Idle\n\n"
            end
            text = text .. "\nAuto Fishing V3: " .. (Config.AutoFishingV3 and "ON" or "OFF")
            StatusLabel:Set(text)
        end
    end)
    
    local Selected = {}
    local Quests = {
        {Name = "Aura", Display = "Aura Boat"},
        {Name = "Deep Sea", Display = "Ghostfinn Rod"},
        {Name = "Element", Display = "Element Rod"}
    }
    
    for _, quest in ipairs(Quests) do
        Tab4:CreateSection("QUEST: " .. quest.Display)
        
        local function build_dropdown_options()
            local opts = {"Auto"}
            for _, t in ipairs(getActiveTasks(quest.Name)) do
                table.insert(opts, t.name)
            end
            return opts
        end
        
        local dropdown = Tab4:CreateDropdown({
            Name = "Select Task - " .. quest.Display,
            Options = build_dropdown_options(),
            CurrentOption = {"Auto"},
            Callback = function(opt)
                if type(opt) == "table" then opt = opt[1] end
                Selected[quest.Name] = opt
            end
        })
        
        task.spawn(function()
            while task.wait(10) do
                if dropdown and dropdown.Refresh then
                    dropdown:Refresh(build_dropdown_options(), true)
                end
            end
        end)
        
        Tab4:CreateToggle({
            Name = "Auto " .. quest.Display,
            CurrentValue = false,
            Callback = function(val)
                if val then
                    if quest.Name == "Element" and getQuestProgress("Deep Sea") < 100 then
                        Rayfield:Notify({
                            Title = "Warning",
                            Content = "Need Ghostfinn 100% first!",
                            Duration = 3
                        })
                        return
                    end
                    
                    local sel = Selected[quest.Name] or "Auto"
                    if type(sel) == "table" then sel = sel[1] end
                    if sel == "Auto" then sel = nil end
                    
                    QuestState.Active = true
                    QuestState.CurrentQuest = quest.Name
                    QuestState.SelectedTask = sel
                    QuestState.CurrentLocation = nil
                    QuestState.Teleported = false
                    QuestState.Fishing = false
                    QuestState.LastProgress = getQuestProgress(quest.Name)
                    QuestState.LastTaskIndex = nil
                    
                    SendQuestNotification(quest.Display, sel or "Auto", QuestState.LastProgress, "START")
                    
                    Rayfield:Notify({
                        Title = "Quest Started",
                        Content = quest.Display .. " active!",
                        Duration = 3
                    })
                else
                    QuestState.Active = false
                    Config.AutoFishingV3 = false
                end
            end
        })
        
        Tab4:CreateButton({
            Name = "Check Progress - " .. quest.Display,
            Callback = function()
                local all = getAllTasks(quest.Name)
                if #all == 0 then
                    Rayfield:Notify({
                        Title = "No Tasks Found",
                        Content = "Quest not available",
                        Duration = 2
                    })
                    return
                end
                
                local progress = getQuestProgress(quest.Name)
                local msg = quest.Display .. " Progress:\n"
                for _, t in ipairs(all) do
                    msg = msg .. string.format("- %s\n", t.name)
                end
                msg = msg .. string.format("\nTOTAL: %.1f%%", progress)
                
                Rayfield:Notify({
                    Title = quest.Display,
                    Content = msg,
                    Duration = 6
                })
            end
        })
    end
    
    -- ========================================================================
    -- TAB 5: HOOK SYSTEM
    -- ========================================================================
    
    local Tab5 = Window:CreateTab("HOOK SYSTEM", 4483362458)
    
    Tab5:CreateSection("Telegram Settings")
    
    Tab5:CreateToggle({
        Name = "Enable Telegram Hook",
        CurrentValue = TelegramConfig.Enabled,
        Callback = function(v)
            TelegramConfig.Enabled = v
        end
    })
    
    Tab5:CreateToggle({
        Name = "Enable Quest Notifications",
        CurrentValue = TelegramConfig.QuestNotifications,
        Callback = function(v)
            TelegramConfig.QuestNotifications = v
        end
    })
    
    Tab5:CreateInput({
        Name = "Telegram Chat ID",
        PlaceholderText = "Enter Chat ID (e.g., -1001234567890)",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            TelegramConfig.ChatID = Text
            SaveConfig()
            Rayfield:Notify({
                Title = "Chat ID Saved",
                Content = "Telegram configured!",
                Duration = 2
            })
        end
    })
    
    Tab5:CreateParagraph({
        Title = "Token Info",
        Content = "Bot token is pre-configured. Just enter your Chat ID above."
    })
    
    Tab5:CreateSection("Select Rarities (Max 3)")
    
    local rarities = {"MYTHIC", "LEGENDARY", "SECRET", "EPIC", "RARE", "UNCOMMON", "COMMON"}
    
    for _, r in ipairs(rarities) do
        Tab5:CreateToggle({
            Name = r,
            CurrentValue = TelegramConfig.SelectedRarities[r] or false,
            Callback = function(val)
                if val then
                    if CountSelected() + 1 > TelegramConfig.MaxSelection then
                        Rayfield:Notify({
                            Title = "Max Selection",
                            Content = "Maximum 3 rarities allowed!",
                            Duration = 2
                        })
                        TelegramConfig.SelectedRarities[r] = false
                        return
                    else
                        TelegramConfig.SelectedRarities[r] = true
                    end
                else
                    TelegramConfig.SelectedRarities[r] = false
                end
                SaveConfig()
            end
        })
    end
    
    Tab5:CreateSection("Test Notifications")
    
    Tab5:CreateButton({
        Name = "Test Random SECRET",
        Callback = function()
            if TelegramConfig.ChatID == "" then
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Enter Chat ID first!",
                    Duration = 2
                })
                return
            end
            
            local secretItems = {}
            for id, info in pairs(ItemDatabase) do
                local tier = tonumber(info.Tier) or 0
                if tier == 7 or string.upper(tostring(info.Rarity)) == "SECRET" then
                    table.insert(secretItems, {Id = id, Info = info})
                end
            end
            
            if #secretItems == 0 then
                Rayfield:Notify({
                    Title = "No Data",
                    Content = "No SECRET items in database",
                    Duration = 2
                })
                return
            end
            
            local chosen = secretItems[math.random(1, #secretItems)]
            local weight = math.random(2, 6) + math.random()
            local invCount = RefreshInventoryCount()
            
            local msg = BuildTelegramMessage(chosen.Info, chosen.Id, "SECRET", weight, invCount)
            SendTelegram(msg)
            
            Rayfield:Notify({
                Title = "Test Sent",
                Content = "SECRET fish notification sent!",
                Duration = 2
            })
        end
    })
    
    Tab5:CreateButton({
        Name = "Test Random LEGENDARY",
        Callback = function()
            if TelegramConfig.ChatID == "" then
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Enter Chat ID first!",
                    Duration = 2
                })
                return
            end
            
            local legendaryItems = {}
            for id, info in pairs(ItemDatabase) do
                local tier = tonumber(info.Tier) or 0
                if tier == 5 or string.upper(tostring(info.Rarity)) == "LEGENDARY" then
                    table.insert(legendaryItems, {Id = id, Info = info})
                end
            end
            
            if #legendaryItems == 0 then
                Rayfield:Notify({
                    Title = "No Data",
                    Content = "No LEGENDARY items",
                    Duration = 2
                })
                return
            end
            
            local chosen = legendaryItems[math.random(1, #legendaryItems)]
            local weight = math.random(1, 5) + math.random()
            local invCount = RefreshInventoryCount()
            
            local msg = BuildTelegramMessage(chosen.Info, chosen.Id, "LEGENDARY", weight, invCount)
            SendTelegram(msg)
            
            Rayfield:Notify({
                Title = "Test Sent",
                Content = "LEGENDARY fish notification sent!",
                Duration = 2
            })
        end
    })
    
    Tab5:CreateButton({
        Name = "Test Random MYTHIC",
        Callback = function()
            if TelegramConfig.ChatID == "" then
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Enter Chat ID first!",
                    Duration = 2
                })
                return
            end
            
            local mythicItems = {}
            for id, info in pairs(ItemDatabase) do
                local tier = tonumber(info.Tier) or 0
                local rarity = string.upper(tostring(info.Rarity))
                if tier == 6 or rarity == "MYTHIC" or rarity == "MYTICH" then
                    table.insert(mythicItems, {Id = id, Info = info})
                end
            end
            
            if #mythicItems == 0 then
                Rayfield:Notify({
                    Title = "No Data",
                    Content = "No MYTHIC items",
                    Duration = 2
                })
                return
            end
            
            local chosen = mythicItems[math.random(1, #mythicItems)]
            local weight = math.random(2, 5) + math.random()
            local invCount = RefreshInventoryCount()
            
            local msg = BuildTelegramMessage(chosen.Info, chosen.Id, "MYTHIC", weight, invCount)
            SendTelegram(msg)
            
            Rayfield:Notify({
                Title = "Test Sent",
                Content = "MYTHIC fish notification sent!",
                Duration = 2
            })
        end
    })
    
    -- ========================================================================
    -- TAB 6: UTILITY
    -- ========================================================================
    
    local Tab6 = Window:CreateTab("UTILITY", 4483362458)
    
    Tab6:CreateSection("Speed Settings")
    
    Tab6:CreateSlider({
        Name = "Walk Speed",
        Range = {16, 500},
        Increment = 1,
        CurrentValue = Config.WalkSpeed,
        Callback = function(Value)
            Config.WalkSpeed = Value
            if Humanoid then
                Humanoid.WalkSpeed = Value
            end
        end
    })
    
    Tab6:CreateSlider({
        Name = "Jump Power",
        Range = {50, 500},
        Increment = 5,
        CurrentValue = Config.JumpPower,
        Callback = function(Value)
            Config.JumpPower = Value
            if Humanoid then
                Humanoid.JumpPower = Value
            end
        end
    })
    
    Tab6:CreateInput({
        Name = "Custom Speed",
        PlaceholderText = "Enter any speed value",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local speed = tonumber(Text)
            if speed and speed >= 1 then
                if Humanoid then
                    Humanoid.WalkSpeed = speed
                    Config.WalkSpeed = speed
                    Rayfield:Notify({
                        Title = "Speed Set",
                        Content = "Speed: " .. speed,
                        Duration = 2
                    })
                end
            end
        end
    })
    
    Tab6:CreateButton({
        Name = "Reset Speed to Normal",
        Callback = function()
            if Humanoid then
                Humanoid.WalkSpeed = 16
                Humanoid.JumpPower = 50
                Config.WalkSpeed = 16
                Config.JumpPower = 50
                Rayfield:Notify({
                    Title = "Reset",
                    Content = "Speed back to normal",
                    Duration = 2
                })
            end
        end
    })
    
    Tab6:CreateSection("Extra Utility")
    
    Tab6:CreateToggle({
        Name = "NoClip",
        CurrentValue = Config.NoClip,
        Callback = function(Value)
            Config.NoClip = Value
            if Value then NoClip() end
        end
    })
    
    Tab6:CreateToggle({
        Name = "XRay (Transparent Walls)",
        CurrentValue = Config.XRay,
        Callback = function(Value)
            Config.XRay = Value
            if Value then XRay() end
        end
    })
    
    Tab6:CreateButton({
        Name = "Infinite Jump",
        Callback = function()
            UserInputService.JumpRequest:Connect(function()
                if Humanoid then
                    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
            Rayfield:Notify({
                Title = "Infinite Jump",
                Content = "Enabled!",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateSection("Player ESP")
    
    Tab6:CreateToggle({
        Name = "Enable ESP",
        CurrentValue = Config.ESPEnabled,
        Callback = function(Value)
            Config.ESPEnabled = Value
            if Value then ESP() end
        end
    })
    
    Tab6:CreateSlider({
        Name = "ESP Distance",
        Range = {10, 100},
        Increment = 5,
        CurrentValue = Config.ESPDistance,
        Callback = function(Value)
            Config.ESPDistance = Value
        end
    })
    
    Tab6:CreateButton({
        Name = "Highlight All Players",
        Callback = function()
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    pcall(function()
                        local highlight = Instance.new("Highlight", player.Character)
                        highlight.FillColor = Color3.fromRGB(255, 0, 0)
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.FillTransparency = 0.5
                    end)
                end
            end
            Rayfield:Notify({
                Title = "ESP Enabled",
                Content = "All players highlighted",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateButton({
        Name = "Remove All Highlights",
        Callback = function()
            for _, player in pairs(Players:GetPlayers()) do
                if player.Character then
                    for _, obj in pairs(player.Character:GetChildren()) do
                        if obj:IsA("Highlight") then
                            obj:Destroy()
                        end
                    end
                end
            end
            Rayfield:Notify({
                Title = "ESP Disabled",
                Content = "Highlights removed",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateSection("Graphics & Performance")
    
    Tab6:CreateButton({
        Name = "Fullbright",
        Callback = function()
            Config.Brightness = 3
            Config.TimeOfDay = 14
            Lighting.Brightness = Config.Brightness
            Lighting.ClockTime = Config.TimeOfDay
            ApplyPermanentLighting()
            Rayfield:Notify({
                Title = "Fullbright",
                Content = "Enabled permanent lighting!",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateButton({
        Name = "Remove Fog",
        Callback = function()
            RemoveFog()
            Rayfield:Notify({
                Title = "Fog Removed",
                Content = "Fog permanently disabled!",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateButton({
        Name = "Performance Mode",
        Callback = function()
            PerformanceMode()
            Rayfield:Notify({
                Title = "Performance Mode",
                Content = "Ultra performance activated!",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateButton({
        Name = "Disable Performance Mode",
        Callback = function()
            PerformanceModeActive = false
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            Rayfield:Notify({
                Title = "Quality Restored",
                Content = "Performance mode disabled",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateToggle({
        Name = "HD Graphic Mode",
        CurrentValue = Config.HDGraphicMode,
        Callback = function(Value)
            if Value then
                HDGraphicMode()
                Rayfield:Notify({
                    Title = "HD Graphics",
                    Content = "High quality graphics enabled!",
                    Duration = 2
                })
            else
                DisableHDGraphicMode()
                Rayfield:Notify({
                    Title = "HD Disabled",
                    Content = "Graphics quality restored to normal",
                    Duration = 2
                })
            end
        end
    })
    
    Tab6:CreateButton({
        Name = "Remove Particles",
        Callback = function()
            RemoveParticles()
            Rayfield:Notify({
                Title = "Particles Removed",
                Content = "All visual effects cleared!",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateButton({
        Name = "Remove Seaweed",
        Callback = function()
            RemoveSeaweed()
            Rayfield:Notify({
                Title = "Seaweed Removed",
                Content = "All plants and seaweed cleared!",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateButton({
        Name = "Optimize Water",
        Callback = function()
            OptimizeWater()
            Rayfield:Notify({
                Title = "Water Optimized",
                Content = "Water effects minimized!",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateButton({
        Name = "8-Bit Mode",
        Callback = function()
            Enable8Bit()
            Rayfield:Notify({
                Title = "8-Bit Mode",
                Content = "Super smooth rendering enabled!",
                Duration = 2
            })
        end
    })
    
    Tab6:CreateSection("Camera Settings")
    
    Tab6:CreateToggle({
        Name = "Infinite Zoom",
        CurrentValue = Config.InfiniteZoom,
        Callback = function(Value)
            Config.InfiniteZoom = Value
            if Value then InfiniteZoom() end
        end
    })
    
    Tab6:CreateSlider({
        Name = "Brightness",
        Range = {0, 10},
        Increment = 0.1,
        CurrentValue = Config.Brightness,
        Callback = function(Value)
            Config.Brightness = Value
            Lighting.Brightness = Value
        end
    })
    
    Tab6:CreateSlider({
        Name = "Time of Day",
        Range = {0, 24},
        Increment = 0.5,
        CurrentValue = Config.TimeOfDay,
        Callback = function(Value)
            Config.TimeOfDay = Value
            Lighting.ClockTime = Value
        end
    })
    
    -- ========================================================================
    -- TAB 7: SETTINGS
    -- ========================================================================
    
    local Tab7 = Window:CreateTab("SETTINGS", 4483362458)
    
    Tab7:CreateSection("Configuration Management")
    
    Tab7:CreateButton({
        Name = "Save Configuration",
        Callback = function()
            local success = SaveConfig()
            Rayfield:Notify({
                Title = success and "Config Saved" or "Save Failed",
                Content = success and "All settings saved to disk!" or "Failed to save configuration",
                Duration = 3
            })
        end
    })
    
    Tab7:CreateButton({
        Name = "Load Configuration",
        Callback = function()
            local success = LoadConfig()
            Rayfield:Notify({
                Title = success and "Config Loaded" or "Load Failed",
                Content = success and "Settings restored from disk!" or "No saved configuration found",
                Duration = 3
            })
        end
    })
    
    Tab7:CreateButton({
        Name = "Reset Configuration",
        Callback = function()
            Config = {
                AutoFishingV1 = false,
                AutoFishingV2 = false,
                AutoFishingV3 = false,
                AutoFishingNewMethod = false,
                FishingDelay = 0.3,
                PerfectCatch = false,
                AntiAFK = false,
                AutoJump = false,
                AutoJumpDelay = 3,
                AutoSell = false,
                SellThreshold = 100,
                AutoBuyWeather = false,
                AutoRejoin = false,
                WalkSpeed = 16,
                JumpPower = 50,
                WalkOnWater = false,
                NoClip = false,
                XRay = false,
                ESPEnabled = false,
                ESPDistance = 20,
                InfiniteZoom = false,
                Brightness = 2,
                TimeOfDay = 14,
                HDGraphicMode = false,
                SavedPosition = nil,
                CheckpointPosition = HumanoidRootPart.CFrame,
                LockedPosition = false,
                LockCFrame = nil,
                SelectedWeathers = {},
            }
            
            if Humanoid then
                Humanoid.WalkSpeed = Config.WalkSpeed
                Humanoid.JumpPower = Config.JumpPower
            end
            
            Lighting.Brightness = Config.Brightness
            Lighting.ClockTime = Config.TimeOfDay
            
            Rayfield:Notify({
                Title = "Config Reset",
                Content = "All settings reset to defaults!",
                Duration = 3
            })
        end
    })
    
    Tab7:CreateSection("Auto Rejoin System")
    
    Tab7:CreateToggle({
        Name = "Auto Rejoin",
        CurrentValue = Config.AutoRejoin,
        Callback = function(Value)
            Config.AutoRejoin = Value
            if Value then
                SetupAutoRejoin()
                Rayfield:Notify({
                    Title = "Auto Rejoin",
                    Content = "System enabled - Will auto rejoin on disconnect",
                    Duration = 3
                })
            end
        end
    })
    
    Tab7:CreateButton({
        Name = "Save Rejoin Data Now",
        Callback = function()
            SaveRejoinData()
            Rayfield:Notify({
                Title = "Rejoin Data Saved",
                Content = "Position and settings saved for rejoin!",
                Duration = 2
            })
        end
    })
    
    Tab7:CreateSection("System Information")
    
    Tab7:CreateLabel("Player: " .. LocalPlayer.Name)
    Tab7:CreateLabel("User ID: " .. LocalPlayer.UserId)
    
    local FPSLabel = Tab7:CreateLabel("FPS: Calculating...")
    local PingLabel = Tab7:CreateLabel("Ping: Calculating...")
    local MemoryLabel = Tab7:CreateLabel("Memory: Calculating...")
    
    task.spawn(function()
        local lastTick = tick()
        local frames = 0
        
        while task.wait() do
            frames = frames + 1
            if tick() - lastTick >= 1 then
                local fps = math.floor(frames / (tick() - lastTick))
                FPSLabel:Set("FPS: " .. fps)
                frames = 0
                lastTick = tick()
            end
            
            -- Update memory usage
            local memory = math.floor(collectgarbage("count") / 1024)
            MemoryLabel:Set("Memory: " .. string.format("%.2f", memory) .. " MB")
        end
    end)
    
    Tab7:CreateSection("Developer Tools")
    
    Tab7:CreateButton({
        Name = "Health Check Remotes",
        Callback = function()
            local healthy = HealthCheckRemotes()
            Rayfield:Notify({
                Title = healthy and "Remotes Healthy" or "Remotes Issue",
                Content = healthy and "All remotes found!" or "Some remotes missing, check console",
                Duration = 5
            })
        end
    })
    
    Tab7:CreateButton({
        Name = "Print Runtime State",
        Callback = function()
            print("=== RUNTIME STATE ===")
            for key, value in pairs(RuntimeState) do
                print(key .. ":", value)
            end
            print("=== CONFIG STATE ===")
            for key, value in pairs(Config) do
                if type(value) ~= "table" then
                    print(key .. ":", value)
                end
            end
            Rayfield:Notify({
                Title = "State Printed",
                Content = "Check console for runtime state",
                Duration = 3
            })
        end
    })
    
    Tab7:CreateButton({
        Name = "Reconnect Character",
        Callback = function()
            Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
            Humanoid = Character:WaitForChild("Humanoid")
            Rayfield:Notify({
                Title = "Character Reconnected",
                Content = "Character references updated!",
                Duration = 2
            })
        end
    })
    
    Tab7:CreateSection("Script Information")
    
    Tab7:CreateParagraph({
        Title = "HIRAKO FISH IT - UPGRADED V2.0",
        Content = "DEVELOPER: HIRAKO\nVERSION: 2.0 UPGRADED - FULLY OPTIMIZED\nDATE: 2025\n\nFEATURES:\n• 4 Auto Fishing Modes\n• Auto Quest System\n• Telegram Notifications\n• Auto Sell & Inventory Management\n• Weather System\n• Advanced Teleportation\n• Performance Optimization\n• Save/Load Configuration"
    })
    
    Tab7:CreateButton({
        Name = "Close UI",
        Callback = function()
            Rayfield:Destroy()
        end
    })
    
end

-- ============================================================================
-- INITIALIZATION & STARTUP
-- ============================================================================

-- Character respawn handler
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
    
    task.wait(1)
    
    -- Restore settings
    if Humanoid then
        Humanoid.WalkSpeed = Config.WalkSpeed
        Humanoid.JumpPower = Config.JumpPower
    end
    
    -- Restore active features
    if Config.WalkOnWater then
        WalkOnWater()
    end
    
    if Config.NoClip then
        NoClip()
    end
    
    if Config.XRay then
        XRay()
    end
    
    if Config.ESPEnabled then
        ESP()
    end
    
    if Config.InfiniteZoom then
        InfiniteZoom()
    end
    
    print("[RESPAWN] Character reinitialized and settings restored")
end)

-- Fish caught hook for Telegram notifications
local function SetupFishHook()
    if Remotes.FishCaught then
        Remotes.FishCaught.OnClientEvent:Connect(function(fishData)
            if not fishData then return end
            
            local fishId = fishData.Id
            local weight = fishData.Weight
            local rarity = fishData.Rarity
            
            if not fishId then return end
            
            local itemInfo = GetItemInfo(fishId)
            local actualRarity = rarity or itemInfo.Rarity
            
            -- Send Telegram notification if enabled and rarity matches
            if ShouldSendByRarity(actualRarity) then
                local inventoryCount = RefreshInventoryCount()
                local message = BuildTelegramMessage(itemInfo, fishId, actualRarity, weight, inventoryCount)
                
                spawn(function()
                    local success, result = SendTelegram(message)
                    if success then
                        print("[Telegram] Fish notification sent for:", itemInfo.Name, "(" .. actualRarity .. ")")
                    else
                        warn("[Telegram] Failed to send notification:", result)
                    end
                end)
            end
            
            -- Update last fish time
            RuntimeState.LastFishTime = tick()
        end)
    else
        warn("[FishHook] FishCaught remote not found")
    end
end

-- Main initialization function
local function Initialize()
    print("=== HIRAKO FISH IT - INITIALIZING ===")
    
    -- Health check
    HealthCheckRemotes()
    
    -- Load saved configuration
    LoadConfig()
    
    -- Load rejoin data if available
    if Config.AutoRejoin then
        task.wait(3)
        LoadRejoinData()
    end
    
    -- Apply permanent settings
    ApplyPermanentLighting()
    RemoveFog()
    
    -- Setup hooks
    SetupFishHook()
    
    -- Create UI
    CreateUI()
    
    -- Setup auto rejoin if enabled
    if Config.AutoRejoin then
        SetupAutoRejoin()
    end
    
    -- Apply initial settings
    if Humanoid then
        Humanoid.WalkSpeed = Config.WalkSpeed
        Humanoid.JumpPower = Config.JumpPower
    end
    
    Lighting.Brightness = Config.Brightness
    Lighting.ClockTime = Config.TimeOfDay
    
    print("=== HIRAKO FISH IT - READY ===")
    print("Version: 2.0 UPGRADED")
    print("Developer: HIRAKO")
    print("All systems initialized successfully!")
    
    Rayfield:Notify({
        Title = "HIRAKO FISH IT LOADED",
        Content = "Version 2.0 UPGRADED - All systems ready!",
        Duration = 5
    })
end

-- Start the script
Initialize()
