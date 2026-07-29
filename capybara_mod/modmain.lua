PrefabFiles = {
    "capybara",
}

Assets = {
    Asset("ANIM", "anim/capybara.zip"),
}

GLOBAL.STRINGS.NAMES.CAPYBARA = "Capybara"
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.CAPYBARA = "Hm, Capybara!"

local UNFOLLOW_CAPY = GLOBAL.Action({ priority = 10, rmb = true, distance = 3, mount_valid = true })
UNFOLLOW_CAPY.id = "UNFOLLOW_CAPY"
UNFOLLOW_CAPY.str = "Stop!"
UNFOLLOW_CAPY.fn = function(act)
    if act.target and act.target.prefab == "capybara" and act.target.StopFollowingLeader then
        act.target:StopFollowingLeader()
        return true
    end
    return false
end
AddAction(UNFOLLOW_CAPY)

GLOBAL.STRINGS.ACTIONS.UNFOLLOW_CAPY = "Stop!"

AddComponentAction("SCENE", "inspectable", function(inst, doer, actions, right)
    if right and inst.prefab == "capybara" and inst:HasTag("following_leader") then
        table.insert(actions, GLOBAL.ACTIONS.UNFOLLOW_CAPY)
    end
end)

AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(GLOBAL.ACTIONS.UNFOLLOW_CAPY, "give"))
AddStategraphActionHandler("wilson_client", GLOBAL.ActionHandler(GLOBAL.ACTIONS.UNFOLLOW_CAPY, "give"))

local function CheckCapybara(world)
    if not world.state.issummer then
        for _, ent in pairs(GLOBAL.Ents) do
            if ent.prefab == "capybara" and not ent:HasTag("claimed") then
                ent:Remove()
            end
        end
        return
    end

    local count = 0
    for _, ent in pairs(GLOBAL.Ents) do
        if ent.prefab == "capybara" then
            count = count + 1
        end
    end

    if count == 0 then
        for _, ent in pairs(GLOBAL.Ents) do
            if ent.prefab == "oasislake" then
                local x, y, z = ent.Transform:GetWorldPosition()
                local offset = GLOBAL.FindWalkableOffset(GLOBAL.Vector3(x, y, z), math.random() * 2 * GLOBAL.PI, 4, 6)
                local capy = GLOBAL.SpawnPrefab("capybara")
                
                if offset then
                    capy.Transform:SetPosition(x + offset.x, y, z + offset.z)
                else
                    capy.Transform:SetPosition(x, y, z)
                end
                
                capy.components.knownlocations:RememberLocation("home", capy:GetPosition())
                break
            end
        end
    end
end

AddPrefabPostInit("world", function(inst)
    if not GLOBAL.TheWorld.ismastersim then return end
    
    inst:DoTaskInTime(5, CheckCapybara)
    inst:WatchWorldState("cycles", CheckCapybara)
    inst:WatchWorldState("issummer", CheckCapybara)
end)