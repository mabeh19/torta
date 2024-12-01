package process_events


import ev "../event"

dataReceivedEvent := ev.new([]u8, "Data Received")
lineReadEvent := ev.new("Line Read")
lineUnreadEvent := ev.new("Line Unread")
