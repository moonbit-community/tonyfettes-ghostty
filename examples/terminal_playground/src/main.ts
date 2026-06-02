const WASM_URL =
  "../../_build/wasm-gc/debug/build/tools/terminal_playground_core/terminal_playground_core.wasm";

const ESC = "\u001B";
const BEL = "\u0007";

type PlaygroundExports = {
  playground_new(cols: number, rows: number): number;
  playground_free(handle: number): void;
  playground_reset(handle: number): void;
  playground_resize(handle: number, cols: number, rows: number): number;
  playground_apply_text(handle: number, input: string): void;
  playground_scroll_delta(handle: number, delta: number): void;
  playground_render_html(handle: number): string;
  playground_render_plain(handle: number): string;
  playground_render_vt(handle: number): string;
  playground_state_json(handle: number): string;
  playground_cell_json(handle: number, row: number, col: number): string;
  playground_kitty_json(handle: number): string;
  playground_pty_output(handle: number): string;
  playground_clear_pty_output(handle: number): void;
};

type StatePayload = {
  rows: number;
  columns: number;
  widthPx: number;
  heightPx: number;
  cursorX: number;
  cursorY: number;
  cursorStyle: string;
  cursorVisible: boolean;
  cursorPendingWrap: boolean;
  activeScreen: string;
  title: string | null;
  pwd: string | null;
  mouseTracking: boolean;
  paletteDirty: boolean;
  scrollbackRows: number;
  totalRows: number;
  scrollbar: {
    total: number;
    len: number;
    offset: number;
  };
  bellCount: number;
  titleChangeCount: number;
  ptyLength: number;
};

type KittyPayload = {
  count: number;
  placements: KittyPlacement[];
};

type KittyPlacement = {
  image: KittyImage;
  columns: number;
  rows: number;
  viewport: { row: number; col: number } | null;
};

type KittyImage = {
  width: number;
  height: number;
  format: "rgb" | "rgba" | "png";
  dataBase64: string;
};

type Scenario = {
  id: string;
  name: string;
  note: string;
  editorText: string;
  image?: string;
};

const statusText = element<HTMLParagraphElement>("statusText");
const colsInput = element<HTMLInputElement>("colsInput");
const rowsInput = element<HTMLInputElement>("rowsInput");
const resizeButton = element<HTMLButtonElement>("resizeButton");
const resetButton = element<HTMLButtonElement>("resetButton");
const applyButton = element<HTMLButtonElement>("applyButton");
const scrollUpButton = element<HTMLButtonElement>("scrollUpButton");
const scrollDownButton = element<HTMLButtonElement>("scrollDownButton");
const clearPtyButton = element<HTMLButtonElement>("clearPtyButton");
const viewport = element<HTMLDivElement>("viewport");
const scenarioGrid = element<HTMLDivElement>("scenarioGrid");
const editorInput = element<HTMLTextAreaElement>("editorInput");
const stateSummary = element<HTMLDListElement>("stateSummary");
const inspectRowInput = element<HTMLInputElement>("inspectRowInput");
const inspectColInput = element<HTMLInputElement>("inspectColInput");
const inspectButton = element<HTMLButtonElement>("inspectButton");
const cursorButton = element<HTMLButtonElement>("cursorButton");
const cellOutput = element<HTMLPreElement>("cellOutput");
const kittyCanvas = element<HTMLCanvasElement>("kittyCanvas");
const kittyOutput = element<HTMLPreElement>("kittyOutput");
const plainOutput = element<HTMLPreElement>("plainOutput");
const vtOutput = element<HTMLPreElement>("vtOutput");
const ptyOutput = element<HTMLPreElement>("ptyOutput");
const screenTag = element<HTMLSpanElement>("screenTag");
const cursorTag = element<HTMLSpanElement>("cursorTag");
const replyTag = element<HTMLSpanElement>("replyTag");

let exportsRef: PlaygroundExports | null = null;
let handle = 0;

const scenarios: Scenario[] = [
  {
    id: "styles",
    name: "Styles",
    note: "SGR colors and underline",
    editorText:
      "Plain text\\r\\n\\x1b[1;32mBold green\\x1b[0m · \\x1b[38;2;255;120;40mRGB amber\\x1b[0m\\r\\n\\x1b[4mUnderline\\x1b[0m",
  },
  {
    id: "cursor",
    name: "Cursor",
    note: "Margins and cursor shape",
    editorText:
      "\\x1b[5 qfirst\\r\\nsecond\\r\\nthird\\r\\n\\x1b[2;4r\\x1b[2;1H\\x1b[2Linserted\\r\\n",
  },
  {
    id: "scrollback",
    name: "Scrollback",
    note: "Overflow into history",
    editorText: Array.from({ length: 36 }, (_, index) =>
      `line ${String(index + 1).padStart(2, "0")}`,
    ).join("\\r\\n"),
  },
  {
    id: "alternate",
    name: "Alt screen",
    note: "Switch into 1049",
    editorText:
      "primary\\r\\n\\x1b[?1049halt screen\\r\\nstatus row\\r\\n\\x1b[?25l",
  },
  {
    id: "hyperlink",
    name: "Links",
    note: "OSC title and hyperlink",
    editorText:
      "\\x1b]0;Link demo\\x07\\x1b]8;;https://ghostty.org\\x1b\\\\ghostty.org\\x1b]8;;\\x1b\\\\\\r\\n\\x1b]8;;https://example.com\\x1b\\\\more\\x1b]8;;\\x1b\\\\",
  },
  {
    id: "queries",
    name: "Queries",
    note: "PTY replies and bell",
    editorText: "\\x07\\x05\\x1b[5n\\x1b[18t\\x1b[>q",
  },
  {
    id: "kitty",
    name: "Kitty",
    note: "RGBA image placement",
    editorText: buildKittyScenario(),
    image: "./assets/kitty-dog.png",
  },
];

void init();

async function init(): Promise<void> {
  setControlsDisabled(true);
  renderScenarioButtons();
  editorInput.value = scenarios[0].editorText;
  try {
    exportsRef = await loadExports();
    handle = exportsRef.playground_new(readNumber(colsInput), readNumber(rowsInput));
    wireEvents();
    window.addEventListener("pagehide", () => {
      if (exportsRef && handle !== 0) {
        exportsRef.playground_free(handle);
        handle = 0;
      }
    });
    await applyEditor(false);
    statusText.textContent = "Ready";
    setControlsDisabled(false);
  } catch (error) {
    console.error(error);
    statusText.textContent =
      "This browser needs WebAssembly GC + js-string builtins. Use a recent Chromium build.";
    viewport.textContent = String(error);
  }
}

function wireEvents(): void {
  applyButton.addEventListener("click", () => {
    void applyEditor(false);
  });
  resetButton.addEventListener("click", () => {
    if (!exportsRef) {
      return;
    }
    exportsRef.playground_reset(handle);
    void refresh();
  });
  resizeButton.addEventListener("click", () => {
    if (!exportsRef) {
      return;
    }
    exportsRef.playground_resize(handle, readNumber(colsInput), readNumber(rowsInput));
    void refresh();
  });
  scrollUpButton.addEventListener("click", () => {
    if (!exportsRef) {
      return;
    }
    exportsRef.playground_scroll_delta(handle, -1);
    void refresh();
  });
  scrollDownButton.addEventListener("click", () => {
    if (!exportsRef) {
      return;
    }
    exportsRef.playground_scroll_delta(handle, 1);
    void refresh();
  });
  clearPtyButton.addEventListener("click", () => {
    if (!exportsRef) {
      return;
    }
    exportsRef.playground_clear_pty_output(handle);
    void refresh();
  });
  inspectButton.addEventListener("click", () => {
    void refreshCell();
  });
  cursorButton.addEventListener("click", () => {
    const state = parseJson<StatePayload>(exportsRef?.playground_state_json(handle) ?? "{}");
    inspectRowInput.value = String(state.cursorY ?? 0);
    inspectColInput.value = String(state.cursorX ?? 0);
    void refreshCell();
  });
}

function renderScenarioButtons(): void {
  scenarioGrid.innerHTML = "";
  for (const scenario of scenarios) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "scenario-button";
    button.innerHTML = `
      <span class="scenario-copy">
        <span class="scenario-name">${escapeHtml(scenario.name)}</span>
        <span class="scenario-note">${escapeHtml(scenario.note)}</span>
      </span>
      ${
        scenario.image
          ? `<img class="scenario-thumb" src="${scenario.image}" alt="">`
          : ""
      }
    `;
    button.addEventListener("click", () => {
      editorInput.value = scenario.editorText;
      void applyEditor(true);
    });
    scenarioGrid.appendChild(button);
  }
}

async function applyEditor(resetFirst: boolean): Promise<void> {
  if (!exportsRef) {
    return;
  }
  if (resetFirst) {
    exportsRef.playground_reset(handle);
  }
  exportsRef.playground_apply_text(handle, parseEscapes(editorInput.value));
  await refresh();
}

async function refresh(): Promise<void> {
  if (!exportsRef) {
    return;
  }

  const html = exportsRef.playground_render_html(handle);
  viewport.innerHTML =
    html.length > 0 ? html : `<div class="empty">Load a scenario or write bytes.</div>`;

  const plain = exportsRef.playground_render_plain(handle);
  const vt = exportsRef.playground_render_vt(handle);
  const pty = exportsRef.playground_pty_output(handle);
  const state = parseJson<StatePayload>(exportsRef.playground_state_json(handle));
  const kitty = parseJson<KittyPayload>(exportsRef.playground_kitty_json(handle));

  plainOutput.textContent = plain;
  vtOutput.textContent = vt;
  ptyOutput.textContent = pty;
  renderState(state);
  renderKitty(kitty);

  inspectRowInput.value = String(state.cursorY);
  inspectColInput.value = String(state.cursorX);
  await refreshCell();
}

async function refreshCell(): Promise<void> {
  if (!exportsRef) {
    return;
  }
  const row = readNumber(inspectRowInput);
  const col = readNumber(inspectColInput);
  const payload = parseJson<Record<string, unknown>>(
    exportsRef.playground_cell_json(handle, row, col),
  );
  cellOutput.textContent = JSON.stringify(payload, null, 2);
}

function renderState(state: StatePayload): void {
  const fields: Array<[string, string]> = [
    ["Title", state.title ?? "—"],
    ["PWD", state.pwd ?? "—"],
    ["Screen", state.activeScreen],
    ["Cursor", `${state.cursorY},${state.cursorX} ${state.cursorStyle}`],
    ["Viewport", `${state.rows}×${state.columns}`],
    ["Scrollback", `${state.scrollbackRows}`],
    ["Bell", `${state.bellCount}`],
    ["PTY bytes", `${state.ptyLength}`],
    ["Mouse", state.mouseTracking ? "on" : "off"],
    ["Wrap", state.cursorPendingWrap ? "pending" : "clear"],
  ];

  stateSummary.innerHTML = fields
    .map(
      ([label, value]) =>
        `<dt>${escapeHtml(label)}</dt><dd>${escapeHtml(value)}</dd>`,
    )
    .join("");

  screenTag.textContent = state.activeScreen;
  cursorTag.textContent = `cursor ${state.cursorY},${state.cursorX}`;
  replyTag.textContent = `pty ${state.ptyLength}`;
}

function renderKitty(payload: KittyPayload): void {
  kittyOutput.textContent = JSON.stringify(payload, null, 2);
  const context = kittyCanvas.getContext("2d");
  if (!context) {
    return;
  }
  context.clearRect(0, 0, kittyCanvas.width, kittyCanvas.height);
  if (!payload.placements.length) {
    return;
  }

  const first = payload.placements[0];
  const image = first.image;
  if (image.format === "png") {
    return;
  }

  const bytes = base64ToBytes(image.dataBase64);
  const rgba = image.format === "rgba" ? bytes : expandRgb(bytes);
  const imageData = new ImageData(
    new Uint8ClampedArray(rgba),
    image.width,
    image.height,
  );

  const offscreen = document.createElement("canvas");
  offscreen.width = image.width;
  offscreen.height = image.height;
  const offscreenContext = offscreen.getContext("2d");
  if (!offscreenContext) {
    return;
  }
  offscreenContext.putImageData(imageData, 0, 0);
  context.imageSmoothingEnabled = false;
  context.drawImage(offscreen, 0, 0, kittyCanvas.width, kittyCanvas.height);
}

async function loadExports(): Promise<PlaygroundExports> {
  const response = await fetch(WASM_URL);
  const bytes = await response.arrayBuffer();
  const result = await WebAssembly.instantiate(
    bytes,
    { _: {} },
    {
      builtins: ["js-string"],
      importedStringConstants: "_",
    },
  );
  return result.instance.exports as unknown as PlaygroundExports;
}

function setControlsDisabled(disabled: boolean): void {
  for (const control of [
    colsInput,
    rowsInput,
    resizeButton,
    resetButton,
    applyButton,
    scrollUpButton,
    scrollDownButton,
    clearPtyButton,
    editorInput,
    inspectRowInput,
    inspectColInput,
    inspectButton,
    cursorButton,
  ]) {
    control.disabled = disabled;
  }
}

function parseEscapes(input: string): string {
  return input
    .replace(/\\u\{([0-9a-fA-F]+)\}/g, (_match, hex: string) =>
      String.fromCodePoint(Number.parseInt(hex, 16)),
    )
    .replace(/\\u([0-9a-fA-F]{4})/g, (_match, hex: string) =>
      String.fromCodePoint(Number.parseInt(hex, 16)),
    )
    .replace(/\\x([0-9a-fA-F]{2})/g, (_match, hex: string) =>
      String.fromCodePoint(Number.parseInt(hex, 16)),
    )
    .replace(/\\r/g, "\r")
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "\t")
    .replace(/\\\\/g, "\\");
}

function buildKittyScenario(): string {
  const pixels = new Uint8Array([
    255, 94, 77, 255,
    244, 163, 59, 255,
    142, 191, 79, 255,
    70, 165, 195, 255,
    244, 163, 59, 255,
    255, 94, 77, 255,
    70, 165, 195, 255,
    142, 191, 79, 255,
    142, 191, 79, 255,
    70, 165, 195, 255,
    255, 94, 77, 255,
    244, 163, 59, 255,
    70, 165, 195, 255,
    142, 191, 79, 255,
    244, 163, 59, 255,
    255, 94, 77, 255,
  ]);
  const base64 = bytesToBase64(pixels);
  return `kitty\\r\\n\\x1b_Ga=T,t=d,f=32,i=7,p=1,s=4,v=4,c=8,r=4;${base64}\\x1b\\\\`;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const value of bytes) {
    binary += String.fromCharCode(value);
  }
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function expandRgb(bytes: Uint8Array): Uint8Array {
  const rgba = new Uint8Array((bytes.length / 3) * 4);
  for (let index = 0, out = 0; index < bytes.length; index += 3, out += 4) {
    rgba[out] = bytes[index];
    rgba[out + 1] = bytes[index + 1];
    rgba[out + 2] = bytes[index + 2];
    rgba[out + 3] = 255;
  }
  return rgba;
}

function readNumber(input: HTMLInputElement): number {
  return Number.parseInt(input.value, 10);
}

function parseJson<T>(value: string): T {
  return JSON.parse(value) as T;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function element<T extends HTMLElement>(id: string): T {
  const found = document.getElementById(id);
  if (!(found instanceof HTMLElement)) {
    throw new Error(`Missing element: ${id}`);
  }
  return found as T;
}
