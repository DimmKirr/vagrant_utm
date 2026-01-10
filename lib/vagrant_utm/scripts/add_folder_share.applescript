---
-- add_directory_share.applescript
-- This script adds directory sharing in UTM for both QEMU (9pfs) and Apple Virtualization (VirtioFS).
-- Backend is auto-detected from VM properties.
-- Usage: osascript add_directory_share.applescript UUID --id <ID> --dir <DIR> [--id <ID2> --dir <DIR2> ...]
-- Example: osascript add_directory_share.applescript UUID --id vagrant --dir "/path/to/dir"
-- Note: For Apple Virtualization, dirs auto-mount at /Volumes/My Shared Files/

-- Function to create QEMU arguments for directory sharing (9pfs)
on createQemuArgsForDir(dirId, dirPath)
    -- Prepare the QEMU argument strings
    set fsdevArgStr to "-fsdev local,id=" & dirId & ",path=" & dirPath & ",security_model=mapped-xattr"
    set deviceArgStr to "-device virtio-9p-pci,fsdev=" & dirId & ",mount_tag=" & dirId
    return {fsdevArgStr, deviceArgStr}
end createQemuArgsForDir

-- Main script
on run argv
    -- VM id is assumed to be the first argument
    set vmId to item 1 of argv

    -- Initialize variables
    set idList to {}
    set dirList to {}
    set idFlag to false
    set dirFlag to false

    -- Parse arguments
    repeat with i from 2 to (count of argv)
        set currentArg to item i of argv
        if currentArg is "--id" then
            set idFlag to true
            set dirFlag to false
        else if currentArg is "--dir" then
            set dirFlag to true
            set idFlag to false
        else if idFlag then
            set end of idList to currentArg
            set idFlag to false
        else if dirFlag then
            set end of dirList to currentArg
            set dirFlag to false
        end if
    end repeat

    -- Initialize the directory list (used for registry update - both backends)
    set directoryList to {}
    repeat with i from 1 to (count of dirList)
        set dirPath to item i of dirList
        set dirURL to POSIX file dirPath
        set end of directoryList to dirURL
    end repeat

    tell application "UTM"
        set vm to virtual machine id vmId

        -- Read backend type from VM (qemu or apple)
        set vmBackend to backend of vm

        if vmBackend is qemu then
            -- QEMU backend: add 9pfs arguments to config
            set config to configuration of vm
            set qemuAddArgs to qemu additional arguments of config

            repeat with i from 1 to (count of dirList)
                set dirPath to item i of dirList
                set dirId to item i of idList
                set {fsdevArgStr, deviceArgStr} to my createQemuArgsForDir(dirId, dirPath)
                set end of qemuAddArgs to {argument string:fsdevArgStr}
                set end of qemuAddArgs to {argument string:deviceArgStr}
            end repeat

            set qemu additional arguments of config to qemuAddArgs
            update configuration of vm with config
        end if
        -- For Apple Virtualization, no config changes needed - registry update handles VirtioFS

        -- Get current registry paths (to avoid overwriting valid sandbox bookmarks)
        set reg to registry of vm
        set existingPaths to {}
        repeat with r in reg
            set end of existingPaths to (POSIX path of r)
        end repeat

        -- Only add directories that are not already in the registry
        set newDirs to {}
        repeat with i from 1 to (count of directoryList)
            set dirURL to item i of directoryList
            set dirPosixPath to POSIX path of dirURL
            if existingPaths does not contain dirPosixPath then
                set end of newDirs to dirURL
            end if
        end repeat

        -- Update registry only if there are new directories to add
        if (count of newDirs) > 0 then
            set reg to reg & newDirs
            update registry of vm with reg
        end if
    end tell
end run