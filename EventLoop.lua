local Event = require("CustomEvents");
local Timer = require("Timer");

local EventLoop = {
    alarm = Event:new(),
    char = Event:new(),
    computer_command = Event:new(),
    disk = Event:new(),
    disk_eject = Event:new(),
    file_transfer = Event:new(),
    http_check = Event:new(),
    http_failure = Event:new(),
    http_success = Event:new(),
    key = Event:new(),
    key_up = Event:new(),
    modem_message = Event:new(),
    monitor_resize = Event:new(),
    monitor_touch = Event:new(),
    mouse_click = Event:new(),
    mouse_drag = Event:new(),
    mouse_scroll = Event:new(),
    mouse_up = Event:new(),
    paste = Event:new(),
    peripheral = Event:new(),
    peripheral_detach = Event:new(),
    rednet_message = Event:new(),
    redstone = Event:new(),
    setting_changed = Event:new(),
    speaker_audio_empty = Event:new(),
    task_complete = Event:new(),
    term_resize = Event:new(),
    terminate = Event:new(),
    tick = Event:new(),
    turtle_inventory = Event:new(),
    websocket_closed = Event:new(),
    websocket_failure = Event:new(),
    websocket_message = Event:new(),
    websocket_success = Event:new(),
}

function EventLoop:pollCCEvents()
    local eventData = {};
    local eventName = "";
    while true do
        eventData = {os.pullEvent();}
        eventName = table.remove(eventData, 1);
        if(eventName == "timer") then break end;
        self[eventName]:fire(table.unpack(eventData));
    end
    self["tick"]:fire();
end

function EventLoop:tickTimers()
    local runningTimers = Timer.getRunning();
    local elapsedTimers = {};
    for timer, _ in pairs(runningTimers) do
        timer.timeRemaining = timer.timeRemaining-0.05;
        if(timer.timeRemaining <= 0) then
            timer.onElapsed:fire();
            if(not timer.looping) then
                elapsedTimers[#elapsedTimers+1] = timer;
            end
        end
    end

    for _, timer in ipairs(elapsedTimers) do
        runningTimers[timer] = nil;
    end
end

function EventLoop:sleep(seconds)
    seconds = seconds and math.ceil(seconds*20)/20 or 0.05;
    
end

function EventLoop:start()
    while(true) do
        os.startTimer(0.05);
        self:pollCCEvents();
        self:tickTimers();
    end
end

return EventLoop;