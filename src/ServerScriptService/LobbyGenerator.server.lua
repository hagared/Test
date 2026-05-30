--[[
    LobbyGenerator.server.lua  (v5 — new TransportHeli)
    Помести в ServerScriptService.

    Скрипт НЕ трогает: Sky, Atmosphere, ClockTime, ColorShift, Fog.
    Небо/атмосферу настраивай сам в Lighting.
]]

local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")
local Players   = game:GetService("Players")

----------------------------------------------------------------
-- КОНФИГ
----------------------------------------------------------------
local CFG = {
    BASE_PLATE_SIZE = 1900,

    PLAY_RADIUS     = 150,
    WALL_HEIGHT     = 300,
    WALL_SEGMENTS   = 24,

    HELI_COUNT      = 5,
    HELI_RADIUS     = 108,

    OUTER_WALL_R    = 760,
    OUTER_WALL_SEGS = 36,

    DEBRIS_COUNT    = 160,
    REBAR_COUNT     = 25,

    SEED            = 4242,
}

local NO_HOST_COLOR = Color3.fromRGB(70, 255, 110)
local HOST_COLOR    = Color3.fromRGB(70, 140, 255)

math.randomseed(CFG.SEED)

local function rnd(min, max) return math.random() * (max - min) + min end
local function pick(t) return t[math.random(1, #t)] end
local function chance(p) return math.random() < p end


local function makePart(props, parent)
    local class = props.ClassName or "Part"
    local p = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "ClassName" then p[k] = v end
    end
    p.Anchored = true
    if p:IsA("BasePart") then
        if props.TopSurface == nil then p.TopSurface = Enum.SurfaceType.Smooth end
        if props.BottomSurface == nil then p.BottomSurface = Enum.SurfaceType.Smooth end
    end
    p.Parent = parent
    return p
end

----------------------------------------------------------------
-- ОЧИСТКА
----------------------------------------------------------------
do
    local prev = Workspace:FindFirstChild("ZombieLobby")
    if prev then prev:Destroy() end
    local oldHeli = Workspace:FindFirstChild("TransportHeli_Generated")
    if oldHeli then oldHeli:Destroy() end
end

local lobby = Instance.new("Model")
lobby.Name = "ZombieLobby"
lobby.Parent = Workspace

----------------------------------------------------------------
-- ОСВЕЩЕНИЕ (skybox/время/атмосферу НЕ трогаем)
----------------------------------------------------------------
do
    Lighting.Brightness           = 2.5
    Lighting.ExposureCompensation = 0.1
    Lighting.GlobalShadows        = true
    Lighting.ShadowSoftness       = 0.5

    for _, child in ipairs(Lighting:GetChildren()) do
        if child.Name:sub(1, 4) == "Apoc" then child:Destroy() end
    end

    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "ApocColorCorrection"
    cc.Brightness = 0.0
    cc.Contrast = 0.05
    cc.Saturation = 0.0
    cc.TintColor = Color3.fromRGB(255, 255, 255)
    cc.Parent = Lighting

    local bloom = Instance.new("BloomEffect")
    bloom.Name = "ApocBloom"
    bloom.Intensity = 0.4
    bloom.Size = 24
    bloom.Threshold = 0.95
    bloom.Parent = Lighting
end

----------------------------------------------------------------
-- ЗЕМЛЯ
----------------------------------------------------------------
makePart({
    Name = "GroundPlate",
    Size = Vector3.new(CFG.BASE_PLATE_SIZE, 4, CFG.BASE_PLATE_SIZE),
    CFrame = CFrame.new(0, -2, 0),
    Material = Enum.Material.Concrete,
    Color = Color3.fromRGB(55, 50, 48),
}, lobby)

makePart({
    Name = "PlayPad",
    Size = Vector3.new(CFG.PLAY_RADIUS * 2 + 10, 0.2, CFG.PLAY_RADIUS * 2 + 10),
    CFrame = CFrame.new(0, 0.1, 0),
    Material = Enum.Material.Slate,
    Color = Color3.fromRGB(50, 45, 43),
}, lobby)


----------------------------------------------------------------
-- НЕВИДИМАЯ СТЕНА (вокруг игровой зоны)
----------------------------------------------------------------
do
    local wallFolder = Instance.new("Folder")
    wallFolder.Name = "InvisibleWall"
    wallFolder.Parent = lobby

    local segs = CFG.WALL_SEGMENTS
    local R = CFG.PLAY_RADIUS
    local segLen = 2 * R * math.sin(math.pi / segs) * 1.05

    for i = 1, segs do
        local angle = (i - 0.5) / segs * math.pi * 2
        local x = math.cos(angle) * R
        local z = math.sin(angle) * R
        local p = makePart({
            Name = "WallSeg",
            Size = Vector3.new(segLen, CFG.WALL_HEIGHT, 1),
            CFrame = CFrame.new(x, CFG.WALL_HEIGHT * 0.5, z)
                * CFrame.Angles(0, -angle + math.pi * 0.5, 0),
            Transparency = 1,
            CanCollide = true,
            Material = Enum.Material.SmoothPlastic,
            Color = Color3.fromRGB(255, 0, 0),
        }, wallFolder)
        p.CastShadow = false
    end
end

----------------------------------------------------------------
-- МУСОР (только в игровой зоне)
----------------------------------------------------------------
do
    local folder = Instance.new("Folder")
    folder.Name = "Debris"; folder.Parent = lobby

    local mats = {
        Enum.Material.Concrete, Enum.Material.CorrodedMetal,
        Enum.Material.Slate, Enum.Material.Brick, Enum.Material.Concrete,
    }
    local cols = {
        Color3.fromRGB(80, 75, 70), Color3.fromRGB(95, 90, 85),
        Color3.fromRGB(110, 90, 70), Color3.fromRGB(60, 58, 55),
        Color3.fromRGB(75, 65, 55),
    }

    for _ = 1, CFG.DEBRIS_COUNT do
        local angle = math.random() * math.pi * 2
        local r = rnd(20, CFG.PLAY_RADIUS - 8)
        local x = math.cos(angle) * r
        local z = math.sin(angle) * r
        local sx, sy, sz = rnd(1.5, 7), rnd(0.6, 3), rnd(1.5, 7)
        makePart({
            Name = "Debris",
            Size = Vector3.new(sx, sy, sz),
            CFrame = CFrame.new(x, sy * 0.4 + 0.2, z) * CFrame.Angles(
                math.rad(rnd(-30, 30)), math.rad(rnd(0, 360)), math.rad(rnd(-30, 30))
            ),
            Material = pick(mats), Color = pick(cols),
        }, folder)
    end

    for _ = 1, CFG.REBAR_COUNT do
        local angle = math.random() * math.pi * 2
        local r = rnd(30, CFG.PLAY_RADIUS - 10)
        makePart({
            Shape = Enum.PartType.Cylinder,
            Name = "Rebar",
            Size = Vector3.new(rnd(3, 6), 0.3, 0.3),
            CFrame = CFrame.new(math.cos(angle) * r, 0.3, math.sin(angle) * r)
                * CFrame.Angles(math.rad(rnd(-20, 20)), math.rad(rnd(0, 360)), math.rad(rnd(70, 110))),
            Material = Enum.Material.CorrodedMetal,
            Color = Color3.fromRGB(115, 85, 55),
        }, folder)
    end
end


----------------------------------------------------------------
-- НЕБОСКРЁБ
----------------------------------------------------------------
local CONCRETE_COLS = {
    Color3.fromRGB(60, 55, 53),
    Color3.fromRGB(70, 64, 60),
    Color3.fromRGB(78, 72, 68),
    Color3.fromRGB(52, 50, 50),
    Color3.fromRGB(82, 72, 62),
}
local WINDOW_DARK = Color3.fromRGB(20, 22, 28)
local WINDOW_DIM  = Color3.fromRGB(60, 75, 100)
local WINDOW_FIRE = Color3.fromRGB(255, 130, 50)
local WINDOW_BLUE = Color3.fromRGB(80, 130, 200)

local FLOOR_HEIGHT = 4

local function makeFacade(parent, baseCFrame, width, floors, _, height, bodyColor)
    local floorH = height / floors
    for f = 0, floors - 1 do
        local yOff = (f + 0.5) * floorH - height * 0.5
        local windowColor = WINDOW_DIM
        local lit = math.random()
        if lit < 0.05 then
            windowColor = WINDOW_FIRE
        elseif lit < 0.15 then
            windowColor = WINDOW_BLUE
        elseif lit < 0.55 then
            windowColor = WINDOW_DARK
        end

        local strip = makePart({
            Name = "WindowStrip",
            Size = Vector3.new(width - 1.2, floorH * 0.55, 0.2),
            CFrame = baseCFrame * CFrame.new(0, yOff, 0.05),
            Material = Enum.Material.Neon,
            Color = windowColor,
            Transparency = (windowColor == WINDOW_DARK) and 0.0 or 0.15,
        }, parent)

        if windowColor == WINDOW_FIRE and chance(0.7) then
            local pl = Instance.new("PointLight")
            pl.Color = WINDOW_FIRE; pl.Range = 18; pl.Brightness = 1.6 + math.random()
            pl.Parent = strip
        elseif windowColor == WINDOW_BLUE and chance(0.5) then
            local pl = Instance.new("PointLight")
            pl.Color = WINDOW_BLUE; pl.Range = 12; pl.Brightness = 0.8
            pl.Parent = strip
        end

        makePart({
            Name = "FloorBand",
            Size = Vector3.new(width, floorH * 0.45, 0.3),
            CFrame = baseCFrame * CFrame.new(0, yOff - floorH * 0.5, 0),
            Material = Enum.Material.Concrete,
            Color = bodyColor,
        }, parent)

        if f == 0 then
            local cols = math.max(2, math.floor(width / 5))
            for c = 0, cols do
                local xOff = (c / cols - 0.5) * (width - 0.5)
                makePart({
                    Name = "Column",
                    Size = Vector3.new(0.5, height, 0.4),
                    CFrame = baseCFrame * CFrame.new(xOff, 0, 0.05),
                    Material = Enum.Material.Concrete,
                    Color = bodyColor,
                }, parent)
            end
        end
    end
end


local function buildSkyscraper(centerX, centerZ, sizeX, sizeZ, height, yawRad, parent)
    local model = Instance.new("Model")
    model.Name = "Skyscraper"
    model.Parent = parent

    local bodyColor = pick(CONCRETE_COLS)
    local cf0 = CFrame.new(centerX, 0, centerZ) * CFrame.Angles(0, yawRad, 0)

    local bodyHeight = height
    local damageTop = chance(0.55)
    local damageSide = chance(0.20)

    local bodyHeightLeft = bodyHeight
    local bodyHeightRight = bodyHeight
    if damageSide then
        if chance(0.5) then bodyHeightRight = bodyHeight * rnd(0.4, 0.7)
        else bodyHeightLeft = bodyHeight * rnd(0.4, 0.7) end
    end

    local halfX = sizeX * 0.5
    local quartX = sizeX * 0.25

    local function buildHalf(offsetX, h, width)
        if h < FLOOR_HEIGHT * 2 then return end
        local floors = math.max(2, math.floor(h / FLOOR_HEIGHT))
        local realH = floors * FLOOR_HEIGHT

        makePart({
            Name = "Body",
            Size = Vector3.new(width, realH, sizeZ),
            CFrame = cf0 * CFrame.new(offsetX, realH * 0.5, 0),
            Material = Enum.Material.Concrete,
            Color = bodyColor,
        }, model)

        local frontCF = cf0 * CFrame.new(offsetX, realH * 0.5, sizeZ * 0.5 + 0.1)
        local backCF  = cf0 * CFrame.new(offsetX, realH * 0.5, -sizeZ * 0.5 - 0.1) * CFrame.Angles(0, math.pi, 0)
        local leftCF  = cf0 * CFrame.new(offsetX - width * 0.5 - 0.1, realH * 0.5, 0) * CFrame.Angles(0, -math.pi * 0.5, 0)
        local rightCF = cf0 * CFrame.new(offsetX + width * 0.5 + 0.1, realH * 0.5, 0) * CFrame.Angles(0, math.pi * 0.5, 0)

        makeFacade(model, frontCF, width, floors, 0, realH, bodyColor)
        makeFacade(model, backCF,  width, floors, 0, realH, bodyColor)
        makeFacade(model, leftCF,  sizeZ, floors, 0, realH, bodyColor)
        makeFacade(model, rightCF, sizeZ, floors, 0, realH, bodyColor)
        return realH
    end

    local realLeft = buildHalf(-quartX, bodyHeightLeft, halfX)
    local realRight = buildHalf(quartX, bodyHeightRight, halfX)

    makePart({
        Name = "Base",
        Size = Vector3.new(sizeX + 4, 4, sizeZ + 4),
        CFrame = cf0 * CFrame.new(0, 2, 0),
        Material = Enum.Material.Concrete,
        Color = Color3.fromRGB(48, 45, 43),
    }, model)

    if damageTop then
        local topY = math.max(realLeft or 0, realRight or 0)
        for _ = 1, math.random(5, 10) do
            local rx = rnd(-halfX * 0.9, halfX * 0.9)
            local rz = rnd(-sizeZ * 0.4, sizeZ * 0.4)
            local rs = rnd(1.5, 3.5)
            makePart({
                Name = "Rubble",
                Size = Vector3.new(rs, rnd(1, 3), rs),
                CFrame = cf0 * CFrame.new(rx, topY + rnd(0, 2), rz)
                    * CFrame.Angles(math.rad(rnd(-40, 40)), math.rad(rnd(0, 360)), math.rad(rnd(-40, 40))),
                Material = Enum.Material.Concrete,
                Color = pick(CONCRETE_COLS),
            }, model)
        end
        for _ = 1, math.random(2, 5) do
            local rx = rnd(-halfX * 0.9, halfX * 0.9)
            local rz = rnd(-sizeZ * 0.4, sizeZ * 0.4)
            makePart({
                Shape = Enum.PartType.Cylinder,
                Name = "Rebar",
                Size = Vector3.new(rnd(2, 5), 0.2, 0.2),
                CFrame = cf0 * CFrame.new(rx, topY + rnd(0.5, 3), rz)
                    * CFrame.Angles(math.rad(rnd(-30, 30)), math.rad(rnd(0, 360)), math.rad(rnd(60, 120))),
                Material = Enum.Material.CorrodedMetal,
                Color = Color3.fromRGB(110, 85, 55),
            }, model)
        end
    end

    if chance(0.30) then
        local fireY = rnd(FLOOR_HEIGHT * 2, math.min(realLeft or 30, realRight or 30) - 4)
        local pl = Instance.new("PointLight")
        pl.Color = WINDOW_FIRE; pl.Range = 32; pl.Brightness = 2.5
        local emb = makePart({
            Name = "InteriorFire",
            Size = Vector3.new(2, 2, 2),
            CFrame = cf0 * CFrame.new(rnd(-halfX * 0.4, halfX * 0.4), fireY, 0),
            Material = Enum.Material.Neon,
            Color = WINDOW_FIRE,
            Transparency = 0.4,
        }, model)
        pl.Parent = emb
        task.spawn(function()
            while emb.Parent do
                pl.Brightness = 1.6 + math.random() * 1.5
                task.wait(0.08 + math.random() * 0.12)
            end
        end)
    end
    return model
end


----------------------------------------------------------------
-- РАССТАНОВКА ГОРОДА
----------------------------------------------------------------
do
    local cityFolder = Instance.new("Folder")
    cityFolder.Name = "City"
    cityFolder.Parent = lobby

    local rings = {
        { r = 180, count = 22, hMin = 100, hMax = 200, sxMin = 22, sxMax = 38 },
        { r = 245, count = 28, hMin = 80,  hMax = 160, sxMin = 24, sxMax = 40 },
        { r = 320, count = 34, hMin = 60,  hMax = 130, sxMin = 22, sxMax = 38 },
        { r = 410, count = 40, hMin = 45,  hMax = 100, sxMin = 20, sxMax = 36 },
        { r = 510, count = 46, hMin = 30,  hMax = 80,  sxMin = 20, sxMax = 36 },
        { r = 620, count = 52, hMin = 25,  hMax = 65,  sxMin = 18, sxMax = 32 },
    }

    for _, ring in ipairs(rings) do
        for i = 1, ring.count do
            local base = (i - 1) / ring.count * math.pi * 2
            local angle = base + rnd(-0.04, 0.04)
            local r = ring.r + rnd(-15, 15)
            local x = math.cos(angle) * r
            local z = math.sin(angle) * r
            local sizeX = rnd(ring.sxMin, ring.sxMax)
            local sizeZ = rnd(ring.sxMin * 0.85, ring.sxMax * 0.85)
            local h = rnd(ring.hMin, ring.hMax)
            local yaw = math.atan2(-x, -z)
            buildSkyscraper(x, z, sizeX, sizeZ, h, yaw, cityFolder)
        end
    end

    for _ = 1, 60 do
        local angle = math.random() * math.pi * 2
        local r = rnd(210, 600)
        local x = math.cos(angle) * r
        local z = math.sin(angle) * r
        local yaw = math.atan2(-x, -z) + rnd(-0.3, 0.3)
        buildSkyscraper(x, z, rnd(16, 30), rnd(16, 30), rnd(35, 140), yaw, cityFolder)
    end

    for _ = 1, 30 do
        local angle = math.random() * math.pi * 2
        local r = rnd(180, 600)
        local cx = math.cos(angle) * r
        local cz = math.sin(angle) * r
        local pile = Instance.new("Model")
        pile.Name = "CollapsedBuilding"
        pile.Parent = cityFolder
        for _ = 1, math.random(8, 16) do
            local sx, sy, sz = rnd(4, 10), rnd(2, 6), rnd(4, 10)
            makePart({
                Name = "RubbleBig",
                Size = Vector3.new(sx, sy, sz),
                CFrame = CFrame.new(cx + rnd(-15, 15), sy * 0.4, cz + rnd(-15, 15))
                    * CFrame.Angles(math.rad(rnd(-25, 25)), math.rad(rnd(0, 360)), math.rad(rnd(-25, 25))),
                Material = Enum.Material.Concrete,
                Color = pick(CONCRETE_COLS),
            }, pile)
        end
    end
end

----------------------------------------------------------------
-- ВНЕШНЯЯ СТЕНА — периметр-баррикада
----------------------------------------------------------------
do
    local outerFolder = Instance.new("Folder")
    outerFolder.Name = "OuterWall"
    outerFolder.Parent = lobby

    local R = CFG.OUTER_WALL_R
    local SEGS = CFG.OUTER_WALL_SEGS
    local segLen = 2 * R * math.sin(math.pi / SEGS) * 1.04

    for i = 1, SEGS do
        local angle = (i - 0.5) / SEGS * math.pi * 2
        local x = math.cos(angle) * R
        local z = math.sin(angle) * R
        local h = rnd(110, 220)
        if chance(0.18) then h = rnd(20, 60) end
        local segCF = CFrame.new(x, h * 0.5, z) * CFrame.Angles(0, -angle + math.pi * 0.5, 0)

        makePart({
            Name = "OuterSeg",
            Size = Vector3.new(segLen, h, 8),
            CFrame = segCF,
            Material = Enum.Material.Concrete,
            Color = pick(CONCRETE_COLS),
        }, outerFolder)

        for _ = 1, math.random(3, 7) do
            local rs = rnd(2, 5)
            makePart({
                Name = "WallTopRubble",
                Size = Vector3.new(rs, rnd(1.5, 4), rs),
                CFrame = segCF * CFrame.new(rnd(-segLen * 0.45, segLen * 0.45), h * 0.5 + rnd(0, 2), rnd(-2, 2))
                    * CFrame.Angles(math.rad(rnd(-40, 40)), math.rad(rnd(0, 360)), math.rad(rnd(-40, 40))),
                Material = Enum.Material.Concrete,
                Color = pick(CONCRETE_COLS),
            }, outerFolder)
        end

        if chance(0.25) then
            local glow = makePart({
                Name = "WallGlow",
                Size = Vector3.new(rnd(4, 10), rnd(6, 14), 0.4),
                CFrame = segCF * CFrame.new(rnd(-segLen * 0.4, segLen * 0.4), rnd(-h * 0.2, h * 0.3), 4.05),
                Material = Enum.Material.Neon,
                Color = Color3.fromRGB(220, 50, 30),
                Transparency = 0.25,
            }, outerFolder)
            local pl = Instance.new("PointLight")
            pl.Color = Color3.fromRGB(255, 60, 30); pl.Range = 35; pl.Brightness = 2
            pl.Parent = glow
            task.spawn(function()
                while glow.Parent do
                    pl.Brightness = 1.5 + math.random() * 1.4
                    task.wait(0.1 + math.random() * 0.15)
                end
            end)
        end

        if chance(0.5) then
            makePart({
                Name = "Buttress",
                Size = Vector3.new(rnd(6, 12), 16, 8),
                CFrame = segCF * CFrame.new(rnd(-segLen * 0.4, segLen * 0.4), -h * 0.5 + 8, -6),
                Material = Enum.Material.Concrete,
                Color = pick(CONCRETE_COLS),
            }, outerFolder)
        end
    end
end


----------------------------------------------------------------
-- ТРАНСПОРТНЫЙ ВЕРТОЛЁТ (новая модель пользователя)
----------------------------------------------------------------
local HELI_SCALE = 1.5
local LEFT_SEAT_ROT  = CFrame.Angles(0, math.rad(90), 0)
local RIGHT_SEAT_ROT = CFrame.Angles(0, math.rad(-90), 0)
-- Опускаем модель так, чтобы шасси стояло на земле (нижняя точка ~8.6 * scale).
local HELI_DROP = 8.6 * HELI_SCALE

local function scaleVec3(v)
    return Vector3.new(v.X * HELI_SCALE, v.Y * HELI_SCALE, v.Z * HELI_SCALE)
end

local function buildHelicopter(spawnCFrame, parent, idx)
    local model = Instance.new("Model")
    model.Name = "TransportHeli_" .. idx
    model.Parent = parent

    local floorPart = nil

    local function hPart(data)
        local cn = data.Class or "Part"
        local p = Instance.new(cn)
        p.Name = data.Name or "Part"
        p.Size = scaleVec3(data.Size or Vector3.new(1, 1, 1))
        local localCF = CFrame.new((data.CF or CFrame.new()).Position * HELI_SCALE) * (data.CF or CFrame.new()).Rotation
        p.CFrame = spawnCFrame * localCF
        p.Anchored = true
        p.TopSurface = data.TopSurface or Enum.SurfaceType.Smooth
        p.BottomSurface = data.BottomSurface or Enum.SurfaceType.Smooth
        if data.Color then p.Color = data.Color end
        p.Material = data.Material or Enum.Material.Metal
        if data.Transparency ~= nil then p.Transparency = data.Transparency end
        if data.Reflectance ~= nil then p.Reflectance = data.Reflectance end
        if data.CanCollide ~= nil then p.CanCollide = data.CanCollide else p.CanCollide = true end
        if data.CastShadow ~= nil then p.CastShadow = data.CastShadow end
        if cn == "Part" and data.Shape then p.Shape = data.Shape end
        if cn == "Seat" then
            local nm = data.Name or ""
            if string.find(nm, "^SeatR") or string.find(nm, "^PilotSeatR") then
                p.CFrame = p.CFrame * RIGHT_SEAT_ROT
            else
                p.CFrame = p.CFrame * LEFT_SEAT_ROT
            end
        end
        p.Parent = model
        if data.Name == "CargoFloor" and not floorPart then floorPart = p end
        return p
    end


    hPart({Name="CargoFloor", Class="Part", Size=Vector3.new(6, 0.4, 18), CF=CFrame.new(0, 11.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(55, 60, 55), Material=Enum.Material.DiamondPlate, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="CargoRoof", Class="Part", Size=Vector3.new(6.4, 0.4, 18), CF=CFrame.new(0, 18.200001, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(85, 95, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="HullLeft_Bot", Class="Part", Size=Vector3.new(0.4, 3, 18), CF=CFrame.new(3, 13.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(85, 95, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="HullLeft_Top", Class="Part", Size=Vector3.new(0.4, 3, 18), CF=CFrame.new(3, 16.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(85, 95, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="HullRight_Bot", Class="Part", Size=Vector3.new(0.4, 3, 18), CF=CFrame.new(-3, 13.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(85, 95, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="HullRight_Top", Class="Part", Size=Vector3.new(0.4, 3, 18), CF=CFrame.new(-3, 16.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(85, 95, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowL_-3", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(3, 15, -6.6, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowR_-3", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(-3, 15, -6.6, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowL_-2", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(3, 15, -4.4, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowR_-2", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(-3, 15, -4.4, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowL_-1", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(3, 15, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowR_-1", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(-3, 15, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowL_0", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(3, 15, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowR_0", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(-3, 15, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowL_1", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(3, 15, 2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowR_1", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(-3, 15, 2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowL_2", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(3, 15, 4.4, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowR_2", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(-3, 15, 4.4, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowL_3", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(3, 15, 6.6, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="WindowR_3", Class="Part", Size=Vector3.new(0.45, 1.2, 1.4), CF=CFrame.new(-3, 15, 6.6, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.5, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="CockpitBulkhead", Class="Part", Size=Vector3.new(6, 6, 0.4), CF=CFrame.new(0, 15, 9.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(60, 68, 58), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="NoseBase", Class="Part", Size=Vector3.new(5.6, 3.2, 4), CF=CFrame.new(0, 13.6, 11.4, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(85, 95, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="NoseGlass", Class="WedgePart", Size=Vector3.new(5.6, 3.2, 4), CF=CFrame.new(0, 16.799999, 11.4, -1, 0, -0, 0, 1, 0, 0, 0, -1), Color=Color3.fromRGB(140, 190, 240), Material=Enum.Material.Glass, Transparency=0.45, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})


    hPart({Name="PilotSeatL", Class="Seat", Size=Vector3.new(1.8, 0.4, 1.8), CF=CFrame.new(1.2, 12.5, 10.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="PilotSeatR", Class="Seat", Size=Vector3.new(1.8, 0.4, 1.8), CF=CFrame.new(-1.2, 12.5, 10.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="Dashboard", Class="Part", Size=Vector3.new(5, 1.5, 1), CF=CFrame.new(0, 14.5, 12, 1, 0, 0, 0, 0.939693, -0.34202, 0, 0.34202, 0.939693), Color=Color3.fromRGB(30, 30, 35), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="TailBoom", Class="Part", Size=Vector3.new(2, 2.5, 14), CF=CFrame.new(0, 17.15, -16, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(85, 95, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="VerticalFin", Class="WedgePart", Size=Vector3.new(0.4, 4.5, 3.5), CF=CFrame.new(0, 20.65, -21.25, -1, 0, -0, 0, 1, 0, 0, 0, -1), Color=Color3.fromRGB(85, 95, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="Stabilizer", Class="Part", Size=Vector3.new(7, 0.2, 2.5), CF=CFrame.new(0, 17.15, -21, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(85, 95, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="EndplateL", Class="Part", Size=Vector3.new(0.2, 2.5, 2.5), CF=CFrame.new(3.5, 17.15, -21, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(60, 68, 58), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="EndplateR", Class="Part", Size=Vector3.new(0.2, 2.5, 2.5), CF=CFrame.new(-3.5, 17.15, -21, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(60, 68, 58), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="RearBulkhead", Class="Part", Size=Vector3.new(6, 2.5, 0.4), CF=CFrame.new(0, 16.950001, -9.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(60, 68, 58), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="RampFloor", Class="Part", Size=Vector3.new(5.6, 0.4, 8), CF=CFrame.new(0, 10.612074, -12.907782, 1, 0, 0, 0, 0.939693, 0.34202, 0, -0.34202, 0.939693), Color=Color3.fromRGB(70, 70, 65), Material=Enum.Material.DiamondPlate, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="HydraulicL", Class="Part", Size=Vector3.new(4, 0.35, 0.35), CF=CFrame.new(2.5, 12.5, -10, -0, -1, 0, 0.642788, -0, -0.766044, 0.766044, -0, 0.642788), Color=Color3.fromRGB(180, 170, 50), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="HydraulicR", Class="Part", Size=Vector3.new(4, 0.35, 0.35), CF=CFrame.new(-2.5, 12.5, -10, -0, -1, 0, 0.642788, -0, -0.766044, 0.766044, -0, 0.642788), Color=Color3.fromRGB(180, 170, 50), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="DoorLeft", Class="Part", Size=Vector3.new(0.15, 6.2, 3.5), CF=CFrame.new(3.22, 15, 5.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(60, 68, 58), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="DoorRight", Class="Part", Size=Vector3.new(0.15, 6.2, 3.5), CF=CFrame.new(-3.22, 15, 5.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(60, 68, 58), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="EngineL_Nacelle", Class="Part", Size=Vector3.new(6, 2.2, 2.2), CF=CFrame.new(1.6, 19.5, 1, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(60, 68, 58), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="EngineL_Intake", Class="Part", Size=Vector3.new(1.2, 2.5, 2.5), CF=CFrame.new(1.6, 19.5, 4.5, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="EngineL_Exhaust", Class="Part", Size=Vector3.new(2, 1.4, 1.4), CF=CFrame.new(1.6, 19.5, -2.5, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(40, 40, 45), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="EngineR_Nacelle", Class="Part", Size=Vector3.new(6, 2.2, 2.2), CF=CFrame.new(-1.6, 19.5, 1, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(60, 68, 58), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="EngineR_Intake", Class="Part", Size=Vector3.new(1.2, 2.5, 2.5), CF=CFrame.new(-1.6, 19.5, 4.5, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="EngineR_Exhaust", Class="Part", Size=Vector3.new(2, 1.4, 1.4), CF=CFrame.new(-1.6, 19.5, -2.5, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(40, 40, 45), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="MainRotorHub", Class="Part", Size=Vector3.new(1.5, 2.5, 2.5), CF=CFrame.new(0, 20, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="RotorMast", Class="Part", Size=Vector3.new(1.2, 1.6, 1.2), CF=CFrame.new(0, 19.200001, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="MainBlade_0", Class="Part", Size=Vector3.new(1.2, 0.15, 16), CF=CFrame.new(0, 20.200001, 8, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(60, 60, 65), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="MainBlade_1", Class="Part", Size=Vector3.new(1.2, 0.15, 16), CF=CFrame.new(7.608452, 20.200001, 2.472136, 0.309017, 0, 0.951057, 0, 1, 0, -0.951057, 0, 0.309017), Color=Color3.fromRGB(60, 60, 65), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="MainBlade_2", Class="Part", Size=Vector3.new(1.2, 0.15, 16), CF=CFrame.new(4.702281, 20.200001, -6.472136, -0.809017, 0, 0.587785, 0, 1, 0, -0.587785, 0, -0.809017), Color=Color3.fromRGB(60, 60, 65), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="MainBlade_3", Class="Part", Size=Vector3.new(1.2, 0.15, 16), CF=CFrame.new(-4.702283, 20.200001, -6.472136, -0.809017, 0, -0.587785, 0, 1, 0, 0.587785, 0, -0.809017), Color=Color3.fromRGB(60, 60, 65), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="MainBlade_4", Class="Part", Size=Vector3.new(1.2, 0.15, 16), CF=CFrame.new(-7.608452, 20.200001, 2.472137, 0.309017, 0, -0.951056, 0, 1, 0, 0.951056, 0, 0.309017), Color=Color3.fromRGB(60, 60, 65), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="TailRotorHub", Class="Part", Size=Vector3.new(0.6, 0.8, 0.8), CF=CFrame.new(0.5, 20.65, -21.25, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="TailBlade_0", Class="Part", Size=Vector3.new(0.4, 0.12, 3.5), CF=CFrame.new(0.5, 22.4, -21.25, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(60, 60, 65), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="TailBlade_1", Class="Part", Size=Vector3.new(0.4, 0.12, 3.5), CF=CFrame.new(0.5, 20.65, -19.5, 1, 0, 0, 0, -0, -1, 0, 1, -0), Color=Color3.fromRGB(60, 60, 65), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="TailBlade_2", Class="Part", Size=Vector3.new(0.4, 0.12, 3.5), CF=CFrame.new(0.5, 18.9, -21.25, 1, 0, 0, 0, -1, 0, 0, -0, -1), Color=Color3.fromRGB(60, 60, 65), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="TailBlade_3", Class="Part", Size=Vector3.new(0.4, 0.12, 3.5), CF=CFrame.new(0.5, 20.65, -23, 1, 0, 0, 0, 0, 1, 0, -1, 0), Color=Color3.fromRGB(60, 60, 65), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="NoseGearStrut", Class="Part", Size=Vector3.new(0.4, 2, 0.4), CF=CFrame.new(0, 11, 9, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="NoseWheel", Class="Part", Size=Vector3.new(1, 1.5, 1.5), CF=CFrame.new(0, 10, 9, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(25, 25, 25), Material=Enum.Material.SmoothPlastic, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="MainGearStrutL", Class="Part", Size=Vector3.new(0.5, 2.2, 0.5), CF=CFrame.new(2.5, 11, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="MainWheelL", Class="Part", Size=Vector3.new(1.2, 2.2, 2.2), CF=CFrame.new(2.5, 9.7, -2, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(25, 25, 25), Material=Enum.Material.SmoothPlastic, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})
    hPart({Name="MainGearStrutR", Class="Part", Size=Vector3.new(0.5, 2.2, 0.5), CF=CFrame.new(-2.5, 11, -2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="MainWheelR", Class="Part", Size=Vector3.new(1.2, 2.2, 2.2), CF=CFrame.new(-2.5, 9.7, -2, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(25, 25, 25), Material=Enum.Material.SmoothPlastic, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})

    hPart({Name="SeatL_0", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(2.2, 12.3, 7, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatR_0", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(-2.2, 12.3, 7, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatL_1", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(2.2, 12.3, 4.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatR_1", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(-2.2, 12.3, 4.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatL_2", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(2.2, 12.3, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatR_2", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(-2.2, 12.3, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatL_3", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(2.2, 12.3, -0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatR_3", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(-2.2, 12.3, -0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatL_4", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(2.2, 12.3, -3, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatR_4", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(-2.2, 12.3, -3, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatL_5", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(2.2, 12.3, -5.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="SeatR_5", Class="Seat", Size=Vector3.new(1.6, 0.35, 1.6), CF=CFrame.new(-2.2, 12.3, -5.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(90, 75, 55), Material=Enum.Material.Fabric, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})

    hPart({Name="BenchFrameL", Class="Part", Size=Vector3.new(1.8, 0.25, 16), CF=CFrame.new(2.2, 12.05, 0.75, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="BenchFrameR", Class="Part", Size=Vector3.new(1.8, 0.25, 16), CF=CFrame.new(-2.2, 12.05, 0.75, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(75, 75, 80), Material=Enum.Material.Metal, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="CeilingLight_-2", Class="Part", Size=Vector3.new(0.6, 0.15, 0.6), CF=CFrame.new(0, 17.9, -7, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(255, 240, 200), Material=Enum.Material.Neon, Transparency=0.1, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="CeilingLight_-1", Class="Part", Size=Vector3.new(0.6, 0.15, 0.6), CF=CFrame.new(0, 17.9, -3.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(255, 240, 200), Material=Enum.Material.Neon, Transparency=0.1, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="CeilingLight_0", Class="Part", Size=Vector3.new(0.6, 0.15, 0.6), CF=CFrame.new(0, 17.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(255, 240, 200), Material=Enum.Material.Neon, Transparency=0.1, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="CeilingLight_1", Class="Part", Size=Vector3.new(0.6, 0.15, 0.6), CF=CFrame.new(0, 17.9, 3.5, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(255, 240, 200), Material=Enum.Material.Neon, Transparency=0.1, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="CeilingLight_2", Class="Part", Size=Vector3.new(0.6, 0.15, 0.6), CF=CFrame.new(0, 17.9, 7, 1, 0, 0, 0, 1, 0, 0, 0, 1), Color=Color3.fromRGB(255, 240, 200), Material=Enum.Material.Neon, Transparency=0.1, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true})
    hPart({Name="LandingLight", Class="Part", Size=Vector3.new(0.3, 1, 1), CF=CFrame.new(0, 12.2, 11, -0, -1, 0, 1, -0, 0, 0, 0, 1), Color=Color3.fromRGB(255, 255, 220), Material=Enum.Material.Neon, Transparency=0, Reflectance=0, Anchored=true, CanCollide=true, CastShadow=true, Shape=Enum.PartType.Cylinder})

    return model, floorPart
end



----------------------------------------------------------------
-- ХОСТ-ЗОНЫ (без надписи)
----------------------------------------------------------------
local hostZones = {}
local currentHost = nil
local touchDebounce = {}

local function syncZoneColors()
    local color = currentHost and HOST_COLOR or NO_HOST_COLOR
    for _, z in ipairs(hostZones) do
        z.Color = color
        local pl = z:FindFirstChildOfClass("PointLight")
        if pl then pl.Color = color end
    end
end

local function setHost(plr)
    if currentHost == plr then return end
    if currentHost then currentHost:SetAttribute("IsHost", false) end
    currentHost = plr
    if plr then
        plr:SetAttribute("IsHost", true)
        print(("[LobbyHost] Host -> %s"):format(plr.Name))
    else
        print("[LobbyHost] Host cleared")
    end
    syncZoneColors()
end

Players.PlayerRemoving:Connect(function(plr)
    touchDebounce[plr] = nil
    if currentHost == plr then setHost(nil) end
end)

local function makeHostZone(parent, floorPart)
    local zone = Instance.new("Part")
    zone.Name = "HostZone"
    zone.Size = Vector3.new(7, 0.5, 7)
    zone.Anchored = true
    zone.CanCollide = false
    zone.Material = Enum.Material.Neon
    zone.Color = NO_HOST_COLOR
    zone.Transparency = 0.4
    zone.TopSurface = Enum.SurfaceType.Smooth
    zone.BottomSurface = Enum.SurfaceType.Smooth

    local floorYRot = math.rad(floorPart.Orientation.Y)
    zone.CFrame = CFrame.new(floorPart.Position + Vector3.new(0, floorPart.Size.Y * 0.5 + 0.3, 0))
        * CFrame.Angles(0, floorYRot, 0)
    zone.Parent = parent

    local pl = Instance.new("PointLight")
    pl.Color = NO_HOST_COLOR; pl.Brightness = 1.2; pl.Range = 14
    pl.Parent = zone

    zone.Touched:Connect(function(hit)
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local plr = Players:GetPlayerFromCharacter(char)
        if not plr then return end
        local now = os.clock()
        if touchDebounce[plr] and now - touchDebounce[plr] < 0.5 then return end
        touchDebounce[plr] = now
        setHost(plr)
    end)

    table.insert(hostZones, zone)
    return zone
end

----------------------------------------------------------------
-- СПАВН ВЕРТОЛЁТОВ ПО КРУГУ — носом (кабиной) к центру
----------------------------------------------------------------
do
    local heliFolder = Instance.new("Folder")
    heliFolder.Name = "Helicopters"
    heliFolder.Parent = lobby

    for i = 1, CFG.HELI_COUNT do
        local phi = (i - 1) / CFG.HELI_COUNT * math.pi * 2
        local px = math.cos(phi) * CFG.HELI_RADIUS
        local pz = math.sin(phi) * CFG.HELI_RADIUS
        -- Нос модели смотрит в +Z; повернём так, чтобы +Z указывал в центр.
        local yaw = math.atan2(-px, -pz)

        local spawnCFrame = CFrame.new(px, -HELI_DROP, pz) * CFrame.Angles(0, yaw, 0)

        local model, floorPart = buildHelicopter(spawnCFrame, heliFolder, i)
        if floorPart then
            makeHostZone(model, floorPart)
        else
            warn(("[LobbyGenerator] TransportHeli_%d: CargoFloor not found"):format(i))
        end
    end
end

syncZoneColors()

print(("[LobbyGenerator v5] Done. Helis: %d, play radius: %d.")
    :format(CFG.HELI_COUNT, CFG.PLAY_RADIUS))
