local NativeEvents = require("NativeEvents");
local Event = require("Event");

local _type = {};
local _subscribedEvents, _subscribedTables, _unsubscribed = {}, {}, {};
local _pollHandler, _indexNext = {}, {};

local function unwrap(event)
    event.once = nil;
    event.subscribe = nil;
    local type = event[_type];
    local unsubscribed = type[_unsubscribed];
    local parent = unsubscribed[event];
    unsubscribed[event] = nil;

    local events, tables = type[_subscribedEvents], type[_subscribedTables];
    local index = type[_indexNext];
    type[_indexNext] = index + 1;
    events[index] = event;
    tables[index] = parent;
end

local function onceWrapper(event, handler)
    unwrap(event);
    event:once(handler);
end

local function subscribeWrapper(event, handler)
    unwrap(event);
    event:subscribe(handler);
end

---@class PolledEventType
---@field triggerEvent Event Event that triggers a poll.
---@field pollPredicate fun(event, weakTable) Predicate that should fire the event if its parent meets the conditions.
local PolledEventType = {
    newEvent = function(self, parent)
        local event = Event.new();
        self[_unsubscribed][event] = parent;
        event[_type] = self;
        event.subscribe = subscribeWrapper;
        event.once = onceWrapper;
        return event;
    end,
};

---Creates a poll handler closure that will 
---@param self PolledEventType
---@return function 
local function getPollHandler(self)
    return function()
        local pollPredicate = self.pollPredicate;
        local i = 1;
        local len = self[_indexNext]-1;

        local events = self[_subscribedEvents];
        local tables = self[_subscribedTables];
        local event = events[i];
        local parent = tables[i];
        while event do
            if(parent) then
                pollPredicate(event, parent);
                i = i+1;
                event = events[i]; parent = tables[i];
            else
                --todo: event destroy here potentially
                if(i ~= len) then
                    event = events[len]; parent = tables[len];
                    events[i] = event; tables[i] = parent;
                else
                    event = nil;
                end
                events[len] = nil; tables[len] = nil;
                len = len-1;
            end
        end
        self.triggerEvent:once(self[_pollHandler]);
    end
end

---Wraps PolledEventType:newEvent to only start polling when it creates its first event.
---@param self PolledEventType
---@param parent table 
local function newEventWrapper(self, parent)
    self.newEvent = nil;
    local pollHandler = getPollHandler(self);
    self[_pollHandler] = pollHandler;
    self.triggerEvent:once(pollHandler);

    self:newEvent(parent);
end

local meta = {__index = PolledEventType};
local weakTable = {__mode='kv'};
local weakVal = {__mode='v'};
---Creates a new polled event type.
---@param triggerEvent Event Event that triggers a poll.
---@param pollPredicate fun(event, parent) Predicate that should fire the event if its parent meets the conditions.
---@return PolledEventType
function PolledEventType.new(pollPredicate, triggerEvent)
    local instance = setmetatable({
        [_subscribedEvents] = {},
        [_subscribedTables] = setmetatable({}, weakVal),
        [_unsubscribed] = setmetatable({}, weakTable),
        [_indexNext] = 1,
        triggerEvent = triggerEvent or NativeEvents.tick,
        pollPredicate = pollPredicate,
        newEvent = newEventWrapper
    }, meta);
    return instance;
end

return PolledEventType;