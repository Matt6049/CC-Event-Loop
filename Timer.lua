local Event = require("Event");
local RunningTimers = {}


local Timer = {
    interval = 0.05,
    timeRemaining = 0,
    looping = false,
    onElapsed = nil,

    start = function(self)
        self.timeRemaining = self.interval;
        RunningTimers[self] = true;
    end,

    cancel = function(self)
        self.timeRemaining = 0;
        RunningTimers[self] = nil;
    end,

    getRunning = function()
        return RunningTimers;
    end
}

function Timer:new(props)
    local instance = setmetatable(props or {}, {
        __index = Timer
    });
    instance.onElapsed = Event:new();
    instance.onElapsed:subscribe(function()
        RunningTimers[instance] = nil
    end);
    return instance;
end

return Timer;