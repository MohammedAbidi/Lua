---------------
-- Functions --
---------------
local ROUND = math.round
local function RoundToNearest(number:number, delta:number):number
	return ROUND(number/delta)*delta
end

-- Returns the Axis Aligned Bounding Box sizes of a part
local ABS = math.abs
local function GetAABB(part:BasePart):(x,y,z)
	local cf = part.CFrame
	local size = part.Size
	local sx,sy,sz = size.X,size.Y,size.Z
	local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22 = cf:GetComponents()
	return ABS(r00)*sx + ABS(r01)*sy + ABS(r02)*sz, -- Size X
	       ABS(r10)*sx + ABS(r11)*sy + ABS(r12)*sz, -- Size Y
	       ABS(r20)*sx + ABS(r21)*sy + ABS(r22)*sz	-- Size Z
end

-- If they werent unit vectors it would be: math.acos(math.min(math.max(v1:Dot(v2)/(v1.Magnitude * v2.Magnitude)),-1),1)
local ACOS,CLAMP = math.acos, math.clamp
local function GetAngleBetweenUnitVectors(v1:Vector3, v2:Vector3):radian
	return ACOS(CLAMP(v1:Dot(v2),-1,1)) -- stay between exactly -1 and 1 to prevent floating point errors
end

-- Takes a normalized vector and figures out where the closest basis vector is in a cframe.
local PI360 = math.pi*2
local function GetClosestNormal(cf:CFrame, normal:Vector3):(Vector3,number)
	local l,u,r = cf.LookVector, cf.UpVector, cf.RightVector -- Face Vectors
	local closest = l -- Arbitrarily chosen in case of worst case
	local angle = PI360 -- Literally should never happen, but if it does, its gonna 360 and return like nothing happened
	for _, direction in ipairs({l,u,r,-l,-u,-r}) do -- Get the closest Normal Vector
		local a = GetAngleBetweenUnitVectors(normal, direction) -- Get the angle in radians
		if a < 0.005 then return direction, 0 end -- Trying to prevent floating point errors, so pretend this means == 0
		if a < angle then angle = a closest = direction end
	end
	return closest, angle
end

-- Same but tweaked to get the axis direction of a part
local EAX,EAY,EAZ = Enum.Axis.X,Enum.Axis.Y,Enum.Axis.Z
local function GetClosestAxis(cf:CFrame, normal:Vector3):Enum.Axis
	local l,u,r = cf.LookVector, cf.UpVector, cf.RightVector
	local closest
	local angle = PI360
	for direction, axis in pairs({[l]=EAZ,[u]=EAY,[r]=EAX,[-l]=EAZ,[-u]=EAY,[-r]=EAX}) do
		local a = GetAngleBetweenUnitVectors(normal, direction)
		if a < 0.005 then return axis end
		if a < angle then angle = a closest = axis end
	end
	return closest
end

-- Same but tweaked to get a parts size on an axis
local function GetClosestAxisSize(part:BasePart, normal:Vector3):number
	local axis = GetClosestAxis(part.CFrame, normal)
	local size = part.Size
	return axis == EAX and size.X or axis == EAY and size.Y or size.Z
end

-- Aligns two CFrames by a cross product and a given basis vector property name of the first cframe
-- Returns the translation that it takes to get to this point
local CFAA = CFrame.fromAxisAngle
local function AlignCFramesByCross(cf1:CFrame, cf2:CFrame, isUpVectorElseRightVector:boolean):CFrame
	local normal = isUpVectorElseRightVector and cf1.UpVector or cf1.RightVector
	local closest, angle = GetClosestNormal(cf2, normal)
	if angle == 0 then return cf1 end
	return CFAA(normal:Cross(closest), angle) * cf1
end

-- Takes 2 cframes and snaps them such that the nearest faces align, and the orientation of the second one locks to a 90 deg step
-- Cf1 is the CFrame attempting to snap, Cf2 is the existing one.
local function GetFacedSnapOrientation(cf1:CFrame, cf2:CFrame):CFrame
	local cf = AlignCFramesByCross(AlignCFramesByCross(cf1,cf2,true),cf2)
	return cf - cf.Position
end

-- Tweaked to return perpendicular cframe + perpendicular normal vectors
local function GetFacedSnapGeometry(cf1:CFrame, cf2:CFrame, normal:Vector3):(CFrame, Vector3, Vector3) -- orientation, normalX, normalZ
	local normalX = cf2.UpVector
	local normalZ

	local anglecheck = GetAngleBetweenUnitVectors(normal, normalX)
	if anglecheck < 0.005 or anglecheck > math.pi-.005 then
		normalZ = cf2.LookVector
		normalX = cf2.RightVector
	else
		normalZ = normal:Cross(normalX).Unit
		normalX = normal:Cross(normalZ).Unit
	end

	return GetFacedSnapOrientation(cf1, CFrame.fromMatrix(normal, normalX, normalZ)), normalX, normalZ
end

local function GetMouseNormalDepth(mousePosition:Vector3, targetPosition:Vector3, normal:Vector3):Vector3
	local v = mousePosition - targetPosition
	return normal*math.cos(GetAngleBetweenUnitVectors(normal,v.Unit))*v.Magnitude
end

local function GetCorners(cframe: CFrame, size2: Vector3): {Vector3}
	local corners = {}
	for i = 0, 7 do
		corners[i + 1] = cframe * (size2 * Vector3.new(
			2 * (math.floor(i / 4) % 2) - 1,
			2 * (math.floor(i / 2) % 2) - 1,
			2 * (i % 2) - 1 ))
	end
	return corners
end

local function GetPointCloud(parts: {BasePart}): {Vector3}
	local cloud = {}
	for _, part in parts do
		local corners = GetCorners(part.CFrame, part.Size / 2)
		for _, corner in corners do
			table.insert(cloud, corner)
		end
	end
	return cloud
end

local function GetOBB(orientation: CFrame, parts: {BasePart}): (CFrame, Vector3)
	orientation = orientation.Rotation -- want X, Y, Z to be 0, 0, 0

	local cloud = GetPointCloud(parts)
	for i = 1, #cloud do
		cloud[i] = orientation:PointToObjectSpace(cloud[i])
	end

	local maxV, minV = cloud[1], cloud[1]

	for i = 2, #cloud do
		local point = cloud[i]
		maxV = maxV:Max(point)
		minV = minV:Min(point)
	end

	local wMaxV = orientation:PointToWorldSpace(maxV)
	local wMinV = orientation:PointToWorldSpace(minV)

	return CFrame.new((wMaxV + wMinV) / 2) * orientation, maxV - minV
end


-------------
-- Private --
-------------
local IGNORE_FOLDER = workspace:WaitForChild("Ignore")

local Placing = {}
Placing.PositionAlignment = 1 -- studs
Placing.OrientationAlignment = 90 -- 360 degree angle
--[[
Placing.Part:BasePart -- part
Placing.Hologram:BasePart -- part
Placing.Connection:connection -- main loop

Placing.SnapToCenter:boolean
Placing.SnapToSurface:boolean
Placing.AlignOrientation:boolean
Placing.Reverse:boolean

Placing.IsLocked:boolean -- read only
Placing.LockX:number -- studs
Placing.LockY:number -- studs
Placing.LockZ:number -- studs
Placing.LockOX:number -- 360 degree angle
Placing.LockOY:number -- 360 degree angle
Placing.LockOZ:number -- 360 degree angle
--]]

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local function RegularSnap(normal:Vector3)
	local mousePos = mouse.Hit.Position
	local hologram = Placing.Hologram

	local grip = Placing.Grip
	if grip then
		local cf:CFrame = Placing.Hologram.CFrame
		mousePos = mousePos - cf.RightVector*grip.X - cf.UpVector*grip.Y + cf.LookVector*grip.Z
	end

	-- Trying not to place in floor
	local sX,sY,sZ = GetAABB(hologram)
	local hsx,hsy,hsz = sX/2,sY/2,sZ/2
	local x,y,z = mousePos.X,mousePos.Y,mousePos.Z

	-- Align To Studs
	if not grip then
		x += hsx*RoundToNearest(normal.X,1)
		y += hsy*RoundToNearest(normal.Y,1)
		z += hsz*RoundToNearest(normal.Z,1)
	end

	if Placing.PositionAlignment and Placing.PositionAlignment > .001 then
		x = RoundToNearest(RoundToNearest(x-hsx, Placing.PositionAlignment) + hsx, Placing.PositionAlignment/2)
		y = RoundToNearest(RoundToNearest(y-hsy, Placing.PositionAlignment) + hsy, Placing.PositionAlignment/2)
		z = RoundToNearest(RoundToNearest(z-hsz, Placing.PositionAlignment) + hsz, Placing.PositionAlignment/2)
	end
	
	hologram.Position = Vector3.new(x,y,z)
end

local function Dir6Collision(normal:Vector3, RCP:RaycastParams)
	local mousePos = mouse.Hit.Position
	local hologram = Placing.Hologram
	
	-- Trying not to place in wall
	local sX,sY,sZ = GetAABB(hologram)
	local hsx,hsy,hsz = sX/2,sY/2,sZ/2
	local x,y,z = mousePos.X,mousePos.Y,mousePos.Z
	x += hsx*RoundToNearest(normal.X,1)
	y += hsy*RoundToNearest(normal.Y,1)
	z += hsz*RoundToNearest(normal.Z,1)

	-- Bandaid solution to help prevent clipping in the 6 directions, with 6 extra raycasts :(
	local result
	local origin = Vector3.new(x,y,z)
	result = workspace:Raycast(origin, Vector3.new(hsx,0,0),  RCP) if result then x = x - hsx + result.Distance end
	result = workspace:Raycast(origin, Vector3.new(-hsx,0,0), RCP) if result then x = x + hsx - result.Distance end
	result = workspace:Raycast(origin, Vector3.new(0,hsy,0),  RCP) if result then y = y - hsy + result.Distance end
	result = workspace:Raycast(origin, Vector3.new(0,-hsy,0), RCP) if result then y = y + hsy - result.Distance end
	result = workspace:Raycast(origin, Vector3.new(0,0,hsz),  RCP) if result then z = z - hsz + result.Distance end
	result = workspace:Raycast(origin, Vector3.new(0,0,-hsz), RCP) if result then z = z + hsz - result.Distance end

	-- Align To Studs
	if Placing.PositionAlignment and Placing.PositionAlignment > .001 then
		x = RoundToNearest(RoundToNearest(x-hsx, Placing.PositionAlignment) + hsx, Placing.PositionAlignment/2)
		y = RoundToNearest(RoundToNearest(y-hsy, Placing.PositionAlignment) + hsy, Placing.PositionAlignment/2)
		z = RoundToNearest(RoundToNearest(z-hsz, Placing.PositionAlignment) + hsz, Placing.PositionAlignment/2)
	end

	hologram.Position = Vector3.new(x,y,z)
end

-- for speed bridging
local function GetClosestBuildableBlock()
	local targetPos = mouse.Hit.Position
	local target = nil
	local maxdist = 1e100
	for _, part:BasePart in ipairs(workspace:GetChildren()) do
		if part.ClassName == "BasePart" then
			
			local entity = player.Character
			if entity and entity:FindFirstChildOfClass("Humanoid") and entity.Humanoid.Health > 0 then
				local pos, vis = workspace.Camera:WorldToViewportPoint(entity.PrimaryPart.Position)
				local dist = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(pos.X, pos.Y)).Magnitude
				if maxdist > dist and vis then
					maxdist = dist
					target  = entity
				end
			end
		end
	end
end

local function CenterSnap(result:RaycastResult)
	local normal = result.Normal
	local target = result.Instance

	--if target.Locked then-- if looking at baseplate
	--	target = GetClosestBuildableBlock()
	--	normal = GetClosestNormal(target.CFrame, (mouse.Hit.Position - target.Position).Unit)
	--end
	
	local hologram = Placing.Hologram
	local isBlock:boolean = target.ClassName == "Part" and target.Shape == Enum.PartType.Block
	hologram.CFrame = (isBlock and GetFacedSnapOrientation(hologram.CFrame, target.CFrame)
					or GetFacedSnapGeometry(hologram.CFrame, target.CFrame, normal))
					+ target.Position + GetMouseNormalDepth(mouse.Hit.Position,target.Position,normal)
					+ normal * GetClosestAxisSize(hologram,normal)/2
end

local function MouseSnap(result:RaycastResult)
	local normal = result.Normal
	local target = result.Instance
	local hologram = Placing.Hologram
	local isBlock:boolean = target.ClassName == "Part" and target.Shape == Enum.PartType.Block
	local mousePos = mouse.Hit.Position
	local cf = hologram.CFrame
	local grip = Placing.Grip
	if Placing.Grip then mousePos = mousePos - cf.RightVector*grip.X - cf.UpVector*grip.Y + cf.LookVector*grip.Z end
	cf = (isBlock and GetFacedSnapOrientation(cf, target.CFrame) or GetFacedSnapGeometry(cf, target.CFrame, normal)) + mousePos
	if not grip then cf+= normal*GetClosestAxisSize(hologram,normal)/2 end
	hologram.CFrame = cf
end

local function ShowAxis(centerDot:Vector3, normalX:Vector3, normalY:Vector3, normalZ:Vector3)
	local center, x, y, z = Placing.AxisCenter, Placing.AxisX, Placing.AxisY, Placing.AxisZ
	if not center then
		center = Instance.new("Part")
		center.Size = Vector3.new(.05,.05,.05)
		center.Color = Color3.new(1,1,1)
		center.Anchored = true
		center.CanCollide = false
		center.CanTouch = false
		center.CanQuery = false
		center.Material = Enum.Material.Neon
		center.Parent = IGNORE_FOLDER

		x = center:Clone()
		x.Size = Vector3.new(.01,.01,1)
		x.Color = Color3.new(1)
		x.Parent = IGNORE_FOLDER

		y = x:Clone()
		y.Color = Color3.new(0,1)
		y.Parent = IGNORE_FOLDER

		z = x:Clone()
		z.Color = Color3.new(0,0,1)
		z.Parent = IGNORE_FOLDER

		Placing.AxisCenter, Placing.AxisX, Placing.AxisY, Placing.AxisZ = center, x, y, z
	end

	x.CFrame = CFrame.new(centerDot + normalX/2, centerDot + normalX)
	y.CFrame = CFrame.new(centerDot + normalY/2, centerDot + normalY)
	z.CFrame = CFrame.new(centerDot + normalZ/2, centerDot + normalZ)
end

local function HideAxis()
	local center = Placing.AxisCenter
	if center then
		center:Destroy()
		Placing.AxisX:Destroy()
		Placing.AxisY:Destroy()
		Placing.AxisZ:Destroy()
		Placing.AxisCenter = nil
		Placing.AxisX = nil
		Placing.AxisY = nil
		Placing.AxisZ = nil
	end
end

local function StudSnap(result:RaycastResult)
	local normal = result.Normal
	local target = result.Instance
	local hologram = Placing.Hologram
	local isBlock:boolean = target.ClassName == "Part" and target.Shape == Enum.PartType.Block
	
	local cf = hologram.CFrame
	
	local gcf, normalX, normalZ = GetFacedSnapGeometry(cf, target.CFrame, normal)

	local c,s = GetOBB(gcf, {target})
	local sx,sz
	local compare = GetAngleBetweenUnitVectors(normalX, c.UpVector)
	if compare < 0.005 or compare > math.pi-.005 then
		normalX = c.UpVector -- x is up
		sx = s.Y
		compare = GetAngleBetweenUnitVectors(normalZ, c.RightVector)
		if compare < 0.005 or compare > math.pi-.005 then
			normalZ = c.RightVector -- z is right
			sz = s.X
		else
			normalZ = c.LookVector -- z is look
			sz = s.Z
		end
	else
		compare = GetAngleBetweenUnitVectors(normalX, c.RightVector)
		if compare < 0.005 or compare > math.pi-.005 then
			normalX = c.RightVector -- x is right
			sx = s.X
			compare = GetAngleBetweenUnitVectors(normalZ, c.UpVector)
			if compare < 0.005 or compare > math.pi-.005 then
				normalZ = c.UpVector -- z is up
				sz = s.Y
			else
				normalZ = c.LookVector -- z is look
				sz = s.Z
			end
		else
			normalX = c.LookVector -- x is look
			sx = s.Z
			compare = GetAngleBetweenUnitVectors(normalZ, c.UpVector)
			if compare < 0.005 or compare > math.pi-.005 then
				normalZ = c.UpVector -- z is up
				sz = s.Y
			else
				normalZ = c.RightVector -- z is right
				sz = s.X
			end
		end
	end
	
	local mousePos = mouse.Hit.Position
	local hsx,hsz = sx/2,sz/2
	local center = target.Position + GetMouseNormalDepth(mousePos,target.Position,normal)
	local corner = center - normalX*hsx - normalZ*hsz
	
	if Placing.Grip then
		local grip = Placing.Grip
		mousePos = mousePos - cf.RightVector*grip.X - cf.UpVector*grip.Y + cf.LookVector*grip.Z
	end
	local relative = mousePos - corner
	local ru = relative.Unit
	local x = relative*math.cos(GetAngleBetweenUnitVectors(ru, normalX))
	local z = relative*math.cos(GetAngleBetweenUnitVectors(ru, normalZ))

	local ALIGNMENT = Placing.PositionAlignment
	local xoff = ((sx/ALIGNMENT)%1)*ALIGNMENT
	local zoff = ((sz/ALIGNMENT)%1)*ALIGNMENT
	xoff = xoff > ALIGNMENT-.001 and 0 or xoff
	zoff = zoff > ALIGNMENT-.001 and 0 or zoff

	local hxoff = ((GetClosestAxisSize(hologram, normalX)/ALIGNMENT)%2)*ALIGNMENT
	local hzoff = ((GetClosestAxisSize(hologram, normalZ)/ALIGNMENT)%2)*ALIGNMENT

	hxoff = hxoff > 2*ALIGNMENT-.001 and 0 or hxoff
	hzoff = hzoff > 2*ALIGNMENT-.001 and 0 or hzoff

	local xo = xoff + hxoff/2
	local zo = zoff + hzoff/2
	local rx = RoundToNearest(x.Magnitude - xo, ALIGNMENT)
	local rz = RoundToNearest(z.Magnitude - zo, ALIGNMENT)

	hologram.CFrame = (isBlock and GetFacedSnapOrientation(cf, target.CFrame)
					or GetFacedSnapGeometry(cf, target.CFrame, normal))
					+ corner + normalX*rx + normalX*xo + normalZ*rz + normalZ*zo
					+ normal*GetClosestAxisSize(hologram,normal)/2
		
	-- show lasers so it looks better?
	ShowAxis(center + normalX*hsx + normalZ*hsz, -normalX, normal, -normalZ)
end


---------
-- GUI --
---------
local HBC = game:GetService("RunService").Heartbeat
local RSC = game:GetService("RunService").RenderStepped
--Placing.DisableAnimations = false

local GUI = script.PlacingGui
GUI.Parent = player.PlayerGui
GUI = GUI.Frame
local GUI_MAIN = GUI.Main
local GUI_SIDE = GUI.Side
local GUI_TOP = GUI.Top

local function HighlightedText(textBox, t, color)
	if Placing[textBox] then
		Placing[textBox]:Disconnect()
	end
	
	color = color or Color3.new(0,0,1)

	textBox.TextColor3 = color
	
	local timer = tick() + t
	Placing[textBox] = HBC:Connect(function()
		local pct = 1 - (timer - tick()) / t
		
		if pct >= 1 then
			textBox.TextColor3 = Color3.new(1,1,1)
			if Placing[textBox] then
				Placing[textBox]:Disconnect()
				Placing[textBox] = nil
			end
			return
		end
		
		textBox.TextColor3 = color:Lerp(Color3.new(1,1,1), pct)
	end)
end


-- Advanced
local tat = 0
local guiAnimationConnection
local function StopAnimation()
	if guiAnimationConnection then
		guiAnimationConnection:Disconnect()
	end
	guiAnimationConnection = nil
	tat = 0
end

local function SetTransparencies(x)
	local HALF = (x+1)/2
	
	GUI_MAIN.PositionLabel.TextTransparency = x
	GUI_MAIN.PositionLabel.TextStrokeTransparency = x
	GUI_MAIN.Positions.Decrease.TextTransparency = x
	GUI_MAIN.Positions.Decrease.TextStrokeTransparency = x
	GUI_MAIN.Positions.Decrease.BackgroundTransparency = HALF
	GUI_MAIN.Positions.Increase.TextTransparency = x
	GUI_MAIN.Positions.Increase.TextStrokeTransparency = x
	GUI_MAIN.Positions.Increase.BackgroundTransparency = HALF
	GUI_MAIN.Positions.Set.TextTransparency = x
	GUI_MAIN.Positions.Set.TextStrokeTransparency = x
	GUI_MAIN.Positions.Set.BackgroundTransparency = HALF
--	GUI_MAIN.OrientationLabel.TextTransparency = x
--	GUI_MAIN.AlignOrientation.TextTransparency = x
--	GUI_MAIN.AlignToSurface.TextTransparency = x
--	GUI_MAIN.GripLabel.TextTransparency = x
--	GUI_MAIN.OrientationLabel.TextStrokeTransparency = x
--	GUI_MAIN.AlignOrientation.TextStrokeTransparency = x
--	GUI_MAIN.AlignToSurface.TextStrokeTransparency = x
--	GUI_MAIN.GripLabel.TextStrokeTransparency = x
	
	GUI_SIDE.Reverse.TextTransparency = x
	GUI_SIDE.Snap.TextTransparency = x
	GUI_SIDE.Lock.TextTransparency = x
	GUI_SIDE.Reset.TextTransparency = x
	GUI_SIDE.Bytes.TextTransparency = x
	GUI_SIDE.Reverse.TextStrokeTransparency = x
	GUI_SIDE.Snap.TextStrokeTransparency = x
	GUI_SIDE.Lock.TextStrokeTransparency = x
	GUI_SIDE.Reset.TextStrokeTransparency = x
	GUI_SIDE.Bytes.TextStrokeTransparency = x

	GUI_TOP.PositionX.TextTransparency = x
	GUI_TOP.PositionY.TextTransparency = x
	GUI_TOP.PositionZ.TextTransparency = x
	GUI_TOP.PositionXSet.TextTransparency = x
	GUI_TOP.PositionYSet.TextTransparency = x
	GUI_TOP.PositionZSet.TextTransparency = x
	GUI_TOP.OrientationXSet.TextTransparency = x
	GUI_TOP.OrientationYSet.TextTransparency = x
	GUI_TOP.OrientationZSet.TextTransparency = x
	GUI_TOP.PositionX.TextStrokeTransparency = x
	GUI_TOP.PositionY.TextStrokeTransparency = x
	GUI_TOP.PositionZ.TextStrokeTransparency = x
	GUI_TOP.PositionXSet.TextStrokeTransparency = x
	GUI_TOP.PositionYSet.TextStrokeTransparency = x
	GUI_TOP.PositionZSet.TextStrokeTransparency = x
	GUI_TOP.OrientationXSet.TextStrokeTransparency = x
	GUI_TOP.OrientationYSet.TextStrokeTransparency = x
	GUI_TOP.OrientationZSet.TextStrokeTransparency = x
end

local function SetVisibilities(x)
	GUI_MAIN.Visible = x
	GUI_SIDE.Visible = x
	GUI_TOP.PositionX.Visible = x
	GUI_TOP.PositionY.Visible = x
	GUI_TOP.PositionZ.Visible = x
	GUI_TOP.PositionXSet.Visible = x
	GUI_TOP.PositionYSet.Visible = x
	GUI_TOP.PositionZSet.Visible = x
	GUI_TOP.OrientationXSet.Visible = x
	GUI_TOP.OrientationYSet.Visible = x
	GUI_TOP.OrientationZSet.Visible = x
end

local function ShowEnd()
	GUI.Advanced.Text = "Hide Advanced (H)"
	GUI.Position = UDim2.fromScale(0.01, 0.58)
	GUI.Advanced.Position = UDim2.fromScale(0.676, 0.333)
	GUI.Background.Size = UDim2.new(0.667, 1, 0.667, 1)
	GUI.Background.Position = UDim2.fromScale(0,.333)
	SetTransparencies(0)
	SetVisibilities(true)
end

local function HideEnd()
	GUI.Advanced.Text = "Show Advanced (H)"
	GUI.Advanced.Position = UDim2.fromScale(0.01, 0.333)
	GUI.Position = UDim2.fromScale(0.01, 0.802)
	GUI.Background.Size = UDim2.new(0.667, 1, 0.333, 1) -- GUI.Background.Size = UDim2.new(0.667, 1, 0.111, 1)
	GUI.Background.Position = UDim2.new()
	SetVisibilities(false)
	SetTransparencies(1)
end

local function TweenAdvanced(dt, reversed)
	tat = tat + dt*4 -- t = t + dt/ANIMATION_LENGTH
	if tat > 1 then StopAnimation() if reversed then HideEnd() else ShowEnd() end return end
	local x = reversed and tat*tat or 1-tat*tat

	GUI.Position = UDim2.fromScale(0.01, 0.58 + x*0.222)
	GUI.Advanced.Position = UDim2.fromScale(0.676 - x*0.666, 0.333)
	GUI.Background.Size = UDim2.new(0.667, 1, 0.667 - x*0.333, 1) -- GUI.Background.Size = UDim2.new(0.667, 1, 0.667 - x*0.555, 1)
	GUI.Background.Position = UDim2.fromScale(0, 0.333 - x*0.333)

	SetTransparencies(x)
end

local toggledAdvanced = true
function Placing.ShowAdvanced()
	toggledAdvanced = true
	StopAnimation()
	if Placing.DisableAnimations then ShowEnd() return end
	SetVisibilities(true)
	guiAnimationConnection = HBC:Connect(function(dt) TweenAdvanced(dt) end)
end

function Placing.HideAdvanced()
	toggledAdvanced = false
	StopAnimation()
	if Placing.DisableAnimations then HideEnd() return end
	guiAnimationConnection = HBC:Connect(function(dt) TweenAdvanced(dt, true) end)
end

function Placing.ToggleAdvanced(_, inputState:Enum.UserInputState)
	if inputState and inputState ~= Enum.UserInputState.Begin then return end
	if toggledAdvanced then
		Placing.HideAdvanced()
	else
		Placing.ShowAdvanced()
	end
end


--------------------
-- Transformation --
--------------------
local function GetDecimalFromString(x)
	if string.sub(x,1,1) == "." then
		x = "0" .. x
	elseif string.sub(x,1,2) == "-." then
		x = "-0." .. string.sub(x,3)
	end

	local n = tonumber(string.match(x, "%-?%d+%.?%d*"))
	if n then n = RoundToNearest(n, .001) end
	return n
end

local function SetDecimalToString(x, addDegree)
	local str = string.format("%.3f",x):gsub("%.?0+$", "")
	if str == "-0" then str = "0" end
	return addDegree and str .. "°" or str
end

local MAXIMUM_ALIGNMENT = 16
local MINIMUM_ALIGNMENT = 1/8
local function UpdateAlignment()
	if Placing.PositionAlignment >= MAXIMUM_ALIGNMENT then
		GUI.Main.Positions.Increase.Text = ""
	else
		GUI.Main.Positions.Increase.Text = "+"
	end

	if Placing.PositionAlignment <= 0 then
		GUI.Main.Positions.Decrease.Text = ""
		GUI.Main.Positions.Set.Text = "None"
	else
		GUI.Main.Positions.Decrease.Text = "-"
		GUI.Main.Positions.Set.Text = SetDecimalToString(Placing.PositionAlignment)
	end
end

function Placing.SetAlignment(studs:number)
	Placing.PositionAlignment = CLAMP(studs or 1, 0, MAXIMUM_ALIGNMENT)
	UpdateAlignment()
end

local function SetAlignment()
	Placing.SetAlignment(GetDecimalFromString(GUI.Main.Positions.Set.Text) or 1)
end

local function IncreaseAlignment()
	if Placing.PositionAlignment < 0 then
		Placing.PositionAlignment = 0
	elseif Placing.PositionAlignment == 0 then
		Placing.PositionAlignment = MINIMUM_ALIGNMENT
	else
		local nearestPowerOf2 = 2^math.ceil(math.log(Placing.PositionAlignment)/math.log(2))
		if Placing.PositionAlignment == nearestPowerOf2 then
			Placing.PositionAlignment *= 2
			if Placing.PositionAlignment > MAXIMUM_ALIGNMENT then
				Placing.PositionAlignment = MAXIMUM_ALIGNMENT
			end
		else
			Placing.PositionAlignment = nearestPowerOf2
		end
	end
	UpdateAlignment()
end

local function DecreaseAlignment()
	if Placing.PositionAlignment > MAXIMUM_ALIGNMENT then
		Placing.PositionAlignment = MAXIMUM_ALIGNMENT
	elseif Placing.PositionAlignment <= MINIMUM_ALIGNMENT then
		Placing.PositionAlignment = 0
	else
		local nearestPowerOf2 = 2^math.ceil(math.log(Placing.PositionAlignment)/math.log(2))
		if Placing.PositionAlignment == nearestPowerOf2 then
			Placing.PositionAlignment /= 2
			if Placing.PositionAlignment < MINIMUM_ALIGNMENT then
				Placing.PositionAlignment = 0
			end
		else
			Placing.PositionAlignment = nearestPowerOf2/2
		end
	end
	UpdateAlignment()
end


local ORIENTATION_CYCLES = {90, 45, 30, 22.5, 15, 5}
local function UpdateOrientation()
	local min, max = ORIENTATION_CYCLES[#ORIENTATION_CYCLES], ORIENTATION_CYCLES[1]
	if Placing.OrientationAlignment >= max then
		GUI.Main.Orientations.Increase.Text = ""
	else
		GUI.Main.Orientations.Increase.Text = "+"
	end

	if Placing.OrientationAlignment <= min then
		GUI.Main.Orientations.Decrease.Text = ""
	else
		GUI.Main.Orientations.Decrease.Text = "-"
	end

	GUI.Main.Orientations.Set.Text = SetDecimalToString(Placing.OrientationAlignment, true)
end

function Placing.SetOrientation(degrees:number)
	local min,max = 0,360
	if Placing.AlignOrientation then min = 5 max = 90 end
	degrees = CLAMP(tonumber(degrees) or max, min, max)

	if Placing.AlignOrientation then
		Placing.OrientationAlignment = degrees == 22.5 and degrees or RoundToNearest(degrees, 5)
	else
		Placing.OrientationAlignment = degrees
	end
	UpdateOrientation()
end

local function SetOrientation()
	Placing.SetOrientation(GetDecimalFromString(GUI.Main.Orientations.Set.Text) or 90)
end

local function IncreaseOrientation()
	if Placing.OrientationAlignment > ORIENTATION_CYCLES[1] then return end

	for i = #ORIENTATION_CYCLES, 1, -1 do
		local n = ORIENTATION_CYCLES[i]
		if n > Placing.OrientationAlignment then
			Placing.OrientationAlignment = n
			UpdateOrientation()
			return
		end
	end

	-- just in case
	Placing.OrientationAlignment = ORIENTATION_CYCLES[1]
	UpdateOrientation()
end

local function DecreaseOrientation()
	if Placing.OrientationAlignment <= ORIENTATION_CYCLES[#ORIENTATION_CYCLES] then return end
	
	for _, n in ipairs(ORIENTATION_CYCLES) do
		if n < Placing.OrientationAlignment then
			Placing.OrientationAlignment = n
			UpdateOrientation()
			return
		end
	end
	
	-- just in case
	Placing.OrientationAlignment = ORIENTATION_CYCLES[#ORIENTATION_CYCLES]
	UpdateOrientation()
end


local function RoundToDegree64(degree)
	local x = RoundToNearest(degree,5)
	local m = x%45
	if m == 20 then
		x = x + 2.5
	elseif m == 25 then
		x = x - 2.5
	end
	return x%360
end

local function RoundCFrameToDegree64(cf)
	local pos = cf.Position
	local x,y,z = cf:ToOrientation()
	x = math.rad(RoundToDegree64(math.deg(x)))
	y = math.rad(RoundToDegree64(math.deg(y)))
	z = math.rad(RoundToDegree64(math.deg(z)))
	return CFrame.fromOrientation(x,y,z) + pos
end


local lastManualRotation = CFrame.new()
local function RotateOrTilt(tilt:boolean)
	if not Placing.Hologram then return end

	-- Rotate or Tilt
	local ocf
	local rad = math.rad(Placing.OrientationAlignment)
	if Placing.Reverse then
		if tilt then
			ocf = CFrame.Angles(-rad,0,0)
		else
			ocf = CFrame.Angles(0,-rad,0)
		end
	else
		if tilt then
			ocf = CFrame.Angles(rad,0,0)
		else
			ocf = CFrame.Angles(0,rad,0)
		end
	end
	
	-- Round
	local cf:CFrame = Placing.Hologram.CFrame
	local pos = cf.Position
	cf = cf - pos
	local fix
	local a1,a2 = GetAngleBetweenUnitVectors(lastManualRotation.LookVector,  cf.LookVector), GetAngleBetweenUnitVectors(lastManualRotation.RightVector, cf.RightVector)
	if a1 > .001 or a2 > .001 then -- check if orientations are different
		Placing.Orientation = cf
		fix = true
	end
	
	cf = ocf * Placing.Orientation
	Placing.Orientation = cf
	
--	local cf = Placing.Hologram.CFrame
--	cf = ocf * (cf - cf.Position) + cf.Position
	
	if Placing.AlignOrientation then cf = RoundCFrameToDegree64(cf) end
	
	lastManualRotation = cf
	Placing.Hologram.CFrame = cf + pos
	if fix then Placing.Orientation = cf end
end

function Placing.Rotate(_, inputState:Enum.UserInputState)
	if inputState and inputState ~= Enum.UserInputState.Begin then return end
	RotateOrTilt()
	HighlightedText(GUI.Top.Rotate, .25)
end

function Placing.Tilt(_, inputState:Enum.UserInputState)
	if inputState and inputState ~= Enum.UserInputState.Begin then return end
	RotateOrTilt(true)
	HighlightedText(GUI.Top.Tilt, .25)
end


-------------
-- Locking --
-------------
-- Placing.LX
local function UpdateXYZ()
	if not Placing.Hologram then
		GUI.Top.PositionXSet.Text = ""
		GUI.Top.PositionYSet.Text = ""
		GUI.Top.PositionZSet.Text = ""
		GUI.Top.OrientationXSet.Text = ""
		GUI.Top.OrientationYSet.Text = ""
		GUI.Top.OrientationZSet.Text = ""
		return
	end

	local char = player.Character
	if not char then return end
	local pp = char.PrimaryPart
	if not pp then return end
	
	local cf = Placing.Hologram.CFrame
	local hos = cf.Position
	local pos = pp.Position
	
	local x,y,z = Placing.LX, Placing.LY, Placing.LZ
	if not x then
		x = hos.X - ROUND(pos.X)
		if x < -16 or x > 16 then
			GUI.Top.PositionXSet.TextColor3 = Color3.new(1)
			x = CLAMP(x,-16,16)
		else
			GUI.Top.PositionXSet.TextColor3 = Color3.new(1,1,1)
		end
		GUI.Top.PositionXSet.Text = SetDecimalToString(x)
	end
	
	if not y then
		y = hos.Y - ROUND(pos.Y - 3)
		if y < -16 or y > 16 then
			GUI.Top.PositionYSet.TextColor3 = Color3.new(1)
			y = CLAMP(y,-16,16)
		else
			GUI.Top.PositionYSet.TextColor3 = Color3.new(1,1,1)
		end
		GUI.Top.PositionYSet.Text = SetDecimalToString(y)
	end
	
	if not z then
		z = hos.Z - ROUND(pos.Z)
		if z < -16 or z > 16 then
			GUI.Top.PositionZSet.TextColor3 = Color3.new(1)
			z = CLAMP(z,-16,16)
		else
			GUI.Top.PositionZSet.TextColor3 = Color3.new(1,1,1)
		end
		GUI.Top.PositionZSet.Text = SetDecimalToString(z)
	end

	x,y,z = cf:ToOrientation()
	if not Placing.LOX then GUI.Top.OrientationXSet.Text = SetDecimalToString(math.deg(x), true) end
	if not Placing.LOY then GUI.Top.OrientationYSet.Text = SetDecimalToString(math.deg(y), true) end
	if not Placing.LOZ then GUI.Top.OrientationZSet.Text = SetDecimalToString(math.deg(z), true) end
end

local function LockTextbox(textbox, x, addDegree)
	if x then
		textbox.Text = SetDecimalToString(x, addDegree)
		textbox.TextColor3 = Color3.new(0,0,1)
	else
		textbox.Text = ""
		textbox.TextColor3 = Color3.new(1,1,1)
	end
	
	if Placing.LX and Placing.LY and Placing.LZ and Placing.LOX and Placing.LOY and Placing.LOZ then 
		GUI.Side.Lock.TextColor3 = Color3.new(0,0,1)
		GUI.Side.Lock.Text = "Unlock All (L)"
	else
		GUI.Side.Lock.TextColor3 = Color3.new(1,1,1)
		GUI.Side.Lock.Text = "Lock All (L)"
	end
end

function Placing.LockX()
	Placing.LX = GetDecimalFromString(GUI.Top.PositionXSet.Text)
	if Placing.LX then Placing.LX = CLAMP(Placing.LX,-16,16) end
--	if Placing.LX and Placing.LY and Placing.LZ then Placing.LockedAll = Placing.Hologram.Position - Vector3.new(Placing.LX, Placing.LY, Placing.LZ) else Placing.LockedAll = nil end
	LockTextbox(GUI.Top.PositionXSet, Placing.LX)
end

function Placing.LockY()
	Placing.LY = GetDecimalFromString(GUI.Top.PositionYSet.Text)
	if Placing.LY then Placing.LY = CLAMP(Placing.LY,-16,16) end
--	if Placing.LX and Placing.LY and Placing.LZ then Placing.LockedAll = Placing.Hologram.Position - Vector3.new(Placing.LX, Placing.LY, Placing.LZ) else Placing.LockedAll = nil end
	LockTextbox(GUI.Top.PositionYSet, Placing.LY)
end

function Placing.LockZ()
	Placing.LZ = GetDecimalFromString(GUI.Top.PositionZSet.Text)
	if Placing.LZ then Placing.LZ = CLAMP(Placing.LZ,-16,16) end
--	if Placing.LX and Placing.LY and Placing.LZ then Placing.LockedAll = Placing.Hologram.Position - Vector3.new(Placing.LX, Placing.LY, Placing.LZ) else Placing.LockedAll = nil end
	LockTextbox(GUI.Top.PositionZSet, Placing.LZ)
end

function Placing.LockOX()
	local x = GetDecimalFromString(GUI.Top.OrientationXSet.Text)
	if x then x = CLAMP(x,-360,360) Placing.LOX = math.rad(x) else Placing.LOX = nil end
	LockTextbox(GUI.Top.OrientationXSet, x, true)
end

function Placing.LockOY()
	local x = GetDecimalFromString(GUI.Top.OrientationYSet.Text)
	if x then x = CLAMP(x,-360,360) Placing.LOY = math.rad(x) else Placing.LOY = nil end
	LockTextbox(GUI.Top.OrientationYSet, x, true)
end

function Placing.LockOZ()
	local x = GetDecimalFromString(GUI.Top.OrientationZSet.Text)
	if x then x = CLAMP(x,-360,360) Placing.LOZ = math.rad(x) else Placing.LOZ = nil end
	LockTextbox(GUI.Top.OrientationZSet, x, true)
end

function Placing.LockAll()
	Placing.LockX()
	Placing.LockY()
	Placing.LockZ()
	Placing.LockOX()
	Placing.LockOY()
	Placing.LockOZ()
	
	if Placing.LX and Placing.LY and Placing.LZ and Placing.LOX and Placing.LOY and Placing.LOZ then return end
	
	if not Placing.Hologram then return end
	local char = player.Character
	if not char then return end
	local pp = char.PrimaryPart
	if not pp then return end
	
	local cf = Placing.Hologram.CFrame
	local hos = cf.Position
	local pos = pp.Position + Vector3.new(0,-3,0)

	Placing.LX = Placing.LX or CLAMP(hos.X - ROUND(pos.X), -16, 16)
	Placing.LY = Placing.LY or CLAMP(hos.Y - ROUND(pos.Y), -16, 16)
	Placing.LZ = Placing.LZ or CLAMP(hos.Z - ROUND(pos.Z), -16, 16)
	
	local x,y,z = cf:ToOrientation()
	Placing.LOX = Placing.LOX or x
	Placing.LOY = Placing.LOY or y
	Placing.LOZ = Placing.LOZ or z
	
	Placing.Hologram.CFrame = CFrame.new(Placing.LX, Placing.LY, Placing.LZ)
	                        * CFrame.fromOrientation(Placing.LOX, Placing.LOY, Placing.LOZ) + pos
	
	LockTextbox(GUI.Top.PositionXSet, Placing.LX)
	LockTextbox(GUI.Top.PositionYSet, Placing.LY)
	LockTextbox(GUI.Top.PositionZSet, Placing.LZ)
	LockTextbox(GUI.Top.OrientationXSet, Placing.LOX)
	LockTextbox(GUI.Top.OrientationYSet, Placing.LOY)
	LockTextbox(GUI.Top.OrientationZSet, Placing.LOZ)
end

function Placing.UnlockAll()
	Placing.LX = nil
	Placing.LY = nil
	Placing.LZ = nil
	Placing.LOX = nil
	Placing.LOY = nil
	Placing.LOZ = nil
	Placing.LockedAll = nil
	LockTextbox(GUI.Top.PositionXSet)
	LockTextbox(GUI.Top.PositionYSet)
	LockTextbox(GUI.Top.PositionZSet)
	LockTextbox(GUI.Top.OrientationXSet)
	LockTextbox(GUI.Top.OrientationYSet)
	LockTextbox(GUI.Top.OrientationZSet)
end

function Placing.ToggleLocks(_, inputState:Enum.UserInputState)
	if inputState and inputState ~= Enum.UserInputState.Begin then return end
	if not Placing.Hologram then return end
	
	if Placing.LX and Placing.LY and Placing.LZ and Placing.LOX and Placing.LOY and Placing.LOZ then
		Placing.UnlockAll()
	else
		Placing.LockAll()
	end
end


-------------
-- Options --
-------------
function Placing.SetSnapToSurface(boolean)
	Placing.SnapToSurface = boolean
	if boolean then
		GUI.Main.SnapToSurfaceSet.Text = "X"
	else
		GUI.Main.SnapToSurfaceSet.Text = ""
	end
end

function Placing.ToggleSnapToSurface()
	Placing.SetSnapToSurface(not Placing.SnapToSurface)
end

function Placing.SetAlignOrientation(boolean)
	Placing.AlignOrientation = boolean
	if boolean then
		GUI.Main.AlignOrientationSet.Text = "X"
		if Placing.Hologram then Placing.Hologram.CFrame = RoundCFrameToDegree64(Placing.Hologram.CFrame) end
	else
		GUI.Main.AlignOrientationSet.Text = ""
	end
end

function Placing.ToggleAlignOrientation()
	Placing.SetAlignOrientation(not Placing.AlignOrientation)
end

function Placing.HeldSnap(_, inputState:Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		Placing.SnapToCenter = true
		GUI.Side.Snap.TextColor3 = Color3.new(0,0,1)
	elseif inputState == Enum.UserInputState.End then
		Placing.SnapToCenter = nil
		GUI.Side.Snap.TextColor3 = Color3.new(1,1,1)
	end
end

function Placing.HeldReverse(_, inputState:Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		Placing.Reverse = true
		GUI.Side.Reverse.TextColor3 = Color3.new(0,0,1)
		GUI.Top.Rotate.Text = "-Rotate (R)"
		GUI.Top.Tilt.Text = "-Tilt (T)"
		GUI.Main.GripLabel.Text = "Ungrip (G)"
	elseif inputState == Enum.UserInputState.End then
		Placing.Reverse = nil
		GUI.Side.Reverse.TextColor3 = Color3.new(1,1,1)
		GUI.Top.Rotate.Text = "Rotate (R)"
		GUI.Top.Tilt.Text = "Tilt (T)"
		GUI.Main.GripLabel.Text = "Grip (G)"
	end
end


local function DestroyGrip()
	if Placing.Connections then
		if Placing.Connections[2] then
			Placing.Connections[2]:Disconnect()
			Placing.Connections[2] = nil
		end
		if Placing.Connections[3] then
			Placing.Connections[3]:Disconnect()
			Placing.Connections[3] = nil
		end
	end
	if Placing.VisualGrip then
		Placing.VisualGrip:Destroy()
		Placing.VisualGrip = nil
	end
end

function Placing.SetGripAuto()
	GUI.Main.Grips.Auto.BackgroundColor3 = Color3.new(0,1)
	GUI.Main.Grips.Manual.BackgroundColor3 = Color3.new()
	if Placing.Grip or Placing.VisualGrip then
		HighlightedText(GUI.Main.GripLabel, .5, Color3.new(0,1))
	end
	Placing.Grip = nil
	DestroyGrip()
end

function Placing.StartManualGrip()
	GUI.Main.Grips.Auto.BackgroundColor3 = Color3.new()
	GUI.Main.Grips.Manual.BackgroundColor3 = Color3.new(0,0,1)
	if Placing.VisualGrip then Placing.VisualGrip:Destroy() end
	if Placing.Connections[2] then Placing.Connections[2]:Disconnect() end
	
	local size = Placing.Hologram.Size
	size = math.min(size.X,size.Y,size.Z)
	
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = Vector3.new(size,size,size)/4
	part.Color = Color3.new(1)
	part.Transparency = .5
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = IGNORE_FOLDER

	DestroyGrip()
	Placing.VisualGrip = part
	Placing.Connections[2] = RSC:Connect(function()
		part.Position = mouse.Hit.Position
	end)
	Placing.Connections[3] = mouse.Button1Up:Connect(Placing.SetManualGrip)

	HighlightedText(GUI.Main.GripLabel, .5)
end

function Placing.SetManualGrip()
	if not Placing.Hologram then Placing.SetGripAuto() return end

	GUI.Main.Grips.Auto.BackgroundColor3 = Color3.new()
	GUI.Main.Grips.Manual.BackgroundColor3 = Color3.new(0,1)
	DestroyGrip()

	Placing.Grip = Placing.Hologram.CFrame:PointToObjectSpace(mouse.Hit.Position)
	HighlightedText(GUI.Main.GripLabel, .5, Color3.new(0,1))
end

function Placing.ToggleGrip(_, inputState:Enum.UserInputState)
	if inputState and inputState ~= Enum.UserInputState.Begin then return end
	
	if Placing.Reverse then
		Placing.SetGripAuto()
		return
	end
	
	if Placing.VisualGrip then
		Placing.SetManualGrip()
	else
		Placing.StartManualGrip()
	end
end


local function GetBytes()
	if not Placing.Hologram then return 4 end
	
	Placing.Bytes = Placing.Bytes or 4
	
	local cf = Placing.Hologram.CFrame
	local x = RoundToNearest(Placing.LX or cf.X, .001)
	local y = RoundToNearest(Placing.LY or cf.Y, .001)
	local z = RoundToNearest(Placing.LZ or cf.Z, .001)

	local ox,oy,oz = cf:ToOrientation()
	ox = RoundToNearest(math.deg(Placing.LOX or ox), .001)
	oy = RoundToNearest(math.deg(Placing.LOY or oy), .001)
	oz = RoundToNearest(math.deg(Placing.LOZ or oz), .001)
	
	if ox%90 == 0 and oy%90 == 0 and oz%90 == 0 then
		if x%.5 == 0 and y%.5 == 0 and z%.5 == 0 then
			if Placing.Hologram.ClassName == "Part" and Placing.Hologram.Shape == Enum.PartType.Block then
				return 4 + Placing.Bytes
			elseif Placing.Hologram.ClassName == "Model" then
				return 4 + Placing.Bytes
			else
				return 5 + Placing.Bytes
			end
		elseif x%.125 == 0 and y%.125 == 0 and z%.125 == 0 then
			return 6 + Placing.Bytes
		else
			return 12 + Placing.Bytes
		end
	elseif ox%360 == RoundToDegree64(ox) and oy%360 == RoundToDegree64(oy) and oz%360 == RoundToDegree64(oz) then
		if x%.5 == 0 and y%.5 == 0 and z%.5 == 0 then
			return 7 + Placing.Bytes
		elseif x%.125 == 0 and y%.125 == 0 and z%.125 == 0 then
			return 8 + Placing.Bytes
		else
			return 12 + Placing.Bytes
		end
	end
	
	return 18 + Placing.Bytes
end

local lastBytes = 0
local function UpdateBytes()
	local bytes = GetBytes()
	GUI.Side.Bytes.Text = bytes and bytes .. " Bytes" or ""
	if bytes > lastBytes then
		HighlightedText(GUI.Side.Bytes, .5, Color3.new(1))
	elseif bytes < lastBytes then
		HighlightedText(GUI.Side.Bytes, .5, Color3.new(0,1))
	end
	lastBytes = bytes
end

local function UpdateLabel()
	Placing.Name = Placing.Name or ""
	Placing.Amount = CLAMP(Placing.Amount or 0, 0, math.huge)
	Placing.Max = CLAMP(Placing.Max or 0, 0, math.huge)
	GUI.Top.Label.Text = Placing.Name .. " [" .. Placing.Amount .. " / " .. Placing.Max .. "]"
	if Placing.Amount < Placing.Max then
		GUI.Top.Label.TextColor3 = Color3.new(1,1,1)
	else
		GUI.Top.Label.TextColor3 = Color3.new(1)
	end
end

function Placing.SetMaterialName(x)
	Placing.Name = x
	UpdateLabel()
end

function Placing.SetMaterialAmount(x)
	Placing.Amount = x
	UpdateLabel()
end

function Placing.SetMaterialMax(x)
	Placing.Max = x
	UpdateLabel()
end


-------------
-- Placing --
-------------
local CAS = game:GetService("ContextActionService")

function Placing.Cancel(_, inputState:Enum.UserInputState)
	if inputState and inputState ~= Enum.UserInputState.Begin then return end

	-- Clean Up
	GUI.Parent.Enabled = false
	HideAxis()
	DestroyGrip()
	Placing.UnlockAll()
	Placing.HideAdvanced()
	Placing.Part = nil
	if Placing.Hologram then
		Placing.Hologram:Destroy()
		Placing.Hologram = nil
	end
	
	-- Unbind Actions
	CAS:UnbindAction("Locks")
	CAS:UnbindAction("Advanced")
	CAS:UnbindAction("Rotate")
	CAS:UnbindAction("Tilt")
	CAS:UnbindAction("Snap")
	CAS:UnbindAction("Reverse")
	CAS:UnbindAction("Grip")
	CAS:UnbindAction("Reset")
	CAS:UnbindAction("Cancel")
	
	if Placing.Connections then
		for i, connection in next, Placing.Connections do
			connection:Disconnect()
			Placing.Connections[i] = nil
		end
		Placing.Connections = nil
	end
	
	if Placing.OnCancel then Placing.OnCancel() end
end


function Placing.Reset(_, inputState:Enum.UserInputState)
	if inputState and inputState ~= Enum.UserInputState.Begin then return end

	Placing.UnlockAll()
	Placing.SetGripAuto()
	--Placing.SetAlignment(1)
	--Placing.SetOrientation(90)
	--Placing.SetSnapToSurface(false)
	--Placing.SetAlignOrientation(true)
	Placing.Orientation = CFrame.new()
	HighlightedText(GUI.Side.Reset, .75)
	
	if not Placing.Hologram then return end
	Placing.Hologram.Orientation = Vector3.new()
end

--local IGNORE_FOLDER = workspace:WaitForChild("Ignore")
function Placing.Start(part:BasePart)
	Placing.Cancel()
	 
	-- Bind Actions
	Placing.Connections = {}
--	Placing.Connections[1] = RenderStepped PartLoop
--	Placing.Connections[2] = RenderStepped GripLoop
--	Placing.Connections[3] = RenderStepped GripClick
	Placing.Connections[4] = HBC:Connect(UpdateXYZ)
	Placing.Connections[5] = HBC:Connect(UpdateBytes)
	Placing.Connections[6] = mouse.Button1Down:Connect(Placing.Place)
	Placing.Connections[7] = GUI.Main.SnapToSurfaceSet.MouseButton1Click:Connect(Placing.ToggleSnapToSurface)
	Placing.Connections[8] = GUI.Main.AlignOrientationSet.MouseButton1Click:Connect(Placing.ToggleAlignOrientation)
	Placing.Connections[9] = GUI.Main.Positions.Set.FocusLost:Connect(SetAlignment)
	Placing.Connections[10] = GUI.Main.Positions.Increase.MouseButton1Click:Connect(IncreaseAlignment)
	Placing.Connections[11] = GUI.Main.Positions.Decrease.MouseButton1Click:Connect(DecreaseAlignment)
	Placing.Connections[12] = GUI.Main.Orientations.Set.FocusLost:Connect(SetOrientation)
	Placing.Connections[13] = GUI.Main.Orientations.Increase.MouseButton1Click:Connect(IncreaseOrientation)
	Placing.Connections[14] = GUI.Main.Orientations.Decrease.MouseButton1Click:Connect(DecreaseOrientation)
	Placing.Connections[15] = GUI.Main.Grips.Auto.MouseButton1Click:Connect(Placing.SetGripAuto)
	Placing.Connections[16] = GUI.Main.Grips.Manual.MouseButton1Click:Connect(Placing.StartManualGrip)
	Placing.Connections[17] = GUI.Top.PositionXSet.Focused:Connect(Placing.LockX)
	Placing.Connections[18] = GUI.Top.PositionYSet.Focused:Connect(Placing.LockY)
	Placing.Connections[19] = GUI.Top.PositionZSet.Focused:Connect(Placing.LockZ)
	Placing.Connections[20] = GUI.Top.OrientationXSet.Focused:Connect(Placing.LockOX)
	Placing.Connections[21] = GUI.Top.OrientationYSet.Focused:Connect(Placing.LockOY)
	Placing.Connections[22] = GUI.Top.OrientationZSet.Focused:Connect(Placing.LockOZ)
	Placing.Connections[23] = GUI.Top.PositionXSet.FocusLost:Connect(Placing.LockX)
	Placing.Connections[24] = GUI.Top.PositionYSet.FocusLost:Connect(Placing.LockY)
	Placing.Connections[25] = GUI.Top.PositionZSet.FocusLost:Connect(Placing.LockZ)
	Placing.Connections[26] = GUI.Top.OrientationXSet.FocusLost:Connect(Placing.LockOX)
	Placing.Connections[27] = GUI.Top.OrientationYSet.FocusLost:Connect(Placing.LockOY)
	Placing.Connections[28] = GUI.Top.OrientationZSet.FocusLost:Connect(Placing.LockOZ)
	Placing.Connections[29] = GUI.Advanced.MouseButton1Click:Connect(Placing.ToggleAdvanced)
	Placing.Connections[30] = GUI.Side.Lock.MouseButton1Click:Connect(Placing.ToggleLocks)
	Placing.Connections[31] = GUI.Side.Reset.MouseButton1Click:Connect(Placing.Reset)
	Placing.Connections[32] = GUI.Top.Rotate.MouseButton1Click:Connect(Placing.Rotate)
	Placing.Connections[33] = GUI.Top.Tilt.MouseButton1Click:Connect(Placing.Tilt)
	Placing.Connections[34] = GUI.Top.Cancel.MouseButton1Click:Connect(Placing.Cancel)
	
	CAS:BindAction("Locks", Placing.ToggleLocks, false, Enum.KeyCode.L)
	CAS:BindAction("Advanced", Placing.ToggleAdvanced, false, Enum.KeyCode.H)
	CAS:BindAction("Rotate", Placing.Rotate, false, Enum.KeyCode.R)
	CAS:BindAction("Tilt", Placing.Tilt, false, Enum.KeyCode.T)
	CAS:BindAction("Snap", Placing.HeldSnap, false, Enum.KeyCode.LeftControl)
	CAS:BindAction("Reverse", Placing.HeldReverse, false, Enum.KeyCode.LeftShift)
	CAS:BindAction("Grip", Placing.ToggleGrip, false, Enum.KeyCode.G)
	CAS:BindAction("Cancel", Placing.Cancel, false, Enum.KeyCode.X)
	CAS:BindAction("Reset", Placing.Reset, false, Enum.KeyCode.F)
	
	-- Show GUI
	Placing.Reset()
	UpdateLabel()
	GUI.Parent.Enabled = true
	
	-- Begin Showing Hologram
	Placing.Part = part
	Placing.Orientation = CFrame.new()

	local hologram = part:Clone()
	hologram.CanCollide = false
	hologram.CanTouch = false
	hologram.CanQuery = false
	hologram.Anchored = true
	hologram.Transparency = .5
	hologram.Parent = IGNORE_FOLDER

	Placing.Hologram = hologram

	-- placing loop
	local RCP = RaycastParams.new()
	RCP.FilterType = Enum.RaycastFilterType.Blacklist
	Placing.Connections[1] = RSC:Connect(function()
		if Placing.VisualGrip then return end
		
		HideAxis()

		if Placing.LX and Placing.LY and Placing.LZ and Placing.LOX and Placing.LOY and Placing.LOZ then
			local char = player.Character
			if not char then return end
			local pp = char.PrimaryPart
			if not pp then return end
			local pos = pp.Position + Vector3.new(0,-3,0)

			local x = ROUND(pos.X) + Placing.LX
			local y = ROUND(pos.Y) + Placing.LY
			local z = ROUND(pos.Z) + Placing.LZ

			hologram.CFrame = CFrame.new(x,y,z) * CFrame.fromOrientation(Placing.LOX,Placing.LOY,Placing.LOZ)
			return
		end

		-- Raycast
		local origin = mouse.UnitRay
		local direction = origin.Direction*1000
		origin = origin.Origin

		RCP.FilterDescendantsInstances = {IGNORE_FOLDER, player.Character}
		local result = workspace:Raycast(origin, direction, RCP)
		if not result then hologram.Position = mouse.Hit.Position return end -- error (out of range anyway)

		-- Snap to Center
		if Placing.SnapToCenter then
			CenterSnap(result)
			return
		end
		
		if Placing.SnapToSurface then
			if not Placing.PositionAlignment or Placing.PositionAlignment <= .001 then
				MouseSnap(result) -- Unaligned Face Snap
			else
				StudSnap(result) -- Aligned Face Snap
			end
		else
			if Placing.Grip or Placing.AlignOrientation then
				RegularSnap(result.Normal) -- Fixed Pass Walls (easiest for 8 bytes)
			else
				Dir6Collision(result.Normal, RCP) -- Aligned regular dont pass wall (default, could be 16-22 bytes)
			end
		end
		
		if Placing.AlignOrientation then
			hologram.CFrame = RoundCFrameToDegree64(hologram.CFrame)
		end
		
		-- Set Locks
		local cf = hologram.CFrame
		local char = player.Character
		if not char then return end
		local pp = char.PrimaryPart
		if not pp then return end
		local pos = pp.Position + Vector3.new(0,-3,0)
		
		local x,y,z = cf.X,cf.Y,cf.Z
		if Placing.LX then x = ROUND(pos.X) + Placing.LX end
		if Placing.LY then y = ROUND(pos.Y) + Placing.LY end
		if Placing.LZ then z = ROUND(pos.Z) + Placing.LZ end

		local ox,oy,oz = cf:ToOrientation()
		if Placing.LOX then ox = math.deg(Placing.LOX) end
		if Placing.LOY then oy = math.deg(Placing.LOY) end
		if Placing.LOZ then oz = math.deg(Placing.LOZ) end

		hologram.CFrame = CFrame.fromOrientation(ox,oy,oz) + Vector3.new(x,y,z)
	end)
end

local A_LITTLE_EXTRA_SIZE = Vector3.new(.001,.001,.001)
function Placing.Place()
	if Placing.Connections and Placing.Connections[3] then return end
	if not Placing.Hologram then return end
	local item = Placing.Part
	if not item then return end
	
	-- Position fix
	local cf = Placing.Hologram.CFrame
	local pos = cf.Position
	local x = RoundToNearest(pos.X, .001)
	local y = RoundToNearest(pos.Y, .001)
	local z = RoundToNearest(pos.Z, .001)
	cf = cf-pos + Vector3.new(x,y,z)
	
	-- Funct
	if Placing.OnPlace then Placing.OnPlace(cf) end
	
	-- Weld
	local _item = item:Clone()
	local target = mouse.Target
	local size = _item.Size

	_item.Size = size + A_LITTLE_EXTRA_SIZE
	_item.CFrame = cf
	_item.TopSurface = Enum.SurfaceType.Weld
	_item.BottomSurface = Enum.SurfaceType.Weld
	_item.BackSurface = Enum.SurfaceType.Weld
	_item.LeftSurface = Enum.SurfaceType.Weld
	_item.FrontSurface = Enum.SurfaceType.Weld
	_item.RightSurface = Enum.SurfaceType.Weld
	_item.Anchored = true
	_item.Parent = workspace
	_item:MakeJoints()
	_item.Anchored = false
	_item.TopSurface = item.TopSurface
	_item.BottomSurface = item.BottomSurface
	_item.BackSurface = item.BackSurface
	_item.LeftSurface = item.LeftSurface
	_item.FrontSurface = item.FrontSurface
	_item.RightSurface = item.RightSurface

	local earlyReturn
	for _, part in ipairs(_item:GetConnectedParts()) do
		if part.Parent and part.Parent:FindFirstChildOfClass("Humanoid") then
			for _, weld:Weld in ipairs(_item:GetChildren()) do
				if weld.Part0 == part or weld.Part1 == part then
					weld:Destroy()
					break
				end
			end
		elseif part == target then
			_item.Size = size
			earlyReturn = true
		end
	end

	if earlyReturn then return end

	for _, part in ipairs(_item:GetTouchingParts()) do
		if part == target then
			local w = Instance.new("Weld")
			w.Part0 = _item
			w.Part1 = target
			w.C0 = _item.CFrame:Inverse() * target.CFrame
			w.Parent = _item
			_item.Size = size
			return
		end
	end

	_item.Size = size
end


return Placing
