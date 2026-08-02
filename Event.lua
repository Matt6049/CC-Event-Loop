local arrayIncrement = 3;
local _arrayLen, _subNext, _onceNext, _isFiring = {}, {}, {}, {};
local _onceBuffer, _unsubBuffer = {}, {};
--CONVENTION:
--Partitioning (both incrementing up):
--          |       0           1             2      |
-- Array:   | 0: IndexToId, 1: Handler | 0: IdToIndex|

--IdToIndex points to column IndexToId. SubNext also points to IndexToId.
--IdToIndex and isAlive stay static and get their values changed.
--IndexToId and Handler get moved around.
--Yes, empty table keys are better than string keys. Apparently strings do not get cached and identity keys do.

local function clearUnsubQueue(self, unsubBuffer)
    local subTail = self[_subNext];
    for unsubId, _ in pairs(unsubBuffer) do
        subTail = subTail - arrayIncrement;
        local swapId = self[subTail];
        if(unsubId ~= swapId) then
            local index = self[unsubId];
            self[index+1] = self[subTail+1]; --swap subscribers
            self[unsubId] = subTail; self[swapId] = index;
            self[index] = swapId; self[subTail] = unsubId;  --their locations changed, so they point to diff ids now
        end
        self[subTail+1] = nil;
    end
    self[_subNext] = subTail;
end

local _realUnsub, _realOnce = {}, {};
local function lazyUnsub(self, unsubId)
    self[_unsubBuffer] = {};
    self.unsubscribe = self[_realUnsub];
    self[_realUnsub] = nil;
    return self:unsubscribe(unsubId);
end

local function lazyOnce(self, handler)
    self[_onceBuffer] = {};
    self.once = self[_realOnce];
    self[_realOnce] = nil;
    return self:once(handler);
end

---@class Event
local Event = {
    fire = function(self, ...)
        if(self[_isFiring]) then error("Attempted to recursively fire Event"); end
        self[_isFiring] = true;

        local onceBuffer = self[_onceBuffer];
        if(onceBuffer) then
            local onceTail = self[_onceNext]-1;
            self[_onceBuffer] = nil;
            self[_onceNext] = 1;
            self[_realOnce] = self.once;
            self.once = lazyOnce;
            for i=1, onceTail do
                onceBuffer[i](...);
            end
        end
        
        local subTail = self[_subNext]-arrayIncrement;
        for i=2, subTail, arrayIncrement do
            self[i](...);
        end
        self[_isFiring] = false;

        local unsubBuffer = self[_unsubBuffer];
        if(unsubBuffer) then
            self[_unsubBuffer] = nil;
            self[_realUnsub] = self.unsubscribe;
            self.unsubscribe = lazyUnsub;
            return clearUnsubQueue(self, unsubBuffer);
        end
    end,

    ---
    ---@param self any
    ---@param handler any
    ---@return number HandlerId
    subscribe = function(self, handler)
        if(type(handler) ~= "function") then error("Event:subscribe expected type: \"function\". Received: \""..type(handler).."\""); end
        local subIndex = self[_subNext]; local arrayLength = self[_arrayLen];
        local id;
        if(subIndex > arrayLength) then --init new row
            id = subIndex+2;
            self[subIndex] = id;
            self[id] = subIndex;
            self[_arrayLen] = arrayLength+arrayIncrement;
        else
            id = self[subIndex];
        end
        self[subIndex+1] = handler;

        self[_subNext] = subIndex+arrayIncrement;
        return id;
    end,

    ---Adds handler to the unsubscribe queue, deferring its removal until the next event fire.
    ---@param self Event
    ---@param unsubId integer Handle returned by the subscribe method. This is a key to the IdToIndex hashmap.
    unsubscribe = function(self, unsubId)
        local unsubs = self[_unsubBuffer];
        local index = self[unsubId];
        if(not unsubs[unsubId] and self[index+1]) then
            if(self[_isFiring]) then
                unsubs[unsubId] = true;
            else
                local subTail = self[_subNext]-arrayIncrement;
                self[_subNext] = subTail;

                local swapId = self[subTail];
                if(unsubId ~= swapId) then
                    self[index+1] = self[subTail+1]; --swap subscribers
                    self[unsubId] = subTail; self[swapId] = index;
                    self[index] = swapId; self[subTail] = unsubId;  --their locations changed, so they point to diff ids now
                end
                self[subTail+1] = nil;
            end
        end
    end,

    once = function(self, handler)
        if(type(handler) ~= "function") then error("Event:once expected type: \"function\". Received: \""..type(handler).."\""); end
        local onceIndex = self[_onceNext];
        self[_onceBuffer][onceIndex] = handler;
        self[_onceNext] = onceIndex+1;
    end,
}

local meta = {
    __index = Event, 
    __len = function(self) 
        local onceLen = self[_onceNext]-1;
        local subLen = (self[_subNext]-1)/arrayIncrement;
        return onceLen+subLen;
    end,
    __tostring = function (self)
        return self.name;
    end
};
---Creates a new Event instance.
---@return Event
function Event.new(name) 
    return setmetatable({
        name = name,
        once = lazyOnce,
        unsubscribe = lazyUnsub,
        [_arrayLen] = 0,
        [_subNext] = 1,
        [_isFiring] = false,
        [_onceNext] = 1,
    }, meta);
end

return Event;