local min = -math.pow(2, 52);
local max = 2*(math.pow(2, 51)-1)+1;
local _subCount = {};
local _unsubCount = {};

local _maxId = {};
local _fireQueueLen = {};
local _onceHead = {};
local _onceTail = {};

--CONVENTION:
--Handlers are stored in index-1. Their ID is stored in index.
--ID to Index mappings are stored at min+ID. This is a sparse array. 
--maxID is used to guarantee a unique ID for each handler for quick removal.
--Count includes handlers and their IDs. 
--Unsub queue starts at -1 and counts down.

--Yes, empty table keys are better than string keys. No, I don't know why.
--This somehow manages a 5x performance improvement as compared to hashsets.

---@class Event
local Event = {
    fire = function(self, ...)
        local fireQueueLen = self[_fireQueueLen] + 1;
        self[_fireQueueLen] = fireQueueLen;

        if(fireQueueLen > 1) then return; end


        while fireQueueLen > 0 do
            local unsubCount = self[_unsubCount];
            local onceHead, onceTail = self[_onceHead], self[_onceTail];

            if(unsubCount > 0) then
                self:clearUnsubQueue(unsubCount);
            end

            for i=onceTail, onceHead do
                self[i](...);
                self[i] = nil;
            end
            self[_onceHead] = onceTail-1;

            for i=self[_subCount]-1, 1, -2 do
                self[i](...);
            end

            fireQueueLen = self[_fireQueueLen] - 1;
            self[_fireQueueLen] = fireQueueLen;
        end
    end,

    subscribe = function(self, handler)
        local subCount, maxId = self[_subCount]+2, self[_maxId]+2;
        self[_subCount] = subCount;
        self[_maxId], self[_maxId-1] = maxId, true;

        self[subCount-1], self[subCount] = handler, maxId;
        self[maxId] = subCount;
        return maxId;
    end,

    ---Adds handler to the unsubscribe queue, deferring its removal until the next event fire.
    ---@param self Event
    ---@param id integer Handle returned by the subscribe method. This is a key to the IdToIndex hashmap.
    unsubscribe = function(self, id)
        local alive = self[id-1];
        if(alive) then
            self[id-1] = nil;
            local unsubCount = self[_unsubCount];
            self[_unsubCount] = unsubCount + 1;
            self[0-unsubCount-1] = id;
        end
    end,

    ---Clears the unsubscribe queue.
    ---@param self any
    ---@param unsubCount any
    clearUnsubQueue = function(self, unsubCount)
        local subCount = self[_subCount];
        local id, index, swapId = nil, nil, nil;
        for i=-1, -unsubCount, -1 do
            id = self[i];
            index = self[id];
            if(index ~= subCount) then
                swapId = self[subCount];
                self[index-1], self[index] = self[subCount-1], self[subCount];
                self[swapId] = index;
            end
            self[subCount], self[subCount-1], self[id] = nil, nil, nil;
            subCount = subCount - 2;
        end
        self[_subCount] = subCount;
        self[_unsubCount] = 0;
    end,

    once = function(self, handler)
        local onceTail = self[_onceTail]-1;
        self[onceTail] = handler;
        self[_onceTail] = onceTail-1;
    end
}

function Event:new()
    return setmetatable({
        [_maxId] = min,
        [_subCount] = 0,
        [_unsubCount] = 0,
        [_fireQueueLen] = 0,
        [_onceHead] = max-1,
        [_onceTail] = max,
    }, {__index=Event});
end

return Event;