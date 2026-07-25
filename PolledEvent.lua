local EventLoop = require("EventLoop");
local Event = require("Event");

local PolledEvent = {};

function PolledEvent:new(parent, poller)
    local weakRefs = setmetatable({parent, Event:new()}, {__mode='v'});
    local func = nil;
    func = function()
        if(weakRefs[1] and weakRefs[2]) then poller(weakRefs[1], weakRefs[2]);
        else EventLoop.tick:unsubscribe(func); end
    end
    EventLoop.tick:subscribe(func);
    return weakRefs[2];
end

return PolledEvent;