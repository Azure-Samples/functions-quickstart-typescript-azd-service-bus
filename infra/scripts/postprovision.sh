#!/bin/bash
set -euo pipefail

echo "Running post-provision script..."

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v node >/dev/null 2>&1; then
    echo "Error: Node.js is required to update src/local.settings.json." >&2
    exit 1
fi

if ! env_values=$(azd env get-values --output json); then
    echo "Error: Failed to get environment values from azd." >&2
    exit 1
fi

echo "Creating/updating src/local.settings.json..."

# The helper validates the azd output and merges into any existing file so user-added settings are preserved.
if ! sb_values=$(printf '%s' "$env_values" | node "$script_dir/update-local-settings.mjs" ./src/local.settings.json); then
    exit 1
fi
{ read -r ServiceBusNamespace; read -r ServiceBusQueueName; } <<< "$sb_values"

echo "src/local.settings.json has been created/updated successfully!"
echo "Creating/updating send-message.sh..."
cat > ./send-message.sh << EOF
#!/bin/bash
az rest --method POST --uri "https://$ServiceBusNamespace/$ServiceBusQueueName/messages" --headers "Content-Type=application/atom+xml;type=entry;charset=utf-8" --body "Hello from the CLI" --resource "https://servicebus.azure.net"
EOF
chmod +x ./send-message.sh

echo "send-message.sh has been created successfully!"
echo ""
echo "Service Bus Namespace: $ServiceBusNamespace"
echo "Service Bus Queue: $ServiceBusQueueName"
echo ""
echo "You can now run the function locally with 'cd src && func start'"
echo "Send test messages with './send-message.sh'"
