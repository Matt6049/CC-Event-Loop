local onceHead, idHead, unsubHead = -math.pow(2, 52), -math.pow(2, 51), -math.pow(2, 50);
local _idNext, _unsubNext, _onceNext, _onceHead = {}, {}, {}, {};
local _subNext, _isFiring = {}, {};

--CONVENTION:
--Partitioning (both incrementing up):
--Array:    | 0: IndexToId, 1: Handler |
--Hashsets: | 0: IdToIndex, 1: IsAlive | 0: ToUnsub | 0: Once |
--Yes, empty table keys are better than string keys. No, I don't know why.

--This Event implementation somehow manages a 5x performance improvement as compared to hashsets.

---@class Event
local Event = {
    fire = function(self, ...)
        if(self[_isFiring]) then error("Attempted to recursively fire Event"); end

        self[_isFiring] = true;
        local unsubCount = self[_unsubNext] - unsubHead;
        local onceHead = self[_onceHead]; local onceNext = self[_onceNext];

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

        self[_isFiring] = false;
    end,

    subscribe = function(self, handler)
        if(type(handler) ~= "function") then error("Event:subscribe expected type: \"function\". Received: \""..type(handler).."\""); end
        local subIndex = self[_subNext]; local id = self[_idNext];

        self[subIndex] = id; self[subIndex+1] = handler;
        self[id] = subIndex; self[id+1] = true;

        self[_subNext] = subIndex+2; self[_idNext] = id+2;
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
        local subTail = self[_subNext]; local unsubTail = self[_unsubNext]-1;
        local id, index, swapId;
        for i=unsubHead, unsubTail do
            subTail = subTail - 2;
            id = self[i];
            index = self[id];
            if(index ~= subTail) then
                swapId = self[subTail];
                self[index] = self[subTail]; self[index+1] = self[subTail+1];
                self[swapId] = index;
            end
            self[subTail] = nil; self[subTail+1] = nil; self[id] = nil; self[i] = nil;
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

local function readOnlyMetatable()
    error("Cannot modify Event metatable");
end
local meta = {__index = Event, __metatable = readOnlyMetatable};
---Creates a new Event instance.
---@return Event
function Event:new()
    return setmetatable({
        [_subNext] = 1,
        [_isFiring] = false,
        [_idNext] = idHead,
        [_unsubNext] = unsubHead,
        [_onceHead] = onceHead,
        [_onceNext] = onceHead,
    }, meta);
end

return Event;