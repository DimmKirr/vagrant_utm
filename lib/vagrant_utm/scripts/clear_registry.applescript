---
-- clear_registry.applescript
-- Clears the shared folder registry for a VM.
-- This is needed after import because sandbox bookmarks don't transfer.
-- Usage: osascript clear_registry.applescript <VM_UUID>

on run argv
    set vmId to item 1 of argv

    tell application "UTM"
        set vm to virtual machine id vmId

        -- Clear the registry by setting it to an empty list
        update registry of vm with {}
    end tell

    return "Registry cleared for VM " & vmId
end run
