require "Vehicles/TimedActions/ISOpenVehicleDoor"
require "Vehicles/TimedActions/ISExitVehicle"
require "Vehicles/TimedActions/ISCloseVehicleDoor"


local bodyPartSelectionWeight = {
    ["Hand_L"]=5,["Hand_R"]=5,["ForeArm_L"]=10,["ForeArm_R"]=10,
    ["UpperArm_L"]=15,["UpperArm_R"]=15,["Torso_Upper"]=15,["Torso_Lower"]=15,
    ["Head"]=1,["Neck"]=1,["Groin"]=2,["UpperLeg_L"]=15,["UpperLeg_R"]=15,
    ["LowerLeg_L"]=10,["LowerLeg_R"]=10,["Foot_L"]=5,["Foot_R"]=5
}
local bodyPartSelection = {}
for type,weight in pairs(bodyPartSelectionWeight) do
    for i=1, weight do
        --print("body parts: "..i.." - "..type)
        table.insert(bodyPartSelection,type)
    end
end


---@param player IsoPlayer|IsoGameCharacter
local function DamageFromTuckAndRoll(player, hitSeverity)

    local baseDamage = hitSeverity/2
    local iterations = (2 + baseDamage * 0.7)/2

    for i=0, iterations do

        local bpRandSelect = bodyPartSelection[ZombRand(#bodyPartSelection)+1]
        local bpType = BodyPartType.FromString(bpRandSelect)
        local bodyPart = player:getBodyDamage():getBodyPart(bpType)
        local damage = math.max(5, ZombRand(baseDamage-15, baseDamage))

        if player:HasTrait("FastHealer") then
            damage = damage*0.8
        elseif player:HasTrait("SlowHealer") then
            damage = damage*1.2
        end

        if SandboxVars.InjurySeverity == 1 then
            damage = damage*0.5
        elseif SandboxVars.InjurySeverity == 3 then
            damage = damage*1.5
        end

        damage=damage*0.9

        if damage > 10 and ZombRand(100)<=80 then
            bodyPart:setScratched(true, true)
            bodyPart:setScratchTime(bodyPart:getScratchTime()+ZombRand(1,3))
            if damage > 20 and ZombRand(100)<=75 then
                bodyPart:setBleedingTime(ZombRand(3,10))
            end

            local clothingBP = BloodBodyPartType.FromString(bpRandSelect)
            local protection = player:getBodyPartClothingDefense(BodyPartType.ToIndex(bpType), true, false)/100
            damage = damage * (1-(protection*0.9))
            player:addHole(clothingBP)
            player:addBlood(clothingBP, true, true, true)
        end

        bodyPart:AddDamage(damage)

        if damage > 15 and ZombRand(12)==0 then
            bodyPart:generateDeepWound()
        end

        if damage > 10 and ZombRand(100)<=damage then
            bodyPart:setFractureTime(ZombRand(ZombRand(10, damage+10),ZombRand(damage+20, damage+30)))
        end

        if damage > 30 and ZombRand(100)<=80 and bpRandSelect=="Head" then
            bodyPart:setFractureTime(ZombRand(ZombRand(10, damage+10),ZombRand(damage+20, damage+30)))
        end

        if damage > 10 and ZombRand(100)<=50 and bpRandSelect=="Groin" then
            bodyPart:setFractureTime(ZombRand(ZombRand(10, damage+20),ZombRand(damage+30, damage+40)))
        end
    end

    player:getBodyDamage():Update()
    player:addBlood(hitSeverity)
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
local function stumble(player, speedKmHour)
    local nimbleLvl = player:getPerkLevel(Perks.Nimble)
    local speed = math.abs(speedKmHour)

    if math.abs(nimbleLvl-speed) > 3 then
        nimbleLvl = nimbleLvl+3
        player:clearVariable("BumpFallType")
        player:setBumpType("stagger")
        player:setBumpDone(false)
        player:setBumpFall(nimbleLvl < speed)
        player:setBumpFallType("pushedBehind")

        if nimbleLvl < speed then
            print("nimbleLvl ("..nimbleLvl..") < speed ("..speed..")")
            DamageFromTuckAndRoll(player, speed-nimbleLvl)
        end
    end
end


local vehiclesRecentlyJumpedFrom = {}
local function forceVehiclePhysics()
    for vehicle,status in pairs(vehiclesRecentlyJumpedFrom) do
        if status == true then
            if math.abs(vehicle:getCurrentSpeedKmHour()) > 0.5 then
                vehicle:setPhysicsActive(true)
            else
                vehiclesRecentlyJumpedFrom[vehicle] = false
            end
        end
    end
end
Events.OnTick.Add(forceVehiclePhysics)


----Hard Overwrites to avoid checking if vehicle stopped or not
local keyPressers = {}
local function validateKeyPressTimes(player)
    if keyPressers[player] and #keyPressers[player]>0 then
        for key,timeStamp in pairs(keyPressers[player]) do
            if timeStamp+1500 < getTimestampMs() then
                keyPressers[player][key] = nil
            end
        end
    end
end
local function playerTriedExit(player)
    if not keyPressers[player] then
        keyPressers[player] = {}
    end
    table.insert(keyPressers[player], getTimestampMs())
end
Events.OnPlayerUpdate.Add(validateKeyPressTimes)


function ISExitVehicle:isValid()
    self.vehicle = self.character:getVehicle();
    if self.vehicle then
        if math.abs(self.vehicle:getCurrentSpeedKmHour()) > 3 and (not keyPressers[self.character] or #keyPressers[self.character]<4) then
            playerTriedExit(self.character)
            return false
        end
        return true
    end
    return false
end


function ISOpenVehicleDoor:isValid()
    if self.part and self.part:getDoor() and not self.part:getDoor():isOpen() then
        if (self.vehicle == self.character:getVehicle()) and math.abs(self.vehicle:getCurrentSpeedKmHour()) > 3 and (not keyPressers[self.character] or #keyPressers[self.character]<4) then
            return false
        end
        return true
    end
    return false
end

function ISCloseVehicleDoor:isValid() return self.part and self.part:getDoor() and self.part:getDoor():isOpen() end



---Safe Overwrite
local ISExitVehicle_perform = ISExitVehicle.perform
function ISExitVehicle:perform()
    local vehicle = self.character:getVehicle()
    ISExitVehicle_perform(self)
    vehiclesRecentlyJumpedFrom[vehicle] = true
    stumble(self.character, vehicle:getCurrentSpeedKmHour())
end
