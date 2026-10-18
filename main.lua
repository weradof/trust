-- ==========================================================
-- SERVICES & VARIABLES
-- ==========================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ESP_Objects = {}
local ChamsStorage = {}
local Connections = {}

-- ==========================================================
-- UI OVERLAY (DELETE BUTTON)
-- ==========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ESP_Control_Panel"
ScreenGui.ResetOnSpawn = false

if gethui then
    ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then
    syn.protect_gui(ScreenGui)
    ScreenGui.Parent = CoreGui
else
    ScreenGui.Parent = CoreGui
end

local DeleteButton = Instance.new("TextButton")
DeleteButton.Size = UDim2.new(0, 140, 0, 38)
DeleteButton.Position = UDim2.new(0, 15, 0.4, 0)
DeleteButton.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
DeleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DeleteButton.Text = "Delete ESP Script"
DeleteButton.Font = Enum.Font.SourceSansBold
DeleteButton.TextSize = 15
DeleteButton.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = DeleteButton

-- ==========================================================
-- ENGINE CHAMS (BoxHandleAdornments)
-- ==========================================================
local function CreateEngineChams(character)
    if not character then return end
    ChamsStorage[character] = {}

    local function ApplyToPart(part)
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local Adornment = Instance.new("BoxHandleAdornment")
            Adornment.Name = "EngineCham"
            Adornment.Size = part.Size
            Adornment.Color3 = Color3.fromRGB(255, 0, 100)
            Adornment.Transparency = 0.4
            Adornment.AlwaysOnTop = true
            Adornment.ZIndex = 10
            Adornment.Adornee = part
            Adornment.Parent = part

            table.insert(ChamsStorage[character], Adornment)
        end
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        ApplyToPart(descendant)
    end

    local childAdded = character.DescendantAdded:Connect(ApplyToPart)
    table.insert(Connections, childAdded)
end

local function RemoveEngineChams(character)
    if ChamsStorage[character] then
        for _, adornment in ipairs(ChamsStorage[character]) do
            if adornment and adornment.Parent then
                adornment:Destroy()
            end
        end
        ChamsStorage[character] = nil
    end
end

-- ==========================================================
-- ESP CREATION
-- ==========================================================
local function CreateESP(player)
    if player == LocalPlayer then return end

    local Line = Drawing.new("Line")
    Line.Thickness = 1.5
    Line.Color = Color3.fromRGB(255, 255, 255)
    Line.Visible = false

    local Text = Drawing.new("Text")
    Text.Size = 15
    Text.Center = true
    Text.Outline = true
    Text.OutlineColor = Color3.fromRGB(0, 0, 0)
    Text.Color = Color3.fromRGB(255, 255, 255)
    Text.Visible = false

    ESP_Objects[player] = {Line = Line, Text = Text}

    if player.Character then
        CreateEngineChams(player.Character)
    end

    local charAddedConn = player.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        CreateEngineChams(newChar)
    end)

    table.insert(Connections, charAddedConn)
end

local function RemoveESP(player)
    if ESP_Objects[player] then
        ESP_Objects[player].Line:Remove()
        ESP_Objects[player].Text:Remove()
        ESP_Objects[player] = nil
    end

    if player.Character then
        RemoveEngineChams(player.Character)
    end
end

-- ==========================================================
-- RENDER LOOP (SCREEN RESOLUTION RATIO CORRECTION)
-- ==========================================================
local RenderConnection = RunService.RenderStepped:Connect(function()
    -- Get exact camera dimensions on client
    local viewportSize = Camera.ViewportSize
    local inset = GuiService:GetGuiInset()

    -- Bottom Center origin taking inset into account for drawing space
    local BottomScreenPos = Vector2.new(viewportSize.X / 2, viewportSize.Y - inset.Y)

    for player, drawings in pairs(ESP_Objects) do
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local head = character and character:FindFirstChild("Head")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if character and hrp and humanoid and humanoid.Health > 0 then
            -- World to Viewport Point returns Vector3(X, Y, Depth)
            local rootScreenPos, rootOnScreen = Camera:WorldToViewportPoint(hrp.Position)
            
            -- Anchor text directly to head in world space
            local headWorldPos = head and (head.Position + Vector3.new(0, 1.4, 0)) or (hrp.Position + Vector3.new(0, 3.2, 0))
            local headScreenPos, _ = Camera:WorldToViewportPoint(headWorldPos)

            if rootOnScreen and rootScreenPos.Z > 0 then
                -- Drawing API requires exact Screen coordinates (WorldToViewportPoint includes TopBar inset)
                local tracerTarget = Vector2.new(rootScreenPos.X, rootScreenPos.Y - inset.Y)
                local textTarget = Vector2.new(headScreenPos.X, headScreenPos.Y - inset.Y)

                -- Render Line to RootPart
                drawings.Line.From = BottomScreenPos
                drawings.Line.To = tracerTarget
                drawings.Line.Visible = true

                -- Render Text to Head
                local healthPct = math.floor((humanoid.Health / humanoid.MaxHealth) * 100)
                drawings.Text.Position = textTarget
                drawings.Text.Text = string.format("%s [%d%%]", player.Name, healthPct)

                -- Health color coding
                if healthPct > 50 then
                    drawings.Text.Color = Color3.fromRGB(0, 255, 120)
                elseif healthPct > 25 then
                    drawings.Text.Color = Color3.fromRGB(255, 200, 0)
                else
                    drawings.Text.Color = Color3.fromRGB(255, 50, 50)
                end

                drawings.Text.Visible = true
            else
                drawings.Line.Visible = false
                drawings.Text.Visible = false
            end
        else
            drawings.Line.Visible = false
            drawings.Text.Visible = false
        end
    end
end)

table.insert(Connections, RenderConnection)

-- Initialize active players
for _, player in ipairs(Players:GetPlayers()) do
    CreateESP(player)
end

local playerAddedConn = Players.PlayerAdded:Connect(CreateESP)
local playerRemovingConn = Players.PlayerRemoving:Connect(RemoveESP)
table.insert(Connections, playerAddedConn)
table.insert(Connections, playerRemovingConn)

-- ==========================================================
-- CLEANUP / DELETE SCRIPT
-- ==========================================================
local function DeleteScript()
    for _, conn in ipairs(Connections) do
        conn:Disconnect()
    end
    table.clear(Connections)

    for player, _ in pairs(ESP_Objects) do
        RemoveESP(player)
    end

    if ScreenGui then
        ScreenGui:Destroy()
    end
end

DeleteButton.MouseButton1Click:Connect(DeleteScript)
