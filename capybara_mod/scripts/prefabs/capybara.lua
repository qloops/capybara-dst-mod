local assets = {
    Asset("ANIM", "anim/capybara.zip"),
}

local brain = require("brains/capybarabrain")

local MASS = 50
local MAX_HEALTH = 100
local WALK_SPEED = 2
local RUN_SPEED = 4
local FOLLOW_TIME = 15
local SANITY_AURA = 35
local SCALE = 0.6

local function OnSave(inst, data)
    if inst:HasTag("claimed") then
        data.claimed = true
    end
end

local function OnLoad(inst, data)
    if data ~= nil and data.claimed then
        inst:AddTag("claimed")
    end
end

local function StopFollowing(inst)
    inst.leader_target = nil
    inst:RemoveTag("following_leader")
    
    inst:ClearBufferedAction()
    inst.components.locomotor:StopMoving()
    
    if inst.components.timer:TimerExists("follow_leader") then
        inst.components.timer:StopTimer("follow_leader")
    end
    
    if inst.components.knownlocations then
        inst.components.knownlocations:RememberLocation("home", inst:GetPosition())
    end
end

local function OnTimerDone(inst, data)
    if data ~= nil and data.name == "follow_leader" then
        StopFollowing(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("idle")
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, MASS, 0.3)

    inst.DynamicShadow:SetSize(1.5, 0.75)
    inst.Transform:SetTwoFaced()
    inst.Transform:SetScale(SCALE, SCALE, SCALE)
    inst.AnimState:SetBank("capybara")
    inst.AnimState:SetBuild("capybara")
    inst.AnimState:PlayAnimation("idle_loop", true)

    inst:AddTag("animal")
    inst:AddTag("notarget")
    inst:AddTag("sandstormimmune")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = WALK_SPEED
    inst.components.locomotor.runspeed = RUN_SPEED
    inst.components.locomotor.pathcaps = { allowocean = false, ignorecreep = false }

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(MAX_HEALTH)
    inst.components.health:SetInvincible(true)

    inst:AddComponent("inspectable")
    
    inst:AddComponent("sleeper")
    inst.components.sleeper:SetResistance(3)
    
    inst:AddComponent("knownlocations")
    
    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)

    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = SANITY_AURA / 60

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODTYPE.ROUGHAGE }, { FOODTYPE.ROUGHAGE })

    inst.StopFollowingLeader = function(inst)
        StopFollowing(inst)
        if not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("idle")
        end
    end

    inst:AddComponent("trader")
    inst.components.trader:SetAcceptTest(function(inst, item)
        return item.prefab == "watermelon" or item.prefab == "watermelon_cooked" or item.prefab == "cutgrass"
    end)
    
    inst.components.trader.onaccept = function(inst, giver, item)
        inst.sg:GoToState("eat")
        
        if item.prefab == "cutgrass" then
            return 
        end

        inst:AddTag("claimed")
        inst:AddTag("following_leader")
        inst.leader_target = giver
        
        if inst.components.timer:TimerExists("follow_leader") then
            inst.components.timer:SetTimeLeft("follow_leader", FOLLOW_TIME)
        else
            inst.components.timer:StartTimer("follow_leader", FOLLOW_TIME)
        end
    end

    MakeHauntablePanic(inst)

    inst:SetStateGraph("SGcapybara")
    inst:SetBrain(brain)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("capybara", fn, assets)