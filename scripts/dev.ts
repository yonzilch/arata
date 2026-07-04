/// <reference types="bun" />

const PORT = Number(Bun.env.PORT ?? "3333");
const DIST_DIR = Bun.env.DIST_DIR ?? "dist";
const BUILD_MODULE = Bun.env.BUILD_MODULE ?? "build/pipeline";
const DEBUG = Bun.env.DEBUG === "1";

const WATCH_PATTERNS = [
  "src/**/*",
  "content/**/*",
  "static/**/*",
  "gleam.toml",
];

const IGNORED_PREFIXES = [".git/", "build/", "dist/", "node_modules/"];

// Directories that actually exist under DIST_DIR after a build.
// Anything under these should never fall back to index.html.
const STATIC_ASSET_PREFIXES = ["/css/", "/fonts/", "/icons/", "/images/"];

const MIME_TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".xml": "application/xml; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".ico": "image/x-icon",
  ".wasm": "application/wasm",
};

type Snapshot = Map<string, string>;

type SseClient = {
  controller: ReadableStreamDefaultController<Uint8Array>;
  heartbeat: ReturnType<typeof setInterval>;
};

const encoder = new TextEncoder();
const clients = new Set<SseClient>();

let building = false;
let pendingBuild = false;
let scanning = false;
let watchTimer: ReturnType<typeof setTimeout> | null = null;
let lastSnapshot: Snapshot = new Map();

function log(message: string) {
  console.log(`[arata-dev] ${message}`);
}

function warn(message: string) {
  console.warn(`[arata-dev] ${message}`);
}

function debug(message: string) {
  if (DEBUG) console.log(`[arata-dev:debug] ${message}`);
}

function now() {
  return Date.now();
}

function trimLeadingSlash(path: string): string {
  while (path.startsWith("/")) {
    path = path.slice(1);
  }

  return path;
}

function trimTrailingSlash(path: string): string {
  while (path.endsWith("/")) {
    path = path.slice(0, -1);
  }

  return path;
}

function joinPath(...parts: string[]): string {
  return parts
    .filter((part) => part.length > 0)
    .map((part, index) => {
      if (index === 0) return trimTrailingSlash(part);
      return trimLeadingSlash(trimTrailingSlash(part));
    })
    .join("/");
}

function fileExtension(path: string): string {
  const slashIndex = path.lastIndexOf("/");
  const dotIndex = path.lastIndexOf(".");

  if (dotIndex === -1) return "";
  if (slashIndex !== -1 && dotIndex < slashIndex) return "";

  return path.slice(dotIndex);
}

async function fileExists(path: string): Promise<boolean> {
  return await Bun.file(path).exists();
}

async function removeDist() {
  const proc = Bun.spawn({
    cmd: ["rm", "-rf", DIST_DIR],
    stdout: "inherit",
    stderr: "inherit",
  });

  const code = await proc.exited;

  if (code !== 0) {
    throw new Error(`failed to remove ${DIST_DIR}, exit code ${code}`);
  }
}

function isIgnored(path: string): boolean {
  const normalized = path.replaceAll("\\", "/");

  return IGNORED_PREFIXES.some((prefix) => normalized.startsWith(prefix));
}

async function collectWatchFiles(): Promise<string[]> {
  const files = new Set<string>();

  for (const pattern of WATCH_PATTERNS) {
    const glob = new Bun.Glob(pattern);

    for await (const file of glob.scan({
      cwd: ".",
      dot: true,
      onlyFiles: true,
    })) {
      const normalized = file.replaceAll("\\", "/");

      if (!isIgnored(normalized)) {
        files.add(normalized);
      }
    }
  }

  return [...files].sort();
}

async function createSnapshot(): Promise<Snapshot> {
  const snapshot: Snapshot = new Map();
  const files = await collectWatchFiles();

  for (const file of files) {
    const bunFile = Bun.file(file);

    if (!(await bunFile.exists())) {
      continue;
    }

    snapshot.set(file, `${bunFile.size}:${bunFile.lastModified}`);
  }

  return snapshot;
}

function findSnapshotChange(before: Snapshot, after: Snapshot): string | null {
  for (const [file, marker] of after) {
    const previous = before.get(file);

    if (previous === undefined) {
      return `${file} added`;
    }

    if (previous !== marker) {
      return `${file} changed`;
    }
  }

  for (const file of before.keys()) {
    if (!after.has(file)) {
      return `${file} removed`;
    }
  }

  return null;
}

function closeClient(client: SseClient) {
  clearInterval(client.heartbeat);
  clients.delete(client);
}

function broadcast(event: "reload" | "error") {
  const payload = encoder.encode(`event: ${event}\ndata: ${now()}\n\n`);

  for (const client of clients) {
    try {
      client.controller.enqueue(payload);
    } catch {
      closeClient(client);
    }
  }
}

async function runBuild(reason: string) {
  if (building) {
    pendingBuild = true;
    return;
  }

  building = true;
  pendingBuild = false;

  const startedAt = now();

  log(`build started: ${reason}`);

  try {
    await removeDist();
  } catch (error) {
    building = false;
    broadcast("error");
    warn(error instanceof Error ? error.message : String(error));
    return;
  }

  const proc = Bun.spawn({
    cmd: ["gleam", "run", "-m", BUILD_MODULE],
    stdout: "inherit",
    stderr: "inherit",
  });

  const code = await proc.exited;
  const elapsed = now() - startedAt;

  if (code === 0) {
    log(`build succeeded in ${elapsed}ms`);
    broadcast("reload");
  } else {
    warn(`build failed with exit code ${code}`);
    broadcast("error");
  }

  building = false;

  if (pendingBuild) {
    await runBuild("pending changes");
  }
}

function normalizeRequestPath(pathname: string): string | null {
  let decoded: string;

  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return null;
  }

  if (decoded.includes("\0")) {
    return null;
  }

  const segments: string[] = [];

  for (const segment of decoded.split("/")) {
    if (segment === "" || segment === ".") {
      continue;
    }

    if (segment === "..") {
      return null;
    }

    segments.push(segment);
  }

  return segments.join("/");
}

function shouldFallbackToIndex(pathname: string): boolean {
  if (STATIC_ASSET_PREFIXES.some((prefix) => pathname.startsWith(prefix))) {
    return false;
  }

  return fileExtension(pathname) === "";
}

function livereloadScript(): string {
  return `
<script>
(() => {
  const events = new EventSource("/__arata_events");

  events.addEventListener("reload", () => {
    location.reload();
  });

  events.addEventListener("error", () => {
    console.warn("[arata-dev] build failed");
  });
})();
</script>
`;
}

async function serveFile(req: Request, filePath: string): Promise<Response> {
  const ext = fileExtension(filePath);
  const contentType = MIME_TYPES[ext] ?? "application/octet-stream";

  if (req.method === "HEAD") {
    return new Response(null, {
      status: 200,
      headers: {
        "content-type": contentType,
        "cache-control": "no-cache",
      },
    });
  }

  if (ext === ".html") {
    let html = await Bun.file(filePath).text();

    if (html.includes("</body>")) {
      html = html.replace("</body>", `${livereloadScript()}</body>`);
    } else {
      html += livereloadScript();
    }

    return new Response(html, {
      status: 200,
      headers: {
        "content-type": contentType,
        "cache-control": "no-cache",
      },
    });
  }

  return new Response(Bun.file(filePath), {
    status: 200,
    headers: {
      "content-type": contentType,
      "cache-control": "no-cache",
    },
  });
}

function createEventStream(): Response {
  let client: SseClient;

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      const heartbeat = setInterval(() => {
        try {
          controller.enqueue(encoder.encode(`: ping ${now()}\n\n`));
        } catch {
          closeClient(client);
        }
      }, 5000);

      client = {
        controller,
        heartbeat,
      };

      clients.add(client);
      controller.enqueue(encoder.encode(`event: open\ndata: ${now()}\n\n`));
    },

    cancel() {
      if (client) {
        closeClient(client);
      }
    },
  });

  return new Response(stream, {
    headers: {
      "content-type": "text/event-stream",
      "cache-control": "no-cache",
      connection: "keep-alive",
    },
  });
}

async function handleRequest(req: Request): Promise<Response> {
  try {
    const url = new URL(req.url);

    if (url.pathname === "/__arata_events") {
      return createEventStream();
    }

    if (req.method !== "GET" && req.method !== "HEAD") {
      return new Response("Method Not Allowed\n", {
        status: 405,
        headers: {
          allow: "GET, HEAD",
        },
      });
    }

    const requestedPath = url.pathname === "/" ? "/index.html" : url.pathname;

    const normalizedPath = normalizeRequestPath(requestedPath);

    if (normalizedPath === null) {
      return new Response("Forbidden\n", { status: 403 });
    }

    const filePath = joinPath(DIST_DIR, normalizedPath);

    if (await fileExists(filePath)) {
      return await serveFile(req, filePath);
    }

    if (shouldFallbackToIndex(requestedPath)) {
      const indexPath = joinPath(DIST_DIR, "index.html");

      if (await fileExists(indexPath)) {
        return await serveFile(req, indexPath);
      }
    }

    return new Response("Not Found\n", { status: 404 });
  } catch (error) {
    // Guard against races (e.g. a rebuild deleting dist/ mid-request) so a
    // thrown exception can never leave the connection hanging without a
    // response.
    warn(
      `request error: ${error instanceof Error ? error.message : String(error)}`,
    );

    return new Response("Internal Server Error\n", { status: 500 });
  }
}

// Self-rescheduling loop instead of setInterval: the next scan is only
// scheduled after the current one (scan + possible build) has fully
// finished. This prevents overlapping Glob scans / builds from piling up
// and starving the single JS thread that also has to service HTTP
// requests, which is what caused the dev server to become unresponsive.
function scheduleNextScan(delayMs: number) {
  watchTimer = setTimeout(() => {
    void watchTick();
  }, delayMs);
}

async function watchTick() {
  if (scanning) {
    scheduleNextScan(500);
    return;
  }

  scanning = true;
  const startedAt = now();

  try {
    const nextSnapshot = await createSnapshot();
    const change = findSnapshotChange(lastSnapshot, nextSnapshot);

    if (change !== null) {
      log(`detected change: ${change}`);
      lastSnapshot = nextSnapshot;
      await runBuild("file changed");
      lastSnapshot = await createSnapshot();
    } else {
      debug(`scan clean in ${now() - startedAt}ms`);
    }
  } catch (error) {
    warn(
      `watch scan error: ${error instanceof Error ? error.message : String(error)}`,
    );
  } finally {
    scanning = false;
    scheduleNextScan(500);
  }
}

function startWatchLoop() {
  scheduleNextScan(500);
}

const server = Bun.serve({
  port: PORT,
  idleTimeout: 30,
  fetch: handleRequest,
});

log(`server running: http://localhost:${server.port}`);
log(`serving: ${DIST_DIR}`);
log(`build module: ${BUILD_MODULE}`);
log(`watch patterns: ${WATCH_PATTERNS.join(", ")}`);

await runBuild("initial");

lastSnapshot = await createSnapshot();

startWatchLoop();

process.on("SIGINT", () => {
  if (watchTimer) clearTimeout(watchTimer);
  process.exit(0);
});
