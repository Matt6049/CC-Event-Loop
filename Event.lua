local min = -math.pow(2, 52);
local _count = {};
local _maxId = {};

--CONVENTION:
--Handlers are stored in index-1. Their ID is stored in index.
--ID to Index mappings are stored at min+ID. This is a sparse array. 
--maxID is used to guarantee a unique ID for each handler for quick removal.
--Count includes handlers and their IDs. 

--Yes, empty table keys are better than string keys. No, I don't know why.
--This somehow manages a 5x performance improvement as compared to hashsets.
local Event = {
    fire = function(self, ...)
        for i=1, self[_count], 2 do
            self[i](...);
        end
    end,

    subscribe = function(self, handler)
        local count, maxId = self[_count]+2, self[_maxId]+1;
        self[_count], self[_maxId] = count, maxId;
        self[count-1], self[count] = handler, maxId;
        self[maxId] = count;
        return maxId;
    end,

    unsubscribe = function(self, id)
        local count = self[_count];
        local index = self[id];
        if(index ~= count) then
            local swapId = self[count];
            self[index-1], self[index] = self[count-1], self[count];
            self[swapId] = index;
        end
        self[count], self[count-1], self[id] = nil, nil, nil;
        self[_count] = count - 2;
    end
}

function Event:new()
    return setmetatable({
        [_maxId] = min,
        [_count] = 0
    }, {__index=Event});
end

return Event;