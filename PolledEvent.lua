local EventLoop = require("EventLoop");
local Event = require("Event");

local PolledEvent = {};

function PolledEvent:new(parent, poller)
    local weakRefs = setmetatable({parent, Event:new()}, {__mode='v'});
    local func = nil;
    func = function()
        if(#weakRefs < 2) then EventLoop.tick:unsubscribe(func);
        else poller(weakRefs[1], weakRefs[2]); end
    end
    EventLoop.tick:subscribe(func);
    return weakRefs[2];
end

return PolledEvent;