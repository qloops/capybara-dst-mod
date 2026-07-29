require("stategraphs/commonstates")

local EAT_COOLDOWN = 16

local actionhandlers = {
    _G.ActionHandler(_G.ACTIONS.EAT, "eat"),
    _G.ActionHandler(_G.ACTIONS.PICK, "eat"),
}

local events = {
    _G.CommonHandlers.OnStep(),
    _G.CommonHandlers.OnSleep(),
    _G.EventHandler("wake", function(inst)
        inst.sg:GoToState("wake")
    end),
    
    _G.EventHandler("locomote", function(inst)
        if inst.sg:HasStateTag("busy") then return end

        local is_moving = inst.sg:HasStateTag("moving")
        local is_running = inst.sg:HasStateTag("running")
        local is_idle = inst.sg:HasStateTag("idle")
        
        local should_move = inst.components.locomotor:WantsToMoveForward()
        local should_run = inst.components.locomotor:WantsToRun()

        if is_moving and not should_move then
            inst.sg:GoToState("idle")
        elseif (is_moving and is_running ~= should_run) or (not is_moving and should_move) then
            if should_run then
                inst.sg:GoToState("run")
            else
                inst.sg:GoToState("walk")
            end
        end
    end),
}

local states = {
    _G.State{
        name = "idle",
        tags = { "idle", "canrotate" },
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("idle_loop", true)
        end,
    },

    _G.State{
        name = "walk",
        tags = { "moving", "canrotate" },
        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            inst.AnimState:SetDeltaTimeMultiplier(1)
            inst.AnimState:PlayAnimation("walk_loop", true)
        end,
    },

    _G.State{
        name = "run",
        tags = { "moving", "running", "canrotate" },
        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:SetDeltaTimeMultiplier(2)
            inst.AnimState:PlayAnimation("walk_loop", true)
        end,
        onexit = function(inst)
            inst.AnimState:SetDeltaTimeMultiplier(1)
        end,
    },

    _G.State{
        name = "eat",
        tags = { "busy" },
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("eat_loop", true)
            inst.SoundEmitter:PlaySound("dontstarve/beefalo/chew")
            inst.sg:SetTimeout(2)
        end,
        ontimeout = function(inst)
            local action = inst:GetBufferedAction()
            if action ~= nil and action.target ~= nil and action.target:IsValid() then
                if action.target.prefab == "grass" and action.target.components.pickable ~= nil then
                    action.target.components.pickable:MakeEmpty()
                    inst:ClearBufferedAction()
                elseif action.target.prefab == "cutgrass" then
                    action.target:Remove()
                    inst:ClearBufferedAction()
                else
                    inst:PerformBufferedAction()
                end
            else
                inst:PerformBufferedAction()
            end
            
            if inst.components.timer ~= nil then
                if inst.components.timer:TimerExists("eat_cooldown") then
                    inst.components.timer:SetTimeLeft("eat_cooldown", EAT_COOLDOWN)
                else
                    inst.components.timer:StartTimer("eat_cooldown", EAT_COOLDOWN)
                end
            end
            
            inst.sg:GoToState("idle")
        end,
    },

    _G.State{
        name = "wake",
        tags = { "busy", "waking" },
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("sleep_pst")
        end,
        events = {
            _G.EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
}

_G.CommonStates.AddSleepStates(states, {
    start_timeline = nil,
    sleep_timeline = nil,
    end_timeline = nil,
}, {
    onsleep = function(inst) inst.AnimState:PlayAnimation("sleep_pre") end,
    onloop = function(inst) inst.AnimState:PlayAnimation("sleep_loop", true) end,
    onwake = function(inst) inst.AnimState:PlayAnimation("sleep_pst") end,
})

return _G.StateGraph("capybara", states, events, "idle", actionhandlers)