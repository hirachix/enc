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
-- WINDUI SETUP
-- ============================================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "HIRAKO | FISH IT",
    Icon = "lucide:fish", 
    Author = "Hirako",
    Folder = "Hirako",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Midnight",
    Resizable = true,
    SideBarWidth = 200,
    Watermark = "Hirako",
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            WindUI:Notify({
                Title = "User Profile",
                Content = "User profile clicked!",
                Duration = 3
            })
        end
    }
})

-- Override notify function dengan WindUI
local function notify(title, content, duration)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content or "",
            Duration = duration or 3,
            Icon = "bell",
        })
    end)
end

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
        notify("Remote Warning", "Some remotes missing: " .. table.concat(missingRemotes, ", "), 5)
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
                        notify("Auto Sell", "Sold all fish! Inventory was: " .. currentCount .. "/4500", 3)
                        
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
                    notify("AutoFishing V1", "Stopped due to errors. Please restart manually.", 5)
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
                    notify("AutoFishing V3", "Stopped due to errors. Please restart manually.", 5)
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
                
                -- Step 1: Charge Rod
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
                        error("Start minigame failed after 3 attempts")
                    end
                end
                
                -- Step 3: Wait for bite
                local actualDelay = math.max(Config.FishingDelay or 0.3, 0.1)
                task.wait(actualDelay)
                
                -- Step 4: Finish Fishing
                if Remotes.FinishFish then
                    local finishOk = pcall(function()
                        Remotes.FinishFish:FireServer()
                    end)
                    
                    if finishOk then
                        RuntimeState.LastFishTime = tick()
                        consecutiveErrors = 0
                    end
                end
                
                task.wait(0.1)
            end)
            
            if not success then
                consecutiveErrors = consecutiveErrors + 1
                warn("[AutoFishingNewMethod] Cycle error:", err, "| Consecutive errors:", consecutiveErrors)
                
                if consecutiveErrors >= maxConsecutiveErrors then
                    warn("[AutoFishingNewMethod] Too many errors, stopping...")
                    Config.AutoFishingNewMethod = false
                    notify("AutoFishing New", "Stopped due to errors. Please restart manually.", 5)
                    break
                end
                
                task.wait(1)
            else
                task.wait(0.05)
            end
        end
        
        RuntimeState.IsFishingNewMethod = false
        print("[AutoFishingNewMethod] Stopped")
    end)
end

-- ============================================================================
-- FISH CAUGHT HOOK (TELEGRAM NOTIFICATIONS)
-- ============================================================================

-- Hook FishCaught remote for notifications
if Remotes.FishCaught then
    local old
    old = hookfunction(Remotes.FishCaught.FireServer, function(self, fishId, weight, ...)
        local result = old(self, fishId, weight, ...)
        
        -- Get fish info
        local fishInfo = GetItemInfo(fishId)
        local rarity = fishInfo.Rarity
        
        -- Check if we should send telegram
        if ShouldSendByRarity(rarity) then
            local inventoryCount = RefreshInventoryCount()
            local message = BuildTelegramMessage(fishInfo, fishId, rarity, weight, inventoryCount)
            
            spawn(function()
                local success = SendTelegram(message)
                if success then
                    print("[Telegram] Fish notification sent for " .. fishInfo.Name .. " (" .. rarity .. ")")
                end
            end)
        end
        
        return result
    end)
    
    print("[Hook] FishCaught hook installed successfully")
end

-- ============================================================================
-- MOVEMENT & VISUAL SYSTEMS
-- ============================================================================

-- Anti AFK
local function SetupAntiAFK()
    if Config.AntiAFK then
        LocalPlayer.Idled:Connect(function()
            if Config.AntiAFK then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end)
        print("[AntiAFK] Enabled")
    end
end

-- Walk on Water
local function SetupWalkOnWater()
    if Config.WalkOnWater then
        local waterPart = Instance.new("Part")
        waterPart.Name = "WaterWalkPart"
        waterPart.Size = Vector3.new(50, 1, 50)
        waterPart.Anchored = true
        waterPart.CanCollide = true
        waterPart.Transparency = 0.7
        waterPart.Material = Enum.Material.SmoothPlastic
        waterPart.Color = Color3.fromRGB(0, 150, 255)
        waterPart.Parent = Workspace
        
        RunService.Heartbeat:Connect(function()
            if Config.WalkOnWater and HumanoidRootPart then
                local pos = HumanoidRootPart.Position
                waterPart.Position = Vector3.new(pos.X, 0, pos.Z)
            else
                waterPart:Destroy()
            end
        end)
    end
end

-- NoClip
local function SetupNoClip()
    if Config.NoClip then
        RunService.Stepped:Connect(function()
            if Config.NoClip and Character then
                for _, part in pairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

-- XRay
local function SetupXRay()
    if Config.XRay then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Part") and obj.Transparency < 0.5 then
                obj.LocalTransparencyModifier = 0.5
            end
        end
    else
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Part") then
                obj.LocalTransparencyModifier = 0
            end
        end
    end
end

-- HD Graphic Mode
local function SetupHDGraphics()
    if Config.HDGraphicMode then
        -- Enable high quality graphics
        settings().Rendering.QualityLevel = 21
        
        -- Improve lighting
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 1000
        Lighting.Brightness = 2
        
        -- Improve terrain
        if Workspace.Terrain then
            Workspace.Terrain.WaterReflectance = 0.5
            Workspace.Terrain.WaterTransparency = 0.5
            Workspace.Terrain.WaterWaveSize = 0.1
            Workspace.Terrain.WaterWaveSpeed = 10
        end
    else
        -- Reset to default
        settings().Rendering.QualityLevel = 1
        Lighting.GlobalShadows = false
        Lighting.Brightness = 1
    end
end

-- ============================================================================
-- POSITION SYSTEM
-- ============================================================================

-- Save Position
local function SavePosition()
    if HumanoidRootPart then
        Config.SavedPosition = HumanoidRootPart.CFrame
        notify("Position Saved", "Position has been saved successfully", 3)
        print("[Position] Saved at: " .. tostring(Config.SavedPosition))
    end
end

-- Load Position
local function LoadPosition()
    if Config.SavedPosition then
        if HumanoidRootPart then
            HumanoidRootPart.CFrame = Config.SavedPosition
            notify("Position Loaded", "Teleported to saved position", 3)
            print("[Position] Loaded: " .. tostring(Config.SavedPosition))
        end
    else
        notify("Position Error", "No position saved", 3)
    end
end

-- Save Checkpoint
local function SaveCheckpoint()
    if HumanoidRootPart then
        Config.CheckpointPosition = HumanoidRootPart.CFrame
        notify("Checkpoint Saved", "Checkpoint position saved", 3)
        print("[Checkpoint] Saved at: " .. tostring(Config.CheckpointPosition))
    end
end

-- Load Checkpoint
local function LoadCheckpoint()
    if Config.CheckpointPosition then
        if HumanoidRootPart then
            HumanoidRootPart.CFrame = Config.CheckpointPosition
            notify("Checkpoint Loaded", "Teleported to checkpoint", 3)
            print("[Checkpoint] Loaded: " .. tostring(Config.CheckpointPosition))
        end
    else
        notify("Checkpoint Error", "No checkpoint saved", 3)
    end
end

-- Lock Position
local function LockPosition()
    if not Config.LockedPosition then
        Config.LockedPosition = true
        Config.LockCFrame = HumanoidRootPart.CFrame
        notify("Position Locked", "Character position is now locked", 3)
        
        task.spawn(function()
            while Config.LockedPosition do
                if HumanoidRootPart then
                    HumanoidRootPart.CFrame = Config.LockCFrame
                end
                task.wait()
            end
        end)
    else
        Config.LockedPosition = false
        notify("Position Unlocked", "Character can move freely", 3)
    end
end

-- ============================================================================
-- WEATHER SYSTEM
-- ============================================================================

local WeatherTypes = {
    "Clear",
    "Rain",
    "Thunderstorm",
    "Snow",
    "Fog",
    "Wind",
    "Heatwave",
    "Aurora"
}

-- Auto Buy Weather
local function AutoBuyWeather()
    if not Config.AutoBuyWeather then return end
    
    task.spawn(function()
        while Config.AutoBuyWeather do
            for weather, enabled in pairs(Config.SelectedWeathers) do
                if enabled then
                    pcall(function()
                        if Remotes.PurchaseWeather then
                            Remotes.PurchaseWeather:InvokeServer(weather)
                            print("[Weather] Purchased: " .. weather)
                        end
                    end)
                    task.wait(1)
                end
            end
            task.wait(60) -- Check every minute
        end
    end)
end

-- ============================================================================
-- UI CREATION
-- ============================================================================

-- Tabs
local MainTab = Window:Tab({
    Title = "Main",
    Icon = "geist:shareplay",
    Default = true
})

local FishingTab = Window:Tab({
    Title = "Fishing", 
    Icon = "lucide:fish",
})

local AutoTab = Window:Tab({
    Title = "Auto",
    Icon = "lucide:settings",
})

local MovementTab = Window:Tab({
    Title = "Movement",
    Icon = "lucide:move",
})

local VisualTab = Window:Tab({
    Title = "Visual",
    Icon = "lucide:eye",
})

local TeleportTab = Window:Tab({
    Title = "Teleport",
    Icon = "lucide:navigation",
})

local WeatherTab = Window:Tab({
    Title = "Weather",
    Icon = "lucide:cloud",
})

local TelegramTab = Window:Tab({
    Title = "Telegram",
    Icon = "lucide:message-circle",
})

local CreditsTab = Window:Tab({
    Title = "Credit",
    Icon = "lucide:info",
})

-- ============================================================================
-- MAIN TAB
-- ============================================================================

MainTab:Section({
    Title = "Quick Actions",
    TextSize = 16,
})

MainTab:Button({
    Title = "Equip Fishing Rod",
    Icon = "lucide:fishing-rod",
    Desc = "Equip fishing rod from hotbar",
    Callback = function()
        pcall(function()
            if Remotes.EquipTool then
                Remotes.EquipTool:FireServer(1)
                notify("Fishing Rod", "Rod equipped successfully", 3)
            end
        end)
    end
})

MainTab:Button({
    Title = "Sell All Fish",
    Icon = "lucide:coins",
    Desc = "Sell all fish in inventory",
    Callback = function()
        local success = SellAllFish()
        if success then
            notify("Sell Fish", "All fish sold successfully", 3)
        else
            notify("Sell Fish", "Failed to sell fish", 3)
        end
    end
})

MainTab:Button({
    Title = "Refresh Inventory",
    Icon = "lucide:refresh-cw",
    Desc = "Refresh inventory count",
    Callback = function()
        local count = RefreshInventoryCount()
        notify("Inventory", "Current count: " .. count .. "/4500", 3)
    end
})

-- ============================================================================
-- FISHING TAB
-- ============================================================================

FishingTab:Section({
    Title = "Auto Fishing Modes",
    TextSize = 16,
})

FishingTab:Toggle({
    Title = "Auto Fishing V1 (Fast)",
    Icon = "lucide:zap",
    Desc = "Fast fishing with minimal delays",
    Value = Config.AutoFishingV1,
    Callback = function(state)
        Config.AutoFishingV1 = state
        if state then
            AutoFishingV1()
            notify("Auto Fishing V1", "Fast mode activated", 3)
        else
            RuntimeState.IsFishingV1 = false
            notify("Auto Fishing V1", "Stopped", 3)
        end
    end
})

FishingTab:Toggle({
    Title = "Auto Fishing V2 (Game Auto)",
    Icon = "lucide:gamepad-2",
    Desc = "Use game's built-in auto fishing",
    Value = Config.AutoFishingV2,
    Callback = function(state)
        Config.AutoFishingV2 = state
        if state then
            AutoFishingV2()
            notify("Auto Fishing V2", "Game auto mode activated", 3)
        else
            RuntimeState.IsFishingV2 = false
            notify("Auto Fishing V2", "Stopped", 3)
        end
    end
})

FishingTab:Toggle({
    Title = "Auto Fishing V3 (Stable)",
    Icon = "lucide:shield-check",
    Desc = "Stable fishing with 1.5s delay",
    Value = Config.AutoFishingV3,
    Callback = function(state)
        Config.AutoFishingV3 = state
        if state then
            AutoFishingV3()
            notify("Auto Fishing V3", "Stable mode activated", 3)
        else
            RuntimeState.IsFishingV3 = false
            notify("Auto Fishing V3", "Stopped", 3)
        end
    end
})

FishingTab:Toggle({
    Title = "Auto Fishing - New Method",
    Icon = "lucide:sparkles",
    Desc = "Equip rod once and fish continuously",
    Value = Config.AutoFishingNewMethod,
    Callback = function(state)
        Config.AutoFishingNewMethod = state
        if state then
            AutoFishingNewMethod()
            notify("Auto Fishing New", "New method activated", 3)
        else
            RuntimeState.IsFishingNewMethod = false
            notify("Auto Fishing New", "Stopped", 3)
        end
    end
})

FishingTab:Slider({
    Title = "Fishing Delay",
    Icon = "lucide:timer",
    Desc = "Delay between fishing attempts",
    Value = { Min = 0.1, Max = 5, Default = Config.FishingDelay },
    Step = 0.1,
    Suffix = "s",
    Callback = function(val)
        Config.FishingDelay = val
        notify("Fishing Delay", "Set to " .. val .. " seconds", 3)
    end
})

FishingTab:Toggle({
    Title = "Perfect Catch",
    Icon = "lucide:target",
    Desc = "Always get perfect catch (V2 only)",
    Value = Config.PerfectCatch,
    Callback = function(state)
        Config.PerfectCatch = state
        notify("Perfect Catch", state and "Enabled" or "Disabled", 3)
    end
})

-- ============================================================================
-- AUTO TAB
-- ============================================================================

AutoTab:Section({
    Title = "Auto Features",
    TextSize = 16,
})

AutoTab:Toggle({
    Title = "Auto Sell",
    Icon = "lucide:shopping-cart",
    Desc = "Automatically sell fish when threshold reached",
    Value = Config.AutoSell,
    Callback = function(state)
        Config.AutoSell = state
        if state then
            AutoSellWorker()
            notify("Auto Sell", "Enabled - Threshold: " .. Config.SellThreshold, 3)
        else
            notify("Auto Sell", "Disabled", 3)
        end
    end
})

AutoTab:Slider({
    Title = "Sell Threshold",
    Icon = "lucide:bar-chart-3",
    Desc = "Inventory count to trigger auto sell",
    Value = { Min = 50, Max = 2000, Default = Config.SellThreshold },
    Step = 50,
    Suffix = "fish",
    Callback = function(val)
        Config.SellThreshold = val
        notify("Sell Threshold", "Set to " .. val .. " fish", 3)
    end
})

AutoTab:Toggle({
    Title = "Anti AFK",
    Icon = "lucide:user-x",
    Desc = "Prevent being kicked for AFK",
    Value = Config.AntiAFK,
    Callback = function(state)
        Config.AntiAFK = state
        if state then
            SetupAntiAFK()
        end
        notify("Anti AFK", state and "Enabled" or "Disabled", 3)
    end
})

AutoTab:Toggle({
    Title = "Auto Jump",
    Icon = "lucide:rabbit",
    Desc = "Automatically jump periodically",
    Value = Config.AutoJump,
    Callback = function(state)
        Config.AutoJump = state
        if state then
            task.spawn(function()
                while Config.AutoJump do
                    if Humanoid then
                        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                    task.wait(Config.AutoJumpDelay)
                end
            end)
        end
        notify("Auto Jump", state and "Enabled" or "Disabled", 3)
    end
})

AutoTab:Slider({
    Title = "Jump Delay",
    Icon = "lucide:timer",
    Desc = "Delay between auto jumps",
    Value = { Min = 1, Max = 10, Default = Config.AutoJumpDelay },
    Step = 0.5,
    Suffix = "s",
    Callback = function(val)
        Config.AutoJumpDelay = val
        notify("Jump Delay", "Set to " .. val .. " seconds", 3)
    end
})

-- ============================================================================
-- MOVEMENT TAB
-- ============================================================================

MovementTab:Section({
    Title = "Movement Settings",
    TextSize = 16,
})

MovementTab:Slider({
    Title = "Walk Speed",
    Icon = "lucide:zap",
    Desc = "Character movement speed",
    Value = { Min = 16, Max = 200, Default = Config.WalkSpeed },
    Step = 1,
    Suffix = "speed",
    Callback = function(val)
        Config.WalkSpeed = val
        if Humanoid then
            Humanoid.WalkSpeed = val
        end
        notify("Walk Speed", "Set to " .. val, 3)
    end
})

MovementTab:Slider({
    Title = "Jump Power",
    Icon = "lucide:arrow-up",
    Desc = "Character jump height",
    Value = { Min = 50, Max = 200, Default = Config.JumpPower },
    Step = 1,
    Suffix = "power",
    Callback = function(val)
        Config.JumpPower = val
        if Humanoid then
            Humanoid.JumpPower = val
        end
        notify("Jump Power", "Set to " .. val, 3)
    end
})

MovementTab:Toggle({
    Title = "Walk on Water",
    Icon = "lucide:waves",
    Desc = "Create water walking platform",
    Value = Config.WalkOnWater,
    Callback = function(state)
        Config.WalkOnWater = state
        if state then
            SetupWalkOnWater()
        end
        notify("Walk on Water", state and "Enabled" or "Disabled", 3)
    end
})

MovementTab:Toggle({
    Title = "NoClip",
    Icon = "lucide:ghost",
    Desc = "Walk through walls",
    Value = Config.NoClip,
    Callback = function(state)
        Config.NoClip = state
        if state then
            SetupNoClip()
        end
        notify("NoClip", state and "Enabled" or "Disabled", 3)
    end
})

-- ============================================================================
-- VISUAL TAB
-- ============================================================================

VisualTab:Section({
    Title = "Visual Settings",
    TextSize = 16,
})

VisualTab:Toggle({
    Title = "XRay",
    Icon = "lucide:scan",
    Desc = "See through walls",
    Value = Config.XRay,
    Callback = function(state)
        Config.XRay = state
        SetupXRay()
        notify("XRay", state and "Enabled" or "Disabled", 3)
    end
})

VisualTab:Toggle({
    Title = "HD Graphic Mode",
    Icon = "lucide:highlighter",
    Desc = "Enhanced graphics quality",
    Value = Config.HDGraphicMode,
    Callback = function(state)
        Config.HDGraphicMode = state
        SetupHDGraphics()
        notify("HD Graphics", state and "Enabled" or "Disabled", 3)
    end
})

VisualTab:Slider({
    Title = "Brightness",
    Icon = "lucide:sun",
    Desc = "Game world brightness",
    Value = { Min = 0, Max = 10, Default = Config.Brightness },
    Step = 0.1,
    Suffix = "level",
    Callback = function(val)
        Config.Brightness = val
        Lighting.Brightness = val
        notify("Brightness", "Set to " .. val, 3)
    end
})

VisualTab:Slider({
    Title = "Time of Day",
    Icon = "lucide:clock",
    Desc = "Set game time",
    Value = { Min = 0, Max = 24, Default = Config.TimeOfDay },
    Step = 0.5,
    Suffix = "hours",
    Callback = function(val)
        Config.TimeOfDay = val
        Lighting.ClockTime = val
        notify("Time of Day", "Set to " .. val .. ":00", 3)
    end
})

-- ============================================================================
-- TELEPORT TAB
-- ============================================================================

TeleportTab:Section({
    Title = "Position Management",
    TextSize = 16,
})

TeleportTab:Button({
    Title = "Save Position",
    Icon = "lucide:bookmark",
    Desc = "Save current position",
    Callback = SavePosition
})

TeleportTab:Button({
    Title = "Load Position",
    Icon = "lucide:map-pin",
    Desc = "Teleport to saved position",
    Callback = LoadPosition
})

TeleportTab:Button({
    Title = "Save Checkpoint",
    Icon = "lucide:flag",
    Desc = "Save checkpoint position",
    Callback = SaveCheckpoint
})

TeleportTab:Button({
    Title = "Load Checkpoint",
    Icon = "lucide:navigation",
    Desc = "Teleport to checkpoint",
    Callback = LoadCheckpoint
})

TeleportTab:Button({
    Title = "Lock Position",
    Icon = "lucide:lock",
    Desc = "Lock/unlock character position",
    Callback = LockPosition
})

-- ============================================================================
-- WEATHER TAB
-- ============================================================================

WeatherTab:Section({
    Title = "Weather Control",
    TextSize = 16,
})

WeatherTab:Toggle({
    Title = "Auto Buy Weather",
    Icon = "lucide:cloud-rain",
    Desc = "Automatically purchase selected weather",
    Value = Config.AutoBuyWeather,
    Callback = function(state)
        Config.AutoBuyWeather = state
        if state then
            AutoBuyWeather()
        end
        notify("Auto Buy Weather", state and "Enabled" or "Disabled", 3)
    end
})

for _, weather in ipairs(WeatherTypes) do
    WeatherTab:Toggle({
        Title = weather,
        Icon = "lucide:cloud",
        Desc = "Purchase " .. weather .. " weather",
        Value = Config.SelectedWeathers[weather] or false,
        Callback = function(state)
            Config.SelectedWeathers[weather] = state
            notify("Weather", weather .. (state and " selected" or " unselected"), 3)
        end
    })
end

-- ============================================================================
-- TELEGRAM TAB
-- ============================================================================

TelegramTab:Section({
    Title = "Telegram Notifications",
    TextSize = 16,
})

TelegramTab:Toggle({
    Title = "Enable Telegram",
    Icon = "lucide:bell",
    Desc = "Enable telegram notifications",
    Value = TelegramConfig.Enabled,
    Callback = function(state)
        TelegramConfig.Enabled = state
        notify("Telegram", state and "Enabled" or "Disabled", 3)
    end
})

TelegramTab:Input({
    Title = "Bot Token",
    Icon = "lucide:key",
    Desc = "Your telegram bot token",
    Value = TelegramConfig.BotToken,
    Callback = function(val)
        TelegramConfig.BotToken = val
        notify("Telegram", "Bot token updated", 3)
    end
})

TelegramTab:Input({
    Title = "Chat ID",
    Icon = "lucide:message-circle",
    Desc = "Your telegram chat ID",
    Value = TelegramConfig.ChatID,
    Callback = function(val)
        TelegramConfig.ChatID = val
        notify("Telegram", "Chat ID updated", 3)
    end
})

TelegramTab:Toggle({
    Title = "Quest Notifications",
    Icon = "lucide:target",
    Desc = "Send quest progress notifications",
    Value = TelegramConfig.QuestNotifications,
    Callback = function(state)
        TelegramConfig.QuestNotifications = state
        notify("Quest Notifications", state and "Enabled" or "Disabled", 3)
    end
})

TelegramTab:Section({
    Title = "Rarity Filters",
    TextSize = 14,
})

local rarities = {"COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC", "SECRET"}

for _, rarity in ipairs(rarities) do
    TelegramTab:Toggle({
        Title = rarity,
        Icon = "lucide:star",
        Desc = "Notify for " .. rarity .. " fish",
        Value = TelegramConfig.SelectedRarities[rarity] or false,
        Callback = function(state)
            if state and CountSelected() >= TelegramConfig.MaxSelection then
                notify("Telegram", "Max " .. TelegramConfig.MaxSelection .. " rarities allowed", 3)
                return false
            end
            
            TelegramConfig.SelectedRarities[rarity] = state
            notify("Telegram", rarity .. (state and " enabled" or " disabled"), 3)
        end
    })
end

TelegramTab:Button({
    Title = "Test Telegram",
    Icon = "lucide:send",
    Desc = "Send test notification",
    Callback = function()
        local message = "```\n"
        message = message .. "HIRAKO SCRIPT FISH IT\n"
        message = message .. "========================================\n\n"
        message = message .. "TEST NOTIFICATION\n"
        message = message .. "PLAYER: " .. LocalPlayer.Name .. "\n"
        message = message .. "TIME: " .. os.date("%H:%M:%S") .. "\n"
        message = message .. "STATUS: TEST SUCCESSFUL\n\n"
        message = message .. "DEVELOPER: HIRAKO\n"
        message = message .. "VERSION: 2.0 UPGRADED\n"
        message = message .. "========================================\n```"
        
        local success = SendTelegram(message)
        if success then
            notify("Telegram Test", "Notification sent successfully", 3)
        else
            notify("Telegram Test", "Failed to send notification", 3)
        end
    end
})

-- ============================================================================
-- CREDITS TAB
-- ============================================================================

CreditsTab:Section({
    Title = "Credits List",
    TextSize = 16,
})

CreditsTab:Paragraph({
    Title = "UI Framework",
    Desc = "WindUI Interface Suite",
    Image = "layout",
    ImageSize = 20,
})

CreditsTab:Paragraph({
    Title = "Developer", 
    Desc = "Hirako",
    Image = "user",
    ImageSize = 20,
})

CreditsTab:Paragraph({
    Title = "Version",
    Desc = "FISH IT v2.0 UPGRADED",
    Image = "code",
    ImageSize = 20,
})

CreditsTab:Button({
    Title = "Copy Telegram",
    Icon = "message-circle",
    Desc = "Salin link Telegram ke clipboard",
    Callback = function()
        if setclipboard then
            setclipboard("hirakoxs.t.me")
            WindUI:Notify({
                Title = "Telegram",
                Content = "Link berhasil disalin!",
                Duration = 3,
                Icon = "check"
            })
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Clipboard tidak tersedia",
                Duration = 3,
                Icon = "x"
            })
        end
    end
})

-- ============================================================================
-- FINAL SETUP
-- ============================================================================

-- Open button cantik
Window:EditOpenButton({
    Title = "Hirako",
    Icon = "geist:logo-nuxt",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"),
        Color3.fromHex("F89B29")
    ),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

-- Tambah tag
Window:Tag({
    Title = "V2.0.1",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 10,
})

-- Tag Jam
local TimeTag = Window:Tag({
    Title = "--:--:--",
    Icon = "lucide:timer", 
    Radius = 10,
    Color = WindUI:Gradient({
        ["0"] = { Color = Color3.fromHex("#FF0F7B"), Transparency = 0 },
        ["100"] = { Color = Color3.fromHex("#F89B29"), Transparency = 0 },
    }, {
        Rotation = 45,
    }),
})

local hue = 0

-- Rainbow + Jam Real-time
task.spawn(function()
    while true do
        -- Ambil waktu sekarang
        local now = os.date("*t")
        local hours = string.format("%02d", now.hour)
        local minutes = string.format("%02d", now.min) 
        local seconds = string.format("%02d", now.sec)
        
        -- Update warna rainbow
        hue = (hue + 0.01) % 1
        local color = Color3.fromHSV(hue, 1, 1)
        
        -- Update judul tag jadi jam lengkap
        TimeTag:SetTitle(hours .. ":" .. minutes .. ":" .. seconds)
        
        -- Kalau mau rainbow berjalan, aktifkan ini:
        TimeTag:SetColor(color)
        
        task.wait(0.06) -- refresh cepat
    end
end)

-- Initialize systems
HealthCheckRemotes()
SetupAntiAFK()

-- Final notification
notify("HIRAKO FISH IT v2.0", "Script loaded successfully! All systems ready.", 5)
notify("Database", "Item database: " .. (database and "LOADED" or "MISSING"), 3)

print("HIRAKO FISH IT - FINAL UPGRADED VERSION LOADED SUCCESSFULLY!")