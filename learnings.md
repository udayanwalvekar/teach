## A GitHub product should have one product-owned installation command
### Users should install the product, not understand how every supported coding agent manages plugins.
- Teach initially exposed separate Codex marketplace commands, Claude installation steps, and different invocation instructions.
- The better interface is one permanent command: `curl -fsSL https://raw.githubusercontent.com/udayanwalvekar/teach/main/install.sh | sh`.
- The installer should detect each supported agent and place Teach where that agent expects it.
- The same command should handle both first-time installation and upgrades.
- Supporting another agent should require changing the installer, not teaching every user another installation process.

## A prompt-based skill should separate its stable installer from its frequently changing prompt
### Improving the prompt should not require publishing a new plugin version and asking everyone to reinstall.
- The installed skill should be a small, stable bootstrap that resolves the current prompt from GitHub whenever the skill runs.
- Prompt releases need a version, integrity verification, compatibility rules, caching, and an offline bundled fallback.
- A prompt-only change should update automatically for existing users.
- A new installer or plugin version should be required only when executable code, schemas, renderers, or bootstrap behavior changes.
