local utils = require("modules/utils/utils")
local settings = require("modules/utils/settings")
local history = require("modules/utils/history")
local style = require("modules/ui/style")
local editor = require("modules/utils/editor/editor")

local element = require("modules/classes/editor/element")

---Element with position, rotation and optionally scale, handles the rendering / editing of those. Values have to be provided by the inheriting class
---@class positionable : element
---@field transformExpanded boolean
---@field rotationRelative boolean
---@field hasScale boolean
---@field scaleLocked boolean
---@field rotationLocked boolean
---@field relativeOffset table
---@field visualizerState boolean
---@field visualizerDirection string
---@field controlsHovered boolean
---@field randomizationSettings table
local positionable = setmetatable({}, { __index = element })

function positionable:new(sUI)
	local o = element.new(self, sUI)

	o.modulePath = "modules/classes/editor/positionable"

	o.transformExpanded = true
	o.rotationRelative = false
	o.hasScale = false
	o.scaleLocked = true
	o.rotationLocked = false
	o.relativeOffset = {
		x = 0,
		y = 0,
		z = 0
	}

	o.visualizerState = false
	o.visualizerDirection = "none"
	o.controlsHovered = false

	o.randomizationSettings = {
		probability = 0.5
	}

	o.class = utils.combine(o.class, { "positionable" })

	setmetatable(o, { __index = self })
   	return o
end

function positionable:load(data, silent)
	element.load(self, data, silent)
	self.transformExpanded = data.transformExpanded
	self.rotationRelative = data.rotationRelative
	self.scaleLocked = data.scaleLocked
	self.rotationLocked = data.rotationLocked
	if self.rotationLocked == nil then self.rotationLocked = false end

	for key, setting in pairs(data.randomizationSettings or {}) do
		self.randomizationSettings[key] = setting
	end

	if self.scaleLocked == nil then self.scaleLocked = true end
	if self.transformExpanded == nil then self.transformExpanded = true end
	if self.rotationRelative == nil then self.rotationRelative = false end
end

function positionable:drawTransform()
	local position = self:getPosition()
	local rotation = self:getRotation()
	local scale = self:getScale()
	self.controlsHovered = false

	self:drawPosition(position)
	self:drawRelativePosition()
	self:drawRotation(rotation)
	self:drawScale(scale)

	if not self.controlsHovered and self.visualizerDirection ~= "none" then
		if not settings.gizmoOnSelected and not editor.active then
			self:setVisualizerState(false) -- Set vis state first, as loading the mesh app (vis direction) can screw with it
		end
		self:setVisualizerDirection("none")
	end
end

function positionable:getProperties()
	local properties = element.getProperties(self)

	table.insert(properties, {
		id = "transform",
		name = "Transform",
		defaultHeader = true,
		draw = function ()
			self:drawTransform()
		end
	})

	if self.parent and utils.isA(self.parent, "randomizedGroup") then
		table.insert(properties, {
			id = "randomizationSelf",
			name = "Entry Randomization",
			defaultHeader = false,
			draw = function ()
				self:drawEntryRandomization()
			end
		})
	end

	return properties
end

function positionable:setSelected(state)
	local updated = state ~= self.selected
	if updated and not self.hovered and (settings.gizmoOnSelected or editor.active) then
		self:setVisualizerState(state)
	end

	element.setSelected(self, state)

	if updated then
		self.sUI.cachePaths()

		if state then
			if #self.sUI.selectedPaths > 1 then
				for _, entry in ipairs(self.sUI.selectedPaths) do
					if entry and entry.ref ~= self then
						entry.ref:setVisualizerState(false)
					end
				end

				self:setVisualizerState(false)
			end
		elseif #self.sUI.selectedPaths == 1 then
			for _, entry in ipairs(self.sUI.selectedPaths) do
				if entry and entry.ref ~= self then
					entry.ref:setVisualizerState(true)
				end
			end
		end
	end
end

function positionable:setHovered(state)
	if state ~= self.hovered and (not self.selected or (not settings.gizmoOnSelected and not editor.active)) then
		self:setVisualizerState(state)
		self:setVisualizerDirection("none")
	end

	element.setHovered(self, state)
end

function positionable:setVisualizerDirection(direction)
	if not settings.gizmoOnSelected and not editor.active then
		if direction ~= "none" and not self.hovered and not self.visualizerState then
			self:setVisualizerState(true)
		end
	end
	self.visualizerDirection = direction
end

function positionable:setVisualizerState(state)
	if not settings.gizmoActive then state = false end

	self.visualizerState = state
end

function positionable:onEdited() end

---@protected
function positionable:drawCopyPaste(name)
	if not ImGui.IsKeyDown(ImGuiKey.LeftShift) and ImGui.BeginPopupContextItem("##pasteProperty" .. name, ImGuiPopupFlags.MouseButtonRight) then
        if ImGui.MenuItem("Copy position") then
			local pos = self:getPosition()
			utils.insertClipboardValue("position", { x = pos.x, y = pos.y, z = pos.z })
        end
		if ImGui.MenuItem("Copy rotation") then
			local rot = self:getRotation()
			utils.insertClipboardValue("rotation", { roll = rot.roll, pitch = rot.pitch, yaw = rot.yaw })
        end
		if ImGui.MenuItem("Copy position and rotation") then
			local pos = self:getPosition()
			local rot = self:getRotation()
			utils.insertClipboardValue("position", { x = pos.x, y = pos.y, z = pos.z })
			utils.insertClipboardValue("rotation", { roll = rot.roll, pitch = rot.pitch, yaw = rot.yaw })
        end
		ImGui.Separator()
		if ImGui.MenuItem("Paste position") then
			local pos = utils.getClipboardValue("position")
			if pos then
				history.addAction(history.getElementChange(self))
				self:setPosition(Vector4.new(pos.x, pos.y, pos.z, 0))
			end
		end
		if ImGui.MenuItem("Paste rotation") then
			local rot = utils.getClipboardValue("rotation")
			if rot then
				history.addAction(history.getElementChange(self))
				self:setRotation(EulerAngles.new(rot.roll, rot.pitch, rot.yaw))
			end
		end
		if ImGui.MenuItem("Paste position and rotation") then
			local pos = utils.getClipboardValue("position")
			local rot = utils.getClipboardValue("rotation")
			if pos and rot then
				history.addAction(history.getElementChange(self))
				self:setPosition(Vector4.new(pos.x, pos.y, pos.z, 0))
				self:setRotation(EulerAngles.new(rot.roll, rot.pitch, rot.yaw))
			end
		end
		ImGui.Separator()
		if ImGui.MenuItem(string.format("%s Rotation", self.rotationLocked and "Unlock" or "Lock")) then
			history.addAction(history.getElementChange(self))
			self.rotationLocked = not self.rotationLocked
		end
		if ImGui.MenuItem(string.format("%s Rotation and Set Zero", self.rotationLocked and "Unlock" or "Lock")) then
			history.addAction(history.getElementChange(self))
			self:setRotation(EulerAngles.new(0, 0, 0))
			self.rotationLocked = not self.rotationLocked
		end
		ImGui.Separator()
		if ImGui.MenuItem("Copy rotation as Quaternion to clipboard") then
			local quat = self:getRotation():ToQuat()
			ImGui.SetClipboardText(string.format("i = %.6f, j = %.6f, k = %.6f, r = %.6f", quat.i, quat.j, quat.k, quat.r))
		end
        ImGui.EndPopup()
    end
end

---@protected
function positionable:drawProp(prop, name, axis, disableInput)
	local steps = (axis == "roll" or axis == "pitch" or axis == "yaw") and settings.rotSteps or settings.posSteps
	local formatText = "%.2f"

	if ImGui.IsKeyDown(ImGuiKey.LeftShift) then
		steps = steps * 0.1 * settings.precisionMultiplier -- Shift usually is a x10 multiplier, so get rid of that first
		formatText = "%.3f"
	end

	local flags = ImGuiSliderFlags.NoRoundToFormat
	if disableInput then
		flags = flags + ImGuiSliderFlags.NoInput
	end

    local newValue, changed = ImGui.DragFloat("##" .. name, prop, steps, -99999, 99999, formatText .. " " .. name, flags)
	self.controlsHovered = (ImGui.IsItemHovered() or ImGui.IsItemActive()) or self.controlsHovered
	if (ImGui.IsItemHovered() or ImGui.IsItemActive()) and axis ~= self.visualizerDirection then
		self:setVisualizerDirection(axis)
	end

	local finished = ImGui.IsItemDeactivatedAfterEdit()

	if finished then
		history.propBeingEdited = false
		self:onEdited()
	end
	if changed and not history.propBeingEdited then
		history.addAction(history.getElementChange(self))
		history.propBeingEdited = true
	end
    if changed or finished then
		if axis == "x" then
			self:setPositionDelta(Vector4.new(newValue - prop, 0, 0, 0))
		elseif axis == "y" then
			self:setPositionDelta(Vector4.new(0, newValue - prop, 0, 0))
		elseif axis == "z" then
			self:setPositionDelta(Vector4.new(0, 0, newValue - prop, 0))
		elseif axis == "relX" or axis == "relY" or axis == "relZ" then
			if axis == "relX" then
				local v = self:getDirection("right")
				self:setPositionDelta(Vector4.new((v.x * (newValue - self.relativeOffset.x)), (v.y * (newValue - self.relativeOffset.x)), (v.z * (newValue - self.relativeOffset.x)), 0))
				self.relativeOffset.x = newValue
			elseif axis == "relY" then
				v = self:getDirection("forward")
				self:setPositionDelta(Vector4.new((v.x * (newValue - self.relativeOffset.y)), (v.y * (newValue - self.relativeOffset.y)), (v.z * (newValue - self.relativeOffset.y)), 0))
				self.relativeOffset.y = newValue
			elseif axis == "relZ" then
				v = self:getDirection("up")
				self:setPositionDelta(Vector4.new((v.x * (newValue - self.relativeOffset.z)), (v.y * (newValue - self.relativeOffset.z)), (v.z * (newValue - self.relativeOffset.z)), 0))
				self.relativeOffset.z = newValue
			end

			if finished then
				self.relativeOffset = { x = 0, y = 0, z = 0 }
			end
		elseif axis == "roll" then
			self:setRotationDelta(EulerAngles.new(newValue - prop, 0, 0))
		elseif axis == "pitch" then
			self:setRotationDelta(EulerAngles.new(0, newValue - prop, 0))
		elseif axis == "yaw" then
			self:setRotationDelta(EulerAngles.new(0, 0, newValue - prop))
		elseif axis == "scaleX" then
			self:setScaleDelta({ x = newValue - prop, y = 0, z = 0 }, finished)
		elseif axis == "scaleY" then
			self:setScaleDelta({ x = 0, y = newValue - prop, z = 0 }, finished)
		elseif axis == "scaleZ" then
			self:setScaleDelta({ x = 0, y = 0, z = newValue - prop }, finished)
		end
    end

	self:drawCopyPaste(name)

	return finished
end

---@protected
function positionable:drawPosition(position)
	ImGui.PushItemWidth(80 * style.viewSize)
	self:drawProp(position.x, "X", "x")
    ImGui.SameLine()
	self:drawProp(position.y, "Y", "y")
    ImGui.SameLine()
	self:drawProp(position.z, "Z", "z")
    ImGui.PopItemWidth()

    ImGui.SameLine()
    style.pushButtonNoBG(true)
    if ImGui.Button(IconGlyphs.AccountArrowLeftOutline) then
		history.addAction(history.getElementChange(self))
		local pos = utils.getPlayerPosition(editor.active)

        self:setPositionDelta(Vector4.new(pos.x - position.x, pos.y - position.y, pos.z - position.z, 0))
    end
	if ImGui.BeginPopupContextItem("##tpPlayer", ImGuiPopupFlags.MouseButtonRight) then
        if ImGui.MenuItem("Move player here") then
			Game.GetTeleportationFacility():Teleport(GetPlayer(), self:getPosition(), GetPlayer():GetWorldOrientation():ToEulerAngles())
        end
        ImGui.EndPopup()
    end

    style.pushButtonNoBG(false)
	if ImGui.IsItemHovered() then style.setCursorRelative(5, 5) end
	style.tooltip("Set to player position")
end

---@protected
function positionable:drawRelativePosition()
    ImGui.PushItemWidth(80 * style.viewSize)
	style.pushGreyedOut(not self.visible or self.hiddenByParent)
    self:drawProp(self.relativeOffset.x, "Rel X", "relX")
	ImGui.SameLine()
    self:drawProp(self.relativeOffset.y, "Rel Y", "relY")
	ImGui.SameLine()
    self:drawProp(self.relativeOffset.z, "Rel Z", "relZ")
	style.popGreyedOut(not self.visible or self.hiddenByParent)
    ImGui.PopItemWidth()
end

function positionable:handleRightAngleChange(axis, shiftActive)
	if not shiftActive then return end

	if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Left) and shiftActive then
		history.addAction(history.getElementChange(self))
		self:setRotationDelta(EulerAngles.new(axis == "roll" and 90 or 0, axis == "pitch" and 90 or 0, axis == "yaw" and 90 or 0))
	end
	if ImGui.IsItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Right) and shiftActive then
		history.addAction(history.getElementChange(self))
		self:setRotationDelta(EulerAngles.new(axis == "roll" and -90 or 0, axis == "pitch" and -90 or 0, axis == "yaw" and -90 or 0))
	end
end

---@protected
function positionable:drawRotation(rotation)
    ImGui.PushItemWidth(80 * style.viewSize)
	local locked = self.rotationLocked
	local shiftActive = ImGui.IsKeyDown(ImGuiKey.LeftShift) and not ImGui.IsMouseDragging(0, 0)

	local finished = false
	style.pushGreyedOut(locked)
    finished = self:drawProp(rotation.roll, "Roll", "roll", shiftActive) or finished
	self:handleRightAngleChange("roll", shiftActive and not finished)
    ImGui.SameLine()
    finished = self:drawProp(rotation.pitch, "Pitch", "pitch", shiftActive) or finished
	self:handleRightAngleChange("pitch", shiftActive and not finished)
    ImGui.SameLine()
	finished = self:drawProp(rotation.yaw, "Yaw", "yaw", shiftActive) or finished
	self:handleRightAngleChange("yaw", shiftActive and not finished)
	style.popGreyedOut(locked)
    ImGui.SameLine()

	self.rotationRelative, _ = style.toggleButton(IconGlyphs.HorizontalRotateClockwise, self.rotationRelative)
	style.tooltip("Toggle relative rotation")
    ImGui.PopItemWidth()
end

function positionable:drawScale(scale)
	-- TODO: Allow for each axis to be disabled individually
	if not self.hasScale then return end

	ImGui.PushItemWidth(80 * style.viewSize)

	self:drawProp(scale.x, "Scale X", "scaleX")
	ImGui.SameLine()
	self:drawProp(scale.y, "Scale Y", "scaleY")
	ImGui.SameLine()
	self:drawProp(scale.z, "Scale Z", "scaleZ")

	ImGui.SameLine()
	self.scaleLocked, _ = style.toggleButton(IconGlyphs.LinkVariant, self.scaleLocked)
	style.tooltip("Locks the X, Y, and Z axis scales together")

	ImGui.PopItemWidth()
end

function positionable:drawEntryRandomization()
	style.mutedText("Spawning Probability")
	ImGui.SameLine()
	self.randomizationSettings.probability, _, finished = style.trackedDragFloat(self, "##probability", self.randomizationSettings.probability, 0.01, 0, 1, "%.2f")
	if finished then
		self.parent:applyRandomization(true)
	end
	style.tooltip("The base probability of this element being spawned, also depends on randomization mode of parent group.")
end

function positionable:setPosition(position)
end

function positionable:setPositionDelta(delta)
end

---@return Vector4
function positionable:getPosition()
	return Vector4.new(0, 0, 0, 0)
end

function positionable:setRotation(rotation)
end

function positionable:setRotationDelta(delta)
end

---@return EulerAngles
function positionable:getRotation()
	return EulerAngles.new(0, 0, 0)
end

function positionable:setScale(scale, finished)

end

function positionable:setScaleDelta(delta, finished)

end

function positionable:getScale()
	return Vector4.new(1, 1, 1, 0)
end

---@param direction string
---@return Vector4?
function positionable:getDirection(direction)
	if direction == "right" then
		return Vector4.new(1, 0, 0, 0)
	elseif direction == "forward" then
		return Vector4.new(0, 1, 0, 0)
	elseif direction == "up" then
		return Vector4.new(0, 0, 1, 0)
	end
end

function positionable:dropToSurface(grouped, direction)

end

function positionable:serialize()
	local data = element.serialize(self)

	data.transformExpanded = self.transformExpanded
	data.rotationRelative = self.rotationRelative
	data.scaleLocked = self.scaleLocked
	data.rotationLocked = self.rotationLocked
	data.randomizationSettings = utils.deepcopy(self.randomizationSettings)
	data.pos = utils.fromVector(self:getPosition()) -- For savedUI

	return data
end

return positionable