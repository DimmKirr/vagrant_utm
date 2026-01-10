# frozen_string_literal: true

require File.expand_path("version_4_5", __dir__)

module VagrantPlugins
  module Utm
    module Driver
      # Driver for UTM 4.6.x
      class Version_4_6 < Version_4_5 # rubocop:disable Naming/ClassAndModuleCamelCase
        def initialize(uuid)
          super

          @logger = Log4r::Logger.new("vagrant::provider::utm::version_4_6")
        end

        # Implement clear_shared_folders
        def clear_shared_folders
          # Get the list of shared folders (returns empty for Apple Virtualization)
          shared_folders = read_shared_folders
          return if shared_folders.nil? || shared_folders.empty?

          # QEMU only: Get the args to remove the shared folders
          script_path = @script_path.join("read_shared_folders_args.js")
          cmd = ["osascript", "-l", "JavaScript", script_path.to_s, @uuid, "--ids", shared_folders.join(",")]
          output = execute_shell(*cmd)
          result = JSON.parse(output)
          return unless result["status"]

          # Flatten the list of args and build the command
          sf_args = result["result"].flatten
          return unless sf_args.any?

          command = ["remove_qemu_additional_args.applescript", @uuid, "--args", *sf_args]
          execute_osa_script(command)
        end

        def import(utm)
          utm = Vagrant::Util::Platform.windows_path(utm)

          vm_id = nil

          command = ["import_vm.applescript", utm]
          output = execute_osa_script(command)

          @logger.debug("Import output: #{output}")

          # Check if we got the VM ID
          if output =~ /virtual machine id ([A-F0-9-]+)/
            vm_id = ::Regexp.last_match(1) # Capture the VM ID

            # Clear registry after import - security-scoped bookmarks from base box
            # are invalid after import, causing "Cannot access resource" errors.
            # User will be prompted to add shared folders via UTM GUI.
            clear_registry(vm_id)
          end

          vm_id
        end

        # Clears the shared folder registry for a VM
        def clear_registry(vm_id)
          @logger.debug("Clearing registry for VM #{vm_id}")
          command = ["clear_registry.applescript", vm_id]
          execute_osa_script(command)
        rescue StandardError => e
          @logger.warn("Failed to clear registry: #{e.message}")
        end

        def export(path)
          @logger.debug("Exporting UTM file to: #{path}")
          command = ["export_vm.applescript", @uuid, path]
          execute_osa_script(command)
        end

        def read_shared_folders
          @logger.debug("Reading shared folders")
          result = read_shared_folders_info

          # For Apple Virtualization VMs, reading QEMU args fails
          # Return empty array in that case
          return [] unless result && result["status"]

          # Return the list of shared folders names(id)
          result["result"]
        end

        # Returns full shared folders info including backend type
        def read_shared_folders_info
          script_path = @script_path.join("read_shared_folders.js")
          cmd = ["osascript", "-l", "JavaScript", script_path.to_s, @uuid]
          output = execute_shell(*cmd)
          JSON.parse(output)
        rescue StandardError
          nil
        end

        def share_folders(folders)
          @logger.debug("Sharing folders: #{folders}")

          # AppleScript auto-detects backend (QEMU vs Apple Virtualization)
          folders.each do |folder|
            args = ["--id", folder[:name], "--dir", folder[:hostpath]]
            command = ["add_folder_share.applescript", @uuid, *args]
            execute_osa_script(command)
          end
        end

        def unshare_folders(folders)
          @logger.debug("Unsharing folders: #{folders}")

          # QEMU only: Get the args to remove the shared folders
          # For Apple Virtualization, this will fail gracefully (result["status"] = false)
          script_path = @script_path.join("read_shared_folders_args.js")
          cmd = ["osascript", "-l", "JavaScript", script_path.to_s, @uuid, "--ids", folders.join(",")]
          output = execute_shell(*cmd)
          result = JSON.parse(output)
          return unless result["status"]

          # Flatten the list of args and build the command
          sf_args = result["result"].flatten
          return unless sf_args.any?

          command = ["remove_qemu_additional_args.applescript", @uuid, "--args", *sf_args]
          execute_osa_script(command)
        end
      end
    end
  end
end
