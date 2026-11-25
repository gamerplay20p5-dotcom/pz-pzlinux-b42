require "PZLinuxConfig"
require "AAA_PZLinuxCompat"
require "PZLinuxEconomy"
require "PZLinuxLocalMarket"
require "Vehicles/ISUI/ISUI3DScene"

-- UI client do Mercado Local.
-- Este arquivo cuida apenas da tela, botoes, listas e respostas do server.
-- As regras compartilhadas ficam em shared/PZLinuxLocalMarket.lua.
PZLinuxLocalMarketClient = PZLinuxLocalMarketClient or {}
PZLinuxLocalMarketClient.Data = PZLinuxLocalMarketClient.Data or { listings = {} }
PZLinuxLocalMarketInstance = PZLinuxLocalMarketInstance or nil

local MODULE = PZLinuxModule or "PZLinux"

-- Ajuste estes valores para reposicionar as pre-visualizacoes sem tocar no restante da UI.
-- x/y/z movem o objeto no preview 3D seguro da B42.20.
-- A previa 3D de itens foi removida de proposito: na .19 ela gerava erros
-- no prerender. Mantemos somente o veiculo 3D.
PZLinuxLocalMarketPreviewConfig = PZLinuxLocalMarketPreviewConfig or {
    vehicle = {
        x = 0,
        y = 0,
        z = -0.28,
        zoom = 6.50,
        maxZoom = 30,
        rotateStep = 0.35,
    },
}

local function marketCommand(command, args)
    args = args or {}
    if command == "RequestLocalMarket" and not args.force and PZLinuxSendClientCommandThrottled then
        PZLinuxSendClientCommandThrottled(MODULE, command, args or {}, 5000)
    elseif sendClientCommand then
        sendClientCommand(MODULE, command, args or {})
    end
end

-- Som do mercado emite no mundo perto do jogador. Falhas aqui nao devem travar UI.
local function playMarketSound(player, soundName)
    if not player or not soundName or soundName == "" then
        return
    end
    local square = player.getSquare and player:getSquare() or nil
    if not square then
        return
    end
    local sound = getSoundManager():PlayWorldSound(soundName, false, square, 0, 20, 1, true)
    if sound and sound.setVolume then
        sound:setVolume(getCore():getOptionSoundVolume() / 50)
    end
end

-- ListBox do PZ guarda a linha selecionada em items[selected].item.
local function getSelectedItem(listBox)
    if not listBox or not listBox.items or not listBox.selected then
        return nil
    end
    local row = listBox.items[listBox.selected]
    return row and row.item or nil
end

-- Botao padrao verde estilo terminal antigo.
local function addGreenButton(parent, x, y, w, h, label, target, onclick)
    local button = ISButton:new(x, y, w, h, label, target, onclick)
    button.backgroundColor = { r = 0, g = 0, b = 0, a = 0.55 }
    button.borderColor = { r = 0, g = 0.5, b = 0, a = 0.7 }
    button.textColor = { r = 0, g = 1, b = 0, a = 1 }
    button:initialise()
    parent:addChild(button)
    return button
end

-- Retangulo util dentro da textura do computador. A UI e posicionada relativa
-- a essa area para continuar alinhada em resolucoes diferentes.
local function getTerminalScreenRect(width, height)
    return {
        x = math.floor(width * 0.125),
        y = math.floor(height * 0.12),
        w = math.floor(width * 0.73),
        h = math.floor(height * 0.515),
    }
end

-- Escala a textura do PC sem ultrapassar a tela real.
local function getResponsiveTerminalSize(texture)
    local realScreenW = getCore():getScreenWidth()
    local realScreenH = getCore():getScreenHeight()
    local maxW = realScreenW * 0.86
    local maxH = realScreenH * 0.90
    local scale = math.min(maxW / texture:getWidth(), maxH / texture:getHeight())
    return realScreenW, realScreenH, math.floor(texture:getWidth() * scale), math.floor(texture:getHeight() * scale)
end

-- Estilo visual reutilizado nas listas do mercado.
local function styleListBox(list)
    list.backgroundColor = { r = 0, g = 0, b = 0, a = 0.86 }
    list.borderColor = { r = 0, g = 0.45, b = 0, a = 0.7 }
    list.font = UIFont.Small
end

-- Painel de fundo simples usado como moldura das secoes.
local function addPanelBox(parent, x, y, w, h)
    local panel = ISPanel:new(x, y, math.max(1, w), math.max(1, h))
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.48 }
    panel.borderColor = { r = 0, g = 0.42, b = 0, a = 0.72 }
    panel:initialise()
    parent:addChild(panel)
    return panel
end

-- Campos de texto do terminal usam fundo escuro e borda verde.
local function styleTextEntry(entry)
    if not entry then
        return
    end
    entry.backgroundColor = { r = 0, g = 0, b = 0, a = 0.72 }
    entry.borderColor = { r = 0, g = 0.45, b = 0, a = 0.7 }
end

local function setElementVisible(element, visible)
    if element and element.setVisible then
        element:setVisible(visible and true or false)
    end
end

local function setElementsVisible(elements, visible)
    for _, element in pairs(elements or {}) do
        setElementVisible(element, visible)
    end
end

local function fitTextToWidth(text, font, maxWidth)
    text = tostring(text or "")
    if not maxWidth or maxWidth <= 0 then return "" end

    local textManager = getTextManager()
    if textManager:MeasureStringX(font, text) <= maxWidth then
        return text
    end

    local suffix = "..."
    local low, high = 0, #text
    while low < high do
        local middle = math.ceil((low + high) / 2)
        if textManager:MeasureStringX(font, text:sub(1, middle) .. suffix) <= maxWidth then
            low = middle
        else
            high = middle - 1
        end
    end
    return text:sub(1, low) .. suffix
end

-- Quebra linhas sem deixar texto vazar do painel de detalhes.
local function wrapTextToWidth(text, font, maxWidth)
    text = tostring(text or "")
    if text == "" then return { "" } end

    local lines = {}
    local current = ""
    for word in text:gmatch("%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if getTextManager():MeasureStringX(font, candidate) <= maxWidth then
            current = candidate
        else
            if current ~= "" then table.insert(lines, current) end
            current = fitTextToWidth(word, font, maxWidth)
        end
    end
    if current ~= "" then table.insert(lines, current) end
    return #lines > 0 and lines or { "" }
end

-- Converte os campos do formulario para valor unico em dinheiro vanilla.
-- Campo 1 = Base.MoneyBundle (100), campo 2 = Base.Money (1), campo 3 = extra solto.
local function coinFieldsToValue(goldField, silverField, copperField)
    local bundles = math.max(0, math.floor(tonumber(goldField and goldField:getText() or 0) or 0))
    local money = math.max(0, math.floor(tonumber(silverField and silverField:getText() or 0) or 0))
    local extra = math.max(0, math.floor(tonumber(copperField and copperField:getText() or 0) or 0))
    local value = (bundles * 100) + money + extra
    return PZLinuxLocalMarket.normalizePrice(value)
end

-- Data curta para caber na lista/detalhes do terminal.
local function formatDate(createdAt)
    local value = tonumber(createdAt)
    if not value or value <= 0 then
        return "-"
    end
    if os and os.date then
        local ok, text = pcall(function()
            return os.date("%d/%m %H:%M", value)
        end)
        if ok and text then
            return tostring(text)
        end
    end
    return tostring(math.floor(value))
end

-- Mensagem local quando uma venda e creditada para o jogador.
local function formatSaleNotice(notice)
    if type(notice) ~= "table" then
        return ""
    end

    return PZLinuxText(
        "UI_PZLinux_LocalMarketSoldNotice",
        "Sold %1 to %2 for %3",
        tostring(notice.itemName or "?"),
        tostring(notice.buyer or "?"),
        PZLinuxFormatCurrency(notice.amount or 0)
    )
end

-- Aplica creditos vindos do server e atualiza a UI aberta, se existir.
local function showSaleNotice(notice)
    local player = getPlayer()
    if not player or type(notice) ~= "table" then
        return
    end

    if tonumber(notice.balance) then
        local modData = PZLinuxGetModData(player)
        if modData then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(notice.balance) or 0))
        end
    end

    local text = formatSaleNotice(notice)
    if text ~= "" then
        playMarketSound(player, "sold")
        HaloTextHelper.addGoodText(player, text)
        if PZLinuxLocalMarketInstance and PZLinuxLocalMarketInstance.setNotice then
            PZLinuxLocalMarketInstance:setNotice(text)
            PZLinuxLocalMarketInstance:refreshAll()
        end
    end
end

-- Classe principal da janela. Ela herda ISPanel e desenha sobre a imagem do PC.
localMarketUI = ISPanel:derive("localMarketUI")

function localMarketUI:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.width = width
    o.height = height
    o.player = player
    o.selectedSeller = "all"
    o.selectedCategory = "items"
    o.marketView = "home"
    o.sortMode = "date"
    o.marketData = PZLinuxLocalMarketClient.Data or { listings = {} }
    o.isDragging = false
    o.lastVehiclePreviewId = nil
    return o
end

function localMarketUI:initialise()
    ISPanel.initialise(self)

    -- Layout responsivo. Todos os controles sao calculados a partir da area
    -- preta do monitor, nao da janela inteira.
    local screen = getTerminalScreenRect(self.width, self.height)
    self.screenRect = screen
    local sx = screen.x
    local sy = screen.y
    local sw = screen.w
    local sh = screen.h
    local gap = math.max(8, math.floor(sh * 0.018))
    local rowH = math.max(22, math.floor(sh * 0.052))
    local buttonH = math.max(24, math.floor(sh * 0.06))
    local sellerW = math.floor(sw * 0.20)
    local rightX = sx + sellerW + gap
    local rightW = sw - sellerW - gap
    local categoryY = sy + rowH + (gap * 2)
    local filterY = categoryY + rowH + gap
    local listY = filterY + rowH + gap
    local listH = math.max(rowH * 4, math.floor(sh * 0.27))
    local detailY = listY + listH + gap
    local detailH = math.max(rowH * 3, math.floor(sh * 0.19))
    local sellY = detailY + detailH + gap
    local sellButtonY = sy + sh - buttonH
    local sellListY = sellY + rowH + gap
    local sellListH = math.max(34, sellButtonY - gap - sellListY)
    local detailTextW = math.floor(rightW * 0.58)
    local previewX = rightX + detailTextW + gap
    local previewW = rightW - detailTextW - gap
    self.detailX = rightX
    self.detailY = detailY
    self.detailW = detailTextW
    self.detailH = detailH
    self.detailLines = nil
    self.noticeMaxWidth = math.max(80, (sx + sw - 156) - rightX)
    self.balanceMaxWidth = self.noticeMaxWidth

    self.topBar = ISPanel:new(0, 0, self.width, self.height)
    self.topBar.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.topBar.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.topBar:setVisible(true)
    self:addChild(self.topBar)
    self.topBar.parent = self

    function self.topBar:onMouseDown(x, y)
        self.parent.isDragging = true
        self.parent.initialX = self.parent:getX()
        self.parent.initialY = self.parent:getY()
        self.parent.mouseStartX = getMouseX()
        self.parent.mouseStartY = getMouseY()
    end

    function self.topBar:onMouseMove(x, y)
        if self.parent.isDragging then
            self.parent:setX(self.parent.initialX + (getMouseX() - self.parent.mouseStartX))
            self.parent:setY(self.parent.initialY + (getMouseY() - self.parent.mouseStartY))
        end
    end

    function self.topBar:onMouseUp(x, y)
        self.parent.isDragging = false
    end

    self.homeBox = addPanelBox(self.topBar, sx + math.floor(sw * 0.22), sy + math.floor(sh * 0.16), math.floor(sw * 0.56), math.floor(sh * 0.42))
    self.sidebarBox = addPanelBox(self.topBar, sx - 4, sy + rowH + gap, sellerW + 8, sellY - (sy + rowH + gap) - gap)
    self.controlsBox = addPanelBox(self.topBar, rightX - 4, categoryY - 4, rightW + 8, (rowH * 2) + gap + 8)
    self.listBoxFrame = addPanelBox(self.topBar, rightX - 4, listY - 4, rightW + 8, listH + 8)
    self.detailBoxFrame = addPanelBox(self.topBar, rightX - 4, detailY - 4, detailTextW + 8, detailH + 8)
    self.previewBoxFrame = addPanelBox(self.topBar, previewX - 4, detailY - 4, previewW + 8, detailH + 8)
    self.sellBoxFrame = addPanelBox(self.topBar, rightX - 4, sellY - 4, rightW + 8, math.max(buttonH + 8, sellButtonY + buttonH - sellY + 8))

    self.titleLabel = ISLabel:new(sx, sy + 3, rowH, PZLinuxText("UI_PZLinux_LocalMarket", "LOCAL MARKET"), 0, 1, 0, 1, UIFont.Small, true)
    self.titleLabel:initialise()
    self.topBar:addChild(self.titleLabel)

    self.balanceLabel = ISLabel:new(rightX, sy + 3, rowH, "", 0, 1, 0, 1, UIFont.Small, true)
    self.balanceLabel:initialise()
    self.topBar:addChild(self.balanceLabel)

    self.noticeLabel = ISLabel:new(rightX, sy + rowH, rowH, "", 0, 0.78, 0, 1, UIFont.Small, true)
    self.noticeLabel:initialise()
    self.topBar:addChild(self.noticeLabel)

    self.closeButton = addGreenButton(self.topBar, sx + sw - 24, sy + 2, 24, rowH, "x", self, self.onClose)
    self.backButton = addGreenButton(self.topBar, sx + sw - 52, sy + 2, 24, rowH, "-", self, self.onBack)
    self.refreshButton = addGreenButton(self.topBar, sx + sw - 148, sy + 2, 88, rowH, PZLinuxText("UI_PZLinux_Refresh", "Refresh"), self, self.onRefresh)

    local homeButtonW = math.floor(sw * 0.46)
    local homeButtonH = math.max(30, math.floor(sh * 0.082))
    local homeX = sx + math.floor((sw - homeButtonW) / 2)
    local homeY = sy + math.floor(sh * 0.22)
    self.homeItemsButton = addGreenButton(self.topBar, homeX, homeY, homeButtonW, homeButtonH, PZLinuxText("UI_PZLinux_LocalMarketItemsWeapons", "Weapons and Items"), self, function() self:setView("items") end)
    self.homeVehiclesButton = addGreenButton(self.topBar, homeX, homeY + homeButtonH + gap, homeButtonW, homeButtonH, PZLinuxText("UI_PZLinux_LocalMarketVehicles", "Vehicles"), self, function() self:setView("vehicles") end)
    self.homeHelpButton = addGreenButton(self.topBar, homeX, homeY + ((homeButtonH + gap) * 2), homeButtonW, homeButtonH, PZLinuxText("UI_PZLinux_Help", "Help"), self, function() self:setView("help") end)
    self.homeHelpLabel = ISLabel:new(homeX, homeY + ((homeButtonH + gap) * 3) + gap, rowH, PZLinuxText("UI_PZLinux_LocalMarketHomeHelp", "Choose a market section."), 0, 0.78, 0, 1, UIFont.Small, true)
    self.homeHelpLabel:initialise()
    self.topBar:addChild(self.homeHelpLabel)

    self.helpBox = addPanelBox(self.topBar, homeX, homeY, homeButtonW, math.floor(sh * 0.32))
    self.helpPanel = ISRichTextPanel:new(homeX + gap, homeY + gap, homeButtonW - (gap * 2), math.floor(sh * 0.32) - (gap * 2))
    self.helpPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.helpPanel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.helpPanel.autosetheight = false
    self.helpPanel.text = "<GREEN>" .. PZLinuxText("UI_PZLinux_LocalMarketHelpText", "Items and vehicles are listed separately. Refresh updates only this screen.") .. "</GREEN>"
    self.helpPanel:initialise()
    self.helpPanel:instantiate()
    self.helpPanel:paginate()
    self.topBar:addChild(self.helpPanel)

    self.sellerLabel = ISLabel:new(sx, sy + rowH + gap, rowH, PZLinuxText("UI_PZLinux_LocalMarketStores", "Stores"), 0, 1, 0, 1, UIFont.Small, true)
    self.sellerLabel:initialise()
    self.topBar:addChild(self.sellerLabel)

    self.sellerList = ISScrollingListBox:new(sx, listY, sellerW, listH + detailH + gap)
    styleListBox(self.sellerList)
    self.sellerList.itemheight = math.max(20, math.floor(rowH * 0.95))
    self.sellerList:initialise()
    self.sellerList:instantiate()
    self.sellerList.target = self
    self.sellerList.onMouseDown = function(listBox, x, y)
        ISScrollingListBox.onMouseDown(listBox, x, y)
        local selected = getSelectedItem(listBox)
        if selected then
            self.selectedSeller = selected.seller
            self:refreshListings()
        end
    end
    self.topBar:addChild(self.sellerList)

    self.categoryLabel = ISLabel:new(rightX, categoryY, rowH, PZLinuxText("UI_PZLinux_LocalMarketCategory", "Category"), 0, 1, 0, 1, UIFont.Small, true)
    self.categoryLabel:initialise()
    self.topBar:addChild(self.categoryLabel)

    local tabY = categoryY
    local tabX = rightX + math.floor(rightW * 0.16)
    local tabW = math.floor((rightW - (tabX - rightX) - (gap * 3)) / 4)
    self.allButton = addGreenButton(self.topBar, tabX, tabY, tabW, rowH, PZLinuxText("UI_PZLinux_All", "All"), self, function() self:setCategory("all") end)
    self.itemButton = addGreenButton(self.topBar, tabX + (tabW + gap), tabY, tabW, rowH, PZLinuxLocalMarket.categoryText("items"), self, function() self:setCategory("items") end)
    self.foodButton = addGreenButton(self.topBar, tabX + ((tabW + gap) * 2), tabY, tabW, rowH, PZLinuxLocalMarket.categoryText("food"), self, function() self:setCategory("food") end)
    self.weaponButton = addGreenButton(self.topBar, tabX + ((tabW + gap) * 3), tabY, tabW, rowH, PZLinuxLocalMarket.categoryText("weapons"), self, function() self:setCategory("weapons") end)

    self.searchLabel = ISLabel:new(rightX, filterY + 2, rowH, PZLinuxText("UI_PZLinux_Search", "Search"), 0, 1, 0, 1, UIFont.Small, true)
    self.searchLabel:initialise()
    self.topBar:addChild(self.searchLabel)

    local searchX = rightX + math.floor(rightW * 0.16)
    local searchW = math.floor(rightW * 0.44)
    self.searchField = ISTextEntryBox:new("", searchX, filterY, searchW, rowH)
    styleTextEntry(self.searchField)
    self.searchField:initialise()
    self.searchField:instantiate()
    self.searchField:setPlaceholderText(PZLinuxText("UI_PZLinux_Search", "Search"))
    self.searchField.target = self
    self.searchField.onTextChangeFunction = function(target)
        if target and target.refreshListings then
            target:refreshListings()
        end
    end
    self.topBar:addChild(self.searchField)

    self.sortButton = addGreenButton(self.topBar, searchX + searchW + gap, filterY, math.floor(rightW * 0.23), rowH, "", self, self.onSort)

    self.listingList = ISScrollingListBox:new(rightX, listY, rightW, listH)
    styleListBox(self.listingList)
    self.listingList.itemheight = math.max(20, math.floor(rowH * 0.95))
    self.listingList:initialise()
    self.listingList:instantiate()
    self.listingList.onMouseDown = function(listBox, x, y)
        ISScrollingListBox.onMouseDown(listBox, x, y)
        self:updateDetails()
    end
    self.topBar:addChild(self.listingList)

    self.detailLabel = ISLabel:new(rightX, detailY, rowH, "", 0, 1, 0, 1, UIFont.Small, false)
    self.detailLabel:initialise()
    self.topBar:addChild(self.detailLabel)

    -- Previa 3D SOMENTE para veiculos. O wrapper Lua existe em
    -- Vehicles/ISUI/ISUI3DScene.lua e a parte Java aceita comandos via fromLua*.
    if ISUI3DScene then
        local ok, preview = pcall(function()
            local model = ISUI3DScene:new(previewX, detailY, previewW, detailH)
            model.background = true
            model.backgroundColor = { r = 0, g = 0, b = 0, a = 0.82 }
            model.borderColor = { r = 0, g = 0.45, b = 0, a = 0.7 }
            model:initialise()
            model:instantiate()
            model.javaObject:fromLua1("setMaxZoom", PZLinuxLocalMarketPreviewConfig.vehicle.maxZoom or 30)
            model.javaObject:fromLua1("setDrawGrid", false)
            model.javaObject:fromLua1("createVehicle", "vehicle")
            model.javaObject:fromLua1("setZoom", PZLinuxLocalMarketPreviewConfig.vehicle.zoom or 6.50)
            model:setView("Left")
            model.javaObject:fromLua2("setObjectAutoRotate", "vehicle", true)
            model.onMouseDown = function() return true end
            model.onMouseMove = function() end
            model.onMouseUp = function() end
            model.onMouseUpOutside = function() end
            model.onMouseWheel = function() return true end
            return model
        end)
        if ok and preview then
            self.vehiclePreview = preview
            self.topBar:addChild(self.vehiclePreview)
        end
    end

    self.vehiclePreviewLabel = ISLabel:new(previewX + 4, detailY + 4, rowH, "", 0, 0.78, 0, 1, UIFont.Small, true)
    self.vehiclePreviewLabel:initialise()
    self.topBar:addChild(self.vehiclePreviewLabel)

    local buyW = math.floor(rightW * 0.22)
    local buyQuantityW = math.floor(rightW * 0.12)
    self.buyQuantityField = ISTextEntryBox:new("1", rightX, detailY + detailH - buttonH, buyQuantityW, buttonH)
    styleTextEntry(self.buyQuantityField)
    self.buyQuantityField:initialise()
    self.buyQuantityField:instantiate()
    self.buyQuantityField:setOnlyNumbers(true)
    self.buyQuantityField:setPlaceholderText(PZLinuxText("UI_PZLinux_Quantity", "QUANTITY"))
    self.topBar:addChild(self.buyQuantityField)
    self.buyButton = addGreenButton(self.topBar, rightX + buyQuantityW + gap, detailY + detailH - buttonH, buyW, buttonH, PZLinuxText("UI_PZLinux_Buy", "BUY"), self, self.onBuy)
    self.cancelButton = addGreenButton(self.topBar, rightX + buyQuantityW + buyW + (gap * 2), detailY + detailH - buttonH, buyW, buttonH, PZLinuxText("UI_PZLinux_Cancel", "Cancel"), self, self.onCancelListing)

    self.sellLabel = ISLabel:new(sx, sellY, rowH, PZLinuxText("UI_PZLinux_LocalMarketSell", "Sell"), 0, 1, 0, 1, UIFont.Small, true)
    self.sellLabel:initialise()
    self.topBar:addChild(self.sellLabel)

    local quantityW = math.floor(rightW * 0.12)
    local coinW = math.floor(rightW * 0.14)
    local descriptionW = rightW - quantityW - (coinW * 3) - (gap * 4)
    self.itemQuantityField = ISTextEntryBox:new("1", rightX, sellY, quantityW, rowH)
    styleTextEntry(self.itemQuantityField)
    self.itemQuantityField:initialise()
    self.itemQuantityField:instantiate()
    self.itemQuantityField:setOnlyNumbers(true)
    self.itemQuantityField:setPlaceholderText(PZLinuxText("UI_PZLinux_Quantity", "QUANTITY"))
    self.topBar:addChild(self.itemQuantityField)

    local priceX = rightX + quantityW + gap
    self.itemGoldField = ISTextEntryBox:new("", priceX, sellY, coinW, rowH)
    styleTextEntry(self.itemGoldField)
    self.itemGoldField:initialise()
    self.itemGoldField:instantiate()
    self.itemGoldField:setOnlyNumbers(true)
    self.itemGoldField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketGold", "Bundles"))
    self.topBar:addChild(self.itemGoldField)

    self.itemSilverField = ISTextEntryBox:new("", priceX + coinW + gap, sellY, coinW, rowH)
    styleTextEntry(self.itemSilverField)
    self.itemSilverField:initialise()
    self.itemSilverField:instantiate()
    self.itemSilverField:setOnlyNumbers(true)
    self.itemSilverField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketSilver", "Money"))
    self.topBar:addChild(self.itemSilverField)

    self.itemCopperField = ISTextEntryBox:new("", priceX + ((coinW + gap) * 2), sellY, coinW, rowH)
    styleTextEntry(self.itemCopperField)
    self.itemCopperField:initialise()
    self.itemCopperField:instantiate()
    self.itemCopperField:setOnlyNumbers(true)
    self.itemCopperField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketCopper", "Extra"))
    self.topBar:addChild(self.itemCopperField)

    self.descriptionField = ISTextEntryBox:new("", priceX + ((coinW + gap) * 3), sellY, descriptionW, rowH)
    styleTextEntry(self.descriptionField)
    self.descriptionField:initialise()
    self.descriptionField:instantiate()
    self.descriptionField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketDescription", "Description"))
    self.topBar:addChild(self.descriptionField)

    self.itemList = ISScrollingListBox:new(rightX, sellListY, rightW, sellListH)
    styleListBox(self.itemList)
    self.itemList.itemheight = math.max(20, math.floor(rowH * 0.92))
    self.itemList:initialise()
    self.itemList:instantiate()
    self.itemList.target = self
    self.itemList.onMouseDown = function(listBox, x, y)
        ISScrollingListBox.onMouseDown(listBox, x, y)
        local selected = getSelectedItem(listBox)
        if selected then
            self:updateItemPreview({
                id = "inventory:" .. tostring(selected.fullType),
                type = "item",
                item = selected.snapshot,
                items = { selected.snapshot },
                quantity = selected.count,
            })
        end
    end
    self.topBar:addChild(self.itemList)

    local leftFieldX = sx + math.floor(sellerW * 0.34)
    local leftFieldW = math.max(48, sellerW - (leftFieldX - sx))
    self.vehicleTitleField = ISTextEntryBox:new("", leftFieldX, sellY, leftFieldW, rowH)
    styleTextEntry(self.vehicleTitleField)
    self.vehicleTitleField:initialise()
    self.vehicleTitleField:instantiate()
    self.vehicleTitleField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketTitle", "Title"))
    self.topBar:addChild(self.vehicleTitleField)

    self.vehicleOwnerField = ISTextEntryBox:new("", leftFieldX, sellY + rowH + gap, leftFieldW, rowH)
    styleTextEntry(self.vehicleOwnerField)
    self.vehicleOwnerField:initialise()
    self.vehicleOwnerField:instantiate()
    self.vehicleOwnerField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketOwner", "Owner"))
    self.topBar:addChild(self.vehicleOwnerField)

    self.vehicleGoldField = ISTextEntryBox:new("", rightX, sellY, coinW, rowH)
    styleTextEntry(self.vehicleGoldField)
    self.vehicleGoldField:initialise()
    self.vehicleGoldField:instantiate()
    self.vehicleGoldField:setOnlyNumbers(true)
    self.vehicleGoldField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketGold", "Bundles"))
    self.topBar:addChild(self.vehicleGoldField)

    self.vehicleSilverField = ISTextEntryBox:new("", rightX + coinW + gap, sellY, coinW, rowH)
    styleTextEntry(self.vehicleSilverField)
    self.vehicleSilverField:initialise()
    self.vehicleSilverField:instantiate()
    self.vehicleSilverField:setOnlyNumbers(true)
    self.vehicleSilverField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketSilver", "Money"))
    self.topBar:addChild(self.vehicleSilverField)

    self.vehicleCopperField = ISTextEntryBox:new("", rightX + ((coinW + gap) * 2), sellY, coinW, rowH)
    styleTextEntry(self.vehicleCopperField)
    self.vehicleCopperField:initialise()
    self.vehicleCopperField:instantiate()
    self.vehicleCopperField:setOnlyNumbers(true)
    self.vehicleCopperField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketCopper", "Extra"))
    self.topBar:addChild(self.vehicleCopperField)

    self.vehicleDescriptionField = ISTextEntryBox:new("", rightX + ((coinW + gap) * 3), sellY, descriptionW, rowH)
    styleTextEntry(self.vehicleDescriptionField)
    self.vehicleDescriptionField:initialise()
    self.vehicleDescriptionField:instantiate()
    self.vehicleDescriptionField:setPlaceholderText(PZLinuxText("UI_PZLinux_LocalMarketDescription", "Description"))
    self.topBar:addChild(self.vehicleDescriptionField)

    self.vehicleList = ISScrollingListBox:new(rightX, sellListY, rightW, sellListH)
    styleListBox(self.vehicleList)
    self.vehicleList.itemheight = math.max(20, math.floor(rowH * 0.92))
    self.vehicleList:initialise()
    self.vehicleList:instantiate()
    self.topBar:addChild(self.vehicleList)

    self.listItemButton = addGreenButton(self.topBar, rightX, sellButtonY, rightW, buttonH, PZLinuxText("UI_PZLinux_LocalMarketListItem", "List item"), self, self.onListItem)
    self.listVehicleButton = addGreenButton(self.topBar, rightX, sellButtonY, rightW, buttonH, PZLinuxText("UI_PZLinux_LocalMarketListVehicle", "List vehicle"), self, self.onListVehicle)

    -- Grupos de visibilidade: setView liga/desliga grupos inteiros ao trocar
    -- entre Home, Ajuda, Itens e Veiculos.
    self.homeElements = {
        self.homeBox,
        self.homeItemsButton,
        self.homeVehiclesButton,
        self.homeHelpButton,
        self.homeHelpLabel,
    }
    self.helpElements = {
        self.helpBox,
        self.helpPanel,
    }
    self.browseElements = {
        self.sidebarBox,
        self.controlsBox,
        self.listBoxFrame,
        self.detailBoxFrame,
        self.sellerLabel,
        self.sellerList,
        self.categoryLabel,
        self.allButton,
        self.itemButton,
        self.foodButton,
        self.weaponButton,
        self.searchLabel,
        self.searchField,
        self.sortButton,
        self.listingList,
        self.detailLabel,
        self.buyQuantityField,
        self.buyButton,
        self.cancelButton,
    }
    self.itemSellElements = {
        self.itemQuantityField,
        self.itemGoldField,
        self.itemSilverField,
        self.itemCopperField,
        self.descriptionField,
        self.itemList,
        self.listItemButton,
    }
    self.vehicleSellElements = {
        self.vehicleTitleField,
        self.vehicleOwnerField,
        self.vehicleGoldField,
        self.vehicleSilverField,
        self.vehicleCopperField,
        self.vehicleDescriptionField,
        self.vehicleList,
        self.listVehicleButton,
    }
    self.vehiclePreviewElements = {
        self.previewBoxFrame,
        self.vehiclePreview,
        self.vehiclePreviewLabel,
    }

    self:refreshAll()
    self:setView("home")
    self:onRefresh()
end

function localMarketUI:onClose()
    local modData = PZLinuxGetModData()
    if modData then
        modData.PZLinuxUIOpenMenu = 0
    end
    self:removeFromUIManager()
    local player = self.player or getPlayer()
    if player and player.StopAllActionQueue then
        player:StopAllActionQueue()
    end
    if PZLinuxLocalMarketInstance == self then
        PZLinuxLocalMarketInstance = nil
    end
end

function localMarketUI:onBack()
    if self.marketView ~= "home" then
        self:setView("home")
        return
    end

    local modData = PZLinuxGetModData()
    if modData then
        modData.PZLinuxUIOpenMenu = 1
    end
    self:removeFromUIManager()
    if PZLinuxLocalMarketInstance == self then
        PZLinuxLocalMarketInstance = nil
    end
end

-- Desenha apenas os textos de detalhe; preview de item foi removido.
function localMarketUI:prerender()
    ISPanel.prerender(self)

    if not self.detailLines or (self.marketView ~= "items" and self.marketView ~= "vehicles") then
        return
    end

    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    local y = self.detailY + 2
    local maxY = self.detailY + self.detailH - lineHeight
    for _, line in ipairs(self.detailLines) do
        for _, wrappedLine in ipairs(wrapTextToWidth(line, UIFont.Small, self.detailW - 8)) do
            if y > maxY then
                return
            end
            self:drawText(wrappedLine, self.detailX + 4, y, 0, 1, 0, 1, UIFont.Small)
            y = y + lineHeight + 1
        end
    end
end

function localMarketUI:setNotice(text)
    if self.noticeLabel then
        self.noticeLabel:setName(fitTextToWidth(text, UIFont.Small, self.noticeMaxWidth))
    end
end

function localMarketUI:onRefresh()
    marketCommand("RequestLocalMarket", { force = true })
    self:refreshSellSources()
end

function localMarketUI:onSort()
    if self.sortMode == "date" then
        self.sortMode = "price"
    elseif self.sortMode == "price" then
        self.sortMode = "name"
    else
        self.sortMode = "date"
    end
    self:refreshListings()
end

function localMarketUI:updateSortButton()
    if not self.sortButton then
        return
    end
    local label = PZLinuxText("UI_PZLinux_LocalMarketSortDate", "Sort: Date")
    if self.sortMode == "price" then
        label = PZLinuxText("UI_PZLinux_LocalMarketSortPrice", "Sort: Price")
    elseif self.sortMode == "name" then
        label = PZLinuxText("UI_PZLinux_LocalMarketSortName", "Sort: Name")
    end
    self.sortButton:setTitle(label)
end

function localMarketUI:setView(view)
    self.marketView = view or "home"
    if self.marketView == "items" then
        if self.selectedCategory == "vehicles" then
            self.selectedCategory = "items"
        end
    elseif self.marketView == "vehicles" then
        self.selectedCategory = "vehicles"
    end

    local isHome = self.marketView == "home"
    local isHelp = self.marketView == "help"
    local isItems = self.marketView == "items"
    local isVehicles = self.marketView == "vehicles"
    local isBrowse = isItems or isVehicles

    setElementsVisible(self.homeElements, isHome)
    setElementsVisible(self.helpElements, isHelp)
    setElementsVisible(self.browseElements, isBrowse)
    setElementsVisible(self.itemSellElements, isItems)
    setElementsVisible(self.vehicleSellElements, isVehicles)
    setElementVisible(self.sellBoxFrame, isItems or isVehicles)
    setElementVisible(self.sellLabel, isItems or isVehicles)
    setElementVisible(self.buyQuantityField, isItems)
    -- A moldura/preview 3D aparece so na aba de veiculos. Na aba de itens a
    -- area fica livre para evitar chamadas problematicas de item 3D.
    setElementVisible(self.vehiclePreviewLabel, isVehicles)
    setElementVisible(self.previewBoxFrame, isVehicles)
    if not isVehicles then
        setElementsVisible(self.vehiclePreviewElements, false)
    end
    setElementVisible(self.refreshButton, isBrowse)
    setElementVisible(self.backButton, true)

    if self.noticeLabel then
        self.noticeLabel:setVisible(isHelp or isBrowse)
        if isHelp then
            self:setNotice(PZLinuxText("UI_PZLinux_LocalMarketHelpText", "Items and vehicles are listed separately. Refresh updates only this screen."))
            self.showingHelpNotice = true
        elseif self.showingHelpNotice then
            self:setNotice("")
            self.showingHelpNotice = false
        end
    end

    if self.categoryLabel then
        self.categoryLabel:setName(isVehicles and PZLinuxLocalMarket.categoryText("vehicles") or PZLinuxText("UI_PZLinux_LocalMarketCategory", "Category"))
    end
    setElementsVisible({ self.allButton, self.itemButton, self.foodButton, self.weaponButton }, isItems)

    if isVehicles and self.vehicleOwnerField then
        local username = PZLinuxLocalMarket.getUsername(self.player or getPlayer()) or ""
        if self.vehicleOwnerField:getText() == "" then
            self.vehicleOwnerField:setText(username)
        end
    end

    self:updateSortButton()
    self:refreshSellers()
    self:refreshListings()
    self:refreshSellSources()
end

function localMarketUI:setCategory(category)
    self.selectedCategory = category or "all"
    self:refreshListings()
end

-- Dados locais mais recentes recebidos do server.
function localMarketUI:getListings()
    return self.marketData and self.marketData.listings or {}
end

-- Garante que a aba Itens nao mostre veiculos e vice-versa.
function localMarketUI:listingMatchesView(listing)
    if type(listing) ~= "table" then
        return false
    end

    local category = PZLinuxLocalMarket.normalizeCategory(listing.category)
    if self.marketView == "vehicles" then
        return listing.type == "vehicle" or category == "vehicles"
    end

    if self.marketView == "items" then
        return listing.type ~= "vehicle" and category ~= "vehicles"
    end

    return false
end

-- Filtro de busca por nome, vendedor, descricao e tipo.
function localMarketUI:listingMatchesSearch(listing)
    if not self.searchField or not self.searchField.getText then
        return true
    end

    local query = tostring(self.searchField:getText() or ""):lower()
    query = query:match("^%s*(.-)%s*$") or ""
    if query == "" then
        return true
    end

    local haystack = table.concat({
        tostring(listing.name or ""),
        tostring(listing.seller or ""),
        tostring(listing.ownerName or ""),
        tostring(listing.description or ""),
        tostring(PZLinuxLocalMarket.categoryText(listing.category) or ""),
    }, " "):lower()

    return haystack:find(query, 1, true) ~= nil
end

-- Atualiza tudo que depende do estado atual da UI.
function localMarketUI:refreshAll()
    local modData = PZLinuxGetModData(self.player)
    local balance = math.max(0, math.floor(tonumber(modData and modData.PZLinuxBank or 0) or 0))
    self.balanceLabel:setName(fitTextToWidth(PZLinuxText("UI_PZLinux_BankBalance", "Bank Balance: %1", PZLinuxFormatCurrency(balance)), UIFont.Small, self.balanceMaxWidth))
    self:refreshSellers()
    self:refreshListings()
    self:refreshSellSources()
end

-- Monta a lista lateral de vendedores/lojas.
function localMarketUI:refreshSellers()
    self.sellerList:clear()
    local selectedSeller = tostring(self.selectedSeller or "all")
    local selectedIndex = 1
    self.sellerList:addItem(PZLinuxText("UI_PZLinux_All", "All"), { seller = "all" })

    local seen = {}
    for _, listing in ipairs(self:getListings()) do
        local seller = tostring(listing.seller or "")
        if seller ~= "" and self:listingMatchesView(listing) and not seen[seller:lower()] then
            seen[seller:lower()] = true
            self.sellerList:addItem(seller, { seller = seller })
            if seller:lower() == selectedSeller:lower() then
                selectedIndex = #self.sellerList.items
            end
        end
    end

    self.sellerList.selected = selectedIndex
end

-- Recria a lista principal respeitando vendedor, aba, busca e ordenacao.
function localMarketUI:refreshListings()
    local selectedListing = getSelectedItem(self.listingList)
    local selectedListingId = selectedListing and selectedListing.id or nil
    self.listingList:clear()
    local selectedSeller = tostring(self.selectedSeller or "all")
    local selectedCategory = tostring(self.selectedCategory or "all")
    local selectedIndex = -1
    local rows = {}

    for _, listing in ipairs(self:getListings()) do
        local sellerMatches = selectedSeller == "all" or tostring(listing.seller or ""):lower() == selectedSeller:lower()
        local categoryMatches = selectedCategory == "all" or PZLinuxLocalMarket.normalizeCategory(listing.category) == selectedCategory
        if sellerMatches and categoryMatches and self:listingMatchesView(listing) and self:listingMatchesSearch(listing) then
            table.insert(rows, listing)
        end
    end

    table.sort(rows, function(left, right)
        if self.sortMode == "price" then
            local lp = tonumber(left.price) or 0
            local rp = tonumber(right.price) or 0
            if lp == rp then
                return tostring(left.name or ""):lower() < tostring(right.name or ""):lower()
            end
            return lp < rp
        elseif self.sortMode == "name" then
            return tostring(left.name or ""):lower() < tostring(right.name or ""):lower()
        end
        return (tonumber(left.createdAt) or 0) > (tonumber(right.createdAt) or 0)
    end)

    for _, listing in ipairs(rows) do
        local label
        if self.marketView == "vehicles" then
            label = string.format(
                "%s | %s | %s",
                tostring(listing.name or listing.title or "?"),
                tostring(listing.ownerName or listing.seller or "?"),
                PZLinuxFormatCurrency(listing.price or 0)
            )
        else
            local quantity = math.max(1, math.floor(tonumber(listing.quantity) or 1))
            label = string.format(
                "%s | x%d | %s cada | %s",
                tostring(listing.name or "?"),
                quantity,
                PZLinuxFormatCurrency(listing.price or 0),
                tostring(listing.seller or "?")
            )
        end
        self.listingList:addItem(label, listing)
        if selectedListingId and listing.id == selectedListingId then
            selectedIndex = #self.listingList.items
        end
    end

    if selectedIndex ~= -1 then
        self.listingList.selected = selectedIndex
    end

    self:updateDetails()
end

-- Monta o painel de detalhe e escolhe qual preview deve ser atualizado.
function localMarketUI:updateDetails()
    local listing = getSelectedItem(self.listingList)
    if not listing then
        self.detailLines = { PZLinuxText("UI_PZLinux_LocalMarketNoSelection", "Select a listing.") }
        self.detailLabel:setName("")
        self:updateVehiclePreview(nil)
        self:updateItemPreview(nil)
        return
    end

    local category = PZLinuxLocalMarket.categoryText(listing.category)
    local lines = {
        tostring(listing.name or "?"),
        PZLinuxText("UI_PZLinux_Seller", "Seller") .. ": " .. tostring(listing.seller or "?"),
        PZLinuxText("UI_PZLinux_LocalMarketCategory", "Category") .. ": " .. category,
        PZLinuxText("UI_PZLinux_Price", "Price") .. ": " .. PZLinuxFormatCurrency(listing.unitPrice or listing.price or 0),
        PZLinuxText("UI_PZLinux_LocalMarketDate", "Date") .. ": " .. formatDate(listing.createdAt),
    }

    if listing.type == "vehicle" and listing.vehicle then
        table.insert(lines, PZLinuxText("UI_PZLinux_LocalMarketOwner", "Owner") .. ": " .. tostring(listing.ownerName or listing.seller or "?"))
        table.insert(lines, "ID: " .. tostring(listing.vehicle.vgid or "?"))
        table.insert(lines, PZLinuxText("UI_PZLinux_LocalMarketCondition", "Condition") .. ": " .. tostring(listing.vehicle.condition or 0) .. "%")
        table.insert(lines, PZLinuxText("UI_PZLinux_LocalMarketEngine", "Engine") .. ": " .. tostring(listing.vehicle.engineQuality or 0) .. "%")
    elseif listing.type == "item" then
        local snapshots = type(listing.items) == "table" and listing.items or { listing.item }
        local snapshot = snapshots[1] or {}
        local quantity = math.max(1, math.floor(tonumber(listing.quantity) or #snapshots or 1))
        local conditionMax = math.max(0, math.floor(tonumber(snapshot.conditionMax) or 0))
        local condition = math.max(0, math.floor(tonumber(snapshot.condition) or conditionMax))
        table.insert(lines, PZLinuxText("UI_PZLinux_Quantity", "Quantity") .. ": " .. tostring(quantity))
        if conditionMax > 0 then
            table.insert(lines, PZLinuxText("UI_PZLinux_LocalMarketCondition", "Condition") .. ": " .. tostring(condition) .. "/" .. tostring(conditionMax))
        end
    end

    local description = tostring(listing.description or "")
    if description ~= "" then
        table.insert(lines, description)
    end

    self.detailLines = lines
    self.detailLabel:setName("")
    if listing.type == "vehicle" then
        self:updateItemPreview(nil)
        self:updateVehiclePreview(listing)
    else
        self:updateVehiclePreview(nil)
        self:updateItemPreview(listing)
    end
end

-- Atualiza a cena 3D do veiculo selecionado. Esse e o unico preview 3D que
-- deve existir no PZLinux Local Market.
function localMarketUI:updateVehiclePreview(listing)
    if not self.vehiclePreviewLabel then
        return
    end

    if self.marketView ~= "vehicles" or not listing or listing.type ~= "vehicle" then
        self.vehiclePreviewLabel:setName("")
        setElementVisible(self.vehiclePreview, false)
        self.lastVehiclePreviewId = nil
        return
    end

    local vehicleInfo = listing.vehicle or {}
    local missingParts = 0
    if type(vehicleInfo.parts) == "table" then
        for _, part in ipairs(vehicleInfo.parts) do
            if type(part) == "table" and part.installed == false then
                missingParts = missingParts + 1
            end
        end
    end

    local scriptName = tostring(vehicleInfo.scriptFullName or vehicleInfo.scriptName or "")
    local previewId = tostring(listing.id or "") .. ":" .. scriptName
    setElementVisible(self.vehiclePreview, self.vehiclePreview ~= nil and scriptName ~= "")

    if self.vehiclePreview and scriptName ~= "" and self.lastVehiclePreviewId ~= previewId then
        local ok = pcall(function()
            self.vehiclePreview.javaObject:fromLua2("setVehicleScript", "vehicle", scriptName)
            local position = PZLinuxLocalMarketPreviewConfig.vehicle
            self.vehiclePreview.javaObject:fromLua4("setObjectPosition", "vehicle", position.x, position.y, position.z)
            self.vehiclePreview.javaObject:fromLua1("setZoom", position.zoom or 6.50)
            self.vehiclePreview:setView("Left")
            self.vehiclePreview.javaObject:fromLua2("setObjectAutoRotate", "vehicle", true)
        end)
        if ok then
            if missingParts > 0 then
                self.vehiclePreviewLabel:setName(PZLinuxText(
                    "UI_PZLinux_LocalMarketVehiclePreviewRemote",
                    "3D preview is approximate. Missing parts: %1",
                    tostring(missingParts)
                ))
            else
                self.vehiclePreviewLabel:setName("")
            end
            self.lastVehiclePreviewId = previewId
            return
        end
    elseif self.vehiclePreview and scriptName ~= "" then
        if missingParts > 0 then
            self.vehiclePreviewLabel:setName(PZLinuxText(
                "UI_PZLinux_LocalMarketVehiclePreviewRemote",
                "3D preview is approximate. Missing parts: %1",
                tostring(missingParts)
            ))
        else
            self.vehiclePreviewLabel:setName("")
        end
        return
    end

    self.lastVehiclePreviewId = previewId
    self.vehiclePreviewLabel:setName(PZLinuxText("UI_PZLinux_LocalMarketVehiclePreviewUnavailable", "Vehicle model unavailable."))
end

-- Mantido como no-op intencional: itens nao tem preview 3D nem icone desenhado.
-- Isso evita os erros de prerender vistos nas versoes anteriores da B42.
function localMarketUI:updateItemPreview(listing)
    if self.vehiclePreviewLabel and (not listing or listing.type ~= "vehicle") then
        self.vehiclePreviewLabel:setName("")
    end
end

-- Atualiza as fontes de venda dependendo da aba ativa.
function localMarketUI:refreshSellSources()
    if self.marketView == "items" then
        self:refreshInventoryItems()
    elseif self.marketView == "vehicles" then
        self:refreshOwnedVehicles()
    end
end

-- Agrupa itens iguais do inventario principal que podem ser anunciados.
function localMarketUI:refreshInventoryItems()
    self.itemList:clear()
    local player = self.player or getPlayer()
    local inventory = player and player.getInventory and player:getInventory() or nil
    if not inventory then
        return
    end

    local grouped = {}
    local items = inventory:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item and item.getFullType and not PZLinuxIsEquippedInventoryItem(player, item) then
            local fullType = item:getFullType()
            if not PZLinuxLocalMarket.isCoin(fullType) then
                local itemInventory = PZLinuxSafeGetItemInventory and PZLinuxSafeGetItemInventory(item) or nil
                local hasContents = false
                if itemInventory and itemInventory.getItems then
                    hasContents = itemInventory:getItems():size() > 0
                end
                if not hasContents then
                    local displayName = PZLinuxLocalMarket.getItemDisplayName(item, fullType)
                    local category = PZLinuxLocalMarket.classifyItem(item, fullType)
                    local group = grouped[fullType]
                    if not group then
                        local scriptItem = item.getScriptItem and item:getScriptItem() or nil
                        local modelScript = item.getWorldStaticModel and item:getWorldStaticModel() or nil
                        if (not modelScript or tostring(modelScript) == "") and item.getStaticModel then
                            modelScript = item:getStaticModel()
                        end
                        group = {
                            fullType = fullType,
                            category = category,
                            displayName = displayName,
                            count = 0,
                            snapshot = {
                                fullType = fullType,
                                displayName = displayName,
                                condition = item.getCondition and item:getCondition() or nil,
                                conditionMax = item.getConditionMax and item:getConditionMax() or nil,
                                modelScript = modelScript and tostring(modelScript) or nil,
                                icon = scriptItem and scriptItem.getIcon and tostring(scriptItem:getIcon() or "") or nil,
                            },
                        }
                        grouped[fullType] = group
                    end
                    group.count = group.count + 1
                end
            end
        end
    end

    local rows = {}
    for _, group in pairs(grouped) do
        rows[#rows + 1] = group
    end
    table.sort(rows, function(left, right)
        return tostring(left.displayName):lower() < tostring(right.displayName):lower()
    end)
    for _, group in ipairs(rows) do
        self.itemList:addItem(
            string.format("%s | x%d | %s", group.displayName, group.count, PZLinuxLocalMarket.categoryText(group.category)),
            group
        )
    end
end

-- Lista apenas veiculos do jogador registrados pelo JeevesClaims.
function localMarketUI:refreshOwnedVehicles()
    if not PZLinuxConfig.IsEnabled("VehicleTrading") then self.vehicleList:clear(); return end
    self.vehicleList:clear()
    local player = self.player or getPlayer()
    local username = PZLinuxLocalMarket.getUsername(player)
    if not username or not JeevesClaims or not JeevesClaims.getVehicleOwner then
        return
    end

    local cell = getCell()
    local vehicles = JeevesClaims.listCellVehicles and JeevesClaims.listCellVehicles(cell) or {}
    for _, vehicle in ipairs(vehicles) do
        local owner = JeevesClaims.getVehicleOwner(vehicle)
        if owner and JeevesClaims.isSameUsername(owner, username) then
            local modData = vehicle.getModData and vehicle:getModData() or nil
            local vgid = modData and modData.JC_VID or nil
            local vehicleId = JeevesClaims.getSafeVehicleId and JeevesClaims.getSafeVehicleId(vehicle) or nil
            local name = PZLinuxLocalMarket.getVehicleDisplayName(vehicle)
            self.vehicleList:addItem(name .. " [" .. tostring(vgid or "?") .. "]", {
                vehicleId = vehicleId,
                vgid = vgid,
                name = name,
            })
        end
    end
end

function localMarketUI:getPriceAndDescription()
    local price = coinFieldsToValue(self.itemGoldField, self.itemSilverField, self.itemCopperField)
    local description = PZLinuxLocalMarket.sanitizeDescription(self.descriptionField:getText())
    local quantity = PZLinuxLocalMarket.normalizeQuantity(self.itemQuantityField and self.itemQuantityField:getText() or 1)
    return price, description, quantity
end

function localMarketUI:getVehicleSaleData()
    local price = coinFieldsToValue(self.vehicleGoldField, self.vehicleSilverField, self.vehicleCopperField)
    local description = PZLinuxLocalMarket.sanitizeDescription(self.vehicleDescriptionField and self.vehicleDescriptionField:getText() or "")
    local title = PZLinuxLocalMarket.sanitizeDescription(self.vehicleTitleField and self.vehicleTitleField:getText() or "")
    local ownerName = PZLinuxLocalMarket.sanitizeDescription(self.vehicleOwnerField and self.vehicleOwnerField:getText() or "")
    return price, description, title, ownerName
end

function localMarketUI:onListItem()
    if not PZLinuxRequireFeature("LocalMarket", self.player or getPlayer()) then return end
    local selected = getSelectedItem(self.itemList)
    local price, description, quantity = self:getPriceAndDescription()
    if not selected or price <= 0 or quantity > math.max(0, tonumber(selected.count) or 0) then
        HaloTextHelper.addBadText(self.player, PZLinuxText("UI_PZLinux_LocalMarketInvalidSale", "Select something and set a valid price."))
        return
    end
    marketCommand("ListLocalMarketItem", {
        fullType = selected.fullType,
        category = selected.category,
        price = price,
        quantity = quantity,
        description = description,
    })
    self:setNotice(PZLinuxText("UI_PZLinux_LocalMarketUpdating", "Updating market..."))
end

function localMarketUI:onListVehicle()
    if not PZLinuxRequireFeature("VehicleTrading", self.player or getPlayer()) then return end
    local selected = getSelectedItem(self.vehicleList)
    local price, description, title, ownerName = self:getVehicleSaleData()
    if not selected or price <= 0 then
        HaloTextHelper.addBadText(self.player, PZLinuxText("UI_PZLinux_LocalMarketInvalidSale", "Select something and set a valid price."))
        return
    end
    marketCommand("ListLocalMarketVehicle", {
        vgid = selected.vgid,
        vehicleId = selected.vehicleId,
        price = price,
        description = description,
        title = title,
        ownerName = ownerName,
    })
    self:setNotice(PZLinuxText("UI_PZLinux_LocalMarketUpdating", "Updating market..."))
end

-- Compra item/veiculo selecionado. O server valida dinheiro, dono e entrega.
function localMarketUI:onBuy()
    if not PZLinuxRequireFeature("LocalMarket", self.player or getPlayer()) then return end
    local listing = getSelectedItem(self.listingList)
    if not listing then
        return
    end
    local quantity = listing.type == "item"
        and PZLinuxLocalMarket.normalizeQuantity(self.buyQuantityField and self.buyQuantityField:getText() or 1, listing.quantity or 1)
        or 1
    marketCommand("BuyLocalMarketListing", { listingId = listing.id, quantity = quantity })
    self:setNotice(PZLinuxText("UI_PZLinux_LocalMarketUpdating", "Updating market..."))
end

-- Cancela anuncio proprio, ou de admin quando permitido pelo server.
function localMarketUI:onCancelListing()
    local listing = getSelectedItem(self.listingList)
    if not listing then
        return
    end
    marketCommand("CancelLocalMarketListing", { listingId = listing.id })
    self:setNotice(PZLinuxText("UI_PZLinux_LocalMarketUpdating", "Updating market..."))
end

-- Recebe snapshot completo do server e redesenha a tela.
function localMarketUI:onMarketData(args)
    self.marketData = args or { listings = {} }
    self:refreshAll()
end

-- Resultado de acao enviada ao server: listar, comprar, cancelar etc.
function localMarketUI:onMarketResult(args)
    if args and tonumber(args.balance) ~= nil then
        local modData = PZLinuxGetModData(self.player)
        if modData then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(args.balance) or 0))
        end
    end
    if args and args.ok then
        if args.pending then
            self:setNotice(PZLinuxText(
                "UI_PZLinux_LocalMarketTakeToMailbox",
                "Listing prepared. Deposit %1 item(s) in a mailbox.",
                tostring(args.quantity or 1)
            ))
        elseif args.submitted then
            self:setNotice(PZLinuxText(
                "UI_PZLinux_LocalMarketSubmitted",
                "Mailbox deposit confirmed. Listing published."
            ))
        else
            self:setNotice(PZLinuxText("UI_PZLinux_LocalMarketOk", "Local market updated."))
        end
    elseif args then
        self:setNotice(PZLinuxText("UI_PZLinux_LocalMarketFailed", "Local market action failed") .. ": " .. tostring(args.reason or "failed"))
    end
    self:refreshAll()
end

-- Entrada padrao para dados do server. Tambem sincroniza saldo local.
function PZLinuxLocalMarketOnData(args)
    PZLinuxLocalMarketClient.Data = args or { listings = {} }
    if type(args) == "table" and tonumber(args.balance) ~= nil then
        local player = getPlayer()
        local modData = player and PZLinuxGetModData(player) or nil
        if modData then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(args.balance) or 0))
        end
    end
    if PZLinuxLocalMarketInstance and PZLinuxLocalMarketInstance.onMarketData then
        PZLinuxLocalMarketInstance:onMarketData(PZLinuxLocalMarketClient.Data)
    end

    if type(args) == "table" and type(args.saleNotices) == "table" then
        for _, notice in ipairs(args.saleNotices) do
            showSaleNotice(notice)
        end
    end

    if type(args) == "table" and math.floor(tonumber(args.pendingCredit) or 0) > 0 then
        local player = getPlayer()
        local amount = math.floor(tonumber(args.pendingCredit) or 0)
        local text = PZLinuxText("UI_PZLinux_LocalMarketPendingCredit", "Market payout received: %1", PZLinuxFormatCurrency(amount))
        if player then
            HaloTextHelper.addGoodText(player, text)
        end
        if PZLinuxLocalMarketInstance and PZLinuxLocalMarketInstance.setNotice then
            PZLinuxLocalMarketInstance:setNotice(text)
        end
    end
end

-- Entrada padrao para resultado de comandos do server.
function PZLinuxLocalMarketOnResult(args)
    local player = getPlayer()
    if not player then
        return
    end

    if args and args.ok then
        playMarketSound(player, "sold")
        if args.pending then
            HaloTextHelper.addGoodText(player, PZLinuxText(
                "UI_PZLinux_LocalMarketTakeToMailbox",
                "Listing prepared. Deposit %1 item(s) in a mailbox.",
                tostring(args.quantity or 1)
            ))
        elseif args.submitted then
            HaloTextHelper.addGoodText(player, PZLinuxText(
                "UI_PZLinux_LocalMarketSubmitted",
                "Mailbox deposit confirmed. Listing published."
            ))
        else
            HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_LocalMarketOk", "Local market updated."))
        end
    else
        playMarketSound(player, "error")
        local reason = tostring(args and args.reason or "failed")
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_LocalMarketFailed", "Local market action failed") .. ": " .. reason)
    end

    if PZLinuxLocalMarketInstance and PZLinuxLocalMarketInstance.onMarketResult then
        PZLinuxLocalMarketInstance:onMarketResult(args or {})
    end
end

local function onDepositCoinsResult(args)
    local player = getPlayer()
    if not player then
        return
    end

    if args and args.ok then
        local modData = PZLinuxGetModData(player)
        if modData and tonumber(args.balance) then
            modData.PZLinuxBank = math.max(0, math.floor(tonumber(args.balance) or 0))
        end
        playMarketSound(player, "sold")
        HaloTextHelper.addGoodText(player, PZLinuxText("UI_PZLinux_DepositCoinsOk", "Money deposited") .. ": " .. PZLinuxFormatCurrency(args.amount or 0))
        if PZLinuxLocalMarketInstance and PZLinuxLocalMarketInstance.refreshAll then
            PZLinuxLocalMarketInstance:refreshAll()
        end
    else
        playMarketSound(player, "error")
        HaloTextHelper.addBadText(player, PZLinuxText("UI_PZLinux_DepositCoinsFailed", "No money to deposit."))
    end
end

-- Deposito local/SP ou comando client/MP para converter dinheiro fisico do inventario
-- em saldo bancario PZLinux.
function PZLinuxDepositCoinsFromMailbox()
    if isClient() and sendClientCommand then
        sendClientCommand(MODULE, "DepositCoins", { amount = "all" })
        return
    end

    local player = getPlayer()
    if not player then
        return
    end

    local counts = PZLinuxEconomyGetInventoryCoinCounts(player)
    local amount = math.max(0, math.floor(tonumber(counts and counts.value or 0) or 0))
    if amount <= 0 then
        onDepositCoinsResult({ ok = false, reason = "no_money" })
        return
    end

    local result = PZLinuxEconomyRemoveCoinValueFromInventory(player, amount)
    if not result or not result.ok then
        onDepositCoinsResult({ ok = false, reason = "remove_failed" })
        return
    end

    local modData = PZLinuxGetModData(player)
    modData.PZLinuxBank = math.max(0, math.floor(tonumber(modData.PZLinuxBank) or 0)) + amount
    PZLinuxSyncPlayerModData(player)
    onDepositCoinsResult({ ok = true, amount = amount, balance = modData.PZLinuxBank })
end

-- Roteador dos comandos enviados pelo server para este modulo.
local function onServerCommand(module, command, args)
    if module ~= MODULE then
        return
    end
    if command == "LocalMarketData" then
        PZLinuxLocalMarketOnData(args or {})
    elseif command == "LocalMarketResult" then
        PZLinuxLocalMarketOnResult(args or {})
    elseif command == "LocalMarketSellerNotice" then
        showSaleNotice(args or {})
    elseif command == "DepositCoinsResult" then
        onDepositCoinsResult(args or {})
    end
end

Events.OnServerCommand.Add(onServerCommand)

-- Abre a janela centralizada sobre a textura do PC.
function localMarketMenu_ShowUI(player)
    if not PZLinuxRequireFeature("LocalMarket", player) then return end
    local texture = getTexture("media/ui/PC100.png")
    if not texture then return nil end

    local realScreenW, realScreenH, finalW, finalH = getResponsiveTerminalSize(texture)
    local uiX = (realScreenW - finalW) / 2
    local uiY = (realScreenH - finalH) / 2

    if PZLinuxLocalMarketInstance then
        PZLinuxLocalMarketInstance:removeFromUIManager()
        PZLinuxLocalMarketInstance = nil
    end

    local ui = localMarketUI:new(uiX, uiY, finalW, finalH, player)
    local centeredImage = ISImage:new(0, 0, finalW, finalH, texture)
    centeredImage.scaled = true
    centeredImage.scaledWidth = finalW
    centeredImage.scaledHeight = finalH
    ui:addChild(centeredImage)
    ui.centeredImage = centeredImage
    ui:initialise()
    ui:addToUIManager()
    PZLinuxLocalMarketInstance = ui
    return ui
end
