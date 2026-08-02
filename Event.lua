local arrayIncrement = 3;
local _arrayLen, _subNext, _onceNext, _isFiring = 1, 2, 3, 4;
local _onceBuffer, _unsubBuffer = 5, 6;
--CONVENTION:
--Partitioning:
--          |       0           1             2      |
-- Array:   | 0: IndexToId, 1: Handler | 0: IdToIndex|

--IndexToId points to IdToIndex column and vice versa.
--Both get recycled for new subscribers upon unsubscription, their mappings change, however.
--Please spray me with water or something if I decide to try to refactor this again

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

local function lazyOnce(self, handler)
    self[_onceBuffer] = {};
    self.once = nil;
    return self:once(handler);
end

---High-performance synchronous event.
---@class Event
local Event = {
    ---Fires the event, calling every subscribed handler with the provided event args.
    ---@param self Event
    ---@param ... any Event args to pass to each handler.
    fire = function(self, ...)
        if(self[_isFiring]) then error("Attempted to recursively fire Event"); end
        self[_isFiring] = true;

        local onceBuffer = self[_onceBuffer];
        if(onceBuffer) then
            local onceTail = self[_onceNext]-1;
            self[_onceBuffer] = nil;
            self[_onceNext] = 1;
            self.once = lazyOnce;
            for i=1, onceTail do
                onceBuffer[i](...);
            end
        end
        
        local subTail = self[_subNext]-arrayIncrement+1;
        for i=8, subTail, arrayIncrement do
            self[i](...);
        end
        self[_isFiring] = false;

        local unsubBuffer = self[_unsubBuffer];
        if(unsubBuffer) then
            self[_unsubBuffer] = nil;
            return clearUnsubQueue(self, unsubBuffer);
        end
    end,

    ---Subscribes to the event, calling the provided event handler each time the event fires.
    ---@param self Event
    ---@param handler fun(...:any): nil Event handler.
    ---@return number Id Handler's unsubscription ID.
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

    ---Unsubscribes the event under the provided ID.
    ---Reusing the same ID with this method may lead to undefined behavior.
    ---@param self Event
    ---@param unsubId integer Handle returned by the subscribe method.
    unsubscribe = function(self, unsubId)
        local index = self[unsubId];
        if(index and self[index+1]) then
            if(self[_isFiring]) then
                local unsubs = self[_unsubBuffer];
                if(not unsubs) then unsubs = {}; self[_unsubBuffer] = unsubs; end
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

    ---Calls the provided handler upon the next time the event fires.
    ---@param self Event
    ---@param handler fun(...:any):nil Event handler.
    once = function(self, handler)
        if(type(handler) ~= "function") then error("Event:once expected type: \"function\". Received: \""..type(handler).."\""); end
        local onceIndex = self[_onceNext];
        self[_onceBuffer][onceIndex] = handler;
        self[_onceNext] = onceIndex+1;
    end,

    ---Unsubscribes every handler, allowing the event and its handlers to be collected.
    ---@param self Event
    destroy = function(self)
        for i=8, self[_subNext]+1-arrayIncrement, arrayIncrement do
            self[i] = nil;
        end
        self[_onceBuffer] = nil;
        self[_unsubBuffer] = nil;
    end
}

local meta = {
    __index = Event, 
    __len = function(self) 
        local onceLen = self[_onceNext]-1;
        local subLen = (self[_subNext]-1)/arrayIncrement;
        return onceLen+subLen-6;
    end,
    __tostring = function (self)
        return self.name;
    end
};
---Creates a new Event instance with the provided name.
---@return Event
function Event.new(name) 
    return setmetatable({
        name = name,
        once = lazyOnce,
        [_arrayLen] = 6,
        [_subNext] = 7,
        [_isFiring] = false,
        [_onceNext] = 1,
    }, meta);
end


---@param Event Event
local function tests(Event)
    local ev = Event.new("test");
    local testFunFired = false;
    local receivedArgs = false;
    local function testFun(...) testFunFired = true; receivedArgs = ...; end;

    local testSuite = {
        ---Tests event:subscribe for handler insertion.
        function()
            local id = assert(ev:subscribe(testFun), "Event subscription doesn't return ID");
            local index = assert(ev[id], "Event subscription doesn't create idToIndex mapping");
            assert(ev[index] == id, "Event subscription doesn't correctly create indexToId mapping");
            assert(ev[index+1] == testFun, "Event subscription doesn't correctly insert event handler");
        end,    
        ---Tests event:subscribe for ID incrementation and allocation of new memory
        function()
            local id = ev:subscribe(testFun);
            local id2 = ev:subscribe(function() end);
            assert(id~=id2, "ID not incremented for new subscribers");
        end,
        ---Tests event:once for buffer creation and insertion.
        function()
            ev:once(testFun);
            local buffer = assert(ev[_onceBuffer], "Once buffer not created for events");
            assert(buffer[1] == testFun, "Handler not inserted into event:once buffer");
        end,
        ---Tests event:fire and its arg passing to subscribers.
        function()
            local id = ev:subscribe(testFun);
            ev:fire(true);
            assert(testFunFired, "Event doesn't call subscribers upon firing");
            assert(receivedArgs, "Event handler doesn't receive event args");
        end,
        ---Tests event:fire for one-time subscribers, as well as buffer deletion afterwards
        function()
            ev:once(testFun);
            ev:fire(true);
            assert(testFunFired, "Event doesn't call event:once subscribers upon firing");
            assert(receivedArgs, "Event doesn't pass args to event:once subscribers upon firing");
            assert(not ev[_onceBuffer], "Event doesn't clean up event:once buffer after firing");
        end,
        ---Tests event:unsubscribe for handlers, seeing if they still evaluate despite that.
        function()
            local id = ev:subscribe(testFun);
            ev:unsubscribe(id);
            ev:fire();
            assert(not testFunFired, "Event doesn't unsubscribe handlers correctly");
        end,
        ---Tests event:unsubscribe swap and pop.
        function()
            local id = ev:subscribe(testFun);
            local fun2 = function() end;
            local id2 = ev:subscribe(fun2);
            local index = ev[id];
            local index2 = ev[id2];
            ev:unsubscribe(id);
            assert(index == ev[id2], "idToIndex mappings not swapped on unsubscribe");
            assert(ev[index] == id2, "indexToId mappings not swapped on unsubscribe");
            assert(not ev[index2+1], "Last handler not popped on unsubscribe");
        end,
        ---Tests event:unsubscribe subscriber list mutation prevention, and unsubscribe queue clearing.
        function()
            local id;
            ev:subscribe(function() ev:unsubscribe(id); end);
            id = ev:subscribe(testFun);
            ev:subscribe(function() 
                assert(ev[_unsubBuffer],
                "Event unsub buffer not correctly initialized when deferring unsubscribes") 
            end);
            ev:fire(true);
            assert(testFunFired, "event:subscribe during event:fire mutates the subscriber list");
            assert(not ev[_unsubBuffer], "Event does not clear the unsub queue after running deferred unsubscribes");
        end
    };
    for i, test in ipairs(testSuite) do
        ev = Event.new("test");
        testFunFired = false; receivedArgs = false;
        test();
    end
end
tests(Event);

return Event;