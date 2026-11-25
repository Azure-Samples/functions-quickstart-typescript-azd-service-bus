// Updates src/local.settings.json with the Service Bus values from `azd env get-values --output json`.
// Used by both post-provision hooks so they share the same strict parsing and merge behavior.
// Usage: azd env get-values --output json | node update-local-settings.mjs <settings-path>
// Prints the namespace and queue name on separate lines when successful.
import fs from "node:fs";
import path from "node:path";

const NAMESPACE_KEY = "SERVICE_BUS_CONNECTION__fullyQualifiedNamespace";
const QUEUE_KEY = "SERVICE_BUS_QUEUE_NAME";

function fail(message) {
    console.error(`Error: ${message}`);
    process.exit(1);
}

function isPlainObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function stripBom(text) {
    return text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
}

const settingsPath = process.argv[2];
if (!settingsPath) {
    fail("Usage: node update-local-settings.mjs <settings-path>");
}

let envValues;
try {
    envValues = JSON.parse(stripBom(fs.readFileSync(0, "utf8")));
} catch {
    fail("Invalid JSON from azd env get-values. Check the azd environment and run 'azd provision' again.");
}
if (!isPlainObject(envValues)) {
    fail("'azd env get-values --output json' did not return a JSON object.");
}

const namespace = envValues[NAMESPACE_KEY];
const queueName = envValues[QUEUE_KEY];
if (typeof namespace !== "string" || !namespace.trim() || typeof queueName !== "string" || !queueName.trim()) {
    fail(`Required Service Bus environment values are missing (${NAMESPACE_KEY}, ${QUEUE_KEY}). Make sure 'azd provision' completed successfully.`);
}

let settings = { IsEncrypted: false, Values: {} };
if (fs.existsSync(settingsPath)) {
    let text;
    try {
        text = fs.readFileSync(settingsPath, "utf8");
    } catch (err) {
        fail(`Could not read ${settingsPath}: ${err.message}`);
    }
    try {
        settings = JSON.parse(stripBom(text));
    } catch {
        fail(`Invalid JSON in ${settingsPath}. Fix or remove it and run 'azd provision' again.`);
    }
    if (!isPlainObject(settings)) {
        fail(`${settingsPath} must contain a JSON object. Fix or remove it and run 'azd provision' again.`);
    }
    if (settings.IsEncrypted === true) {
        fail(`${settingsPath} is encrypted. Decrypt it with 'func settings decrypt' and run 'azd provision' again.`);
    }
    if (settings.Values !== undefined && !isPlainObject(settings.Values)) {
        fail(`'Values' in ${settingsPath} must be a JSON object. Fix or remove it and run 'azd provision' again.`);
    }
}

settings.IsEncrypted ??= false;
settings.Values ??= {};
settings.Values.AzureWebJobsStorage ??= "UseDevelopmentStorage=true";
settings.Values.FUNCTIONS_WORKER_RUNTIME ??= "node";
settings.Values.ServiceBusConnection__fullyQualifiedNamespace = namespace;
settings.Values.ServiceBusQueueName = queueName;

// Write to a temporary file first so a failed write never leaves a partial settings file.
const tempPath = path.join(path.dirname(settingsPath), `.${path.basename(settingsPath)}.${process.pid}.tmp`);
try {
    fs.writeFileSync(tempPath, JSON.stringify(settings, null, 4) + "\n");
    fs.renameSync(tempPath, settingsPath);
} catch (err) {
    fs.rmSync(tempPath, { force: true });
    fail(`Could not write ${settingsPath}: ${err.message}`);
}

console.log(namespace);
console.log(queueName);
