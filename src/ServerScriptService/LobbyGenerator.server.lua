--[[
    LobbyGenerator.server.lua  (v2 — realistic ruined city)
    Помести в ServerScriptService.

    Что внутри:
      * Игровая зона (radius 150) ограждена невидимой стеной.
      * За стеной — мрачный мегаполис: реальные небоскрёбы с фасадами
        и светящимися окнами, обрушенными верхушками, неоновыми пожарами.
      * Внутри зоны — 5 вертолётов (кабинами к центру), хост-зоны на полу.
      * Атмосфера сумерек.
]]

local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")
local Players   = game:GetService("Players")

----------------------------------------------------------------
-- КОНФИГ
----------------------------------------------------------------
local CFG = {
    BASE_PLATE_SIZE   = 1500,

    -- Игровая зона (где может ходить игрок)
    PLAY_RADIUS       = 150,
    WALL_HEIGHT       = 300,
    WALL_SEGMENTS     = 24,

    -- Вертолёты
    HELI_COUNT        = 5,
    HELI_RADIUS       = 110,
    HELI_HEIGHT       = 12,

    -- Город
    CITY_INNER_R      = 175,   -- сразу за стеной
    CITY_OUTER_R      = 520,
    CITY_RING_COUNT   = 4,     -- сколько колец зданий
    BUILDINGS_PER_RING= 14,    -- по умолчанию

    -- Мусор (только в игровой зоне)
    DEBRIS_COUNT      = 160,
    REBAR_COUNT       = 25,

    SEED              = 4242,
}

local NO_HOST_COLOR = Color3.fromRGB(70, 255, 110)
local HOST_COLOR    = Color3.fromRGB(70, 140, 255)

math.randomseed(CFG.SEED)

----------------------------------------------------------------
-- ХЕЛПЕРЫ
----------------------------------------------------------------
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
end

local lobby = Instance.new("Model")
lobby.Name = "ZombieLobby"
lobby.Parent = Workspace

----------------------------------------------------------------
-- АТМОСФЕРА
----------------------------------------------------------------
do
    Lighting.ClockTime            = 17.4
    Lighting.GeographicLatitude   = 41
    Lighting.Brightness           = 1.7
    Lighting.GlobalShadows        = true
    Lighting.ShadowSoftness       = 0.5
    Lighting.ExposureCompensation = -0.05
    Lighting.Ambient              = Color3.fromRGB(70, 65, 75)
    Lighting.OutdoorAmbient       = Color3.fromRGB(95, 90, 100)
    Lighting.ColorShift_Top       = Color3.fromRGB(50, 35, 30)
    Lighting.ColorShift_Bottom    = Color3.fromRGB(20, 22, 28)
    Lighting.FogStart             = 150
    Lighting.FogEnd               = 750
    Lighting.FogColor             = Color3.fromRGB(95, 85, 80)

    for _, child in ipairs(Lighting:GetChildren()) do
        if child.Name:sub(1,4) == "Apoc" then child:Destroy() end
    end

    local atmos = Instance.new("Atmosphere")
    atmos.Name    = "ApocAtmosphere"
    atmos.Density = 0.45
    atmos.Offset  = 0.25
    atmos.Color   = Color3.fromRGB(165, 145, 135)
    atmos.Decay   = Color3.fromRGB(85, 70, 65)
    atmos.Glare   = 0.4
    atmos.Haze    = 2.0
    atmos.Parent  = Lighting

    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name       = "ApocColorCorrection"
    cc.Brightness = 0.0
    cc.Contrast   = 0.12
    cc.Saturation = -0.20
    cc.TintColor  = Color3.fromRGB(225, 215, 205)
    cc.Parent     = Lighting

    local bloom = Instance.new("BloomEffect")
    bloom.Name      = "ApocBloom"
    bloom.Intensity = 0.55
    bloom.Size      = 24
    bloom.Threshold = 0.85
    bloom.Parent    = Lighting
end

----------------------------------------------------------------
-- ЗЕМЛЯ
----------------------------------------------------------------
makePart({
    Name     = "GroundPlate",
    Size     = Vector3.new(CFG.BASE_PLATE_SIZE, 4, CFG.BASE_PLATE_SIZE),
    CFrame   = CFrame.new(0, -2, 0),
    Material = Enum.Material.Concrete,
    Color    = Color3.fromRGB(50, 48, 46),
}, lobby)

-- Тёмная "асфальтовая" заплатка под игровой зоной
makePart({
    Name     = "PlayPad",
    Size     = Vector3.new(CFG.PLAY_RADIUS * 2 + 10, 0.2, CFG.PLAY_RADIUS * 2 + 10),
    CFrame   = CFrame.new(0, 0.1, 0),
    Material = Enum.Material.Slate,
    Color    = Color3.fromRGB(45, 43, 42),
}, lobby)

----------------------------------------------------------------
-- НЕВИДИМАЯ СТЕНА (24 сегмента вокруг игровой зоны)
----------------------------------------------------------------
do
    local wallFolder = Instance.new("Folder")
    wallFolder.Name = "InvisibleWall"
    wallFolder.Parent = lobby

    local segs = CFG.WALL_SEGMENTS
    local R = CFG.PLAY_RADIUS
    local segLen = 2 * R * math.sin(math.pi / segs) * 1.05  -- лёгкий нахлёст

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
            CanCollide   = true,
            Material     = Enum.Material.SmoothPlastic,
            Color        = Color3.fromRGB(255, 0, 0),  -- не видно при transparency=1
        }, wallFolder)
        p.CastShadow = false
    end
end


----------------------------------------------------------------
-- МУСОР (только в игровой зоне, чтоб не лез в стену)
----------------------------------------------------------------
do
    local folder = Instance.new("Folder")
    folder.Name = "Debris"; folder.Parent = lobby

    local mats = {
        Enum.Material.Concrete, Enum.Material.CorrodedMetal,
        Enum.Material.Slate, Enum.Material.Brick, Enum.Material.Concrete,
    }
    local cols = {
        Color3.fromRGB(80, 78, 75), Color3.fromRGB(95, 95, 95),
        Color3.fromRGB(110, 90, 65), Color3.fromRGB(60, 60, 62),
        Color3.fromRGB(75, 65, 55),
    }

    for i = 1, CFG.DEBRIS_COUNT do
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

    for i = 1, CFG.REBAR_COUNT do
        local angle = math.random() * math.pi * 2
        local r = rnd(30, CFG.PLAY_RADIUS - 10)
        makePart({
            Shape = Enum.PartType.Cylinder,
            Name = "Rebar",
            Size = Vector3.new(rnd(3, 6), 0.3, 0.3),
            CFrame = CFrame.new(math.cos(angle)*r, 0.3, math.sin(angle)*r)
                * CFrame.Angles(math.rad(rnd(-20,20)), math.rad(rnd(0,360)), math.rad(rnd(70,110))),
            Material = Enum.Material.CorrodedMetal,
            Color    = Color3.fromRGB(115, 85, 55),
        }, folder)
    end
end


----------------------------------------------------------------
-- НЕБОСКРЁБ — реалистичное здание с фасадом и окнами
----------------------------------------------------------------
local CONCRETE_COLS = {
    Color3.fromRGB(58, 56, 54),
    Color3.fromRGB(68, 64, 60),
    Color3.fromRGB(75, 72, 68),
    Color3.fromRGB(50, 50, 52),
    Color3.fromRGB(82, 75, 65),
}
local WINDOW_DARK   = Color3.fromRGB(20, 25, 35)
local WINDOW_DIM    = Color3.fromRGB(60, 80, 110)
local WINDOW_FIRE   = Color3.fromRGB(255, 130, 50)
local WINDOW_BLUE   = Color3.fromRGB(80, 130, 200)

local FLOOR_HEIGHT  = 4

-- Создаёт ленту окон вдоль фасада здания
-- baseCFrame: центр фасада (на поверхности), нормаль -Z в локальных
-- width:      ширина фасада
-- floors:     этажей в фасаде
-- startY:     y нижнего края фасада (мировой)
-- height:     общая высота фасада
local function makeFacade(parent, baseCFrame, width, floors, startY, height, bodyColor)
    -- Тонкие межэтажные плиты (тёмные горизонтальные полосы)
    local floorH = height / floors
    for f = 0, floors - 1 do
        local yOff = (f + 0.5) * floorH - height * 0.5
        -- Полоса окна (Neon, тёмно-синие)
        local windowColor = WINDOW_DIM
        local lit = math.random()
        if lit < 0.05 then
            windowColor = WINDOW_FIRE       -- горящее окно
        elseif lit < 0.15 then
            windowColor = WINDOW_BLUE       -- ярко-синее (ещё работающее)
        elseif lit < 0.55 then
            windowColor = WINDOW_DARK       -- разбитое/мёртвое
        end

        local strip = makePart({
            Name = "WindowStrip",
            Size = Vector3.new(width - 1.2, floorH * 0.55, 0.2),
            CFrame = baseCFrame * CFrame.new(0, yOff, 0.05),
            Material = Enum.Material.Neon,
            Color = windowColor,
            Transparency = (windowColor == WINDOW_DARK) and 0.0 or 0.15,
        }, parent)

        -- Делаем "разбитые" окна более тусклыми: иногда добавляем PointLight
        if windowColor == WINDOW_FIRE and chance(0.7) then
            local pl = Instance.new("PointLight")
            pl.Color = WINDOW_FIRE
            pl.Range = 18
            pl.Brightness = 1.6 + math.random()
            pl.Parent = strip
        elseif windowColor == WINDOW_BLUE and chance(0.5) then
            local pl = Instance.new("PointLight")
            pl.Color = WINDOW_BLUE
            pl.Range = 12
            pl.Brightness = 0.8
            pl.Parent = strip
        end

        -- Тонкая бетонная плита между этажами
        makePart({
            Name = "FloorBand",
            Size = Vector3.new(width, floorH * 0.45, 0.3),
            CFrame = baseCFrame * CFrame.new(0, yOff - floorH * 0.5, 0),
            Material = Enum.Material.Concrete,
            Color = bodyColor,
        }, parent)

        -- Вертикальные "колонны" между окнами (~3 на фасад)
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


-- Главная функция: построить небоскрёб
-- centerXZ: Vector2-like {x, z}, footprint: ширина по X и Z, height: общая высота
-- yawRad:   поворот здания вокруг Y (чтобы фасад смотрел на центр лобби)
local function buildSkyscraper(centerX, centerZ, sizeX, sizeZ, height, yawRad, parent)
    local model = Instance.new("Model")
    model.Name = "Skyscraper"
    model.Parent = parent

    local bodyColor = pick(CONCRETE_COLS)
    local cf0 = CFrame.new(centerX, 0, centerZ) * CFrame.Angles(0, yawRad, 0)

    -- Основное тело — высокий бокс
    local bodyHeight = height
    local damageTop  = chance(0.55)              -- срезанная верхушка
    local damageSide = chance(0.20)              -- обвал сбоку

    -- если "обвал сбоку", вторая половина здания ниже
    local bodyHeightLeft  = bodyHeight
    local bodyHeightRight = bodyHeight
    if damageSide then
        if chance(0.5) then bodyHeightRight = bodyHeight * rnd(0.4, 0.7)
        else                bodyHeightLeft  = bodyHeight * rnd(0.4, 0.7) end
    end

    -- Делим здание на 2 половины по X (чтобы можно было одну "обрушить")
    local halfX = sizeX * 0.5
    local quartX = sizeX * 0.25

    local function buildHalf(offsetX, h, width)
        if h < FLOOR_HEIGHT * 2 then return end
        local floors = math.max(2, math.floor(h / FLOOR_HEIGHT))
        local realH = floors * FLOOR_HEIGHT

        -- Тело (тёмный бетон)
        makePart({
            Name = "Body",
            Size = Vector3.new(width, realH, sizeZ),
            CFrame = cf0 * CFrame.new(offsetX, realH * 0.5, 0),
            Material = Enum.Material.Concrete,
            Color = bodyColor,
        }, model)

        -- 4 фасада — рисуем окна на каждом
        -- Front (+Z), Back (-Z), Left (-X), Right (+X)
        local frontCF = cf0 * CFrame.new(offsetX, realH * 0.5, sizeZ * 0.5 + 0.1)
        local backCF  = cf0 * CFrame.new(offsetX, realH * 0.5, -sizeZ * 0.5 - 0.1)
                          * CFrame.Angles(0, math.pi, 0)
        local leftCF  = cf0 * CFrame.new(offsetX - width * 0.5 - 0.1, realH * 0.5, 0)
                          * CFrame.Angles(0, -math.pi * 0.5, 0)
        local rightCF = cf0 * CFrame.new(offsetX + width * 0.5 + 0.1, realH * 0.5, 0)
                          * CFrame.Angles(0,  math.pi * 0.5, 0)

        makeFacade(model, frontCF, width, floors, 0, realH, bodyColor)
        makeFacade(model, backCF,  width, floors, 0, realH, bodyColor)
        makeFacade(model, leftCF,  sizeZ, floors, 0, realH, bodyColor)
        makeFacade(model, rightCF, sizeZ, floors, 0, realH, bodyColor)

        return realH
    end

    local realLeft  = buildHalf(-quartX, bodyHeightLeft,  halfX)
    local realRight = buildHalf( quartX, bodyHeightRight, halfX)

    -- Основание (расширенная база для устойчивого вида)
    makePart({
        Name = "Base",
        Size = Vector3.new(sizeX + 4, 4, sizeZ + 4),
        CFrame = cf0 * CFrame.new(0, 2, 0),
        Material = Enum.Material.Concrete,
        Color = Color3.fromRGB(45, 43, 42),
    }, model)


    -- Повреждение верхушки: куски бетона торчат сверху и торчащая арматура
    if damageTop then
        local topY = math.max(realLeft or 0, realRight or 0)
        for i = 1, math.random(5, 10) do
            local rx = rnd(-halfX * 0.9, halfX * 0.9)
            local rz = rnd(-sizeZ * 0.4, sizeZ * 0.4)
            local rs = rnd(1.5, 3.5)
            makePart({
                Name = "Rubble",
                Size = Vector3.new(rs, rnd(1, 3), rs),
                CFrame = cf0 * CFrame.new(rx, topY + rnd(0, 2), rz)
                    * CFrame.Angles(math.rad(rnd(-40,40)), math.rad(rnd(0,360)), math.rad(rnd(-40,40))),
                Material = Enum.Material.Concrete,
                Color = pick(CONCRETE_COLS),
            }, model)
        end
        -- Торчащая арматура
        for i = 1, math.random(2, 5) do
            local rx = rnd(-halfX * 0.9, halfX * 0.9)
            local rz = rnd(-sizeZ * 0.4, sizeZ * 0.4)
            makePart({
                Shape = Enum.PartType.Cylinder,
                Name = "Rebar",
                Size = Vector3.new(rnd(2, 5), 0.2, 0.2),
                CFrame = cf0 * CFrame.new(rx, topY + rnd(0.5, 3), rz)
                    * CFrame.Angles(math.rad(rnd(-30,30)), math.rad(rnd(0,360)), math.rad(rnd(60,120))),
                Material = Enum.Material.CorrodedMetal,
                Color    = Color3.fromRGB(110, 85, 55),
            }, model)
        end
    end

    -- Большой "пожар" внутри здания иногда виден через окна
    if chance(0.30) then
        local fireY = rnd(FLOOR_HEIGHT * 2, math.min(realLeft or 30, realRight or 30) - 4)
        local pl = Instance.new("PointLight")
        pl.Color = WINDOW_FIRE
        pl.Range = 32
        pl.Brightness = 2.5
        local emb = makePart({
            Name = "InteriorFire",
            Size = Vector3.new(2, 2, 2),
            CFrame = cf0 * CFrame.new(rnd(-halfX*0.4, halfX*0.4), fireY, 0),
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
-- РАССТАНОВКА ГОРОДА: концентрические кольца зданий
----------------------------------------------------------------
do
    local cityFolder = Instance.new("Folder")
    cityFolder.Name = "City"
    cityFolder.Parent = lobby

    -- 4 кольца зданий: ближнее с самыми высокими (как Манхэттен)
    -- ring index 1..N: радиус и высота
    local rings = {
        { r = 180,  count = 14, hMin = 90,  hMax = 180, sxMin = 22, sxMax = 38 }, -- передний ряд - небоскрёбы
        { r = 250,  count = 16, hMin = 70,  hMax = 140, sxMin = 24, sxMax = 40 },
        { r = 340,  count = 18, hMin = 50,  hMax = 110, sxMin = 22, sxMax = 38 },
        { r = 450,  count = 22, hMin = 30,  hMax = 80,  sxMin = 20, sxMax = 36 }, -- дальний фон
    }

    for ringIdx, ring in ipairs(rings) do
        for i = 1, ring.count do
            -- Базовый угол + лёгкое случайное смещение, чтобы не было идеального круга
            local base  = (i - 1) / ring.count * math.pi * 2
            local jitterAng = rnd(-0.04, 0.04)
            local angle = base + jitterAng

            local r  = ring.r + rnd(-15, 15)
            local x  = math.cos(angle) * r
            local z  = math.sin(angle) * r

            local sizeX = rnd(ring.sxMin, ring.sxMax)
            local sizeZ = rnd(ring.sxMin * 0.85, ring.sxMax * 0.85)
            local h     = rnd(ring.hMin, ring.hMax)

            -- Здание развёрнуто фасадом к центру (yaw указывает наружу — фасад смотрит внутрь)
            local yaw = angle + math.pi * 0.5  -- ось X фасада касательна окружности

            -- Чтобы здание смотрело фасадом на игрока, повернём так,
            -- чтобы +Z (фронт) направлен в центр
            yaw = math.atan2(-x, -z)

            buildSkyscraper(x, z, sizeX, sizeZ, h, yaw, cityFolder)
        end
    end

    -- Несколько "случайных" зданий между кольцами для плотности
    for i = 1, 25 do
        local angle = math.random() * math.pi * 2
        local r = rnd(210, 480)
        local x = math.cos(angle) * r
        local z = math.sin(angle) * r
        local sx = rnd(18, 30)
        local sz = rnd(18, 30)
        local h  = rnd(40, 130)
        local yaw = math.atan2(-x, -z) + rnd(-0.3, 0.3)
        buildSkyscraper(x, z, sx, sz, h, yaw, cityFolder)
    end

    -- Несколько полностью обрушенных зданий — низкие груды на земле
    for i = 1, 14 do
        local angle = math.random() * math.pi * 2
        local r = rnd(180, 470)
        local cx = math.cos(angle) * r
        local cz = math.sin(angle) * r
        local pile = Instance.new("Model")
        pile.Name = "CollapsedBuilding"
        pile.Parent = cityFolder
        for k = 1, math.random(8, 16) do
            local px = cx + rnd(-15, 15)
            local pz = cz + rnd(-15, 15)
            local sx = rnd(4, 10); local sy = rnd(2, 6); local sz = rnd(4, 10)
            makePart({
                Name = "RubbleBig",
                Size = Vector3.new(sx, sy, sz),
                CFrame = CFrame.new(px, sy * 0.4, pz)
                    * CFrame.Angles(math.rad(rnd(-25,25)), math.rad(rnd(0,360)), math.rad(rnd(-25,25))),
                Material = Enum.Material.Concrete,
                Color = pick(CONCRETE_COLS),
            }, pile)
        end
    end
end


----------------------------------------------------------------
-- ВЕРТОЛЁТ
----------------------------------------------------------------
local function buildHelicopter(spawnCFrame, parent, idx)
    local model = Instance.new("Model")
    model.Name = "Helicopter_" .. idx
    model.Parent = parent

    local floorPart = nil

    local function createPart(name, className, size, relCFrame, color, material, transparency, shape)
        local p = Instance.new(className)
        p.Name = name
        p.Size = size
        p.CFrame = spawnCFrame * relCFrame
        p.Color = color
        p.Material = material
        p.Transparency = transparency
        p.Anchored = true
        p.CanCollide = true
        if className == "Part" and shape then p.Shape = shape end
        p.Parent = model
        if name == "Floor" and not floorPart then floorPart = p end
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
-- ХОСТ-ЗОНЫ
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
    zone.Size = Vector3.new(6, 0.5, 6)
    zone.Anchored = true
    zone.CanCollide = false
    zone.Material = Enum.Material.Neon
    zone.Color = NO_HOST_COLOR
    zone.Transparency = 0.4
    zone.TopSurface    = Enum.SurfaceType.Smooth
    zone.BottomSurface = Enum.SurfaceType.Smooth

    local floorYRot = math.rad(floorPart.Orientation.Y)
    zone.CFrame = CFrame.new(floorPart.Position + Vector3.new(0, floorPart.Size.Y * 0.5 + 0.25, 0))
        * CFrame.Angles(0, floorYRot, 0)
    zone.Parent = parent

    local pl = Instance.new("PointLight")
    pl.Color = NO_HOST_COLOR; pl.Brightness = 1.2; pl.Range = 14
    pl.Parent = zone

    local bb = Instance.new("BillboardGui")
    bb.Name = "HostLabel"; bb.Size = UDim2.new(0, 200, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true
    bb.LightInfluence = 0; bb.Parent = zone
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0); label.BackgroundTransparency = 1
    label.Text = "HOST ZONE"; label.TextColor3 = Color3.fromRGB(240,240,240)
    label.TextStrokeTransparency = 0.2; label.Font = Enum.Font.GothamBold
    label.TextScaled = true; label.Parent = bb

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
-- СПАВН ВЕРТОЛЁТОВ ПО КРУГУ — кабины РАЗВЁРНУТЫ К ЦЕНТРУ (180° правка)
----------------------------------------------------------------
do
    local heliFolder = Instance.new("Folder")
    heliFolder.Name = "Helicopters"
    heliFolder.Parent = lobby

    -- Локальный forward вертолёта (-0.587, 0, 0.809) — поворот +0.628 от +Z.
    -- Чтобы кабина смотрела ОТ центра -> theta = phi + 0.628.
    -- Чтобы кабина смотрела В центр  -> theta = phi - π + 0.628 (это была старая версия).
    -- Юзер сказал, что нужно развернуть на 180° -> theta = phi + 0.628
    local LOCAL_FORWARD_OFFSET = 0.628

    for i = 1, CFG.HELI_COUNT do
        local phi   = (i - 1) / CFG.HELI_COUNT * math.pi * 2
        local px    = math.sin(phi) * CFG.HELI_RADIUS
        local pz    = math.cos(phi) * CFG.HELI_RADIUS
        local theta = phi + LOCAL_FORWARD_OFFSET   -- ← разворот на 180° относительно прошлой версии

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

print(("[LobbyGenerator v2] Done. Helis: %d, play radius: %d, walls: %d.")
    :format(CFG.HELI_COUNT, CFG.PLAY_RADIUS, CFG.WALL_SEGMENTS))
