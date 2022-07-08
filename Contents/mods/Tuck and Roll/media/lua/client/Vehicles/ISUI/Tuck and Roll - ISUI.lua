require "Vehicles/ISUI/ISVehicleMenu"

function ISVehicleMenu.onSwitchSeat(playerObj, seatTo)
    local vehicle = playerObj:getVehicle()
    if not vehicle then return end
    --if math.abs(vehicle:getCurrentSpeedKmHour()) > 0.8 and vehicle:isDriver(playerObj) then ISTimedActionQueue.add(ISStopVehicle:new(playerObj)) end
    ISTimedActionQueue.add(ISSwitchVehicleSeat:new(playerObj, seatTo))
end

function ISVehicleMenu.onExit(playerObj, seatFrom)
    local vehicle = playerObj:getVehicle()
    vehicle:updateHasExtendOffsetForExit(playerObj)
    if (not playerObj:isBlockMovement()) then
        if not vehicle then return end
        --if vehicle:isDriver(playerObj) then
        --	if math.abs(vehicle:getCurrentSpeedKmHour()) > 0.8 then ISTimedActionQueue.add(ISStopVehicle:new(playerObj)) end
        --else
        --	if not vehicle:isStopped() then
        --	playerObj:Say(getText("IGUI_PlayerText_CanNotExitFromMovingCar"))
        --		vehicle:updateHasExtendOffsetForExitEnd(playerObj)
        --		return
        --	end
        --end
        seatFrom = seatFrom or vehicle:getSeat(playerObj)
        if vehicle:isExitBlocked(playerObj, seatFrom) then
            local seatTo = ISVehicleMenu.getBestSwitchSeatExit(playerObj, vehicle, seatFrom)
            if seatTo then
                ISTimedActionQueue.add(ISSwitchVehicleSeat:new(playerObj, seatTo))
                ISVehicleMenu.onExitAux(playerObj, seatTo)
                return
            end
        else
            ISVehicleMenu.onExitAux(playerObj, seatFrom)
        end
    end
end