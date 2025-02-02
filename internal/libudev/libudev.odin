package udev

import "core:c"
import "core:sys/linux"


UDev :: distinct rawptr
UDevDevice :: distinct rawptr
UDevEnumerate :: distinct rawptr
UDevMonitor :: distinct rawptr
UDevListEntry :: distinct rawptr

foreign {
    // Udev
    udev_new :: proc "c" () -> UDev ---
    udev_ref :: proc "c" (udev: UDev) -> UDev ---
    udev_unref :: proc "c" (udev: UDev) -> UDev ---

    // Udev device
    udev_device_new_from_syspath :: proc "c" (udev: UDev, syspath: cstring) -> UDevDevice ---
    udev_device_new_from_devnum :: proc "c" (udev: UDev, type: c.char, devnum: linux.Dev) -> UDevDevice ---
    udev_device_new_from_subsystem_sysname :: proc "c" (udev: UDev, subsystem: cstring, sysname: cstring) -> UDevDevice ---
    udev_device_new_from_device_id :: proc "c" (udev: UDev, id: cstring) -> UDevDevice ---
    udev_device_from_environment :: proc "c" (udev: UDev) -> UDevDevice ---
    udev_device_ref :: proc "c" (udev_device: UDevDevice) -> UDevDevice ---
    udev_device_unref :: proc "c" (udev_device: UDevDevice) -> UDevDevice ---


    // Udev enumerate
    udev_enumerate_new :: proc "c" (udev: UDev) -> UDevEnumerate ---
    udev_enumerate_ref :: proc "c" (udev_enumerate: UDevEnumerate) -> UDevEnumerate ---
    udev_enumerate_unref :: proc "c" (udev_enumerate: UDevEnumerate) -> UDevEnumerate ---

    // Udev monitor
    udev_monitor_new_from_netlink :: proc "c" (udev: UDev, name: cstring) -> UDevMonitor ---
    udev_monitor_ref :: proc "c" (udev_monitor: UDevMonitor) -> UDevMonitor ---
    udev_monitor_unref :: proc "c" (udev_monitor: UDevMonitor) -> UDevMonitor ---

    // Udev list entry
    udev_list_entry_get_next :: proc "c" (list_entry: UDevListEntry) -> UDevListEntry ---
    udev_list_entry_get_by_name :: proc "c" (list_entry: UDevListEntry, name: cstring) -> UDevListEntry ---
    udev_list_entry_get_name :: proc "c" (list_entry: UDevListEntry) -> cstring ---
    udev_list_entry_get_value :: proc "c" (list_entry: UDevListEntry) -> cstring ---

    // Udev device attributes
    udev_device_has_tag :: proc "c" (udev_device: UDevDevice, tag: cstring) -> c.int ---
    udev_device_has_current_tag :: proc "c" (udev_device: UDevDevice, tag: cstring) -> c.int ---
    udev_device_get_devlinks_list_entry :: proc "c" (udev_device: UDevDevice) -> UDevListEntry ---
    udev_device_get_properties_list_entry :: proc "c" (udev_device: UDevDevice) -> UDevListEntry ---
    udev_device_get_tags_list_entry :: proc "c" (udev_device: UDevDevice) -> UDevListEntry ---
    udev_device_get_current_tags_list_entry :: proc "c" (udev_device: UDevDevice) -> UDevListEntry ---
    udev_device_get_sysattr_list_entry :: proc "c" (udev_device: UDevDevice) -> UDevListEntry ---
    udev_device_get_sysattr_value :: proc "c" (udev_device: UDevDevice, sysattr: cstring) -> cstring ---
    udev_device_get_property_value :: proc "c" (udev_device: UDevDevice, key: cstring) -> cstring ---
    udev_device_set_sysattr_value :: proc "c" (udev_device: UDevDevice, sysattr: cstring, value: cstring) -> c.int ---
}
