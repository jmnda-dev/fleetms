// AshTypescript landing page animation
// Typewriter effect with syntax highlighting, inspired by ash-hq.org

const HEXDOCS = "https://hexdocs.pm/ash_typescript";

interface Stage {
  name: string;
  description: string;
  docsPath: string;
  elixir: string;
  typescript: string;
}

const stages: Stage[] = [
  {
    name: "Type-Safe RPC",
    description: "Auto-generated TypeScript functions for every Ash action with full type inference.",
    docsPath: "/first-rpc-action.html",
    elixir: `use Ash.Domain,
  extensions: [AshTypescript.Rpc]

typescript_rpc do
  resource MyApp.Todo do
    rpc_action :list_todos, :read
    rpc_action :create_todo, :create
    rpc_action :update_todo, :update
  end
end`,
    typescript: `import { listTodos, createTodo } from "./ash_rpc";

const result = await listTodos({
  fields: ["id", "title", { user: ["name"] }],
  filter: { completed: { eq: false } },
  sort: [{ field: "insertedAt", order: "desc" }],
});

if (result.success) {
  // result.data is fully typed!
  result.data.forEach(todo => {
    console.log(todo.title, todo.user.name);
  });
}`,
  },
  {
    name: "Typed Controllers",
    description: "Typed route helpers and fetch functions for Phoenix controllers.",
    docsPath: "/typed-controllers.html",
    elixir: `use AshTypescript.TypedController

typed_controller do
  module_name MyAppWeb.SessionController

  get :current_user do
    run fn conn, _params ->
      json(conn, current_user(conn))
    end
  end

  post :login do
    argument :email, :string, allow_nil?: false
    argument :password, :string, allow_nil?: false
    run fn conn, params ->
      # authenticate and respond
    end
  end
end`,
    typescript: `import {
  currentUserPath,
  login,
} from "./routes";

// Typed path helpers
currentUserPath(); // => "/session/current_user"

// Typed fetch functions for mutations
const result = await login({
  email: "user@example.com",
  password: "secret",
  headers: buildCSRFHeaders(),
});`,
  },
  {
    name: "Typed Channels",
    description: "Type-safe Phoenix channel event subscriptions with Ash PubSub.",
    docsPath: "/typed-channels.html",
    elixir: `# Resource with PubSub
pub_sub do
  prefix "posts"
  publish :create, [:id],
    event: "post_created",
    transform: :post_summary
end

# Typed channel definition
typed_channel do
  topic "org:*"

  resource MyApp.Post do
    publish :post_created
    publish :post_updated
  end
end`,
    typescript: `import {
  createOrgChannel,
  onOrgChannelMessages,
} from "./ash_typed_channels";

const channel = createOrgChannel(socket, orgId);

const refs = onOrgChannelMessages(channel, {
  post_created: (payload) => {
    // payload type inferred from calculation!
    addPost(payload.id, payload.title);
  },
  post_updated: (payload) => {
    updatePost(payload.id, payload.title);
  },
});`,
  },
  {
    name: "Field Selection",
    description: "Request exactly the fields you need with full type narrowing.",
    docsPath: "/field-selection.html",
    elixir: `# Define your resource with relationships
attributes do
  uuid_primary_key :id
  attribute :title, :string, public?: true
  attribute :body, :string, public?: true
  attribute :view_count, :integer, public?: true
end

relationships do
  belongs_to :author, MyApp.User, public?: true
end

calculations do
  calculate :reading_time, :integer,
    expr(string_length(body) / 200)
end`,
    typescript: `// Only fetch what you need - response is narrowed
const posts = await listPosts({
  fields: [
    "id",
    "title",
    "readingTime",
    { author: ["name", "avatarUrl"] },
  ],
});

// TypeScript knows the exact shape:
posts.data[0].title;             // string ✓
posts.data[0].readingTime;       // number ✓
posts.data[0].author.name;       // string ✓
posts.data[0].body;              // Error! Not selected`,
  },
];

// Elixir syntax highlighting
function highlightElixir(code: string): string {
  const tokens: { start: number; end: number; cls: string }[] = [];
  const patterns: [RegExp, string][] = [
    [/#[^\n]*/g, "text-gray-500"],
    [/"[^"]*"/g, "text-yellow-400"],
    [/\b(defmodule|def|defp|do|end|use|fn|if|else|case|cond|with|for|unless|import|alias|require)\b/g, "text-pink-400"],
    [/\b(true|false|nil)\b/g, "text-purple-400"],
    [/(:[a-zA-Z_][a-zA-Z0-9_?!]*)/g, "text-cyan-400"],
    [/\b([A-Z][a-zA-Z0-9]*(\.[A-Z][a-zA-Z0-9]*)*)\b/g, "text-blue-400"],
    [/(\|>|->|<-|=>)/g, "text-pink-400"],
  ];
  for (const [re, cls] of patterns) {
    let m: RegExpExecArray | null;
    while ((m = re.exec(code)) !== null) {
      const overlaps = tokens.some(t => m!.index < t.end && m!.index + m![0].length > t.start);
      if (!overlaps) tokens.push({ start: m.index, end: m.index + m[0].length, cls });
    }
  }
  tokens.sort((a, b) => a.start - b.start);
  let result = "";
  let pos = 0;
  for (const t of tokens) {
    if (t.start > pos) result += esc(code.slice(pos, t.start));
    result += `<span class="${t.cls}">${esc(code.slice(t.start, t.end))}</span>`;
    pos = t.end;
  }
  if (pos < code.length) result += esc(code.slice(pos));
  return result;
}

// TypeScript syntax highlighting
function highlightTS(code: string): string {
  const tokens: { start: number; end: number; cls: string }[] = [];
  const patterns: [RegExp, string][] = [
    [/\/\/[^\n]*/g, "text-gray-500"],
    [/"[^"]*"/g, "text-yellow-400"],
    [/`[^`]*`/g, "text-yellow-400"],
    [/\b(import|from|export|const|let|var|function|return|if|else|async|await|new|typeof|interface|type)\b/g, "text-pink-400"],
    [/\b(true|false|null|undefined)\b/g, "text-purple-400"],
    [/(=>)/g, "text-pink-400"],
  ];
  for (const [re, cls] of patterns) {
    let m: RegExpExecArray | null;
    while ((m = re.exec(code)) !== null) {
      const overlaps = tokens.some(t => m!.index < t.end && m!.index + m![0].length > t.start);
      if (!overlaps) tokens.push({ start: m.index, end: m.index + m[0].length, cls });
    }
  }
  tokens.sort((a, b) => a.start - b.start);
  let result = "";
  let pos = 0;
  for (const t of tokens) {
    if (t.start > pos) result += esc(code.slice(pos, t.start));
    result += `<span class="${t.cls}">${esc(code.slice(t.start, t.end))}</span>`;
    pos = t.end;
  }
  if (pos < code.length) result += esc(code.slice(pos));
  return result;
}

function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Typewriter engine
function typewrite(
  el: HTMLElement,
  highlighted: string,
  onComplete: () => void,
  signal: { cancelled: boolean },
): void {
  // Build a flat list of characters with their HTML wrapping
  const chars: string[] = [];
  let inTag = false;
  let tagBuffer = "";
  let openTags: string[] = [];

  for (let i = 0; i < highlighted.length; i++) {
    const ch = highlighted[i];
    if (ch === "<") {
      inTag = true;
      tagBuffer = "<";
      continue;
    }
    if (inTag) {
      tagBuffer += ch;
      if (ch === ">") {
        inTag = false;
        if (tagBuffer.startsWith("</")) {
          openTags.pop();
        } else {
          openTags.push(tagBuffer);
        }
      }
      continue;
    }
    // Handle HTML entities as single visible characters
    let visibleChar = ch;
    if (ch === "&") {
      const semiIdx = highlighted.indexOf(";", i);
      if (semiIdx !== -1 && semiIdx - i < 8) {
        visibleChar = highlighted.slice(i, semiIdx + 1);
        i = semiIdx;
      }
    }
    let wrapped = visibleChar;
    for (const tag of openTags) {
      const cls = tag.match(/class="([^"]*)"/)?.[1] || "";
      wrapped = `<span class="${cls}">${wrapped}</span>`;
    }
    chars.push(wrapped);
  }

  let idx = 0;
  el.innerHTML = '<span class="inline-block w-[2px] h-[1.1em] bg-primary align-text-bottom animate-pulse"></span>';

  function step() {
    if (signal.cancelled) return;
    if (idx >= chars.length) {
      el.innerHTML = highlighted;
      onComplete();
      return;
    }
    // Insert character before cursor
    const cursor = el.querySelector("span:last-child")!;
    cursor.insertAdjacentHTML("beforebegin", chars[idx]);
    idx++;

    const c = chars[idx - 1];
    const isNewline = c.includes("\n") || c === "\n";
    const isSpace = c === " " || c.endsWith("> </span>");
    const delay = isNewline ? 80 : isSpace ? 15 : 25 + Math.random() * 15;
    setTimeout(step, delay);
  }
  step();
}

// Main initialization
export function initLandingPage(container: HTMLElement): () => void {
  let currentStage = 0;
  let signal = { cancelled: false };
  let autoTimer: ReturnType<typeof setTimeout> | null = null;
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  container.innerHTML = buildHTML();
  const elixirEl = container.querySelector<HTMLElement>("#elixir-code")!;
  const tsEl = container.querySelector<HTMLElement>("#ts-code")!;
  const descEl = container.querySelector<HTMLElement>("#stage-description")!;
  const docsLink = container.querySelector<HTMLAnchorElement>("#stage-docs-link")!;
  const dots = container.querySelectorAll<HTMLElement>(".stage-dot");
  const tsPanel = container.querySelector<HTMLElement>("#ts-panel")!;

  function showStage(index: number) {
    signal.cancelled = true;
    signal = { cancelled: false };
    if (autoTimer) clearTimeout(autoTimer);
    currentStage = index;
    const stage = stages[index];

    // Update dots
    dots.forEach((dot, i) => {
      dot.classList.toggle("bg-primary", i === index);
      dot.classList.toggle("opacity-100", i === index);
      dot.classList.toggle("bg-base-content", i !== index);
      dot.classList.toggle("opacity-30", i !== index);
      dot.classList.toggle("scale-125", i === index);
    });

    // Update description
    descEl.textContent = stage.description;
    docsLink.href = HEXDOCS + stage.docsPath;

    // Reset panels — hide TS panel entirely (no layout space)
    tsPanel.hidden = true;
    tsPanel.style.opacity = "0";

    const elixirHL = highlightElixir(stage.elixir);
    const tsHL = highlightTS(stage.typescript);

    if (reducedMotion) {
      elixirEl.innerHTML = elixirHL;
      tsEl.innerHTML = tsHL;
      tsPanel.hidden = false;
      tsPanel.style.opacity = "1";
      autoTimer = setTimeout(() => showStage((currentStage + 1) % stages.length), 6000);
    } else {
      typewrite(elixirEl, elixirHL, () => {
        if (signal.cancelled) return;
        tsPanel.hidden = false;
        requestAnimationFrame(() => { tsPanel.style.opacity = "1"; });
        typewrite(tsEl, tsHL, () => {
          if (signal.cancelled) return;
          autoTimer = setTimeout(() => showStage((currentStage + 1) % stages.length), 4000);
        }, signal);
      }, signal);
    }
  }

  // Dot click handlers
  dots.forEach((dot, i) => {
    dot.addEventListener("click", () => showStage(i));
  });

  // Start
  showStage(0);

  // Cleanup function
  return () => {
    signal.cancelled = true;
    if (autoTimer) clearTimeout(autoTimer);
  };
}

function buildHTML(): string {
  const dotHTML = stages.map((s, i) =>
    `<button class="stage-dot w-3 h-3 rounded-full transition-all duration-300 cursor-pointer ${i === 0 ? "bg-primary opacity-100 scale-125" : "bg-base-content opacity-30"}" title="${s.name}"></button>`
  ).join("");

  return `
    <div class="mb-12">
      <div class="flex items-center justify-between mb-4">
        <div class="flex gap-2 items-center">${dotHTML}</div>
        <a id="stage-docs-link" href="${HEXDOCS}" target="_blank" rel="noopener noreferrer" class="text-sm text-primary hover:underline">View docs &rarr;</a>
      </div>
      <p id="stage-description" class="text-sm opacity-70 mb-4">${stages[0].description}</p>
      <div class="space-y-3">
        <div class="relative">
          <div class="absolute top-2 right-3 text-xs opacity-40 font-mono select-none">Elixir</div>
          <pre class="bg-base-300 rounded-lg p-4 pt-8 text-sm font-mono leading-relaxed overflow-x-auto"><code id="elixir-code" class="text-gray-300"></code></pre>
        </div>
        <div id="ts-panel" class="relative transition-opacity duration-500" style="opacity:0" hidden>
          <div class="absolute top-2 right-3 text-xs opacity-40 font-mono select-none">TypeScript</div>
          <pre class="bg-base-300 rounded-lg p-4 pt-8 text-sm font-mono leading-relaxed overflow-x-auto"><code id="ts-code" class="text-gray-300"></code></pre>
        </div>
      </div>
    </div>`;
}
