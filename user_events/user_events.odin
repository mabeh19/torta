package user_events

import sdl "vendor:sdl2"

import "../serial"
import ev "../event"

openEvent := ev.new(bool, "Open Port")
sendEvent := ev.new([]u8, "Send Data")
settingsChanged := ev.new(serial.PortSettings, "Settings Changed")
refreshPortsEvent := ev.new("Refresh Ports")
clearEvent := ev.new("Clear Buffer")
startTrace := ev.new(string, "Start Trace")
stopTrace := ev.new("Stop Trace")
quitEvent := ev.new("Quit Application")
sendFile := ev.new(string, "Send File")
rawKeypressEvent := ev.new(sdl.KeyboardEvent, "Raw SDL Input")
