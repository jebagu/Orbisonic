"use strict";

const http = require("http");
const fs = require("fs");
const path = require("path");

let RoonApi;
let RoonApiStatus;
let RoonApiTransport;
let RoonApiImage;

try {
  RoonApi = require("node-roon-api");
  RoonApiStatus = require("node-roon-api-status");
  RoonApiTransport = require("node-roon-api-transport");
  try {
    RoonApiImage = require("node-roon-api-image");
  } catch {
    RoonApiImage = null;
  }
} catch (error) {
  console.error(`[roon-bridge] Missing dependency: ${error.message}`);
  console.error("[roon-bridge] Run npm install in the RoonBridge support directory.");
  process.exit(78);
}

const HOST = "127.0.0.1";
const PORT = Number(process.env.ORBISONIC_ROON_BRIDGE_PORT || "37942");
const BRIDGE_VERSION = "0.2.0";
const DEFAULT_ZONE_HINT = "Orbisonic Roon Input";
const zoneHint = String(process.env.ORBISONIC_ROON_ZONE_NAME || DEFAULT_ZONE_HINT).trim();
const selectedZoneFile = path.join(process.cwd(), "selected-zone.json");

let coreInfo = null;
let transport = null;
let imageService = null;
let statusService = null;
let zones = [];
let selectedZoneId = readSelectedZoneId();
let bridgeState = "starting";
let bridgeMessage = "Starting Roon API bridge.";
let lastUpdate = new Date().toISOString();

function readSelectedZoneId() {
  try {
    const payload = JSON.parse(fs.readFileSync(selectedZoneFile, "utf8"));
    return typeof payload.zone_id === "string" ? payload.zone_id : null;
  } catch {
    return null;
  }
}

function writeSelectedZoneId(zoneId) {
  selectedZoneId = zoneId;
  try {
    fs.writeFileSync(selectedZoneFile, `${JSON.stringify({ zone_id: zoneId }, null, 2)}\n`);
  } catch (error) {
    console.error(`[roon-bridge] Failed to persist selected zone: ${error.message}`);
  }
}

function mark(state, message) {
  bridgeState = state;
  bridgeMessage = message;
  lastUpdate = new Date().toISOString();
  if (statusService) {
    statusService.set_status(message, state === "error");
  }
}

function normalize(value) {
  return String(value || "").toLowerCase();
}

function zoneHaystack(zone) {
  const fields = [zone.display_name];
  for (const output of zone.outputs || []) {
    fields.push(output.display_name, output.output_id, output.source_controls && output.source_controls.display_name);
  }
  return normalize(fields.filter(Boolean).join(" "));
}

function zoneById(zoneId) {
  return zones.find((zone) => zone.zone_id === zoneId) || null;
}

function chooseZone() {
  if (selectedZoneId) {
    const saved = zoneById(selectedZoneId);
    if (saved) return saved;
  }

  const desired = normalize(zoneHint);
  const exactHint = zones.find((zone) => zoneHaystack(zone).includes(desired));
  if (exactHint) return exactHint;

  const orbisonicHint = zones.find((zone) => {
    const haystack = zoneHaystack(zone);
    return haystack.includes("orbisonic") && haystack.includes("roon");
  });
  if (orbisonicHint) return orbisonicHint;

  const orbisonicZone = zones.find((zone) => normalize(zone.display_name) === "orbisonic");
  if (orbisonicZone) return orbisonicZone;

  const legacyVirtualHint = zones.find((zone) => zoneHaystack(zone).includes("blackhole"));
  if (legacyVirtualHint) return legacyVirtualHint;

  const playing = zones.find((zone) => zone.state === "playing" || zone.state === "loading");
  if (playing) return playing;

  return zones.length === 1 ? zones[0] : null;
}

function currentControls(zone) {
  if (!zone) {
    return {
      play: false,
      pause: false,
      playpause: false,
      stop: false,
      previous: false,
      next: false
    };
  }

  const canPlay = Boolean(zone.is_play_allowed);
  const canPause = Boolean(zone.is_pause_allowed);
  return {
    play: canPlay,
    pause: canPause,
    playpause: canPlay || canPause,
    stop: zone.state === "playing" || zone.state === "paused" || zone.state === "loading",
    previous: Boolean(zone.is_previous_allowed),
    next: Boolean(zone.is_next_allowed)
  };
}

function compactZone(zone) {
  if (!zone) return null;
  return {
    zone_id: zone.zone_id,
    display_name: zone.display_name,
    state: zone.state,
    is_play_allowed: Boolean(zone.is_play_allowed),
    is_pause_allowed: Boolean(zone.is_pause_allowed),
    is_previous_allowed: Boolean(zone.is_previous_allowed),
    is_next_allowed: Boolean(zone.is_next_allowed),
    is_seek_allowed: Boolean(zone.is_seek_allowed),
    outputs: (zone.outputs || []).map((output) => ({
      output_id: output.output_id,
      display_name: output.display_name,
      state: output.state
    })),
    now_playing: zone.now_playing || null,
    controls: currentControls(zone)
  };
}

function snapshot() {
  const selectedZone = chooseZone();
  const selected = compactZone(selectedZone);
  const state = selected ? bridgeState : (transport ? "waiting_for_zone" : bridgeState);
  const message = selected
    ? `Ready to control ${selected.display_name}.`
    : (transport ? `No Roon zone matching ${zoneHint} is available.` : bridgeMessage);

  return {
    ok: Boolean(transport),
    updated_at: lastUpdate,
    bridge: {
      state,
      message,
      zone_hint: zoneHint,
      version: BRIDGE_VERSION,
      supports_image: Boolean(RoonApiImage),
      image_service_available: Boolean(imageService)
    },
    core: coreInfo,
    selected_zone_id: selected ? selected.zone_id : null,
    selected_zone: selected,
    zones: zones.map(compactZone)
  };
}

function respondJSON(response, statusCode, body) {
  const payload = JSON.stringify(body, null, 2);
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "Content-Length": Buffer.byteLength(payload)
  });
  response.end(payload);
}

function respondImage(imageKey, response) {
  if (!imageService || !imageKey) {
    respondJSON(response, 503, { ok: false, error: "Roon image service is not available." });
    return;
  }

  imageService.get_image(imageKey, { scale: "fit", width: 600, height: 600, format: "image/jpeg" }, (error, contentType, body) => {
    if (error || !body) {
      respondJSON(response, 502, { ok: false, error: String(error || "No image returned.") });
      return;
    }

    const payload = Buffer.isBuffer(body) ? body : Buffer.from(body);
    response.writeHead(200, {
      "Content-Type": contentType || "image/jpeg",
      "Cache-Control": "public, max-age=3600",
      "Content-Length": payload.length
    });
    response.end(payload);
  });
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    let payload = "";
    request.on("data", (chunk) => {
      payload += chunk;
      if (payload.length > 32 * 1024) {
        reject(new Error("Request body too large."));
        request.destroy();
      }
    });
    request.on("end", () => {
      if (!payload) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(payload));
      } catch {
        reject(new Error("Request body must be JSON."));
      }
    });
  });
}

function controlZone(control, response) {
  const allowedControls = new Set(["play", "pause", "playpause", "stop", "previous", "next"]);
  if (!allowedControls.has(control)) {
    respondJSON(response, 400, { ok: false, error: `Unsupported Roon control: ${control}` });
    return;
  }

  const zone = chooseZone();
  if (!transport || !zone) {
    respondJSON(response, 409, { ok: false, error: "No controllable Roon zone is paired.", state: snapshot() });
    return;
  }

  const controls = currentControls(zone);
  if (!controls[control]) {
    respondJSON(response, 409, {
      ok: false,
      error: `${control} is not currently allowed for ${zone.display_name}.`,
      state: snapshot()
    });
    return;
  }

  transport.control(zone, control, (error) => {
    if (error) {
      respondJSON(response, 502, {
        ok: false,
        error: String(error),
        state: snapshot()
      });
      return;
    }

    mark("paired", `Sent ${control} to ${zone.display_name}.`);
    respondJSON(response, 200, {
      ok: true,
      message: bridgeMessage,
      state: snapshot()
    });
  });
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${HOST}:${PORT}`);

  if (request.method === "GET" && (url.pathname === "/health" || url.pathname === "/state")) {
    respondJSON(response, 200, snapshot());
    return;
  }

  if (request.method === "GET" && url.pathname === "/zones") {
    respondJSON(response, 200, { ok: true, zones: zones.map(compactZone), selected_zone: compactZone(chooseZone()) });
    return;
  }

  if (request.method === "GET" && url.pathname.startsWith("/image/")) {
    respondImage(decodeURIComponent(url.pathname.slice("/image/".length)), response);
    return;
  }

  if (request.method === "POST" && url.pathname === "/zone/select") {
    try {
      const body = await readBody(request);
      const zone = zoneById(body.zone_id);
      if (!zone) {
        respondJSON(response, 404, { ok: false, error: "Unknown Roon zone.", state: snapshot() });
        return;
      }
      writeSelectedZoneId(zone.zone_id);
      mark("paired", `Selected ${zone.display_name}.`);
      respondJSON(response, 200, { ok: true, state: snapshot() });
    } catch (error) {
      respondJSON(response, 400, { ok: false, error: error.message });
    }
    return;
  }

  if (request.method === "POST" && url.pathname === "/control") {
    try {
      const body = await readBody(request);
      controlZone(String(body.control || ""), response);
    } catch (error) {
      respondJSON(response, 400, { ok: false, error: error.message });
    }
    return;
  }

  respondJSON(response, 404, { ok: false, error: "Not found." });
});

server.listen(PORT, HOST, () => {
  console.log(`[roon-bridge] HTTP control listening on http://${HOST}:${PORT}`);
});

const roon = new RoonApi({
  extension_id: "com.orbisonic.roon-bridge",
  display_name: "Orbisonic Roon Bridge",
  display_version: BRIDGE_VERSION,
  publisher: "Orbisonic",
  email: "support@example.invalid",
  website: "https://example.invalid/orbisonic",
  log_level: process.env.ORBISONIC_ROON_LOG_LEVEL || "none",

  core_paired: function paired(core) {
    coreInfo = {
      core_id: core.core_id,
      display_name: core.display_name,
      display_version: core.display_version
    };
    transport = core.services.RoonApiTransport;
    imageService = RoonApiImage ? core.services.RoonApiImage : null;
    mark("paired", `Paired with ${core.display_name}.`);

    transport.subscribe_zones((cmd, data) => {
      if (cmd === "Subscribed") {
        zones = data.zones || [];
      } else if (cmd === "Changed") {
        const byId = new Map(zones.map((zone) => [zone.zone_id, zone]));
        for (const zone of data.zones_removed || []) byId.delete(zone.zone_id);
        for (const zone of data.zones_added || []) byId.set(zone.zone_id, zone);
        for (const zone of data.zones_changed || []) byId.set(zone.zone_id, zone);
        for (const seek of data.zones_seek_changed || []) {
          const zone = byId.get(seek.zone_id);
          if (zone && zone.now_playing) {
            zone.now_playing.seek_position = seek.seek_position;
            zone.queue_time_remaining = seek.queue_time_remaining;
          }
        }
        zones = Array.from(byId.values());
      }

      const selected = chooseZone();
      if (selected) {
        mark("paired", `Ready to control ${selected.display_name}.`);
      } else {
        mark("waiting_for_zone", `Waiting for Roon zone matching ${zoneHint}.`);
      }
    });
  },

  core_unpaired: function unpaired(core) {
    const name = core && core.display_name ? core.display_name : "Roon Core";
    coreInfo = null;
    transport = null;
    imageService = null;
    zones = [];
    mark("unpaired", `${name} is no longer paired.`);
  }
});

statusService = new RoonApiStatus(roon);
roon.init_services({
  required_services: RoonApiImage ? [RoonApiTransport, RoonApiImage] : [RoonApiTransport],
  provided_services: [statusService]
});
mark("waiting_for_authorization", "Open Roon Settings > Extensions and enable Orbisonic Roon Bridge.");
roon.start_discovery();

function shutdown() {
  mark("stopped", "Orbisonic Roon Bridge stopped.");
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 500).unref();
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
