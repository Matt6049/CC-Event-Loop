local NativeEvents = require("GlobalEvents");
local Timer = require("Timer");

local EventLoop = {};

function EventLoop:pollCCEvents()
    local eventData = {};
    local eventName = "";
    while true do
        eventData = {os.pullEvent();}
        eventName = table.remove(eventData, 1);
        if(eventName == "timer") then break end;
        NativeEvents[eventName]:fire(table.unpack(eventData));
    end
    NativeEvents["tick"]:fire();
end

function EventLoop:tickTimers()
    local runningTimers = Timer.getRunning();
    local elapsedTimers = {};
    for timer, _ in pairs(runningTimers) do
        timer.timeRemaining = timer.timeRemaining-0.05;
        if(timer.timeRemaining <= 0) then
            timer.onElapsed:fire();
            if(not timer.looping) then
                elapsedTimers[#elapsedTimers+1] = timer;
            end
        end
    end

    for _, timer in ipairs(elapsedTimers) do
        runningTimers[timer] = nil;
    end
end

function EventLoop:sleep(seconds)
    error("unimplemented");
    seconds = seconds and math.ceil(seconds*20)/20 or 0.05;
    
end

function EventLoop:start()
    while(true) do
        os.startTimer(0.05);
        self:pollCCEvents();
        self:tickTimers();
    end
end

return EventLoop;