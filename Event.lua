
local idHead, unsubHead, onceHead = -math.pow(2, 52), -math.pow(2, 51), -math.pow(2, 50);
local _idNext, _unsubNext, _onceNext, _onceHead = {}, {}, {}, {};
local _subNext, _queuedFireCount = {}, {};

--CONVENTION:
--Partitioning (both incrementing up):
--Array:    | 0: IndexToId, 1: Handler |
--Hashsets: | 0: IdToIndex, 1: IsAlive | 0: ToUnsub | 0: Once |
--Yes, empty table keys are better than string keys. No, I don't know why.

--This Event implementation somehow manages a 5x performance improvement as compared to hashsets.
---@class Event
local Event = {
    fire = function(self, ...)
        local queuedFireCount = self[_queuedFireCount] + 1;
        self[_queuedFireCount] = queuedFireCount;

        if(queuedFireCount > 1) then return; end


        while queuedFireCount > 0 do
            local unsubCount = self[_unsubNext] - unsubHead;
            local onceHead, onceNext = self[_onceHead], self[_onceNext];

            if(unsubCount > 0) then
                self:clearUnsubQueue();
            end

            for i=onceHead, onceNext-1 do
                self[i](...);
                self[i] = nil;
            end
            self[_onceHead] = onceNext;

            for i=2, self[_subNext]-1, 2 do
                self[i](...);
            end

            queuedFireCount = self[_queuedFireCount] - 1;
            self[_queuedFireCount] = queuedFireCount;
        end
    end,

    subscribe = function(self, handler)
        if(type(handler) ~= "function") then error("Event:subscribe expected type: \"function\". Received: \""..type(handler).."\""); end
        local subIndex, id = self[_subNext], self[_idNext];

        self[subIndex], self[subIndex+1] = id, handler;
        self[id], self[id+1] = subIndex, true;

        self[_subNext], self[_idNext] = subIndex+2, id+2;
        return id;
    end,

    ---Adds handler to the unsubscribe queue, deferring its removal until the next event fire.
    ---@param self Event
    ---@param id integer Handle returned by the subscribe method. This is a key to the IdToIndex hashmap.
    unsubscribe = function(self, id)
        local alive = self[id+1];
        if(alive) then
            self[id+1] = nil;
            local unsubIndex = self[_unsubNext];
            self[unsubIndex] = id;

            self[_unsubNext] = unsubIndex + 1;
        end
    end,

    clearUnsubQueue = function(self)
        local subTail, unsubTail = self[_subNext], self[_unsubNext]-1;
        local id, index, swapId;
        for i=unsubHead, unsubTail do
            subTail = subTail - 2;
            id = self[i];
            index = self[id];
            if(index ~= subTail) then
                swapId = self[subTail];
                self[index], self[index+1] = self[subTail], self[subTail+1];
                self[swapId] = index;
            end
            self[subTail], self[subTail+1], self[id], self[i] = nil, nil, nil, nil;
        end
        self[_subNext] = subTail;
        self[_unsubNext] = unsubHead;
    end,

    once = function(self, handler)
        if(type(handler) ~= "function") then error("Event:once expected type: \"function\". Received: \""..type(handler).."\""); end
        local onceIndex = self[_onceNext];
        self[onceIndex] = handler;
        self[_onceNext] = onceIndex+1;
    end
}

function Event:new()
    return setmetatable({
        [_subNext] = 1,
        [_queuedFireCount] = 0,
        [_idNext] = idHead,
        [_unsubNext] = unsubHead,
        [_onceHead] = onceHead,
        [_onceNext] = onceHead,
    }, {__index=Event});
end

return Event;