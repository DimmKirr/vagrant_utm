/**
 * Reads the shared directories from a VM in UTM.
 * For QEMU VMs: reads from QEMU additional arguments (9pfs)
 * For Apple VMs: reads from registry (VirtioFS)
 *
 * @param {string} vmIdentifier - The ID of the VM.
 * @returns {string} A JSON string with backend type, shared folder IDs, and registry paths.
 */
function run(argv) {
  if (argv.length === 0) {
      console.log("Usage: osascript -l JavaScript read_shared_folders.js <vm_id>");
      return JSON.stringify({ status: false, result: "No VM ID provided." });
  }

  const vmIdentifier = argv[0];
  const utm = Application('UTM');
  utm.includeStandardAdditions = true;

  try {
      const vm = utm.virtualMachines.byId(vmIdentifier);
      const backend = vm.backend();
      const backendStr = (backend == "qemu") ? "qemu" : "apple";

      let sharedDirIds = [];
      let registryPaths = [];

      // Read registry (works for both backends)
      try {
          const registry = vm.registry();
          if (registry && registry.length > 0) {
              registryPaths = registry.map(f => f.toString());
          }
      } catch (e) {
          // Registry might be empty or inaccessible
      }

      // For QEMU, also read from qemu additional arguments
      if (backendStr === "qemu") {
          try {
              const config = vm.configuration();
              const qemuArgs = config.qemuAdditionalArguments;

              qemuArgs.forEach(arg => {
                  const argStr = arg.argumentString;
                  if (argStr.startsWith("-fsdev")) {
                      const match = argStr.match(/id=([^,]+)/);
                      if (match) {
                          sharedDirIds.push(match[1]);
                      }
                  }
              });
          } catch (e) {
              // QEMU args might not be accessible
          }
      }

      return JSON.stringify({
          status: true,
          backend: backendStr,
          result: sharedDirIds,
          registry: registryPaths
      });
  } catch (error) {
      return JSON.stringify({ status: false, result: error.message });
  }
}