require("behaviours/wander")
require("behaviours/follow")
require("behaviours/doaction")
require("behaviours/approach")
local BrainCommon = require("brains/braincommon")

local FOOD_SEARCH_RADIUS = 5
local WANDER_RADIUS = 10
local FOLLOW_MIN_DIST = 0
local FOLLOW_TARGET_DIST = 3
local FOLLOW_MAX_DIST = 8

local CapybaraBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function EatFoodAction(inst)
    if inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("sleeping") then
        return nil
    end

    if inst.components.timer ~= nil and inst.components.timer:TimerExists("eat_cooldown") then
        return nil
    end

    local grass_item = FindEntity(inst, FOOD_SEARCH_RADIUS, function(item)
        return item.prefab == "cutgrass" and item:IsValid() and not item:IsInLimbo()
    end)
    
    if grass_item then
        return BufferedAction(inst, grass_item, ACTIONS.EAT)
    end

    local grass_bush = FindEntity(inst, FOOD_SEARCH_RADIUS, function(item)
        return item.prefab == "grass" and item.components.pickable and item.components.pickable:CanBePicked()
    end)

    if grass_bush then
        local action = BufferedAction(inst, grass_bush, ACTIONS.EAT)
        action.addvalidfn = function()
            if grass_bush.components.pickable and grass_bush.components.pickable:CanBePicked() then
                grass_bush.components.pickable:MakeEmpty()
            end
            return true
        end
        return action
    end
end

local function GetLightTarget(inst)
    local light = FindEntity(inst, 15, function(item)
        return item.Light ~= nil and item.Light:IsEnabled()
    end)
    
    if light and inst:GetDistanceSqToInst(light) > 16 then
        return light
    end
    return nil
end

function CapybaraBrain:OnStart()
    local root = PriorityNode(
    {
        BrainCommon.PanicTrigger(self.inst),

        WhileNode(function() return TheWorld.state.isnight end, "IsNight",
            PriorityNode({
                ActionNode(function()
                    if self.inst.components.sleeper ~= nil and self.inst.components.sleeper:IsAsleep() then
                        return SUCCESS
                    end
                    return FAILED
                end),
                
                Approach(self.inst, GetLightTarget, 3),
                
                ActionNode(function()
                    if self.inst.components.sleeper ~= nil then
                        self.inst.components.sleeper:GoToSleep()
                        return SUCCESS
                    end
                end)
            }, .25)),
            
        IfNode(function() return not TheWorld.state.isnight and self.inst.components.sleeper ~= nil and self.inst.components.sleeper:IsAsleep() end, "NeedsToWakeUp",
            ActionNode(function()
                self.inst.components.sleeper:WakeUp()
                return SUCCESS
            end)),

        WhileNode(function() return self.inst.leader_target ~= nil end, "HasLeader",
            Follow(self.inst, function() return self.inst.leader_target end, FOLLOW_MIN_DIST, FOLLOW_TARGET_DIST, FOLLOW_MAX_DIST, true)
        ),

        DoAction(self.inst, EatFoodAction, "Eat Grass"),
            
        Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") or self.inst:GetPosition() end, WANDER_RADIUS),
    }, .25)

    self.bt = BT(self.inst, root)
end

return CapybaraBrain