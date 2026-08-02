local min, arrayIncrement, hashIncrement = -math.pow(2, 31), 4, 3;
local onceBase, unsubBase = min+0, min+2;
local _arrayLen, _subNext, _onceNext, _onceBufferUsed, _unsubNext, _isFiring = {}, {}, {}, {}, {}, {};

--CONVENTION:
--Partitioning (both incrementing up):
--          |       0           1             2              3      |
-- Array:   | 0: IndexToId, 1: Handler | 0: IdToIndex,  1: isAlive  | 
-- -2^31:   | 0: Once1,     1: Once2   | 0: UnsubQueue |

--IdToIndex points to column IndexToId. SubNext also points to IndexToId.
--IdToIndex and isAlive stay static and get their values changed.
--IndexToId and Handler get moved around.
--Yes, empty table keys are better than string keys. No, I don't know why.

--This Event implementation manages a 5x performance improvement as compared to hashsets.

local function clearUnsubQueue(self)
    local subTail = self[_subNext]-arrayIncrement; local unsubTail = self[_unsubNext]-hashIncrement;
    for unsub=unsubBase, unsubTail, hashIncrement do
        local unsubId = self[unsub]; self[unsub] = nil;
        local swapId = self[subTail];
        if(unsubId ~= swapId) then
            local index = self[unsubId];
            self[index+1] = self[subTail+1]; --swap subscribers
            self[unsubId] = subTail; self[swapId] = index;
            self[index] = swapId; self[subTail] = unsubId;  --their locations changed, so they point to diff ids now
        end
        self[subTail+1] = nil;
        subTail = subTail - arrayIncrement;
    end
    self[_subNext] = subTail;
    self[_unsubNext] = unsubBase;
end

---@class Event
local Event = {
    fire = function(self, ...)
        if(self[_isFiring]) then error("Attempted to recursively fire Event"); end
        self[_isFiring] = true;

        local onceTail = self[_onceNext]-hashIncrement;
        if(onceTail > min) then
            local bufferUsed = self[_onceBufferUsed];
            self[_onceBufferUsed] = 1-bufferUsed; --switch until the next fire so we don't overwrite unhandled ones
            self[_onceNext] = onceBase + 1-bufferUsed;

            for i=onceBase, onceTail, hashIncrement do
                self[i](...);
                self[i] = nil;
            end
        end
        
        local subTail = self[_subNext]-arrayIncrement;
        for i=2, subTail, arrayIncrement do
            self[i](...);
        end
        self[_isFiring] = false;


        local unsubCount = self[_unsubNext] - unsubBase;
        if(unsubCount > 0) then
            return clearUnsubQueue(self);
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
        self[subIndex+1] = handler; self[id+1] = true;

        self[_subNext] = subIndex+arrayIncrement;
        return id;
    end,

    ---Adds handler to the unsubscribe queue, deferring its removal until the next event fire.
    ---@param self Event
    ---@param unsubId integer Handle returned by the subscribe method. This is a key to the IdToIndex hashmap.
    unsubscribe = function(self, unsubId)
        local alive = self[unsubId+1];
        if(alive) then
            self[unsubId+1] = false;
            if(self[_isFiring]) then
                local unsubIndex = self[_unsubNext];
                self[unsubIndex] = unsubId;
                self[_unsubNext] = unsubIndex + hashIncrement;
            else
                local subTail = self[_subNext]-arrayIncrement;
                self[_subNext] = subTail;

                local swapId = self[subTail];
                if(unsubId ~= swapId) then
                    local index = self[unsubId];
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
        self[onceIndex] = handler;
        self[_onceNext] = onceIndex+hashIncrement;
    end,
}

local meta = {
    __index = Event, 
    __len = function(self) 
        local onceLen = (self[_onceNext]-onceBase-self[_onceBufferUsed])/hashIncrement;
        local subLen = (self[_subNext]-2)/arrayIncrement;
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
        [_arrayLen] = 0,
        [_subNext] = 1,
        [_isFiring] = false,
        [_unsubNext] = unsubBase,
        [_onceNext] = onceBase,
        [_onceBufferUsed] = 0
    }, meta);
end

return Event;