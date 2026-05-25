--[[
    LobbyGenerator.server.lua
    Помести в ServerScriptService. Чистый Luau без type annotations.
    Генерирует: руины города, мусор, 5 вертолётов с хост-зонами, атмосферу.
]]

local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")
local Players   = game:GetService("Players")

local CFG = {
    BASE_PLATE_SIZE   = 600,
    HELI_COUNT        = 5,
    HELI_RADIUS       = 110,
    HELI_HEIGHT       = 12,
    BUILDING_COUNT    = 14,
    BUILDING_RING     = 220,
    DEBRIS_COUNT      = 220,
    REBAR_COUNT       = 35,
    SEED              = 1337,
}

local NO_HOST_COLOR = Color3.fromRGB(70, 255, 110)
local HOST_COLOR    = Color3.fromRGB(70, 140, 255)

math.randomseed(CFG.SEED)

local function rnd(min, max)
    return math.random() * (max - min) + min
end

local function pick(t)
    return t[math.random(1, #t)]
end

local function makePart(props, parent)
    local class = props.ClassName or "Part"
    local p = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "ClassName" then
            p[k] = v
        end
    end
    p.Anchored = true
    p.Parent = parent
    return p
end


-- Очистка предыдущей генерации
do
    local prev = Workspace:FindFirstChild("ZombieLobby")
    if prev then prev:Destroy() end
end

local lobby = Instance.new("Model")
lobby.Name = "ZombieLobby"
lobby.Parent = Workspace

----------------------------------------------------------------
-- АТМОСФЕРА
----------------------------------------------------------------
do
    Lighting.ClockTime            = 17.6
    Lighting.GeographicLatitude   = 41
    Lighting.Brightness           = 1.6
    Lighting.GlobalShadows        = true
    Lighting.ShadowSoftness       = 0.5
    Lighting.ExposureCompensation = -0.05
    Lighting.Ambient              = Color3.fromRGB(78, 72, 80)
    Lighting.OutdoorAmbient       = Color3.fromRGB(105, 98, 105)
    Lighting.ColorShift_Top       = Color3.fromRGB(45, 35, 30)
    Lighting.ColorShift_Bottom    = Color3.fromRGB(25, 25, 30)
    Lighting.FogStart             = 120
    Lighting.FogEnd               = 650
    Lighting.FogColor             = Color3.fromRGB(115, 100, 92)

    for _, child in ipairs(Lighting:GetChildren()) do
        if child.Name == "ApocAtmosphere"
            or child.Name == "ApocColorCorrection"
            or child.Name == "ApocBloom" then
            child:Destroy()
        end
    end

    local atmos = Instance.new("Atmosphere")
    atmos.Name    = "ApocAtmosphere"
    atmos.Density = 0.40
    atmos.Offset  = 0.25
    atmos.Color   = Color3.fromRGB(170, 150, 140)
    atmos.Decay   = Color3.fromRGB(95, 80, 75)
    atmos.Glare   = 0.35
    atmos.Haze    = 1.7
    atmos.Parent  = Lighting

    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name       = "ApocColorCorrection"
    cc.Brightness = 0.02
    cc.Contrast   = 0.10
    cc.Saturation = -0.22
    cc.TintColor  = Color3.fromRGB(225, 215, 205)
    cc.Parent     = Lighting

    local bloom = Instance.new("BloomEffect")
    bloom.Name      = "ApocBloom"
    bloom.Intensity = 0.45
    bloom.Size      = 24
    bloom.Threshold = 0.85
    bloom.Parent    = Lighting
end


----------------------------------------------------------------
-- ЗЕМЛЯ
----------------------------------------------------------------
makePart({
    Name          = "GroundPlate",
    Size          = Vector3.new(CFG.BASE_PLATE_SIZE, 4, CFG.BASE_PLATE_SIZE),
    CFrame        = CFrame.new(0, -2, 0),
    Material      = Enum.Material.Concrete,
    Color         = Color3.fromRGB(58, 56, 54),
    TopSurface    = Enum.SurfaceType.Smooth,
    BottomSurface = Enum.SurfaceType.Smooth,
}, lobby)

----------------------------------------------------------------
-- МУСОР
----------------------------------------------------------------
do
    local folder = Instance.new("Folder")
    folder.Name   = "Debris"
    folder.Parent = lobby

    local mats = {
        Enum.Material.Concrete,
        Enum.Material.CorrodedMetal,
        Enum.Material.Slate,
        Enum.Material.Brick,
        Enum.Material.Concrete,
    }
    local cols = {
        Color3.fromRGB(80, 78, 75),
        Color3.fromRGB(95, 95, 95),
        Color3.fromRGB(110, 90, 65),
        Color3.fromRGB(60, 60, 62),
        Color3.fromRGB(75, 65, 55),
    }

    for i = 1, CFG.DEBRIS_COUNT do
        local angle = math.random() * math.pi * 2
        local r
        local roll = math.random()
        if roll < 0.40 then
            r = rnd(20, 90)
        elseif roll < 0.80 then
            r = rnd(135, 200)
        else
            r = rnd(235, 285)
        end
        local x = math.cos(angle) * r
        local z = math.sin(angle) * r
        local sx = rnd(1.5, 8)
        local sy = rnd(0.6, 3.5)
        local sz = rnd(1.5, 8)

        makePart({
            Name = "Debris",
            Size = Vector3.new(sx, sy, sz),
            CFrame = CFrame.new(x, sy * 0.4 + 0.2, z) * CFrame.Angles(
                math.rad(rnd(-30, 30)),
                math.rad(rnd(0, 360)),
                math.rad(rnd(-30, 30))
            ),
            Material = pick(mats),
            Color    = pick(cols),
        }, folder)
    end


    for i = 1, CFG.REBAR_COUNT do
        local angle = math.random() * math.pi * 2
        local r = rnd(40, 280)
        makePart({
            ClassName = "Part",
            Name      = "Rebar",
            Shape     = Enum.PartType.Cylinder,
            Size      = Vector3.new(rnd(3, 7), 0.3, 0.3),
            CFrame = CFrame.new(math.cos(angle) * r, 0.3, math.sin(angle) * r)
                * CFrame.Angles(
                    math.rad(rnd(-20, 20)),
                    math.rad(rnd(0, 360)),
                    math.rad(rnd(70, 110))
                ),
            Material = Enum.Material.CorrodedMetal,
            Color    = Color3.fromRGB(115, 85, 55),
        }, folder)
    end
end

----------------------------------------------------------------
-- РАЗРУШЕННЫЕ ЗДАНИЯ
----------------------------------------------------------------
local function generateBuilding(centerPos, sizeX, sizeZ, floors, parent)
    local model = Instance.new("Model")
    model.Name   = "RuinedBuilding"
    model.Parent = parent

    local mats = { Enum.Material.Concrete, Enum.Material.Slate }
    local cols = {
        Color3.fromRGB(70, 70, 72),
        Color3.fromRGB(60, 58, 55),
        Color3.fromRGB(80, 78, 75),
        Color3.fromRGB(50, 50, 52),
    }

    local wallThickness = 1
    local floorH        = 6
    local halfX         = sizeX * 0.5
    local halfZ         = sizeZ * 0.5

    local heights = {}
    for i = 1, 4 do
        heights[i] = floors * floorH * rnd(0.55, 1.0)
    end

    local function wall(name, size, offset)
        makePart({
            Name     = name,
            Size     = size,
            CFrame   = CFrame.new(centerPos + offset),
            Material = pick(mats),
            Color    = pick(cols),
        }, model)
    end


    wall("WallN", Vector3.new(sizeX, heights[1], wallThickness), Vector3.new(0, heights[1]*0.5, halfZ))
    wall("WallS", Vector3.new(sizeX, heights[2], wallThickness), Vector3.new(0, heights[2]*0.5, -halfZ))
    wall("WallE", Vector3.new(wallThickness, heights[3], sizeZ), Vector3.new(halfX, heights[3]*0.5, 0))
    wall("WallW", Vector3.new(wallThickness, heights[4], sizeZ), Vector3.new(-halfX, heights[4]*0.5, 0))

    -- Рваный верх стен
    for i = 1, math.random(8, 14) do
        local edge = math.random(1, 4)
        local x, z, h
        if edge == 1 then
            x = rnd(-halfX, halfX); z = halfZ;  h = heights[1]
        elseif edge == 2 then
            x = rnd(-halfX, halfX); z = -halfZ; h = heights[2]
        elseif edge == 3 then
            x = halfX;  z = rnd(-halfZ, halfZ); h = heights[3]
        else
            x = -halfX; z = rnd(-halfZ, halfZ); h = heights[4]
        end
        local rs = rnd(1, 3)
        makePart({
            Name = "Rubble",
            Size = Vector3.new(rs, rnd(0.7, 2.5), rs),
            CFrame = CFrame.new(centerPos + Vector3.new(x, h - rnd(0, 2), z))
                * CFrame.Angles(
                    math.rad(rnd(-50, 50)),
                    math.rad(rnd(0, 360)),
                    math.rad(rnd(-50, 50))
                ),
            Material = Enum.Material.Concrete,
            Color    = pick(cols),
        }, model)
    end

    -- Покосившиеся плиты перекрытий
    local minH = math.min(heights[1], heights[2], heights[3], heights[4])
    for f = 1, floors - 1 do
        local y = f * floorH
        if y > minH - 1 then break end

        local pieceCount = math.random(2, 3)
        for p = 1, pieceCount do
            local pieceX = (sizeX / pieceCount) * rnd(0.55, 0.95)
            local pieceZ = sizeZ * rnd(0.4, 0.85)
            local px = (p - (pieceCount + 1) * 0.5) * (sizeX / pieceCount) + rnd(-1, 1)
            local pz = rnd(-halfZ * 0.4, halfZ * 0.4)
            makePart({
                Name = "FloorSlab",
                Size = Vector3.new(pieceX, 0.5, pieceZ),
                CFrame = CFrame.new(centerPos + Vector3.new(px, y, pz))
                    * CFrame.Angles(
                        math.rad(rnd(-12, 12)),
                        math.rad(rnd(-15, 15)),
                        math.rad(rnd(-12, 12))
                    ),
                Material = Enum.Material.Concrete,
                Color    = pick(cols),
            }, model)
        end


        -- Свисающая арматура
        if math.random() < 0.5 then
            makePart({
                ClassName = "Part",
                Shape     = Enum.PartType.Cylinder,
                Name      = "Rebar",
                Size      = Vector3.new(rnd(2, 4), 0.2, 0.2),
                CFrame = CFrame.new(centerPos + Vector3.new(
                        rnd(-halfX * 0.6, halfX * 0.6),
                        y - 0.3,
                        rnd(-halfZ * 0.6, halfZ * 0.6)
                    ))
                    * CFrame.Angles(0, math.rad(rnd(0, 360)), math.rad(rnd(70, 110))),
                Material = Enum.Material.CorrodedMetal,
                Color    = Color3.fromRGB(110, 85, 55),
            }, model)
        end
    end

    -- Тлеющий костёр внутри (Neon + PointLight)
    if math.random() < 0.45 then
        local fx = rnd(-halfX * 0.6, halfX * 0.6)
        local fz = rnd(-halfZ * 0.6, halfZ * 0.6)
        local fire = makePart({
            Name = "FireEmber",
            Size = Vector3.new(rnd(1.5, 2.5), 0.4, rnd(1.5, 2.5)),
            CFrame = CFrame.new(centerPos + Vector3.new(fx, 0.4, fz)),
            Material = Enum.Material.Neon,
            Color    = Color3.fromRGB(255, 130, 50),
            Transparency = 0.2,
        }, model)
        local pl = Instance.new("PointLight")
        pl.Color      = Color3.fromRGB(255, 140, 70)
        pl.Range      = 28
        pl.Brightness = 2.2
        pl.Parent     = fire
        task.spawn(function()
            while fire.Parent do
                pl.Brightness = 1.4 + math.random() * 1.4
                task.wait(0.07 + math.random() * 0.1)
            end
        end)
    end
end

do
    local folder = Instance.new("Folder")
    folder.Name   = "Buildings"
    folder.Parent = lobby

    for i = 1, CFG.BUILDING_COUNT do
        local angle = (i - 1) / CFG.BUILDING_COUNT * math.pi * 2 + rnd(-0.05, 0.05)
        local r     = CFG.BUILDING_RING + rnd(-25, 30)
        local pos   = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
        local sx    = rnd(20, 35)
        local sz    = rnd(20, 35)
        local floors = math.random(3, 6)
        generateBuilding(pos, sx, sz, floors, folder)
    end
end


----------------------------------------------------------------
-- ВЕРТОЛЁТ
----------------------------------------------------------------
local function buildHelicopter(spawnCFrame, parent, idx)
    local model = Instance.new("Model")
    model.Name   = "Helicopter_" .. idx
    model.Parent = parent

    local floorPart = nil

    local function createPart(name, className, size, relCFrame, color, material, transparency, shape)
        local p = Instance.new(className)
        p.Name         = name
        p.Size         = size
        p.CFrame       = spawnCFrame * relCFrame
        p.Color        = color
        p.Material     = material
        p.Transparency = transparency
        p.Anchored     = true
        p.CanCollide   = true
        if className == "Part" and shape then p.Shape = shape end
        p.Parent = model
        if name == "Floor" and not floorPart then
            floorPart = p
        end
        return p
    end

    createPart("Floor", "Part", Vector3.new(10, 0.5, 24), CFrame.new(1.176, -7.369, 0.527) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("Roof", "Part", Vector3.new(10, 0.5, 24), CFrame.new(1.176, 0.131, 0.527) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("WallL_Bottom", "Part", Vector3.new(0.5, 3, 24), CFrame.new(5.018, -5.619, 3.319) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("WindowL", "Part", Vector3.new(0.2, 2, 24), CFrame.new(5.018, -3.119, 3.319) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(150, 200, 255), Enum.Material.Glass, 0.5, Enum.PartType.Block)
    createPart("WallL_Top", "Part", Vector3.new(0.5, 2.5, 24), CFrame.new(5.018, -0.869, 3.319) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("WallR_Bottom", "Part", Vector3.new(0.5, 3, 24), CFrame.new(-2.667, -5.619, -2.265) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("WindowR", "Part", Vector3.new(0.2, 2, 24), CFrame.new(-2.667, -3.119, -2.265) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(150, 200, 255), Enum.Material.Glass, 0.5, Enum.PartType.Block)
    createPart("WallR_Top", "Part", Vector3.new(0.5, 2.5, 24), CFrame.new(-2.667, -0.869, -2.265) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("CockpitBase", "Part", Vector3.new(10, 4, 6), CFrame.new(-7.641, -5.119, 12.662) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("CockpitGlass", "WedgePart", Vector3.new(10, 3.5, 6), CFrame.new(-7.641, -1.369, 12.662) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(150, 200, 255), Enum.Material.Glass, 0.5, nil)

    createPart("Ramp", "Part", Vector3.new(8, 0.5, 12), CFrame.new(11.168, -9.619, -13.226) * CFrame.Angles(2.619, 0.562, -2.844), Color3.fromRGB(80, 80, 85), Enum.Material.DiamondPlate, 0, Enum.PartType.Block)
    createPart("TailBoom", "Part", Vector3.new(3, 3, 14), CFrame.new(10.647, 1.881, -12.509) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("TailFin", "WedgePart", Vector3.new(1, 6, 6), CFrame.new(12.998, 6.381, -15.745) * CFrame.Angles(0, -0.628, 0), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, nil)
    createPart("Engine_L", "Part", Vector3.new(12, 4, 4), CFrame.new(5.259, -5.119, 5.965) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Cylinder)
    createPart("Engine_R", "Part", Vector3.new(12, 4, 4), CFrame.new(-5.259, -5.119, -1.676) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Cylinder)
    createPart("WingLeft", "Part", Vector3.new(7, 0.5, 3), CFrame.new(5.499, -2.119, 8.612) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("WingRight", "Part", Vector3.new(7, 0.5, 3), CFrame.new(-7.850, -2.119, -1.086) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(95, 105, 95), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("ExhaustL1", "Part", Vector3.new(5, 2, 2), CFrame.new(6.106, -3.619, 9.053) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Cylinder)
    createPart("ExhaustL2", "Part", Vector3.new(5, 2, 2), CFrame.new(8.128, -3.619, 10.522) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Cylinder)
    createPart("ExhaustR1", "Part", Vector3.new(5, 2, 2), CFrame.new(-8.457, -3.619, -1.527) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Cylinder)
    createPart("ExhaustR2", "Part", Vector3.new(5, 2, 2), CFrame.new(-10.479, -3.619, -2.997) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Cylinder)
    createPart("StrutFront", "Part", Vector3.new(0.5, 3.5, 0.5), CFrame.new(-7.053, -9.119, 11.853) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("WheelFront", "Part", Vector3.new(1, 3, 3), CFrame.new(-7.053, -10.869, 11.853) * CFrame.Angles(-3.142, 0.628, -1.571), Color3.fromRGB(30, 30, 30), Enum.Material.Rubber, 0, Enum.PartType.Cylinder)
    createPart("StrutBackL", "Part", Vector3.new(0.5, 3, 0.5), CFrame.new(6.396, -8.619, 1.848) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("WheelBackL", "Part", Vector3.new(1.5, 3.6, 3.6), CFrame.new(6.396, -10.119, 1.848) * CFrame.Angles(-3.142, 0.628, -1.571), Color3.fromRGB(30, 30, 30), Enum.Material.Rubber, 0, Enum.PartType.Cylinder)
    createPart("StrutBackR", "Part", Vector3.new(0.5, 3, 0.5), CFrame.new(-1.694, -8.619, -4.030) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("WheelBackR", "Part", Vector3.new(1.5, 3.6, 3.6), CFrame.new(-1.694, -10.119, -4.030) * CFrame.Angles(-3.142, 0.628, -1.571), Color3.fromRGB(30, 30, 30), Enum.Material.Rubber, 0, Enum.PartType.Cylinder)
    createPart("RotorHub", "Part", Vector3.new(4, 2, 2), CFrame.new(0, 1.381, 2.145) * CFrame.Angles(-3.142, 0.628, -1.571), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Cylinder)

    createPart("MainBlade_1", "Part", Vector3.new(1, 0.2, 24), CFrame.new(7.053, 2.881, 11.853) * CFrame.Angles(-3.142, -0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("MainBlade_2", "Part", Vector3.new(1, 0.2, 24), CFrame.new(11.413, 2.881, -1.563) * CFrame.Angles(0, -1.257, 0), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("MainBlade_3", "Part", Vector3.new(1, 0.2, 24), CFrame.new(0, 2.881, -9.855) * CFrame.Angles(0, 0, 0), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("MainBlade_4", "Part", Vector3.new(1, 0.2, 24), CFrame.new(-11.413, 2.881, -1.563) * CFrame.Angles(0, 1.257, 0), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("MainBlade_5", "Part", Vector3.new(1, 0.2, 24), CFrame.new(-7.053, 2.881, 11.853) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("TailRotorHub", "Part", Vector3.new(1.2, 0.6, 0.6), CFrame.new(11.924, 6.381, -15.289) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Cylinder)
    createPart("TailBlade_1", "Part", Vector3.new(0.2, 6, 0.5), CFrame.new(13.047, 4.881, -17.684) * CFrame.Angles(1.134, -0.298, -2.580), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("TailBlade_2", "Part", Vector3.new(0.2, 6, 0.5), CFrame.new(9.993, 4.881, -13.481) * CFrame.Angles(-1.134, -0.298, 2.580), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("TailBlade_3", "Part", Vector3.new(0.2, 6, 0.5), CFrame.new(11.520, 9.381, -15.582) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("BenchBaseA", "Part", Vector3.new(2, 0.5, 18), CFrame.new(5.183, -6.869, 0.966) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)

    createPart("PassengerSeat_A1", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(0.774, -6.369, 7.034) * CFrame.Angles(0, 0.942, 0), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_A2", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(2.538, -6.369, 4.607) * CFrame.Angles(0, 0.942, 0), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_A3", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(4.301, -6.369, 2.180) * CFrame.Angles(0, 0.942, 0), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_A4", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(6.064, -6.369, -0.247) * CFrame.Angles(0, 0.942, 0), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_A5", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(7.828, -6.369, -2.675) * CFrame.Angles(0, 0.942, 0), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_A6", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(9.591, -6.369, -5.102) * CFrame.Angles(0, 0.942, 0), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("BenchBaseB", "Part", Vector3.new(2, 0.5, 18), CFrame.new(-0.480, -6.869, -3.148) * CFrame.Angles(-3.142, 0.628, -3.142), Color3.fromRGB(80, 80, 85), Enum.Material.Metal, 0, Enum.PartType.Block)
    createPart("PassengerSeat_B1", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(-4.889, -6.369, 2.919) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_B2", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(-3.125, -6.369, 0.492) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_B3", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(-1.362, -6.369, -1.935) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_B4", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(0.401, -6.369, -4.362) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_B5", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(2.165, -6.369, -6.789) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)
    createPart("PassengerSeat_B6", "Seat", Vector3.new(2, 0.5, 2), CFrame.new(3.928, -6.369, -9.216) * CFrame.Angles(-3.142, -0.942, -3.142), Color3.fromRGB(120, 110, 90), Enum.Material.Fabric, 0, Enum.PartType.Block)

    return model, floorPart
end


----------------------------------------------------------------
-- ХОСТ-ЗОНЫ И ЛОГИКА
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
    if currentHost then
        currentHost:SetAttribute("IsHost", false)
    end
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
    if currentHost == plr then
        setHost(nil)
    end
end)

local function makeHostZone(parent, floorPart)
    local zone = Instance.new("Part")
    zone.Name         = "HostZone"
    zone.Size         = Vector3.new(6, 0.5, 6)
    zone.Anchored     = true
    zone.CanCollide   = false
    zone.Material     = Enum.Material.Neon
    zone.Color        = NO_HOST_COLOR
    zone.Transparency = 0.4
    zone.TopSurface    = Enum.SurfaceType.Smooth
    zone.BottomSurface = Enum.SurfaceType.Smooth

    local floorYRot = math.rad(floorPart.Orientation.Y)
    zone.CFrame = CFrame.new(floorPart.Position + Vector3.new(0, floorPart.Size.Y * 0.5 + 0.25, 0))
        * CFrame.Angles(0, floorYRot, 0)
    zone.Parent = parent


    local pl = Instance.new("PointLight")
    pl.Color      = NO_HOST_COLOR
    pl.Brightness = 1.2
    pl.Range      = 14
    pl.Parent     = zone

    local bb = Instance.new("BillboardGui")
    bb.Name           = "HostLabel"
    bb.Size           = UDim2.new(0, 200, 0, 40)
    bb.StudsOffset    = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.Parent         = zone

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text                   = "HOST ZONE"
    label.TextColor3             = Color3.fromRGB(240, 240, 240)
    label.TextStrokeTransparency = 0.2
    label.Font                   = Enum.Font.GothamBold
    label.TextScaled             = true
    label.Parent                 = bb

    zone.Touched:Connect(function(hit)
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local plr = Players:GetPlayerFromCharacter(char)
        if not plr then return end

        local now  = os.clock()
        local prev = touchDebounce[plr]
        if prev and now - prev < 0.5 then return end
        touchDebounce[plr] = now

        setHost(plr)
    end)

    table.insert(hostZones, zone)
    return zone
end


----------------------------------------------------------------
-- СПАВН 5 ВЕРТОЛЁТОВ ПО КРУГУ
----------------------------------------------------------------
do
    local heliFolder = Instance.new("Folder")
    heliFolder.Name   = "Helicopters"
    heliFolder.Parent = lobby

    local LOCAL_FORWARD_OFFSET = 0.628

    for i = 1, CFG.HELI_COUNT do
        local phi   = (i - 1) / CFG.HELI_COUNT * math.pi * 2
        local px    = math.sin(phi) * CFG.HELI_RADIUS
        local pz    = math.cos(phi) * CFG.HELI_RADIUS
        local theta = phi - math.pi + LOCAL_FORWARD_OFFSET

        local spawnCFrame = CFrame.new(px, CFG.HELI_HEIGHT, pz)
            * CFrame.Angles(0, theta, 0)

        local model, floorPart = buildHelicopter(spawnCFrame, heliFolder, i)
        if floorPart then
            makeHostZone(model, floorPart)
        else
            warn(("[LobbyGenerator] Helicopter_%d: Floor not found"):format(i))
        end
    end
end

syncZoneColors()

print(("[LobbyGenerator] Done: %d helis, %d buildings, %d debris.")
    :format(CFG.HELI_COUNT, CFG.BUILDING_COUNT, CFG.DEBRIS_COUNT))
