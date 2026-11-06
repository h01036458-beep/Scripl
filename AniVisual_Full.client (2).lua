-- ANI VISUAL PREMIUM — один LocalScript
-- Положи в StarterPlayer > StarterPlayerScripts как LocalScript (НЕ обычный Script).
if not game:GetService("RunService"):IsClient() then
	warn("[AniVisual] Это должен быть LocalScript в StarterPlayerScripts, а не серверный Script.")
	return
end
if not game:IsLoaded() then game.Loaded:Wait() end
repeat task.wait() until game:GetService("Players").LocalPlayer
repeat task.wait() until workspace.CurrentCamera

-- ===== отчёт об ошибках прямо на экране (тапни по красной плашке, чтобы закрыть) =====
local function report(where, err)
	warn("[AniVisual] " .. where .. ": " .. tostring(err))
	pcall(function()
		local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
		local g = pg:FindFirstChild("AniVisualError")
		if not g then
			g = Instance.new("ScreenGui")
			g.Name = "AniVisualError"; g.ResetOnSpawn = false; g.DisplayOrder = 999; g.IgnoreGuiInset = true
			g.Parent = pg
			local b = Instance.new("TextButton")
			b.Name = "L"; b.Size = UDim2.new(1, -20, 0, 0); b.AutomaticSize = Enum.AutomaticSize.Y
			b.Position = UDim2.fromOffset(10, 60); b.BackgroundColor3 = Color3.fromRGB(60, 0, 0); b.BackgroundTransparency = 0.05
			b.TextColor3 = Color3.new(1, 1, 1); b.TextWrapped = true; b.TextXAlignment = Enum.TextXAlignment.Left
			b.TextYAlignment = Enum.TextYAlignment.Top; b.Font = Enum.Font.Code; b.TextSize = 12; b.Text = ""
			b.AutoButtonColor = false; b.Parent = g
			b.Activated:Connect(function() g:Destroy() end)
		end
		local l = g:FindFirstChild("L")
		if l then l.Text = l.Text .. "[" .. where .. "] " .. string.sub(tostring(err), 1, 450) .. "\n\n" end
	end)
end

local function loadModule(name, fn)
	local ok, res = xpcall(fn, debug.traceback)
	if not ok then report("модуль " .. name, res); return nil end
	return res
end

local function stub(extra)
	local t = { Status = Instance.new("BindableEvent"), Closed = Instance.new("BindableEvent") }
	for k, v in pairs(extra or {}) do t[k] = v end
	return setmetatable(t, { __index = function() return function() end end })
end


-- ================= Config =================
local Config = loadModule("Config", function()
	local Config = {}
	Config.Version = "1.0.0"

	local function copy(t)
		local r = {}
		for k, v in pairs(t) do
			r[k] = type(v) == "table" and copy(v) or v
		end
		return r
	end

	local Defaults = {
		UI = { Transparency = 0.25, AnimSpeed = 1, BubblesEnabled = true, BubbleCount = 18, BubbleSpeed = 1, BubbleSize = 1, BubbleColor = Color3.fromRGB(170, 80, 255) },
		Combat = { AimAssist = false, AutoShoot = false, KnifeTraining = false, Hitbox = false, Radius = 150, AimStrength = 0.15 },
		ESP = {
			Enabled = false, Boxes = true, Highlight = false, Tracers = false, Distance = true, Names = true,
			Units = "studs", BoxTransparency = 0.1, Thickness = 1.5, TracerThickness = 1, MaxDistance = 1000, TextSize = 14,
			ColorMurderer = Color3.fromRGB(255, 40, 40),
			ColorSheriff = Color3.fromRGB(60, 120, 255),
			ColorInnocent = Color3.fromRGB(60, 220, 90),
			ColorTracer = Color3.fromRGB(255, 255, 255),
		},
		Visuals = { Sky = "Default", Stretch = false, StretchScale = 0.7, Trail = "None", HideHead = false, HideLegs = false },
		Gun = { ESP = false, Color = Color3.fromRGB(255, 220, 0) },
		Skins = { Skin = "Default" },
		Misc = { AudioId = "", Volume = 0.5, Neon = true },
	}

	Config.Data = copy(Defaults)
	Config.State = {} -- MenuPos / FloatPos (хранятся в памяти на время сессии)
	Config.Changed = Instance.new("BindableEvent") -- (category, key, value)

	function Config.Set(cat, key, val)
		Config.Data[cat][key] = val
		Config.Changed:Fire(cat, key, val)
	end

	function Config.ResetCategory(cat)
		for k, v in pairs(Defaults[cat]) do
			Config.Set(cat, k, type(v) == "table" and copy(v) or v)
		end
	end

	function Config.ResetAll()
		for cat in pairs(Defaults) do Config.ResetCategory(cat) end
	end

	return Config
end)
if not Config then return end

-- ================= Music =================
local Music = loadModule("Music", function()
	local SoundService = game:GetService("SoundService")

	local Music = {}
	local sound

	function Music.Play(id)
		local clean = tostring(id or ""):gsub("%D", "")
		if clean == "" then return false end
		if not sound then
			sound = Instance.new("Sound")
			sound.Name = "AniMusic"
			sound.Looped = true
			sound.Parent = SoundService
		end
		sound.SoundId = "rbxassetid://" .. clean
		sound.Volume = Config.Data.Misc.Volume
		sound:Play()
		return true
	end

	function Music.Stop()
		if sound then sound:Stop() end
	end

	Config.Changed.Event:Connect(function(cat, key, v)
		if cat == "Misc" and key == "Volume" and sound then sound.Volume = v end
	end)

	return Music
end)
Music = Music or stub()

-- ================= Teleports =================
local Teleports = loadModule("Teleports", function()
	local Players = game:GetService("Players")
	local lp = Players.LocalPlayer

	local Teleports = {}

	function Teleports.List(filter)
		filter = string.lower(filter or "")
		local out = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp and (filter == "" or string.find(string.lower(p.Name), filter, 1, true) or string.find(string.lower(p.DisplayName), filter, 1, true)) then
				table.insert(out, p)
			end
		end
		table.sort(out, function(a, b) return a.Name:lower() < b.Name:lower() end)
		return out
	end

	function Teleports.To(target)
		local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if not (myRoot and root) then return false end
		myRoot.CFrame = root.CFrame + Vector3.new(0, 3, 0)
		return true
	end

	return Teleports
end)
Teleports = Teleports or stub({ List = function() return {} end, To = function() return false end })

-- ================= ESP =================
local ESP = loadModule("ESP", function()
	-- Роли берутся из клиентских данных твоей игры:
	--   1) атрибут игрока  player:SetAttribute("Role", "Murderer" | "Sheriff" | "Innocent")
	--   2) запасной вариант: у кого есть Tool "Knife" -> Murderer, "Gun" -> Sheriff
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local ROLE_ATTRIBUTE = "Role"
	local lp = Players.LocalPlayer

	local ESP = {}
	local entries, conn, screen, folder, slowT = {}, nil, nil, nil, 0
	local hooks = {}

	local function make(class, props, parent)
		local o = Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		o.Parent = parent
		return o
	end

	local function getRole(plr)
		local attr = plr:GetAttribute(ROLE_ATTRIBUTE)
		if attr then return attr end
		local char, bp = plr.Character, plr:FindFirstChildOfClass("Backpack")
		if (char and char:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife")) then return "Murderer" end
		if (char and char:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun")) then return "Sheriff" end
		return "Innocent"
	end

	local function hide(e)
		e.box.Visible = false
		e.tracer.Visible = false
		e.bb.Enabled = false
		e.hl.Enabled = false
	end

	local function attach(e, char)
		e.hl.Parent = char
		e.hl.Adornee = char
		task.spawn(function()
			local part = char:FindFirstChild("Head") or char:WaitForChild("HumanoidRootPart", 5)
			if part and e.bb.Parent then e.bb.Adornee = part end
		end)
	end

	local function newEntry(plr)
		if plr == lp or entries[plr] then return end
		local e = { plr = plr, role = "Innocent" }
		e.box = make("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, screen)
		e.stroke = make("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, e.box)
		e.tracer = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, screen)
		e.hl = make("Highlight", { FillTransparency = 1, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false }, nil)
		e.bb = make("BillboardGui", { Size = UDim2.fromOffset(200, 40), StudsOffset = Vector3.new(0, 2.8, 0), AlwaysOnTop = true, ResetOnSpawn = false, Enabled = false }, folder)
		e.label = make("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
			TextStrokeTransparency = 0.4, TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
		}, e.bb)
		entries[plr] = e
		e.cc = plr.CharacterAdded:Connect(function(c) attach(e, c) end)
		if plr.Character then attach(e, plr.Character) end
	end

	local function removeEntry(plr)
		local e = entries[plr]
		if not e then return end
		e.cc:Disconnect()
		e.box:Destroy(); e.tracer:Destroy(); e.hl:Destroy(); e.bb:Destroy()
		entries[plr] = nil
	end

	local function step()
		local c = Config.Data.ESP
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local my = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local vp = cam.ViewportSize
		local slow = os.clock() - slowT > 0.1
		if slow then slowT = os.clock() end

		for plr, e in pairs(entries) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local dist = (root and my) and (root.Position - my.Position).Magnitude or 0
			if not (root and hum and hum.Health > 0 and dist <= c.MaxDistance) then
				hide(e)
			else
				if slow then e.role = getRole(plr) end
				local col = c["Color" .. e.role] or c.ColorInnocent
				local top = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
				local bot = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3.2, 0))
				local vis = top.Z > 0 and bot.Z > 0

				if c.Boxes and vis then
					local h = math.abs(bot.Y - top.Y)
					local w = h * 0.55
					e.box.Position = UDim2.fromOffset(top.X - w / 2, math.min(top.Y, bot.Y))
					e.box.Size = UDim2.fromOffset(w, h)
					e.stroke.Color = col
					e.stroke.Thickness = c.Thickness
					e.stroke.Transparency = c.BoxTransparency
					e.box.Visible = true
				else
					e.box.Visible = false
				end

				if c.Tracers and vis then
					local a = Vector2.new(vp.X / 2, vp.Y)
					local b = Vector2.new(bot.X, bot.Y)
					local d = b - a
					e.tracer.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
					e.tracer.Size = UDim2.fromOffset(d.Magnitude, c.TracerThickness)
					e.tracer.Rotation = math.deg(math.atan2(d.Y, d.X))
					e.tracer.BackgroundColor3 = c.ColorTracer
					e.tracer.Visible = true
				else
					e.tracer.Visible = false
				end

				e.hl.Enabled = c.Highlight
				e.hl.OutlineColor = col
				e.hl.OutlineTransparency = c.BoxTransparency

				e.bb.Enabled = c.Names or c.Distance
				if slow then
					local lines = {}
					if c.Names then table.insert(lines, plr.DisplayName) end
					if c.Distance then
						if c.Units == "meters" then
							table.insert(lines, string.format("%.0f m", dist * 0.28))
						else
							table.insert(lines, string.format("%.0f studs", dist))
						end
					end
					e.label.Text = table.concat(lines, "\n")
					e.label.TextColor3 = col
					e.label.TextSize = c.TextSize
				end
			end
		end
	end

	function ESP.Refresh()
		local c = Config.Data.ESP
		if c.Enabled then
			if not conn then conn = RunService.RenderStepped:Connect(step) end
		else
			if conn then conn:Disconnect(); conn = nil end
			for _, e in pairs(entries) do hide(e) end
		end
	end

	function ESP.Init()
		local pg = lp:WaitForChild("PlayerGui")
		screen = make("ScreenGui", { Name = "AniESP", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50 }, pg)
		folder = make("Folder", { Name = "AniESPBillboards" }, pg)
		for _, p in ipairs(Players:GetPlayers()) do newEntry(p) end
		table.insert(hooks, Players.PlayerAdded:Connect(newEntry))
		table.insert(hooks, Players.PlayerRemoving:Connect(removeEntry))
		table.insert(hooks, Config.Changed.Event:Connect(function(cat)
			if cat == "ESP" then ESP.Refresh() end
		end))
		ESP.Refresh()
	end

	function ESP.Destroy()
		if conn then conn:Disconnect(); conn = nil end
		for _, h in ipairs(hooks) do h:Disconnect() end
		table.clear(hooks)
		for plr in pairs(entries) do removeEntry(plr) end
		if screen then screen:Destroy() end
		if folder then folder:Destroy() end
	end

	return ESP
end)
ESP = ESP or stub()

-- ================= Gun =================
local Gun = loadModule("Gun", function()
	-- Подсветка пистолета (в руках у игрока или лежит на земле) + кнопка ПОДБОР.
	-- Имена объектов пистолета в твоей игре — меняй в GUN_NAMES.
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local lp = Players.LocalPlayer
	local Gun = {}
	Gun.Status = Instance.new("BindableEvent") -- (text для кнопки)
	Gun.Nearest = nil

	local GUN_NAMES = { Gun = true, GunDrop = true }

	local dropped, visuals, lastHeld = {}, {}, {}
	local conn, dropAdd, dropRem, folder
	local lastT, busy, needRescan, lastStatus = 0, false, true, ""

	local function setStatus(t)
		if t ~= lastStatus then lastStatus = t; Gun.Status:Fire(t) end
	end

	local function isHeld(d)
		local m = d:FindFirstAncestorOfClass("Model")
		return m ~= nil and Players:GetPlayerFromCharacter(m) ~= nil
	end
	local function candidate(d)
		return GUN_NAMES[d.Name] and (d:IsA("BasePart") or d:IsA("Model") or d:IsA("Tool"))
	end
	local function track(d)
		if candidate(d) and not isHeld(d) then dropped[d] = true end
	end
	local function partOf(d)
		if d:IsA("BasePart") then return d end
		if d:IsA("Tool") then return d:FindFirstChild("Handle") or d:FindFirstChildWhichIsA("BasePart", true) end
		return d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart", true)
	end
	local function findGun(container)
		if not container then return nil end
		for name in pairs(GUN_NAMES) do
			local t = container:FindFirstChild(name)
			if t and t:IsA("Tool") then return t end
		end
		return nil
	end
	local function rescan()
		needRescan = false
		table.clear(dropped)
		for _, d in ipairs(Workspace:GetDescendants()) do track(d) end
	end

	local function createVisual()
		local v = {}
		v.hl = Instance.new("Highlight")
		v.hl.FillTransparency = 0.55
		v.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		v.bb = Instance.new("BillboardGui")
		v.bb.Size = UDim2.fromOffset(180, 24)
		v.bb.StudsOffset = Vector3.new(0, 3, 0)
		v.bb.AlwaysOnTop = true
		v.bb.ResetOnSpawn = false
		v.bb.Parent = folder
		v.label = Instance.new("TextLabel")
		v.label.Size = UDim2.fromScale(1, 1)
		v.label.BackgroundTransparency = 1
		v.label.Font = Enum.Font.GothamBold
		v.label.TextSize = 14
		v.label.TextStrokeTransparency = 0.4
		v.label.Parent = v.bb
		return v
	end

	local function update()
		local c = Config.Data.Gun
		local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local keep, heldNow = {}, {}

		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp then
				local ch = p.Character
				local tool = findGun(ch) or findGun(p:FindFirstChildOfClass("Backpack"))
				if tool then
					heldNow[p] = true
					if ch then
						local ad = (tool.Parent == ch and tool:FindFirstChild("Handle")) or ch
						keep[p] = { adornee = ad, label = ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart"), text = "GUN • " .. p.DisplayName }
					end
				end
			end
		end
		for p in pairs(lastHeld) do
			if not heldNow[p] then needRescan = true end
		end
		lastHeld = heldNow
		if needRescan then rescan() end

		local nearest, nd
		for d in pairs(dropped) do
			local part = d.Parent and partOf(d)
			if not part or isHeld(d) then
				dropped[d] = nil
			else
				local dup, a = false, d.Parent
				while a and a ~= Workspace do
					if dropped[a] then dup = true; break end
					a = a.Parent
				end
				if not dup then
					keep[d] = { adornee = d:IsA("Tool") and part or d, label = part, text = "GUN • лежит" }
					if myRoot then
						local dist = (part.Position - myRoot.Position).Magnitude
						if not nd or dist < nd then nearest, nd = d, dist end
					end
				end
			end
		end
		Gun.Nearest = nearest
		if not busy then setStatus(nearest and "ПОДБОР" or "ПОДБОР: нет") end

		for k, info in pairs(keep) do
			local v = visuals[k]
			if not v then v = createVisual(); visuals[k] = v end
			if v.ad ~= info.adornee then
				v.ad = info.adornee
				v.hl.Adornee = info.adornee
				v.hl.Parent = info.adornee
			end
			if v.lb ~= info.label then v.lb = info.label; v.bb.Adornee = info.label end
			v.hl.FillColor, v.hl.OutlineColor = c.Color, c.Color
			v.label.TextColor3 = c.Color
			local txt = info.text
			if myRoot and info.label then
				txt = txt .. string.format("  [%.0f]", (info.label.Position - myRoot.Position).Magnitude)
			end
			v.label.Text = txt
		end
		for k, v in pairs(visuals) do
			if not keep[k] then v.hl:Destroy(); v.bb:Destroy(); visuals[k] = nil end
		end
	end

	local function stop()
		if conn then conn:Disconnect(); conn = nil end
		if dropAdd then dropAdd:Disconnect(); dropAdd = nil end
		if dropRem then dropRem:Disconnect(); dropRem = nil end
		for k, v in pairs(visuals) do v.hl:Destroy(); v.bb:Destroy(); visuals[k] = nil end
		table.clear(dropped); lastHeld = {}; Gun.Nearest = nil
	end

	function Gun.Refresh()
		if Config.Data.Gun.ESP then
			if not conn then
				needRescan = true
				conn = RunService.Heartbeat:Connect(function()
					if os.clock() - lastT < 0.25 then return end
					lastT = os.clock()
					update()
				end)
				dropAdd = Workspace.DescendantAdded:Connect(track)
				dropRem = Workspace.DescendantRemoving:Connect(function(d) dropped[d] = nil end)
			end
		else
			stop()
			setStatus("ПОДБОР")
		end
	end

	-- Телепорт к пистолету -> подбор -> возврат на прежнее место
	function Gun.Pickup()
		if busy then return end
		local target = Gun.Nearest
		local part = target and target.Parent and partOf(target)
		local char = lp.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (part and root) then setStatus("ПОДБОР: нет"); return end
		busy = true
		setStatus("ПОДБОР...")
		local back = root.CFrame
		local t0 = os.clock()
		repeat
			if not part.Parent then break end
			root.CFrame = CFrame.new(part.Position + Vector3.new(0, 1.5, 0))
			root.AssemblyLinearVelocity = Vector3.zero
			task.wait(0.05)
		until findGun(char) or findGun(lp:FindFirstChildOfClass("Backpack")) or not target.Parent or os.clock() - t0 > 1.5
		if root.Parent then
			root.CFrame = back
			root.AssemblyLinearVelocity = Vector3.zero
		end
		busy = false
		setStatus("ПОДБОР")
	end

	function Gun.Init()
		folder = Instance.new("Folder")
		folder.Name = "AniGunBillboards"
		folder.Parent = lp:WaitForChild("PlayerGui")
		Config.Changed.Event:Connect(function(cat)
			if cat == "Gun" then Gun.Refresh() end
		end)
		Gun.Refresh()
	end

	function Gun.Destroy()
		stop()
		if folder then folder:Destroy() end
	end

	return Gun
end)
Gun = Gun or stub()

-- ================= Bubbles =================
local Bubbles = loadModule("Bubbles", function()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local lp = Players.LocalPlayer
	local Bubbles = {}
	local MAXB, RADIUS = 40, 45
	local list, folder, conn = {}, nil, nil

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local function root()
		return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	end

	local function reset(b, initial, r)
		r = r or root()
		if not r then return false end
		params.FilterDescendantsInstances = { lp.Character, folder }
		local ang, dist = math.random() * math.pi * 2, math.sqrt(math.random()) * RADIUS
		local x, z = r.Position.X + math.cos(ang) * dist, r.Position.Z + math.sin(ang) * dist
		local hit = Workspace:Raycast(Vector3.new(x, r.Position.Y + 8, z), Vector3.new(0, -100, 0), params)
		b.gy = hit and hit.Position.Y or (r.Position.Y - 3)
		b.size = math.random(8, 22) / 10
		b.v = math.random(15, 40) / 10
		b.maxH = math.random(12, 28)
		b.h = initial and math.random() * b.maxH or 0
		b.x, b.z, b.t = x, z, math.random() * 6.28
		return true
	end

	local function step(dt)
		local r = root()
		if not r then return end
		local u = Config.Data.UI
		local rp = r.Position
		for i = 1, u.BubbleCount do
			local b = list[i]
			if not b.gy then reset(b, true, r) end
			b.h += dt * b.v * u.BubbleSpeed
			b.t += dt
			local dx, dz = b.x - rp.X, b.z - rp.Z
			if b.h > b.maxH or dx * dx + dz * dz > (RADIUS * 1.4) ^ 2 then reset(b, false, r) end
			local s = b.size * u.BubbleSize
			b.part.Size = Vector3.new(s, s, s)
			b.part.Position = Vector3.new(b.x + math.sin(b.t) * 0.8, b.gy + b.h + s / 2, b.z + math.cos(b.t * 0.7) * 0.8)
			b.part.Transparency = 0.4 + 0.55 * (b.h / b.maxH)
		end
	end

	function Bubbles.Refresh()
		local u = Config.Data.UI
		for i, b in ipairs(list) do
			b.part.Parent = (u.BubblesEnabled and i <= u.BubbleCount) and folder or nil
			b.part.Color = u.BubbleColor
		end
		local want = u.BubblesEnabled and u.BubbleCount > 0
		if want and not conn then
			conn = RunService.Heartbeat:Connect(step)
		elseif not want and conn then
			conn:Disconnect(); conn = nil
		end
	end

	function Bubbles.Init()
		folder = Instance.new("Folder")
		folder.Name = "AniBubbles"
		folder.Parent = Workspace
		for i = 1, MAXB do
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Ball
			p.Material = Enum.Material.Neon
			p.Anchored = true
			p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
			p.Transparency = 0.5
			list[i] = { part = p }
		end
		lp.CharacterAdded:Connect(function()
			for _, b in ipairs(list) do b.gy = nil end
		end)
		Config.Changed.Event:Connect(function(cat)
			if cat == "UI" then Bubbles.Refresh() end
		end)
		Bubbles.Refresh()
	end

	function Bubbles.Destroy()
		if conn then conn:Disconnect(); conn = nil end
		if folder then folder:Destroy() end
	end

	return Bubbles
end)
Bubbles = Bubbles or stub()

-- ================= Combat =================
local Combat = loadModule("Combat", function()
	-- Aim Assist / Auto Shoot работают ТОЛЬКО по мишеням в Workspace.TestTargets
	-- (модели с Humanoid + HumanoidRootPart). Knife Training сам создаёт такую мишень.
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")
	local TweenService = game:GetService("TweenService")

	local lp = Players.LocalPlayer
	local Combat = {}
	local aimConn, screen, circle, dummy, dummyTween
	local lastShot = 0
	local hooks = {}

	local function targetsFolder(create)
		local f = Workspace:FindFirstChild("TestTargets")
		if not f and create then
			f = Instance.new("Folder")
			f.Name = "TestTargets"
			f.Parent = Workspace
		end
		return f
	end

	local function getTargets()
		local list, f = {}, targetsFolder(false)
		if f then
			for _, m in ipairs(f:GetChildren()) do
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and m:FindFirstChild("HumanoidRootPart") then table.insert(list, m) end
			end
		end
		return list
	end

	local function nearestAim()
		local cam, c = Workspace.CurrentCamera, Config.Data.Combat
		local center = cam.ViewportSize / 2
		local best, bestD
		for _, m in ipairs(getTargets()) do
			local p = (m:FindFirstChild("Head") or m.HumanoidRootPart).Position
			local v, on = cam:WorldToViewportPoint(p)
			if on then
				local d = (Vector2.new(v.X, v.Y) - center).Magnitude
				if d <= c.Radius and (not bestD or d < bestD) then best, bestD = p, d end
			end
		end
		return best
	end

	local function step()
		local c, cam = Config.Data.Combat, Workspace.CurrentCamera
		if c.AimAssist then
			local p = nearestAim()
			if p then cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, p), c.AimStrength) end
		end
		if c.AutoShoot and os.clock() - lastShot > 0.3 then
			local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
			local f = targetsFolder(false)
			if tool and f then
				if tool.Name == "Knife" then
					local r = lp.Character:FindFirstChild("HumanoidRootPart")
					for _, m in ipairs(getTargets()) do
						if r and (m.HumanoidRootPart.Position - r.Position).Magnitude <= 10 then
							lastShot = os.clock(); tool:Activate(); break
						end
					end
					return
				end
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = { lp.Character }
				local res = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 500, params)
				if res and res.Instance:IsDescendantOf(f) then
					lastShot = os.clock()
					tool:Activate()
				end
			end
		end
	end

	-- Hitbox visualizer
	local function addHB(model)
		local r = model:FindFirstChild("HumanoidRootPart")
		if not r or r:FindFirstChild("AniHB") then return end
		local a = Instance.new("BoxHandleAdornment")
		a.Name = "AniHB"; a.Adornee = r; a.Size = Vector3.new(4, 5, 2)
		a.Transparency = 0.65; a.Color3 = Color3.new(1, 1, 1); a.AlwaysOnTop = true; a.ZIndex = 1
		a.Parent = r
	end

	local function eachModel(fn)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp and p.Character then fn(p.Character) end
		end
		for _, m in ipairs(getTargets()) do fn(m) end
	end

	local function setHitbox(on)
		if on then
			eachModel(addHB)
		else
			eachModel(function(m)
				local r = m:FindFirstChild("HumanoidRootPart")
				local a = r and r:FindFirstChild("AniHB")
				if a then a:Destroy() end
			end)
		end
	end

	local function hookPlayer(p)
		if p == lp then return end
		table.insert(hooks, p.CharacterAdded:Connect(function(c)
			if Config.Data.Combat.Hitbox then
				c:WaitForChild("HumanoidRootPart", 5)
				addHB(c)
			end
		end))
	end

	-- Training dummies (тестовые боты)
	local bots = {}

	local function removeDummy()
		if dummyTween then dummyTween:Cancel(); dummyTween = nil end
		if dummy then dummy:Destroy(); dummy = nil end
	end

	local function buildDummy(origin, travel)
		local f = targetsFolder(true)
		local m = Instance.new("Model"); m.Name = "AniDummy"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 4, 1); root.Anchored = true
		root.Color = Color3.fromRGB(200, 60, 60); root.CFrame = origin; root.Parent = m
		local head = Instance.new("Part")
		head.Name = "Head"; head.Shape = Enum.PartType.Ball; head.Size = Vector3.new(1.4, 1.4, 1.4)
		head.Color = Color3.fromRGB(230, 200, 160); head.CFrame = origin * CFrame.new(0, 2.7, 0); head.Parent = m
		local w = Instance.new("WeldConstraint"); w.Part0 = root; w.Part1 = head; w.Parent = root
		local hum = Instance.new("Humanoid"); hum.RequiresNeck = false; hum.BreakJointsOnDeath = false; hum.Parent = m
		m.PrimaryPart = root
		m.Parent = f
		local tween = TweenService:Create(root, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = origin * CFrame.new(travel, 0, 0) })
		tween:Play()
		if Config.Data.Combat.Hitbox then addHB(m) end
		return m, tween, hum
	end

	local function spawnDummy()
		removeDummy()
		local base = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local origin = base and (base.CFrame * CFrame.new(0, 0, -25)) or CFrame.new(0, 5, 0)
		local m, tween, hum = buildDummy(origin, 10)
		dummy, dummyTween = m, tween
		hum.Died:Connect(function()
			task.delay(1, function()
				if Config.Data.Combat.KnifeTraining and dummy == m then spawnDummy() end
			end)
		end)
	end

	function Combat.SpawnBots(n)
		local base = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if not base then return end
		for _ = 1, n do
			local origin = base.CFrame * CFrame.new(math.random(-30, 30), 0, -math.random(15, 45))
			local m, tween = buildDummy(origin, math.random(6, 14))
			table.insert(bots, { m = m, tw = tween })
		end
	end

	function Combat.ClearBots()
		for _, b in ipairs(bots) do b.tw:Cancel(); b.m:Destroy() end
		table.clear(bots)
	end

	function Combat.Refresh()
		local c = Config.Data.Combat
		local need = c.AimAssist or c.AutoShoot
		if need and not aimConn then
			aimConn = RunService.RenderStepped:Connect(step)
		elseif not need and aimConn then
			aimConn:Disconnect(); aimConn = nil
		end
		circle.Visible = need
		circle.Size = UDim2.fromOffset(c.Radius * 2, c.Radius * 2)
		setHitbox(c.Hitbox)
		if c.KnifeTraining then
			if not dummy then spawnDummy() end
		else
			removeDummy()
		end
	end

	function Combat.Init()
		screen = Instance.new("ScreenGui")
		screen.Name = "AniCombat"; screen.ResetOnSpawn = false; screen.IgnoreGuiInset = true; screen.DisplayOrder = 40
		screen.Parent = lp:WaitForChild("PlayerGui")
		circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5); circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.BackgroundTransparency = 1; circle.Visible = false; circle.Parent = screen
		local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = circle
		local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(170, 80, 255); st.Thickness = 1.5; st.Transparency = 0.3; st.Parent = circle

		for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
		table.insert(hooks, Players.PlayerAdded:Connect(hookPlayer))
		table.insert(hooks, Config.Changed.Event:Connect(function(cat)
			if cat == "Combat" then Combat.Refresh() end
		end))
		Combat.Refresh()
	end

	function Combat.Destroy()
		if aimConn then aimConn:Disconnect(); aimConn = nil end
		for _, h in ipairs(hooks) do h:Disconnect() end
		table.clear(hooks)
		setHitbox(false)
		removeDummy()
		Combat.ClearBots()
		if screen then screen:Destroy() end
	end

	return Combat
end)
Combat = Combat or stub()

-- ================= Visuals =================
local Visuals = loadModule("Visuals", function()
	local Lighting = game:GetService("Lighting")
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")

	local lp = Players.LocalPlayer
	local Visuals = {}

	local SKIES = {
		Black = { atmo = Color3.fromRGB(0, 0, 0), tint = Color3.fromRGB(255, 255, 255), dark = true },
		Blue = { atmo = Color3.fromRGB(60, 110, 255), tint = Color3.fromRGB(190, 210, 255) },
		Pink = { atmo = Color3.fromRGB(255, 110, 200), tint = Color3.fromRGB(255, 200, 235) },
		Red = { atmo = Color3.fromRGB(255, 40, 40), tint = Color3.fromRGB(255, 190, 190) },
	}
	local TRAILS = {
		Red = Color3.fromRGB(255, 40, 40), Black = Color3.fromRGB(0, 0, 0),
		White = Color3.fromRGB(255, 255, 255), Orange = Color3.fromRGB(255, 140, 0),
	}
	local LEGS = {
		["Left Leg"] = true, ["Right Leg"] = true, LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
		RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	}

	local saved, mine, currentSky, stretchBound = {}, {}, "Default", false

	local function clearSky()
		for _, o in ipairs(mine) do o:Destroy() end
		table.clear(mine)
		for _, o in ipairs(saved) do o.Parent = Lighting end
		table.clear(saved)
		currentSky = "Default"
	end

	local function applySky(name)
		if name == currentSky then return end
		clearSky()
		local d = SKIES[name]
		if not d then return end
		for _, o in ipairs(Lighting:GetChildren()) do
			if o:IsA("Sky") or o:IsA("Atmosphere") then
				table.insert(saved, o)
				o.Parent = nil
			end
		end
		local sky = Instance.new("Sky")
		for _, f in ipairs({ "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }) do sky[f] = "" end
		sky.StarCount = 0; sky.CelestialBodiesShown = false; sky.Parent = Lighting
		local at = Instance.new("Atmosphere")
		at.Density = 0.4; at.Offset = 0.25; at.Color = d.atmo; at.Decay = d.atmo; at.Glare = 0; at.Haze = d.dark and 0 or 2
		at.Parent = Lighting
		local cc = Instance.new("ColorCorrectionEffect")
		cc.TintColor = d.tint; cc.Parent = Lighting
		mine = { sky, at, cc }
		currentSky = name
	end

	local function setStretch()
		local on = Config.Data.Visuals.Stretch
		if on and not stretchBound then
			stretchBound = true
			RunService:BindToRenderStep("AniStretch", Enum.RenderPriority.Camera.Value + 1, function()
				local cam = Workspace.CurrentCamera
				cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, Config.Data.Visuals.StretchScale, 0, 0, 0, 1)
			end)
		elseif not on and stretchBound then
			RunService:UnbindFromRenderStep("AniStretch")
			stretchBound = false
		end
	end

	local function setHidden(inst, hide)
		local prop = "Transparency"
		if hide then
			if inst:GetAttribute("AniT") == nil then inst:SetAttribute("AniT", inst[prop]) end
			inst[prop] = 1
		else
			local t = inst:GetAttribute("AniT")
			if t ~= nil then inst[prop] = t; inst:SetAttribute("AniT", nil) end
		end
	end

	local function applyChar(char)
		if not char then return end
		local v = Config.Data.Visuals
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Name == "Head" then
					setHidden(d, v.HideHead)
				elseif LEGS[d.Name] then
					setHidden(d, v.HideLegs)
				elseif d.Name == "Handle" and d.Parent:IsA("Accessory") then
					local t = d.Parent.AccessoryType
					if t == Enum.AccessoryType.Hat or t == Enum.AccessoryType.Hair or t == Enum.AccessoryType.Face then
						setHidden(d, v.HideHead)
					end
				end
			elseif d:IsA("Decal") and d.Parent and d.Parent.Name == "Head" then
				setHidden(d, v.HideHead)
			end
		end
	end

	local function applyTrail(char)
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		for _, n in ipairs({ "AniTrail", "AniA0", "AniA1" }) do
			local o = root:FindFirstChild(n)
			if o then o:Destroy() end
		end
		local col = TRAILS[Config.Data.Visuals.Trail]
		if not col then return end
		local a0 = Instance.new("Attachment"); a0.Name = "AniA0"; a0.Position = Vector3.new(0, 1, 0); a0.Parent = root
		local a1 = Instance.new("Attachment"); a1.Name = "AniA1"; a1.Position = Vector3.new(0, -1, 0); a1.Parent = root
		local t = Instance.new("Trail")
		t.Name = "AniTrail"; t.Attachment0 = a0; t.Attachment1 = a1
		t.Color = ColorSequence.new(col); t.Lifetime = 0.6
		t.LightEmission = (Config.Data.Visuals.Trail == "Black") and 0 or 0.6
		t.Transparency = NumberSequence.new(0, 1)
		t.Parent = root
	end

	function Visuals.ApplyAll()
		local v = Config.Data.Visuals
		applySky(v.Sky)
		setStretch()
		applyChar(lp.Character)
		applyTrail(lp.Character)
	end

	function Visuals.Init()
		lp.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 5)
			Visuals.ApplyAll()
			task.delay(1.5, function() applyChar(char) end) -- аксессуары догружаются позже
		end)
		Config.Changed.Event:Connect(function(cat)
			if cat == "Visuals" then Visuals.ApplyAll() end
		end)
	end

	function Visuals.Destroy()
		clearSky()
		if stretchBound then RunService:UnbindFromRenderStep("AniStretch"); stretchBound = false end
		local char = lp.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				for _, n in ipairs({ "AniTrail", "AniA0", "AniA1" }) do
					local o = root:FindFirstChild(n)
					if o then o:Destroy() end
				end
			end
			Config.Data.Visuals.HideHead, Config.Data.Visuals.HideLegs = false, false
			applyChar(char)
		end
	end

	return Visuals
end)
Visuals = Visuals or stub()

-- ================= Skins =================
local Skins = loadModule("Skins", function()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")

	local lp = Players.LocalPlayer
	local Skins = {}
	local spin, origDesc

	local BONE = Color3.fromRGB(235, 230, 215)
	local GROUND = -3 -- расстояние от центра HumanoidRootPart до земли

	-- ===== построение моделей из частей =====
	local function newPart(model, name, kind, size, color, mat)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
		if kind == "blob" then
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = p
		elseif kind == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		end
		p.Parent = model
		return p
	end

	local function weld(p, base, cf)
		p.CFrame = base.CFrame * cf
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = base, p
		w.Parent = p
	end

	local function D(kind, size, pos, color, rot)
		return { k = kind, size = size, pos = pos, color = color, rot = rot or CFrame.new() }
	end

	local function build(root, model, defs, s, gy)
		for i, d in ipairs(defs) do
			local p = newPart(model, "P" .. i, d.k, d.size * s, d.color)
			weld(p, root, CFrame.new(d.pos.X * s, gy + d.pos.Y * s, d.pos.Z * s) * d.rot)
		end
	end

	local function potatoDefs()
		local brown, dark = Color3.fromRGB(168, 120, 70), Color3.fromRGB(120, 80, 45)
		local black = Color3.fromRGB(20, 20, 20)
		local defs = {
			D("blob", Vector3.new(1.9, 1.4, 1.5), Vector3.new(0, 0.8, 0), brown),
			D("blob", Vector3.new(0.28, 0.2, 0.22), Vector3.new(0.55, 1.15, -0.5), dark),
			D("blob", Vector3.new(0.3, 0.2, 0.22), Vector3.new(-0.6, 0.95, -0.45), dark),
			D("blob", Vector3.new(0.3, 0.2, 0.25), Vector3.new(0.1, 1.45, 0.15), dark),
			D("blob", Vector3.new(0.22, 0.28, 0.1), Vector3.new(0.3, 0.95, -0.7), black),
			D("blob", Vector3.new(0.22, 0.28, 0.1), Vector3.new(-0.3, 0.95, -0.7), black),
			D("block", Vector3.new(0.35, 0.07, 0.06), Vector3.new(0, 0.6, -0.73), black),
		}
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(defs, D("blob", Vector3.new(0.45, 0.25, 0.6), Vector3.new(sx * 0.4, 0.12, -0.1), dark))
		end
		return defs
	end

	local function skeletonDefs()
		local black = Color3.fromRGB(15, 15, 15)
		local defs = {
			D("blob", Vector3.new(1.0, 1.1, 1.0), Vector3.new(0, 4.35, 0), BONE),
			D("blob", Vector3.new(0.24, 0.3, 0.2), Vector3.new(0.22, 4.4, -0.42), black),
			D("blob", Vector3.new(0.24, 0.3, 0.2), Vector3.new(-0.22, 4.4, -0.42), black),
			D("blob", Vector3.new(0.1, 0.18, 0.1), Vector3.new(0, 4.2, -0.48), black),
			D("block", Vector3.new(0.6, 0.22, 0.6), Vector3.new(0, 3.8, -0.05), BONE),
			D("block", Vector3.new(0.18, 1.5, 0.18), Vector3.new(0, 2.85, 0.05), BONE),
			D("block", Vector3.new(0.95, 0.25, 0.45), Vector3.new(0, 2.0, 0), BONE),
		}
		for i = 1, 4 do
			table.insert(defs, D("block", Vector3.new(1.05 - i * 0.07, 0.09, 0.5), Vector3.new(0, 3.5 - (i - 1) * 0.22, 0), BONE))
		end
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(defs, D("block", Vector3.new(0.14, 0.9, 0.14), Vector3.new(sx * 0.68, 3.1, 0), BONE))
			table.insert(defs, D("block", Vector3.new(0.12, 0.85, 0.12), Vector3.new(sx * 0.72, 2.2, 0), BONE))
			table.insert(defs, D("blob", Vector3.new(0.2, 0.2, 0.2), Vector3.new(sx * 0.72, 1.7, 0), BONE))
			table.insert(defs, D("block", Vector3.new(0.17, 0.95, 0.17), Vector3.new(sx * 0.3, 1.45, 0), BONE))
			table.insert(defs, D("block", Vector3.new(0.14, 0.9, 0.14), Vector3.new(sx * 0.3, 0.5, 0), BONE))
			table.insert(defs, D("block", Vector3.new(0.22, 0.1, 0.45), Vector3.new(sx * 0.3, 0.05, -0.1), BONE))
		end
		return defs
	end

	-- Дрон «Шахед»: сигарообразный корпус, треугольное крыло, шайбы на концах, вращающийся пропеллер
	local function buildDrone(root, model)
		local gray, light, darkc = Color3.fromRGB(190, 195, 200), Color3.fromRGB(215, 218, 222), Color3.fromRGB(70, 72, 76)
		local defs = {
			D("cyl", Vector3.new(5.5, 0.9, 0.9), Vector3.new(0, 0, 0), gray, CFrame.Angles(0, math.rad(90), 0)),
			D("blob", Vector3.new(0.9, 0.9, 1.5), Vector3.new(0, 0, -3.1), gray),
			D("cyl", Vector3.new(0.8, 0.7, 0.7), Vector3.new(0, 0, 3.0), darkc, CFrame.Angles(0, math.rad(90), 0)),
		}
		for i = 0, 7 do
			table.insert(defs, D("block", Vector3.new(0.7 + i * 0.9, 0.1, 0.64), Vector3.new(0, -0.05, -2.2 + i * 0.62), light))
		end
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(defs, D("block", Vector3.new(0.1, 1.2, 0.9), Vector3.new(sx * 3.45, 0.15, 1.85), gray, CFrame.Angles(0, 0, math.rad(-sx * 15))))
		end
		build(root, model, defs, 1, 0)

		-- пропеллер (крутится)
		local hub = newPart(model, "Hub", "blob", Vector3.new(0.25, 0.25, 0.25), darkc)
		for _, size in ipairs({ Vector3.new(1.7, 0.12, 0.06), Vector3.new(0.12, 1.7, 0.06) }) do
			local b = newPart(model, "Blade", "block", size, darkc)
			b.CFrame = hub.CFrame
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = hub, b
			w.Parent = b
		end
		local j = Instance.new("Weld")
		j.Part0, j.Part1 = root, hub
		j.C0 = CFrame.new(0, 0, 3.55)
		j.Parent = hub
		local ang = 0
		spin = RunService.Heartbeat:Connect(function(dt)
			ang += dt * 30
			j.C1 = CFrame.Angles(0, 0, ang)
		end)
	end

	-- ===== скрытие настоящего персонажа =====
	local function hide(char, on)
		local skin = char:FindFirstChild("AniSkin")
		for _, d in ipairs(char:GetDescendants()) do
			if not (skin and d:IsDescendantOf(skin)) then
				if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
					if on then
						if d:GetAttribute("AniSkT") == nil then d:SetAttribute("AniSkT", d.Transparency) end
						d.Transparency = 1
					else
						local t = d:GetAttribute("AniSkT")
						if t ~= nil then d.Transparency = t; d:SetAttribute("AniSkT", nil) end
					end
				end
			end
		end
	end

	local function clearSkin(char)
		if spin then spin:Disconnect(); spin = nil end
		local m = char and char:FindFirstChild("AniSkin")
		if m then m:Destroy() end
	end

	function Skins.Apply()
		local char = lp.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		clearSkin(char)
		hide(char, false)
		local name = Config.Data.Skins.Skin
		if name == "Default" then return end
		hide(char, true)
		local model = Instance.new("Model")
		model.Name = "AniSkin"
		model.Parent = char
		if name == "Shahed" then
			buildDrone(root, model)
		elseif name == "Potato" then
			build(root, model, potatoDefs(), 1, GROUND)
		elseif name == "Skeleton" then
			build(root, model, skeletonDefs(), 0.62, GROUND)
		end
	end

	-- ===== каталог: скин другого игрока по нику =====
	-- Возвращает userId, thumbnail  ИЛИ  nil, текст ошибки (вызывать из task.spawn — функция ждёт ответ)
	function Skins.Lookup(name)
		local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, name)
		if not ok or not id then return nil, "Игрок с таким ником не найден" end
		local ok2, thumb = pcall(Players.GetUserThumbnailAsync, Players, id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		return id, ok2 and thumb or ""
	end

	local function myHumanoid()
		local char = lp.Character
		return char and char:FindFirstChildOfClass("Humanoid")
	end

	function Skins.ApplyUser(userId)
		local hum = myHumanoid()
		if not hum then return false, "Нет персонажа" end
		if not origDesc then
			local ok, d = pcall(function() return hum:GetAppliedDescription() end)
			if ok then origDesc = d end
		end
		if Config.Data.Skins.Skin ~= "Default" then Config.Set("Skins", "Skin", "Default") end
		local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
		if not ok or not desc then return false, "Не удалось получить скин игрока" end
		local ok2, err = pcall(function() hum:ApplyDescription(desc) end)
		if not ok2 then return false, tostring(err) end
		return true
	end

	function Skins.ResetAppearance()
		local hum = myHumanoid()
		if not hum then return false, "Нет персонажа" end
		if Config.Data.Skins.Skin ~= "Default" then Config.Set("Skins", "Skin", "Default") end
		local desc = origDesc
		if not desc then
			local ok, d = pcall(Players.GetHumanoidDescriptionFromUserId, Players, lp.UserId)
			if not ok then return false, "Не удалось получить свой скин" end
			desc = d
		end
		local ok2, err = pcall(function() hum:ApplyDescription(desc) end)
		if not ok2 then return false, tostring(err) end
		return true
	end

	function Skins.Init()
		lp.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart", 5)
			task.wait(0.3)
			origDesc = nil
			Skins.Apply()
			task.delay(1.5, function()
				if char.Parent and Config.Data.Skins.Skin ~= "Default" then Skins.Apply() end
			end)
		end)
		Config.Changed.Event:Connect(function(cat)
			if cat == "Skins" then Skins.Apply() end
		end)
	end

	function Skins.Destroy()
		local char = lp.Character
		if char then
			clearSkin(char)
			hide(char, false)
		end
	end

	return Skins
end)
Skins = Skins or stub()

-- ================= UI =================
local UI = loadModule("UI", function()
	local TweenService = game:GetService("TweenService")
	local UIS = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")


	local UI = {}
	UI.Closed = Instance.new("BindableEvent")

	local ACCENT = Color3.fromRGB(170, 80, 255)
	local FONT, FONTB = Enum.Font.GothamMedium, Enum.Font.GothamBold
	local TG = "@ani_Visual0"
	local DARK = Color3.fromRGB(22, 22, 28)

	local gui
	local conns = {}
	local neon = {}

	local function make(class, props, parent)
		local o = Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		o.Parent = parent
		return o
	end
	local function corner(o, r) return make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
	local function tw(o, props, t)
		TweenService:Create(o, TweenInfo.new((t or 0.2) / math.max(Config.Data.UI.AnimSpeed, 0.1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	end
	local function listen(cat, key, fn)
		table.insert(conns, Config.Changed.Event:Connect(function(c, k, v)
			if c == cat and k == key then fn(v) end
		end))
	end
	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	local function isMove(i)
		return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
	end

	local function draggable(handle, target, onEnd)
		local state = { moved = false }
		local dragging, startIn, startPos
		handle.InputBegan:Connect(function(i)
			if isPress(i) then
				dragging, state.moved = true, false
				startIn, startPos = i.Position, target.Position
				local c
				c = i.Changed:Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						dragging = false
						c:Disconnect()
						if onEnd then onEnd(target.Position) end
					end
				end)
			end
		end)
		table.insert(conns, UIS.InputChanged:Connect(function(i)
			if dragging and isMove(i) then
				local d = i.Position - startIn
				if d.Magnitude > 6 then state.moved = true end
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end))
		return state
	end

	-- ===== controls =====
	local function nextOrder(page)
		local n = (page:GetAttribute("n") or 0) + 1
		page:SetAttribute("n", n)
		return n
	end
	local function row(page, h)
		local f = make("Frame", { Size = UDim2.new(1, -6, 0, h or 34), BackgroundColor3 = DARK, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = nextOrder(page) }, page)
		corner(f, 8)
		return f
	end
	local function label(f, text, top)
		return make("TextLabel", {
			Position = UDim2.fromOffset(10, 0), Size = top and UDim2.new(1, -80, 0, 26) or UDim2.new(1, -60, 1, 0),
			BackgroundTransparency = 1, Text = text, Font = FONT, TextSize = 13, TextColor3 = Color3.fromRGB(235, 235, 240),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, f)
	end

	local function Toggle(page, text, cat, key)
		local f = row(page); label(f, text)
		local sw = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(40, 20), Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(50, 50, 56) }, f)
		corner(sw, 10)
		local knob = make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, sw)
		corner(knob, 8)
		local function render(on)
			tw(sw, { BackgroundColor3 = on and ACCENT or Color3.fromRGB(50, 50, 56) }, 0.15)
			tw(knob, { Position = on and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2) }, 0.15)
		end
		render(Config.Data[cat][key])
		sw.Activated:Connect(function() Config.Set(cat, key, not Config.Data[cat][key]) end)
		listen(cat, key, render)
	end

	local function Slider(page, text, cat, key, min, max, step, fmt)
		local f = row(page, 46); label(f, text, true)
		local val = make("TextLabel", { Position = UDim2.new(1, -70, 0, 0), Size = UDim2.fromOffset(60, 26), BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Right }, f)
		local hit = make("Frame", { Position = UDim2.new(0, 10, 0, 26), Size = UDim2.new(1, -20, 0, 16), BackgroundTransparency = 1 }, f)
		local track = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(45, 45, 52), BorderSizePixel = 0 }, hit)
		corner(track, 3)
		local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }, track)
		corner(fill, 3)
		local function render(v)
			fill.Size = UDim2.fromScale(math.clamp((v - min) / (max - min), 0, 1), 1)
			val.Text = string.format(fmt or "%d", v)
		end
		render(Config.Data[cat][key])
		listen(cat, key, render)
		local dragging = false
		local function setX(x)
			local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			local v = math.clamp(math.floor((min + a * (max - min)) / step + 0.5) * step, min, max)
			Config.Set(cat, key, v)
		end
		hit.InputBegan:Connect(function(i)
			if isPress(i) then
				dragging = true
				page.ScrollingEnabled = false
				setX(i.Position.X)
				local c
				c = i.Changed:Connect(function()
					if i.UserInputState == Enum.UserInputState.End then
						dragging = false; page.ScrollingEnabled = true; c:Disconnect()
					end
				end)
			end
		end)
		table.insert(conns, UIS.InputChanged:Connect(function(i)
			if dragging and isMove(i) then setX(i.Position.X) end
		end))
	end

	local function Button(page, text, cb)
		local f = row(page, 34)
		local b = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = ACCENT, BackgroundTransparency = 0.55, Text = text, Font = FONTB, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true }, f)
		corner(b, 8)
		b.Activated:Connect(cb)
		return b
	end

	local function Choices(page, text, options, cat, key)
		local f = row(page, 58); label(f, text, true)
		local holder = make("Frame", { Position = UDim2.new(0, 8, 0, 28), Size = UDim2.new(1, -16, 0, 24), BackgroundTransparency = 1 }, f)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, holder)
		local btns = {}
		for _, opt in ipairs(options) do
			local b = make("TextButton", { Size = UDim2.new(1 / #options, -4, 1, 0), Text = opt, Font = FONT, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(40, 40, 46) }, holder)
			corner(b, 6)
			btns[opt] = b
			b.Activated:Connect(function() Config.Set(cat, key, opt) end)
		end
		local function render(v)
			for o, b in pairs(btns) do tw(b, { BackgroundColor3 = (o == v) and ACCENT or Color3.fromRGB(40, 40, 46) }, 0.15) end
		end
		render(Config.Data[cat][key])
		listen(cat, key, render)
	end

	local PALETTE = {
		Color3.fromRGB(255, 40, 40), Color3.fromRGB(60, 120, 255), Color3.fromRGB(60, 220, 90), Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 150, 0), Color3.fromRGB(190, 90, 255), Color3.fromRGB(255, 90, 200), Color3.fromRGB(0, 230, 230),
	}
	local function ColorCycle(page, text, cat, key)
		local f = row(page); label(f, text)
		local b = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(40, 20), Text = "", AutoButtonColor = false, BackgroundColor3 = Config.Data[cat][key] }, f)
		corner(b, 6)
		make("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.6 }, b)
		b.Activated:Connect(function()
			local cur, idx = Config.Data[cat][key], 0
			for i, c in ipairs(PALETTE) do if c == cur then idx = i end end
			Config.Set(cat, key, PALETTE[idx % #PALETTE + 1])
		end)
		listen(cat, key, function(v) tw(b, { BackgroundColor3 = v }, 0.15) end)
	end

	local function Input(page, text, cat, key, placeholder)
		local f = row(page); label(f, text)
		local box = make("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.5, 0, 0, 24), BackgroundColor3 = Color3.fromRGB(35, 35, 42), Text = Config.Data[cat][key], PlaceholderText = placeholder or "", Font = FONT, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), ClearTextOnFocus = false }, f)
		corner(box, 6)
		box.FocusLost:Connect(function() Config.Set(cat, key, box.Text) end)
		listen(cat, key, function(v) box.Text = tostring(v) end)
		return box
	end

	local function Note(page, text)
		local f = row(page, 30)
		f.BackgroundTransparency = 1
		local l = label(f, text); l.Size = UDim2.new(1, -10, 1, 0); l.TextSize = 11; l.TextColor3 = Color3.fromRGB(150, 150, 165); l.TextWrapped = true
	end

	local function copyBox(box)
		box.Text = TG
		box:CaptureFocus()
		task.defer(function()
			box.CursorPosition = #TG + 1
			box.SelectionStart = 1
		end)
	end

	-- ===== build =====
	function UI.Build()
		local lp = Players.LocalPlayer
		local cfg = Config.Data.UI
		gui = make("ScreenGui", { Name = "AniVisualGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, lp:WaitForChild("PlayerGui"))
		UI.Gui = gui

		local vp = Workspace.CurrentCamera.ViewportSize
		local W, H = math.clamp(vp.X - 24, 300, 540), math.clamp(vp.Y - 60, 260, 400)
		local defaultPos = UDim2.fromScale(0.5, 0.5)

		local win = make("CanvasGroup", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W, H), Position = Config.State.MenuPos or defaultPos, BackgroundTransparency = 1, GroupTransparency = 1 }, gui)
		corner(win, 16)
		local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 8), BackgroundTransparency = cfg.Transparency, BorderSizePixel = 0 }, win)
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 150, 255)), Rotation = 60 }, bg)
		listen("UI", "Transparency", function(v) bg.BackgroundTransparency = v end)

		local outline = make("Frame", { Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), BackgroundTransparency = 1 }, win)
		corner(outline, 15)
		local outStroke = make("UIStroke", { Color = ACCENT, Thickness = 1.5, Transparency = 0.35 }, outline)
		table.insert(neon, outStroke)

		-- header
		local header = make("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1 }, win)
		local title = make("TextLabel", { Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -90, 0, 24), BackgroundTransparency = 1, Text = "ANI VISUAL", Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left }, header)
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), ACCENT) }, title)
		make("TextLabel", { Position = UDim2.fromOffset(15, 27), Size = UDim2.new(1, -90, 0, 14), BackgroundTransparency = 1, Text = "PREMIUM", Font = FONTB, TextSize = 10, TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Left }, header)

		local function headBtn(txt, xOff)
			local b = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, xOff, 0, 9), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = DARK, BackgroundTransparency = 0.2, Text = txt, Font = FONTB, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true }, header)
			corner(b, 8)
			return b
		end
		local btnMin, btnClose = headBtn("–", -44), headBtn("✕", -10)

		draggable(header, win, function(pos) Config.State.MenuPos = pos end)

		-- tabs + pages
		local tabBar = make("ScrollingFrame", { Position = UDim2.fromOffset(8, 48), Size = UDim2.new(1, -16, 0, 30), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, BorderSizePixel = 0 }, win)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, tabBar)

		local names = { "Combat", "ESP", "Misc", "Visuals", "Catalog", "Teleports", "Settings" }
		local pages, tabs = {}, {}
		local function selectTab(n)
			for k, pg in pairs(pages) do pg.Visible = (k == n) end
			for k, tb in pairs(tabs) do tw(tb, { BackgroundColor3 = (k == n) and ACCENT or DARK }, 0.15) end
		end
		for _, n in ipairs(names) do
			local p = make("ScrollingFrame", { Position = UDim2.fromOffset(8, 84), Size = UDim2.new(1, -16, 1, -92), BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENT, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Visible = false }, win)
			make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, p)
			make("UIPadding", { PaddingBottom = UDim.new(0, 8) }, p)
			pages[n] = p
			local t = make("TextButton", { Size = UDim2.fromOffset(#n * 8 + 28, 26), Text = n, Font = FONTB, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, BackgroundColor3 = DARK, BackgroundTransparency = 0.2 }, tabBar)
			corner(t, 8)
			tabs[n] = t
			t.Activated:Connect(function() selectTab(n) end)
		end

		-- Combat
		local P = pages.Combat
		Note(P, "Работает только по мишеням в Workspace.TestTargets (своя тестовая среда).")
		Toggle(P, "Aim Assist", "Combat", "AimAssist")
		Toggle(P, "Auto Shoot", "Combat", "AutoShoot")
		Toggle(P, "Knife Training (мишень)", "Combat", "KnifeTraining")
		Toggle(P, "Hitbox Visualizer", "Combat", "Hitbox")
		Slider(P, "Радиус обнаружения (px)", "Combat", "Radius", 50, 400, 5)
		Slider(P, "Сила наведения", "Combat", "AimStrength", 0.05, 0.5, 0.01, "%.2f")
		Button(P, "Создать 5 тестовых ботов", function() Combat.SpawnBots(5) end)
		Button(P, "Удалить ботов", function() Combat.ClearBots() end)

		-- ESP
		P = pages.ESP
		Toggle(P, "Players ESP", "ESP", "Enabled")
		Toggle(P, "Boxes", "ESP", "Boxes")
		Toggle(P, "Highlight (контур силуэта)", "ESP", "Highlight")
		Toggle(P, "Tracers", "ESP", "Tracers")
		Toggle(P, "Distance", "ESP", "Distance")
		Toggle(P, "Names", "ESP", "Names")
		Choices(P, "Единицы расстояния", { "studs", "meters" }, "ESP", "Units")
		Slider(P, "Прозрачность рамок", "ESP", "BoxTransparency", 0, 1, 0.05, "%.2f")
		Slider(P, "Толщина контуров", "ESP", "Thickness", 1, 5, 0.5, "%.1f")
		Slider(P, "Толщина трассеров", "ESP", "TracerThickness", 1, 5, 0.5, "%.1f")
		Slider(P, "Дальность (studs)", "ESP", "MaxDistance", 50, 2000, 50)
		Slider(P, "Размер текста", "ESP", "TextSize", 10, 24, 1)
		ColorCycle(P, "Цвет: Murderer", "ESP", "ColorMurderer")
		ColorCycle(P, "Цвет: Sheriff", "ESP", "ColorSheriff")
		ColorCycle(P, "Цвет: Innocent", "ESP", "ColorInnocent")
		ColorCycle(P, "Цвет трассеров", "ESP", "ColorTracer")
		Toggle(P, "Pistol ESP + кнопка ПОДБОР", "Gun", "ESP")
		ColorCycle(P, "Цвет пистолета", "Gun", "Color")

		-- Misc
		P = pages.Misc
		Input(P, "Roblox Audio ID", "Misc", "AudioId", "123456789")
		Button(P, "▶  PLAY", function() Music.Play(Config.Data.Misc.AudioId) end)
		Button(P, "■  STOP", function() Music.Stop() end)
		Slider(P, "Громкость", "Misc", "Volume", 0, 1, 0.05, "%.2f")
		Toggle(P, "Пузырьки", "UI", "BubblesEnabled")
		Toggle(P, "Неоновые контуры", "Misc", "Neon")
		listen("Misc", "Neon", function(on) for _, s in ipairs(neon) do s.Transparency = on and 0.35 or 1 end end)

		-- Visuals
		P = pages.Visuals
		Choices(P, "Sky Changer", { "Default", "Black", "Blue", "Pink", "Red" }, "Visuals", "Sky")
		Toggle(P, "Screen Stretch", "Visuals", "Stretch")
		Slider(P, "Масштаб Stretch", "Visuals", "StretchScale", 0.4, 1, 0.05, "%.2f")
		Button(P, "Вернуть стандартный экран", function()
			Config.Set("Visuals", "Stretch", false); Config.Set("Visuals", "StretchScale", 0.7)
		end)
		Toggle(P, "Bubbles", "UI", "BubblesEnabled")
		Slider(P, "Количество пузырьков", "UI", "BubbleCount", 0, 40, 1)
		Slider(P, "Скорость пузырьков", "UI", "BubbleSpeed", 0.2, 3, 0.1, "%.1f")
		Slider(P, "Размер пузырьков", "UI", "BubbleSize", 0.5, 2.5, 0.1, "%.1f")
		ColorCycle(P, "Цвет пузырьков", "UI", "BubbleColor")
		Choices(P, "Trails", { "None", "Red", "Black", "White", "Orange" }, "Visuals", "Trail")
		Toggle(P, "Скрыть голову (локально)", "Visuals", "HideHead")
		Toggle(P, "Скрыть ноги (локально)", "Visuals", "HideLegs")

		-- Catalog (скины)
		P = pages.Catalog
		Note(P, "Скины видны только тебе (локально). Shahed = дрон.")
		Choices(P, "Скин", { "Default", "Shahed", "Potato", "Skeleton" }, "Skins", "Skin")
		local qRow = row(P, 34)
		local qBox = make("TextBox", { Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 5), BackgroundColor3 = Color3.fromRGB(35, 35, 42), Text = "", PlaceholderText = "Ник игрока Roblox...", Font = FONT, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), ClearTextOnFocus = false }, qRow)
		corner(qBox, 6)
		local card = row(P, 76)
		local img = make("ImageLabel", { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.fromRGB(35, 35, 42), Image = "" }, card)
		corner(img, 8)
		local info = make("TextLabel", { Position = UDim2.fromOffset(82, 6), Size = UDim2.new(1, -90, 1, -12), BackgroundTransparency = 1, Text = "Введи ник и нажми «Найти»", Font = FONT, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true }, card)
		local foundId
		local function search(nm)
			local name = string.gsub(nm or qBox.Text, "%s", "")
			if name == "" then info.Text = "Введи ник игрока"; return end
			info.Text = "Поиск..."
			task.spawn(function()
				local id, thumb = Skins.Lookup(name)
				if not id then
					foundId = nil; img.Image = ""; info.Text = thumb or "Не найден"
					return
				end
				foundId = id
				img.Image = thumb or ""
				info.Text = name .. "\nID: " .. id .. "\nНажми «Применить скин игрока»"
			end)
		end
		qBox.FocusLost:Connect(function(enter) if enter then search() end end)
		Button(P, "Найти игрока", function() search() end)
		Button(P, "Применить скин игрока", function()
			if not foundId then info.Text = "Сначала найди игрока"; return end
			info.Text = "Применяю..."
			task.spawn(function()
				local ok, err = Skins.ApplyUser(foundId)
				info.Text = ok and "Скин применён (виден только тебе)" or ("Ошибка: " .. tostring(err))
			end)
		end)
		Button(P, "Вернуть мой скин", function()
			task.spawn(function()
				local ok, err = Skins.ResetAppearance()
				info.Text = ok and "Мой скин возвращён" or ("Ошибка: " .. tostring(err))
			end)
		end)
		Note(P, "Игроки на сервере — тап, чтобы найти:")
		local clist = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1000 }, P)
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, clist)
		local function crebuild()
			for _, c in ipairs(clist:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			for i, p in ipairs(Teleports.List("")) do
				local b = make("TextButton", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 28), Text = "  " .. p.DisplayName .. "  (@" .. p.Name .. ")", TextXAlignment = Enum.TextXAlignment.Left, Font = FONT, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = DARK, BackgroundTransparency = 0.3, AutoButtonColor = true }, clist)
				corner(b, 6)
				b.Activated:Connect(function() qBox.Text = p.Name; search(p.Name) end)
			end
		end
		table.insert(conns, Players.PlayerAdded:Connect(crebuild))
		table.insert(conns, Players.PlayerRemoving:Connect(function() task.defer(crebuild) end))
		crebuild()

		-- Teleports
		P = pages.Teleports
		local sel
		local searchRow = row(P, 34)
		local search = make("TextBox", { Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 5), BackgroundColor3 = Color3.fromRGB(35, 35, 42), Text = "", PlaceholderText = "Поиск по имени...", Font = FONT, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), ClearTextOnFocus = false }, searchRow)
		corner(search, 6)
		local selRow = row(P, 30)
		local selLabel = label(selRow, "Выбран: —")
		local listFrame = make("Frame", { Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1000 }, P)
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
		local function rebuild()
			for _, c in ipairs(listFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			for i, p in ipairs(Teleports.List(search.Text)) do
				local b = make("TextButton", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 28), Text = "  " .. p.DisplayName .. "  (@" .. p.Name .. ")", TextXAlignment = Enum.TextXAlignment.Left, Font = FONT, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = DARK, BackgroundTransparency = 0.3, AutoButtonColor = true }, listFrame)
				corner(b, 6)
				b.Activated:Connect(function() sel = p; selLabel.Text = "Выбран: " .. p.Name end)
			end
			if sel and not sel.Parent then sel = nil; selLabel.Text = "Выбран: —" end
		end
		Button(P, "Обновить список", rebuild)
		Button(P, "Телепорт к выбранному", function()
			if not sel then selLabel.Text = "Выбери игрока из списка"; return end
			selLabel.Text = Teleports.To(sel) and ("Телепорт: " .. sel.Name) or "Не удалось (нет персонажа)"
		end)
		search:GetPropertyChangedSignal("Text"):Connect(rebuild)
		table.insert(conns, Players.PlayerAdded:Connect(rebuild))
		table.insert(conns, Players.PlayerRemoving:Connect(function() task.defer(rebuild) end))
		rebuild()

		-- Settings
		P = pages.Settings
		Button(P, "Reset Settings", function() Config.ResetAll() end)
		local function resetPos()
			Config.State.MenuPos, Config.State.FloatPos = nil, nil
			win.Position = defaultPos
			UI.FloatDefault()
		end
		Button(P, "Reset GUI Position", resetPos)
		Button(P, "Reset Visuals", function() Config.ResetCategory("Visuals") end)
		Slider(P, "Menu Transparency", "UI", "Transparency", 0, 0.9, 0.05, "%.2f")
		Slider(P, "Animation Speed", "UI", "AnimSpeed", 0.3, 3, 0.1, "%.1f")
		Toggle(P, "Bubbles", "UI", "BubblesEnabled")
		Slider(P, "Bubbles: количество", "UI", "BubbleCount", 0, 40, 1)
		Slider(P, "Bubbles: скорость", "UI", "BubbleSpeed", 0.2, 3, 0.1, "%.1f")
		Slider(P, "Bubbles: размер", "UI", "BubbleSize", 0.5, 2.5, 0.1, "%.1f")
		Note(P, "Ani Visual v" .. Config.Version .. "  •  Luau, LocalScript + ModuleScripts")
		local foot = row(P, 96)
		make("TextLabel", { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "ANI VISUAL", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = ACCENT }, foot)
		local tgBox = make("TextBox", { Position = UDim2.new(0.5, 0, 0, 30), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(1, -20, 0, 22), BackgroundTransparency = 1, Text = "Telegram: " .. TG, Font = FONT, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), ClearTextOnFocus = false, TextEditable = false }, foot)
		local copyBtn = make("TextButton", { Position = UDim2.new(0.5, 0, 0, 58), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(1, -20, 0, 28), BackgroundColor3 = ACCENT, BackgroundTransparency = 0.4, Text = "COPY TELEGRAM", Font = FONTB, TextSize = 12, TextColor3 = Color3.new(1, 1, 1) }, foot)
		corner(copyBtn, 8)
		copyBtn.Activated:Connect(function()
			tgBox.Text = TG
			copyBox(tgBox)
			copyBtn.Text = "ВЫДЕЛЕНО — СКОПИРУЙ (Ctrl+C / долгий тап)"
			task.delay(3, function() copyBtn.Text = "COPY TELEGRAM"; tgBox.Text = "Telegram: " .. TG end)
		end)

		-- floating Ani button
		local float = make("TextButton", { Name = "AniFloat", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(46, 46), Position = Config.State.FloatPos or UDim2.new(0.5, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(8, 8, 8), BackgroundTransparency = 0.15, Text = "Ani", Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Visible = false }, gui)
		corner(float, 23)
		local fs = make("UIStroke", { Color = ACCENT, Thickness = 2, Transparency = 0.2 }, float)
		table.insert(neon, fs)
		local fdrag = draggable(float, float, function(pos) Config.State.FloatPos = pos end)
		function UI.FloatDefault() float.Position = UDim2.new(0.5, 0, 0, 50) end

		-- кнопка ПОДБОР (видна при включённом Pistol ESP)
		local pick = make("TextButton", { Name = "AniPickup", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(110, 46), BackgroundColor3 = Color3.fromRGB(8, 8, 8), BackgroundTransparency = 0.15, Text = "ПОДБОР", Font = FONTB, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Visible = Config.Data.Gun.ESP }, gui)
		corner(pick, 12)
		table.insert(neon, make("UIStroke", { Color = Color3.fromRGB(255, 220, 0), Thickness = 2, Transparency = 0.2 }, pick))
		local pdrag = draggable(pick, pick)
		pick.Activated:Connect(function() if not pdrag.moved then Gun.Pickup() end end)
		table.insert(conns, Gun.Status.Event:Connect(function(t) pick.Text = t end))
		listen("Gun", "ESP", function(on) pick.Visible = on end)

		local isOpen = true

		-- open / minimize / close
		local function setOpen(o)
			isOpen = o
			if o then
				win.Visible = true
				tw(win, { GroupTransparency = 0 }, 0.25)
				float.Visible = false
			else
				tw(win, { GroupTransparency = 1 }, 0.2)
				task.delay(0.2 / math.max(Config.Data.UI.AnimSpeed, 0.1), function()
					if not isOpen then win.Visible = false; float.Visible = true end
				end)
			end
		end
		btnMin.Activated:Connect(function() setOpen(false) end)
		float.Activated:Connect(function() if not fdrag.moved then setOpen(true) end end)
		btnClose.Activated:Connect(function()
			tw(win, { GroupTransparency = 1 }, 0.2)
			task.delay(0.25, function() UI.Closed:Fire() end)
		end)

		selectTab("Combat")
		for _, s in ipairs(neon) do s.Transparency = Config.Data.Misc.Neon and 0.35 or 1 end
		setOpen(true)
	end

	-- Уведомление при запуске (ничего не копируется автоматически)
	function UI.Notify()
		if not gui then return end
		local toast = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -90), Size = UDim2.fromOffset(280, 78), BackgroundColor3 = Color3.fromRGB(8, 8, 8), BackgroundTransparency = 0.1 }, gui)
		corner(toast, 12)
		make("UIStroke", { Color = ACCENT, Thickness = 1.5, Transparency = 0.3 }, toast)
		make("TextLabel", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18), BackgroundTransparency = 1, Text = "ANI VISUAL LOADED", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Left }, toast)
		make("TextLabel", { Position = UDim2.fromOffset(12, 26), Size = UDim2.fromOffset(78, 18), BackgroundTransparency = 1, Text = "TELEGRAM:", Font = FONTB, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left }, toast)
		local box = make("TextBox", { Position = UDim2.fromOffset(88, 26), Size = UDim2.fromOffset(120, 18), BackgroundTransparency = 1, Text = TG, Font = FONT, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, TextEditable = false }, toast)
		local b = make("TextButton", { Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 0, 22), BackgroundColor3 = ACCENT, BackgroundTransparency = 0.4, Text = "COPY TELEGRAM", Font = FONTB, TextSize = 11, TextColor3 = Color3.new(1, 1, 1) }, toast)
		corner(b, 6)
		b.Activated:Connect(function() copyBox(box) end)
		tw(toast, { Position = UDim2.new(0.5, 0, 0, 60) }, 0.4)
		task.delay(9, function()
			if toast.Parent then
				tw(toast, { Position = UDim2.new(0.5, 0, 0, -90) }, 0.4)
				task.delay(0.5, function() toast:Destroy() end)
			end
		end)
	end

	function UI.Destroy()
		for _, c in ipairs(conns) do c:Disconnect() end
		table.clear(conns)
		if gui then gui:Destroy(); gui = nil end
	end

	return UI
end)
if not UI then return end

-- ================= MAIN =================
local function try(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then report(name, err) end
	return ok
end

try("ESP.Init", ESP.Init)
try("Gun.Init", Gun.Init)
try("Bubbles.Init", Bubbles.Init)
try("Combat.Init", Combat.Init)
try("Visuals.Init", Visuals.Init)
try("Skins.Init", Skins.Init)
if try("UI.Build", UI.Build) then
	try("UI.Notify", UI.Notify)
	print("[AniVisual] загружен")
end

UI.Closed.Event:Once(function()
	try("ESP.Destroy", ESP.Destroy)
	try("Gun.Destroy", Gun.Destroy)
	try("Bubbles.Destroy", Bubbles.Destroy)
	try("Combat.Destroy", Combat.Destroy)
	try("Visuals.Destroy", Visuals.Destroy)
	try("Skins.Destroy", Skins.Destroy)
	try("Music.Stop", Music.Stop)
	try("UI.Destroy", UI.Destroy)
end)
