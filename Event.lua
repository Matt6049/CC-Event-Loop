local Event = {
    subscribers = {},

    fire = function(self, ...) 
        for handler, _ in pairs(self.subscribers) do
            handler(...);
        end
    end,

    subscribe = function(self, handler) 
        self.subscribers[handler] = true;
    end,

    unsubscribe = function(self, handler) 
        self.subscribers[handler] = nil;
    end
}

function Event:new()
    local instance = setmetatable({
        subscribers = {}
    }, {
        __index = Event
    });

    return instance;
end


return Event;