// The sidebar as a browser's vertical tab list: each space, its tabs under it,
// and each tab's agents under the tab (sub-agents under their agent). It takes
// the place of Herdr's Spaces and Agents panels and its tab bar, and is built
// from those mods (spaces, agents, tabs) with what their jj-* clones added: a
// detached checkout shows its nearest bookmarks, and tabs and agents are named
// as tmux named windows.
// Click a space or tab to show it, an agent to focus it, a sub-agent to peek at
// it. Right-click for a space's or tab's menu, double-click a tab to rename it,
// drag spaces or tabs to reorder them. A space's chevron folds it; its + opens
// the new tab menu there. Commands: jj-sidebar.next / .prev step down or up the
// list a tab at a time; .waiting-next / .waiting-prev go to the next or previous
// agent that needs you (blocked or done).
// props { footer: true }: the sidebar's footer instead (Settings, the Files and
// Changes panels the tab bar had, Add machine).

import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, machines, panes, agents, terminals, focused, run, openOverlay, notify, exec, hc, home, theme, shared, setShared, setAgentOrder, watchFolder, nextCommand, window, layout, props, updates } from "herdr";
import { status as jjStatus } from "./jj.js";

// Prints "[repo] workspace/subfolder" for a folder in a jj workspace or git worktree.
const JJ_TITLE = "@jjTitle@";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar's rail goes by its width, not a flag: dragging its edge narrows it too.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// To the rail (on macOS wide enough for the traffic lights), or back to the width it had.
function toggleSidebar() {
  const width = find(layout(), "sidebar")?.size?.px;
  if (!narrow()) setShared("sidebar.width", width);
  // Mods edited before the rail went by width still read the flag.
  setShared("sidebar.collapsed", !narrow());
  run("layout.resize", { id: "sidebar", px: narrow() ? (shared("sidebar.width") ?? 268) : window()?.platform === "macos" ? 76 : 44 });
}

// Where a space is now: its first terminal's live folder, else where it was made.
// `ps`: panes(), read once by the caller (each read copies every pane).
function place(s, ps) {
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return ps.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
}
const where = (s, ps) => JSON.stringify([s.machine ?? null, place(s, ps)]);
const base = (path) => path.replace(/\/+$/, "").split("/").pop();
// Changes made outside Herdr (an editor's save, a commit in another app): looked
// for this often, in repos the list shows, while the window is in front.
const FALLBACK = 60000;

// What a stored color name looks like on an avatar (the same in every mod
// that draws space avatars): one strong color per hue, light and dark alike.
const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };
const PALETTE = ["ansi6", "ansi3", "ansi4", "ansi5", "ansi2", "ansi1"];

// Columns: a space's fold chevron, then its avatar, then its name. A tab's
// icon sits under the avatar and its name under the space's; an agent's icon
// under the tab's name, a sub-agent's tree line under the agent's icon.
const TAB_IN = 24;
const AGENT_IN = 50;
const SUB_IN = 56;
// An agent row's first line, which its icon, state and time sit beside.
const LINE = 18;

// Long titles and messages wrap, but only so far.
const clip = (s, n) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);

// A blocked agent's report says what on (OSC 7501 `kind`).
const BLOCKED = { permission: "Wants permission", question: "Has a question", auth: "Needs a login" };

const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();

// The agent's own title (Claude Code names its session), unless it only says the program or a folder.
// Codex ends it with " | <project>", a folder on its path: the space and tab say that.
function told(a, cwd) {
  let live = clean(a.title);
  const tail = / \| ([^|/]+)$/.exec(live);
  if (tail && cwd?.split("/").includes(tail[1])) live = live.slice(0, tail.index);
  const bare = !live || live === a.program?.name || live.toLowerCase() === a.program?.key || /^[~/]|^[A-Za-z]:\\/.test(live) || live.includes("@");
  return bare ? null : live;
}

const RANK = { blocked: 4, done: 3, working: 2, idle: 1 };
// A sub-agent without a pane isn't in agents(): its raw word, error counting as
// blocked. It's never done: it reports to its parent, and the parent's done is the news.
const kidStatus = (k, listed) => {
  const s = listed.get(k.address) ?? k.status;
  return s === "error" ? "blocked" : s === "done" ? "idle" : s;
};

function duration(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return "<1m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

// A program's icon from the app's program table: a one-color glyph or a picture.
function icon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint ? svg(p.icon).size(size).flex_none().text_color(color) : image(p.icon).w(size).h(size).flex_none();
}

// Where a dragged space or tab will land: above the row moving up, below it moving down.
const dropLine = (t, below) => div().absolute().left(0).right(0).h(2).bg(t.accent)
  .when(below, (l) => l.bottom(0))
  .when(!below, (l) => l.top(0));

const stop = (_e, cx) => cx.stop_propagation();

export default class Sidebar extends View {
  init(_props, cx) {
    if (props()?.footer) {
      // The side panel each space had open (as the tab bar remembered it).
      this.panels = JSON.parse(localStorage.getItem("panels") ?? "{}");
      return;
    }
    this.git = {}; // where() -> { name, branch, ahead, behind, repo, linked }, null: not a repo
    this.checked = {}; // where() -> when it was last looked at
    this.unsure = new Set(); // where()s git couldn't answer for (a machine away)
    this.pending = new Set(); // where()s to look at next
    this.busy = {}; // pane -> an agent working or a program in front of its shell
    this.ready = {}; // machine -> its layout was readable at the last look
    this.at = {}; // space -> its where() at the last look
    this.watching = new Set(); // local repos' git folders
    // Spaces made while this runs wait (at most a moment) for their git, so a
    // worktree appears under its repo instead of jumping there.
    this.shown = new Set(spaces().map((s) => s.id));
    this.born = {};
    this.machines = [];
    this.foldedMachines = new Set(JSON.parse(localStorage.getItem("machines.folded") ?? "[]"));
    this.folded = new Set(JSON.parse(localStorage.getItem("spaces.folded") ?? "[]")); // spaces
    this.foldedAgents = new Set(); // agents whose sub-agents are hidden
    this.drag = null; // { kind: "space", i } or { kind: "tab", space, i }: what the pointer pressed
    this.over = null; // the index it's over, in the same machine or space
    this.hovered = null; // the tab under the pointer: it shows its close button
    // Each agent's last state and when it changed (ms), kept across restarts.
    this.changed = JSON.parse(localStorage.getItem("changed") ?? "{}");
    // Each folder's checkout, { repo, rest }, or null outside one or until read.
    this.places = new Map();
    this.refreshMachines(cx);
    cx.timer.every(15000, (cx) => this.refreshMachines(cx));
    // `git status` walks the whole tree, on another machine a process there:
    // only when its answer could have changed (see `due`).
    cx.timer.every(250, (cx) => this.checkNew(cx));
    // The agents' "3m".
    cx.timer.every(30000, (cx) => cx.notify());
    // Keys bound to jj-sidebar.<command>.
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (c === "next" || c === "prev") this.step(c === "next" ? 1 : -1);
        else if (c === "waiting-next" || c === "waiting-prev") this.waiting(c === "waiting-next" ? 1 : -1);
        cx.notify();
      }
    });
  }

  // To the next (or previous) agent that needs you, blocked or done, in the
  // list's order and round at the ends, as agent.next goes through them all.
  waiting(dir) {
    const live = new Map(agents().map((a) => [a.address, a]));
    const list = (this.agentOrder ?? []).map((addr) => live.get(addr)).filter(Boolean);
    const len = list.length;
    const at = list.findIndex((a) => a.focused);
    const start = at < 0 ? (dir > 0 ? -1 : len) : at;
    for (let n = 1; n <= len; n++) {
      const a = list[(((start + dir * n) % len) + len) % len];
      if (!a.focused && (a.status === "blocked" || a.status === "done")) return run("pane.focus", { pane: a.pane });
    }
    notify({ title: "No agent is waiting", level: "info", timeout: 2000 });
  }

  // Down or up the list a tab at a time, on into the next space and round at the
  // ends, as a browser's vertical tabs go. A folded space is one stop: its shown tab.
  step(dir) {
    const stops = this.ordered(spaces(), panes()).flatMap(({ w }) => {
      const tabs = w.tabs.filter((c) => !c.settled);
      return this.folded.has(w.id) ? [{ w, c: tabs.find((c) => c.active) ?? tabs[0] }] : tabs.map((c) => ({ w, c }));
    }).filter((s) => s.c);
    if (!stops.length) return;
    const at = stops.findIndex((s) => s.w.active && (s.c.active || this.folded.has(s.w.id)));
    const i = at < 0 ? (dir > 0 ? 0 : stops.length - 1) : (at + dir + stops.length) % stops.length;
    this.select(stops[i].w, stops[i].c);
  }

  // ---- Spaces' git, as Herdr's spaces mod ----

  checkNew(cx) {
    const now = Date.now();
    const sp = spaces();
    for (const s of sp) if (!this.shown.has(s.id)) this.born[s.id] ??= now;
    const due = this.due(now, sp, panes());
    if (due.size) this.refreshGit(due, cx);
    if (sp.some((s) => !this.shown.has(s.id))) cx.notify();
  }

  // Places whose git could have changed: new ones (a new space, a cd), where a
  // command or an agent's turn just ended (a checkout, a commit, edits), those on
  // a machine that is back, and repos in view whose fallback is due.
  due(now, sp, ps) {
    // Moved there: what it knew of that place may be old.
    const at = {};
    for (const s of sp) at[s.id] = where(s, ps);
    const keys = new Set(Object.values(at).filter((k) => JSON.parse(k)[1]));
    const due = new Set([...keys].filter((k) => !(k in this.git)));
    for (const [id, k] of Object.entries(at)) if (this.at[id] && this.at[id] !== k && keys.has(k)) due.add(k);
    this.at = at;
    const spaceOf = {};
    for (const s of sp) for (const t of s.tabs ?? []) spaceOf[t.id] = s;
    const busy = {};
    for (const p of ps) {
      if (!p.terminal || !spaceOf[p.tab]) continue;
      busy[p.pane] = p.status === "working" || !(p.program?.shell || p.program?.agent);
      if (this.busy[p.pane] && !busy[p.pane]) this.sameRepo(at[spaceOf[p.tab].id], keys).forEach((k) => due.add(k));
    }
    this.busy = busy;
    for (const m of machines()) {
      const ready = m.layout === "ready";
      if (ready && this.ready[m.name] === false) for (const k of keys) if (JSON.parse(k)[0] === m.name) due.add(k);
      this.ready[m.name] = ready;
    }
    if (window().active) {
      for (const k of keys) {
        const asks = this.git[k] || this.unsure.has(k);
        if (asks && !this.foldedMachines.has(JSON.parse(k)[0]) && now - (this.checked[k] ?? 0) > FALLBACK) due.add(k);
      }
    }
    return due;
  }

  // `key` and the other places in its repo (a commit there moves their ahead/behind).
  sameRepo(key, keys) {
    const repo = this.git[key]?.repo;
    return [key, ...(repo ? [...keys].filter((k) => this.git[k]?.repo === repo) : [])];
  }

  refreshMachines(cx) {
    cx.spawn(async (cx) => {
      try {
        const r = await hc(["machine", "ls", "--json"]);
        if (r.code === 0) this.machines = (JSON.parse(r.stdout).machines ?? []).filter((m) => !m.temporary);
      } catch {}
      cx.notify();
    });
  }

  // One look at a time, each place once however often it was asked for meanwhile.
  refreshGit(keys, cx) {
    for (const k of keys) this.pending.add(k);
    if (this.refreshing) return;
    this.refreshing = true;
    cx.spawn(async (cx) => {
      while (this.pending.size) {
        const keys = [...this.pending];
        this.pending.clear();
        for (const key of keys) await this.check(key, cx);
      }
      const used = new Set(Object.values(this.git).filter(Boolean).map((g) => JSON.parse(g.repo)).filter(([on]) => !on).map(([, repo]) => repo));
      for (const repo of this.watching) if (!used.has(repo)) this.watching.delete(repo);
      this.refreshing = false;
      cx.notify();
    });
  }

  // One place's git: branch, ahead/behind, its repo.
  async check(key, cx) {
    const [on, cwd] = JSON.parse(key);
    this.checked[key] = Date.now();
    this.unsure.delete(key);
    try {
      // No optional locks: a status that touched the index would wake the watch again.
      // Writes nothing under .git (index lock, fsmonitor cookie): watch() would wake on it.
      const r = await exec("git", ["--no-optional-locks", "-c", "core.fsmonitor=false", "status", "--porcelain=v2", "--branch"], { cwd, on });
      if (r.code !== 0) {
        // Only git's own "no" is remembered as no repo; anything else is asked again.
        if (!/not a git repository/i.test(r.stderr)) this.unsure.add(key);
        this.git[key] = null;
        return;
      }
      // The repo's own .git folder names it; a worktree's top differs from it.
      const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd, on });
      const common = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd, on });
      const repo = common.stdout.trim();
      const name = repo.endsWith("/.git") ? base(repo.slice(0, -5)) : base(repo).replace(/\.git$/, "");
      const info = { name, branch: null, ahead: 0, behind: 0, repo: JSON.stringify([on, repo]), linked: repo !== `${top.stdout.trim()}/.git` };
      for (const line of r.stdout.split("\n")) {
        if (line.startsWith("# branch.head ")) info.branch = line.slice(14);
        else if (line.startsWith("# branch.ab ")) {
          const [a, b] = line.slice(12).split(" ");
          info.ahead = Math.abs(parseInt(a, 10)) || 0;
          info.behind = Math.abs(parseInt(b, 10)) || 0;
        }
      }
      // jj keeps git's HEAD detached: its nearest bookmarks and trunk() say more.
      if (info.branch === "(detached)") Object.assign(info, (await jjStatus(cwd, on).catch(() => null)) ?? {});
      this.git[key] = info;
      if (!on) this.watch(repo, cx);
    } catch {
      // Couldn't ask (the machine is away): keep what it showed, look again later.
      this.git[key] ??= null;
      this.unsure.add(key);
    }
  }

  watch(repo, cx) {
    if (this.watching.has(repo)) return;
    this.watching.add(repo);
    cx.spawn(async (cx) => {
      try {
        while (this.watching.has(repo)) {
          await watchFolder(repo);
          const mine = JSON.stringify([null, repo]);
          if (this.watching.has(repo)) this.refreshGit(Object.keys(this.git).filter((k) => this.git[k]?.repo === mine), cx);
        }
      } catch {
        this.watching.delete(repo);
      }
    });
  }

  // ---- Names ----

  // A folder's checkout. Read once per folder, and not asked again when it
  // fails: a machine without jj-title (it's in this Mac's nix store) would be
  // asked on every render.
  checkout(cwd, on, cx) {
    if (!cwd) return null;
    const key = `${on ?? ""}\u0000${cwd}`;
    if (!this.places.has(key)) {
      this.places.set(key, null);
      cx.spawn(async (cx) => {
        try {
          const r = await exec(JJ_TITLE, [cwd], { on });
          const m = r.code === 0 && /^\[(.+?)\](?: (.+))?$/.exec(r.stdout.trim());
          if (m) this.places.set(key, { repo: m[1], rest: m[2] ?? null });
        } catch {}
        cx.notify();
      });
    }
    return this.places.get(key);
  }

  // A tab nobody named says its checkout, as tmux named windows: where its
  // focused pane is (else its agent's, else its first's). Below the space's own
  // place, only the rest ("web"); otherwise the checkout ("complement · aptean"),
  // without the repo in a space named for it ("aptean"). A tab the + menu named
  // after its agent ("Claude Code") counts as unnamed.
  tabName(w, c, mine, lead, ctx) {
    if (c.named && c.name !== lead?.program?.name) return c.name;
    const cwds = mine.filter((p) => p.cwd);
    const here = (cwds.find((p) => p.focused) ?? cwds.find((p) => p.program?.agent) ?? cwds[0])?.cwd;
    const at = this.checkout(here, w.machine, ctx.cx);
    if (!at) return lead?.program?.name ?? "Terminal";
    const home = this.checkout(place(w, ctx.ps), w.machine, ctx.cx);
    const parts = (x) => [x.repo, ...(x.rest ?? "").split("/").filter(Boolean)];
    const left = parts(at), said = home ? parts(home) : [];
    let n = 0;
    while (n < said.length && n < left.length && left[n] === said[n]) n++;
    if (n > 0 && n < left.length) return left.slice(n).join("/");
    return !at.rest ? at.repo : w.name === at.repo ? at.rest : `${at.repo} · ${at.rest}`;
  }

  // Where an agent works: its checkout ("complement · aptean"), else its folder.
  workspace(cwd, on, cx) {
    const at = this.checkout(cwd, on, cx);
    if (at) return at.rest ? `${at.repo} · ${at.rest}` : at.repo;
    const h = home();
    return cwd && h && (cwd === h || cwd.startsWith(`${h}/`)) ? `~${cwd.slice(h.length)}` : cwd;
  }

  // ---- Agents ----

  // Stamps agents whose state changed. Done and idle count as one: looking at a
  // finished agent turns done into idle, and looking isn't the agent doing anything.
  track(list, now) {
    let dirty = false;
    for (const a of list) {
      const s = a.status === "done" ? "idle" : a.status;
      if (this.changed[a.address]?.s === s) continue;
      this.changed[a.address] = { s, at: now };
      dirty = true;
    }
    if (!dirty) return;
    // Gone and old: the list alone is empty right after a start.
    const listed = new Set(list.map((a) => a.address));
    for (const [k, c] of Object.entries(this.changed)) if (!listed.has(k) && now - c.at > 30 * 86400000) delete this.changed[k];
    localStorage.setItem("changed", JSON.stringify(this.changed));
  }

  since(a) {
    return this.changed[a.address]?.at ?? 0;
  }

  // Live sub-agents of `addr`, depth first, each with the tree lines in front of it.
  tree(all, addr, lead = []) {
    const kids = all.filter((k) => k.parent === addr && k.state === "live");
    return kids.flatMap((k, i) => {
      const last = i === kids.length - 1;
      return [{ t: k, lines: [...lead, last ? "└" : "├"] }, ...this.tree(all, k.address, [...lead, last ? "" : "│"])];
    });
  }

  // compact: a ! for blocked where a row has no room for "Needs you".
  status(t, st, compact = false) {
    if (st === "working") return svg("mods/workspace-chrome/spinner.svg").size(12).mx(1).flex_none().text_color(t.working).spin(900);
    if (st === "blocked" && compact) return div().size(14).flex_none().rounded(4).bg(t.blocked + "26").text_size(10.5).font_bold().text_color(t.blocked).flex().items_center().justify_center().child("!");
    if (st === "blocked") return div().flex_none().px(6).h(18).rounded(5).bg(t.blocked + "26").text_size(10.5).font_semibold().text_color(t.blocked).flex().items_center().child("Needs you");
    // Idle: a ring; done: a dot.
    if (st === "idle") return div().size(7).mx(3).flex_none().rounded(4).border(1.5).border_color(t.idle ?? t.dim);
    return div().size(7).mx(3).flex_none().rounded(4).bg(st === "done" ? t.done : t.dim + "00");
  }

  // The fold chevron for an agent's sub-agents; folded, their count too, colored by the most urgent.
  fold(a, subs, t) {
    const sts = subs.map((s) => kidStatus(s.t, this.listed));
    const top = sts.reduce((m, s) => ((RANK[s] ?? 0) > (RANK[m] ?? 0) ? s : m), null);
    const open = !this.foldedAgents.has(a.address);
    return div()
      .id(`agent-fold-${a.address}`)
      .h(18)
      .px(3)
      .gap(3)
      .flex()
      .flex_none()
      .items_center()
      .rounded(4)
      .text_size(11)
      .text_color(open ? t.dim : (t[top] ?? t.dim))
      .cursor_pointer()
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => {
        cx.stop_propagation();
        open ? this.foldedAgents.add(a.address) : this.foldedAgents.delete(a.address);
        cx.notify();
      })
      .child(svg(`mods/workspace-chrome/chevron-${open ? "down" : "right"}.svg`).size(11).flex_none())
      .when(!open, (el) => el.child(String(subs.length)));
  }

  // ---- Rows ----

  menu(w) {
    // A popup is as tall as its items; height is only the most.
    openOverlay({ mod: "jj-menu", kind: "popup", width: 200, height: 260, props: { tab: "space", target: { id: w.id } } });
  }

  select(w, c) {
    if (!w.active) run("space.select", { id: w.id });
    run("tab.select", { id: c.id });
  }

  avatar(w, t) {
    const color = (shared("space.colors") ?? {})[w.id] ?? "ansi6";
    const fill = color.startsWith("#") ? color : (MARK[color] ?? t[color]);
    return h_flex().size(18).flex_none().rounded(5).bg(fill).items_center().justify_center().text_size(10.5).font_bold().text_color("#ffffff").child([...w.name][0]?.toUpperCase() ?? "?");
  }

  // Each space keeps a color; new ones take the least used.
  assignColors() {
    const ids = new Set(spaces().map((p) => p.id));
    const stored = shared("space.colors") ?? {};
    const kept = Object.fromEntries(Object.entries(stored).filter(([id]) => ids.has(id)));
    let changed = Object.keys(kept).length !== Object.keys(stored).length;
    for (const p of spaces()) {
      if (kept[p.id] || p.name === "~") continue;
      const uses = (c) => Object.values(kept).filter((v) => v === c).length;
      kept[p.id] = PALETTE.reduce((best, c) => (uses(c) < uses(best) ? c : best));
      changed = true;
    }
    if (changed) setShared("space.colors", kept);
  }

  // Spaces in order, each worktree space moved under its main checkout's.
  ordered(sp, ps) {
    const ready = (w) => this.shown.has(w.id) || where(w, ps) in this.git || Date.now() - (this.born[w.id] ??= Date.now()) > 1500;
    for (const w of sp) if (!this.shown.has(w.id) && ready(w)) this.shown.add(w.id);
    const list = sp.map((w, i) => ({ w, i, g: this.git[where(w, ps)] ?? null })).filter((r) => this.shown.has(r.w.id));
    const mains = new Set(list.filter((r) => r.g && !r.g.linked).map((r) => r.g.repo));
    const nested = (r) => r.g?.linked && mains.has(r.g.repo);
    const out = [];
    const placed = new Set(); // repos whose worktrees are listed (under the first of its spaces)
    for (const r of list) {
      if (nested(r)) continue;
      out.push({ ...r, tree: false });
      if (!r.g || r.g.linked || placed.has(r.g.repo)) continue;
      placed.add(r.g.repo);
      for (const k of list) if (nested(k) && k.g.repo === r.g.repo) out.push({ ...k, tree: true });
    }
    return out;
  }

  // The rows, under a header per machine once one isn't this computer.
  grouped(rows, t, collapsed, ctx) {
    const drawAll = (list) => list.flatMap((r, n) => (collapsed ? [this.compact(r, t)] : this.spaceRows(r, t, ctx, n === 0)));
    const remote = [...new Set([...rows.map((r) => r.w.machine).filter(Boolean), ...this.machines.map((m) => m.name)])].sort();
    const loading = (m) => {
      const layout = machines().find((k) => k.name === m)?.layout;
      return layout === "loading" || (!layout && this.machines.some((k) => k.name === m && k.state === "connected"))
        || spaces().some((s) => (s.machine ?? null) === m && !this.shown.has(s.id));
    };
    const loadingRow = (m) => div().id(`machine-loading-${m ?? "local"}`).h(28).flex_none().px(8).text_size(12).text_color(t.dim).child(collapsed ? "…" : "Loading…");
    if (!remote.length) return loading(null) && !rows.length ? [loadingRow(null)] : drawAll(rows);
    return [null, ...remote].flatMap((m) => {
      const mine = rows.filter((r) => (r.w.machine ?? null) === m);
      const machine = this.machines.find((k) => k.name === m);
      const connected = !m || machine?.state === "connected";
      const folded = this.foldedMachines.has(m);
      const head = h_flex().id(`machine-${m ?? "local"}`).h(26).flex_none().px(collapsed ? 2 : 8).gap(7).items_center().text_size(11).text_color(t.dim)
        .cursor_pointer().hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => {
          folded ? this.foldedMachines.delete(m) : this.foldedMachines.add(m);
          localStorage.setItem("machines.folded", JSON.stringify([...this.foldedMachines]));
          cx.notify();
        })
        .child(svg(`mods/workspace-chrome/${m ? "server" : "monitor"}.svg`).size(13).flex_none())
        .when(!collapsed, (el) => el.child(div().flex_1().truncate().child(m ?? "This computer"))
          .when(!connected, (el) => el.child(div().flex_none().child((machine?.state ?? "asleep").replace(/_/g, " "))))
          .when(connected, (el) => el.child(div().id(`machine-add-${m ?? "local"}`).flex_none().px(4).rounded(4).hover((s) => s.bg(t.hover).text_color(t.foreground))
            .on_click((_e, cx) => { cx.stop_propagation(); run("space.new", m ? { machine: m } : {}); }).child("+")))
          .child(div().size(6).rounded(3).flex_none().bg(connected ? t.ansi2 : t.dim))
          .child(svg(`mods/workspace-chrome/chevron-${folded ? "right" : "down"}.svg`).size(11).flex_none()));
      const empty = h_flex().id(`machine-new-${m ?? "local"}`).h(28).flex_none().px(8).gap(7).items_center().rounded(7)
        .text_size(12).text_color(t.dim).hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click(() => run("space.new", m ? { machine: m } : {}))
        .child(svg("mods/workspace-chrome/plus.svg").size(12)).when(!collapsed, (el) => el.child("New space there"));
      return [head, ...(folded ? [] : mine.length ? drawAll(mine) : [loading(m) ? loadingRow(m) : empty])];
    });
  }

  // A space, then (unless folded) each of its tabs with that tab's agents under it.
  spaceRows(r, t, ctx, first) {
    const out = [this.spaceRow(r, t, first)];
    if (this.folded.has(r.w.id)) return out;
    r.w.tabs.forEach((c, idx) => {
      // Settled tabs are put away on this screen; Herdr brings one back when it needs you.
      if (c.settled) return;
      out.push(this.tabRow(r.w, c, idx, t, ctx));
      for (const a of ctx.byTab.get(c.id) ?? []) out.push(...this.agentRows(r.w, a, t, ctx));
    });
    return out;
  }

  // Only what's unusual, after the name: "herdr · spike ↑2 ↓1". The repo or
  // branch goes when the name already says it (a worktree is named after its branch),
  // and master/main go: nearly every space is on one.
  gitTail(g, tree, name, t) {
    const raw = g.branch ?? "detached";
    const same = (a) => a.toLowerCase() === name.toLowerCase();
    const branch = same(raw) || raw === "master" || raw === "main" ? "" : raw;
    const repo = tree || same(g.name) ? "" : g.name;
    const where = [repo, branch].filter(Boolean).join(" · ");
    return h_flex()
      .flex_1()
      .min_w(0)
      .gap(5)
      .justify_end()
      .items_center()
      .text_size(11.5)
      .text_color(t.dim)
      .when(Boolean(where), (el) => el.child(div().min_w(0).truncate().child(where)))
      .when(g.ahead > 0, (el) => el.child(div().flex_none().text_color(t.ansi2).child(`↑${g.ahead}`)))
      .when(g.behind > 0, (el) => el.child(div().flex_none().text_color(t.ansi1).child(`↓${g.behind}`)));
  }

  // A space's row heads its group, a worktree's with the branch icon in place of the
  // avatar. Its tabs carry the highlight; folded, it does, and says its agents' state.
  spaceRow({ w, i, g, tree }, t, first) {
    const folded = this.folded.has(w.id);
    const d = this.drag?.kind === "space" ? this.drag : null;
    const lit = w.active && folded;
    const st = folded && w.status !== "idle" ? w.status : null;
    return h_flex()
      .relative()
      .id(`space-${w.id}`)
      .when(!first, (el) => el.mt(tree ? 2 : 8))
      .h(30)
      .pl(2)
      .pr(4)
      .gap(8)
      .flex_none()
      .items_center()
      .rounded(8)
      .when(lit, (el) => el.bg(t.selected))
      .when(!lit, (el) => el.hover((s) => s.bg(t.hover)))
      .when(d?.i === i && this.over !== i, (el) => el.opacity(0.5))
      .when(Boolean(d) && this.over === i && d?.i !== i, (el) => el.child(dropLine(t, d.i < i)))
      .on_mouse_down("left", () => {
        this.drag = { kind: "space", i };
        this.over = i;
      })
      .on_mouse_move((_e, cx) => {
        if (this.drag?.kind !== "space") return;
        const source = spaces()[this.drag.i];
        const over = source && (source.machine ?? null) === (w.machine ?? null) ? i : null;
        if (this.over !== over) {
          this.over = over;
          cx.notify();
        }
      })
      .on_mouse_up("left", (_e, cx) => {
        const from = this.drag?.kind === "space" ? this.drag.i : null;
        const over = this.over;
        this.drag = null;
        this.over = null;
        if (from !== null && over === i && from !== i) run("space.move", { id: spaces()[from].id, index: i + 1 });
        else if (from === i) run("space.select", { id: w.id });
        cx.notify();
      })
      .on_mouse_down("right", () => this.menu(w))
      // Its own target, so clicking a space's name never hides its tabs.
      .child(div()
        .id(`fold-${w.id}`)
        .w(14)
        .h(18)
        .flex_none()
        .flex()
        .items_center()
        .justify_center()
        .rounded(4)
        .text_color(t.dim)
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_mouse_down("left", stop)
        .on_click((_e, cx) => {
          cx.stop_propagation();
          folded ? this.folded.delete(w.id) : this.folded.add(w.id);
          localStorage.setItem("spaces.folded", JSON.stringify([...this.folded]));
          cx.notify();
        })
        .child(svg(`mods/workspace-chrome/chevron-${folded ? "right" : "down"}.svg`).size(11)))
      .child(tree
        ? h_flex().size(18).flex_none().items_center().justify_center().child(svg("mods/workspace-chrome/branch.svg").size(13).text_color(t.dim))
        : this.avatar(w, t))
      .child(div().flex_shrink(0).max_w(180).truncate().font_medium().text_color(t.foreground).child(w.name))
      .child(g ? this.gitTail(g, tree, w.name, t) : div().flex_1())
      .when(Boolean(st), (el) => el.child(this.status(t, st, true)))
      .child(div()
        .id(`new-tab-${w.id}`)
        .size(20)
        .flex_none()
        .flex()
        .items_center()
        .justify_center()
        .rounded(5)
        .text_color(t.dim)
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .tooltip("New tab")
        .on_mouse_down("left", stop)
        .on_click((_e, cx) => {
          cx.stop_propagation();
          // The menu starts things in the shown space.
          if (!w.active) run("space.select", { id: w.id });
          openOverlay({ mod: "jj-new-menu", kind: "popup", width: 250, height: 512 });
        })
        .child(svg("mods/workspace-chrome/plus.svg").size(12)));
  }

  // A tab: its program's icon and name; the shown one is highlighted, unless
  // the focus is on one of its agents, which then is; it or the one under the
  // pointer has a close button.
  tabRow(w, c, idx, t, ctx) {
    const mine = ctx.ps.filter((p) => p.tab === c.id);
    const lead = mine.find((p) => p.program?.agent) ?? mine.find((p) => p.focused) ?? mine[0];
    const name = this.tabName(w, c, mine, lead, ctx);
    const shown = w.active && c.active;
    const lit = shown && !(ctx.byTab.get(c.id) ?? []).some((a) => a.focused);
    const d = this.drag?.kind === "tab" && this.drag.space === w.id ? this.drag : null;
    const pic = icon(lead?.program, 14, shown ? t.foreground : t.muted);
    return h_flex()
      .relative()
      .id(`tab-${c.id}`)
      .h(28)
      .pl(TAB_IN)
      .pr(4)
      .gap(8)
      .flex_none()
      .items_center()
      .rounded(8)
      .text_color(shown ? t.foreground : t.muted)
      .when(lit, (el) => el.bg(t.selected))
      .when(!lit, (el) => el.hover((s) => s.bg(t.hover)))
      .when(d?.i === idx && this.over !== idx, (el) => el.opacity(0.5))
      .when(Boolean(d) && this.over === idx && d?.i !== idx, (el) => el.child(dropLine(t, d.i < idx)))
      .on_hover((on, cx) => {
        if (on) this.hovered = c.id;
        else if (this.hovered === c.id) this.hovered = null;
        cx.notify();
      })
      .on_mouse_down("left", (e) => {
        this.drag = { kind: "tab", space: w.id, i: idx };
        this.over = idx;
        if (e.click_count === 2) run("tab.rename", { id: c.id });
      })
      .on_mouse_move((_e, cx) => {
        if (this.drag?.kind !== "tab") return;
        const over = this.drag.space === w.id ? idx : null;
        if (this.over !== over) {
          this.over = over;
          cx.notify();
        }
      })
      .on_mouse_up("left", (_e, cx) => {
        const from = this.drag?.kind === "tab" && this.drag.space === w.id ? this.drag.i : null;
        const over = this.over;
        this.drag = null;
        this.over = null;
        if (from !== null && over === idx && from !== idx) run("tab.move", { id: w.tabs[from].id, index: idx + 1 });
        else if (from === idx) this.select(w, c);
        cx.notify();
      })
      .on_mouse_down("right", () => openOverlay({ mod: "jj-menu", kind: "popup", width: 200, props: { tab: "tab", target: { id: c.id, space: w.id } } }))
      .child(h_flex().w(18).h(18).flex_none().items_center().justify_center()
        .child(pic ?? svg("mods/workspace-chrome/terminal.svg").size(14).text_color(t.dim)))
      .child(div().flex_1().min_w(0).truncate().child(name))
      .when(c.zoomed, (el) => el.child(div().flex_none().text_size(10.5).text_color(t.dim).child("Z")))
      .when(shown || this.hovered === c.id, (el) => el.child(div()
        .id(`close-${c.id}`)
        .size(20)
        .flex_none()
        .flex()
        .items_center()
        .justify_center()
        .rounded(5)
        .text_color(t.dim)
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_mouse_down("left", stop)
        .on_click((_e, cx) => {
          cx.stop_propagation();
          run("tab.close", { id: c.id });
        })
        .child(svg("mods/pane/close.svg").size(12))));
  }

  // An agent and (unless folded) its live sub-agents.
  agentRows(w, a, t, ctx) {
    const subs = this.tree(ctx.all, a.address);
    const row = this.agentRow(w, a, subs, t, ctx);
    return this.foldedAgents.has(a.address) ? [row] : [row, ...subs.map((s) => this.subRow(s, t, ctx))];
  }

  // What an agent says it's doing now (Claude Code reports its current step),
  // what it's blocked on, and how far along it is.
  doing(a, report) {
    const kind = a.status === "blocked" ? BLOCKED[report?.kind] : null;
    const msg = typeof report?.msg === "string" ? report.msg.trim() : "";
    const busy = a.status === "working" || a.status === "blocked";
    const progress = busy && Number.isFinite(report?.progress) ? `${report.progress}%` : null;
    return [kind, msg, progress].filter(Boolean).join(" · ") || null;
  }

  // Lines: the agent's own title (else its program), wrapped rather than cut;
  // its workspace; what it's doing now, when it says. On the first line's
  // right: how long it's been like this, and its state.
  agentRow(w, a, subs, t, ctx) {
    const pic = icon(a.program, 14, t.foreground);
    const cwd = ctx.cwds.get(a.pane);
    const name = told(a, cwd) ?? a.program?.name ?? a.tab_name;
    const ws = this.workspace(cwd, w.machine, ctx.cx);
    const now = this.doing(a, ctx.reports.get(a.address));
    const idle = a.status === "idle" && !a.focused;
    const when = this.since(a);
    // An agent on another machine (`vps/t7`) says which.
    const machine = a.address.includes("/") ? a.address.split("/")[0] : null;
    return h_flex()
      .id(`ag-${a.address}`)
      .py(5)
      .pl(AGENT_IN)
      .pr(8)
      .gap(8)
      .flex_none()
      .items_start()
      .rounded(8)
      .text_size(12.5)
      .cursor_pointer()
      .when(a.focused, (el) => el.bg(t.selected))
      .when(!a.focused, (el) => el.hover((s) => s.bg(t.hover)))
      .on_click(() => run("pane.focus", { pane: a.pane }))
      .when(Boolean(pic), (el) => el.child(h_flex().h(LINE).flex_none().items_center().child(pic)))
      .child(v_flex().flex_1().min_w(0).gap(1)
        .child(div().text_color(idle ? t.muted : t.foreground).child(clip(name, 120)))
        .when(Boolean(ws), (el) => el.child(h_flex().min_w(0).gap(4).items_center().text_size(11.5).text_color(t.dim)
          .child(svg("mods/workspace-chrome/branch.svg").size(11).flex_none())
          .child(div().min_w(0).truncate().child(ws))))
        .when(Boolean(now), (el) => el.child(div().text_size(11.5).text_color(a.status === "blocked" ? t.blocked : t.muted).child(clip(now, 160)))))
      .child(h_flex().h(LINE).flex_none().gap(8).items_center()
        .when(Boolean(machine), (el) => el.child(div().flex_none().text_size(10).text_color(t.dim).child(machine)))
        .when(subs.length > 0, (el) => el.child(this.fold(a, subs, t)))
        .when(Boolean(when) && a.status !== "blocked", (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child(duration(ctx.now - when))))
        .child(this.status(t, a.status)));
  }

  subRow(s, t, ctx) {
    const k = s.t;
    const pic = icon(k.program, 14, t.foreground);
    const on = k.address === ctx.peeked;
    return h_flex()
      .id(`sub-${k.address}`)
      .h(26)
      .pl(SUB_IN)
      .pr(8)
      .flex_none()
      .items_center()
      .rounded(8)
      .text_size(12.5)
      .when(on, (el) => el.bg(t.raised))
      .hover((s) => s.bg(t.hover))
      .on_click(() => run("terminal.peek", { terminal: k.address }))
      .children(s.lines.map((l) => div().self_start().mt(-4).w(9).h(17).mr(4).flex_none()
        .when(Boolean(l), (el) => el.border_l(1.5).border_color(t.input))
        .when(l === "└" || l === "├", (el) => el.border_b(1.5).rounded_bl(6))))
      .when(Boolean(pic), (el) => el.child(div().mr(8).child(pic)))
      .child(div().flex_1().min_w(0).truncate().text_color(on ? t.foreground : t.muted).child(k.name || k.template || k.program?.name || k.address))
      .child(this.status(t, kidStatus(k, this.listed), true));
  }

  // On the rail: each space's avatar, with a dot when something in it needs you or works.
  compact({ w }, t) {
    const st = w.status && w.status !== "idle" ? w.status : null;
    return h_flex()
      .id(`space-${w.id}`)
      .h(30)
      .flex_none()
      .items_center()
      .justify_center()
      .rounded(8)
      .when(w.active, (el) => el.bg(t.selected))
      .when(!w.active, (el) => el.hover((s) => s.bg(t.hover)))
      .on_click(() => run("space.select", { id: w.id }))
      .on_mouse_down("right", () => this.menu(w))
      .child(div().relative().child(this.avatar(w, t))
        .when(Boolean(st), (el) => el.child(div().absolute().top(-3).right(-3).size(8).rounded(4).border(1.5).border_color(t.chrome).bg(t[st] ?? t.dim))));
  }

  // ---- The footer ----

  // The side panel is remembered per space: switching shows that space's choice
  // (closed if it never had one), and opening or closing it records it.
  syncPanel(space, panel, body, enabled) {
    if (!space || !panel) return;
    const now = panel.hidden ? null : body?.active ?? null;
    if (space.id !== this.space) {
      const first = this.space === undefined;
      this.space = space.id;
      this.pendingPanel = null;
      if (!(first && !(space.id in this.panels))) {
        const stored = this.panels[space.id] ?? null, want = enabled.includes(stored) ? stored : null;
        if (want !== now) {
          this.pendingPanel = { want, until: Date.now() + 1000 };
          if (want) {
            run("layout.select", { stack: "panel-body", child: want });
            run("layout.show", { id: "panel" });
          } else run("layout.hide", { id: "panel" });
          return;
        }
      }
    }
    // Until the restore lands (or something else won), the old state isn't a choice.
    if (this.pendingPanel) {
      if (this.pendingPanel.want !== now && Date.now() < this.pendingPanel.until) return;
      this.pendingPanel = null;
    }
    if (this.panels[space.id] === now) return;
    this.panels[space.id] = now;
    localStorage.setItem("panels", JSON.stringify(this.panels));
  }

  footer(t) {
    const collapsed = narrow();
    const root = layout(), panel = find(root, "panel"), body = find(root, "panel-body");
    const enabled = shared("workspace.panels") ?? ["files", "changes"];
    this.syncPanel(spaces().find((s) => s.active), panel, body, enabled);
    const row = (id, icon, label, dim, action) => h_flex().id(id).h(28).px(8).gap(9).items_center().rounded(8)
      .text_color(dim ? t.dim : t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground)).cursor_pointer()
      .on_click(action).child(svg(`mods/workspace-chrome/${icon}.svg`).size(14))
      .when(!collapsed, (el) => el.child(label));
    const panelButton = (id, label, icon) => {
      const on = panel && !panel.hidden && body?.active === id;
      return h_flex().id(`panel-${id}`).h(24).px(7).gap(5).flex_none().items_center().rounded(6)
        .text_size(12).bg(on ? t.selected : t.chrome).text_color(on ? t.foreground : t.muted)
        .hover((s) => s.bg(t.hover))
        .on_click(() => {
          if (on) run("layout.hide", { id: "panel" });
          else {
            run("layout.select", { stack: "panel-body", child: id });
            run("layout.show", { id: "panel" });
          }
        })
        .child(svg(icon).size(14))
        .child(label);
    };
    return v_flex().size_full().bg(t.chrome).border_t(1).border_color(t.border).px(8).pt(4).pb(8).text_size(13)
      .child(h_flex().gap(4).items_center()
        .child(row("settings", "settings", "Settings", false, () => run("app.settings")).flex_1()
          .when(Boolean(updates().app.ready), (el) => el.child(div().size(6).rounded_full().bg(t.accent))))
        .when(!collapsed && enabled.includes("files"), (el) => el.child(panelButton("files", "Files", "mods/files/file.svg")))
        .when(!collapsed && enabled.includes("changes"), (el) => el.child(panelButton("changes", "Changes", "mods/changes/changes.svg"))))
      .child(row("machine", "plus", "Add machine", true, () => run("mod.open", { name: "machine-add" })));
  }

  // ---- The whole ----

  render(cx) {
    const t = theme();
    if (props()?.footer) return this.footer(t);
    const collapsed = narrow();
    this.assignColors();
    const sp = spaces(), ps = panes();
    const list = agents();
    this.listed = new Map(list.map((a) => [a.address, a.status]));
    const now = Date.now();
    this.track(list, now);
    const byTab = new Map();
    for (const a of list) byTab.set(a.tab, [...(byTab.get(a.tab) ?? []), a]);
    const rows = this.ordered(sp, ps);
    // agent.next / agent.prev (and waiting()) go down the tree, through folded spaces too.
    this.agentOrder = rows.flatMap((r) => r.w.tabs.flatMap((c) => (byTab.get(c.id) ?? []).map((a) => a.address)));
    setAgentOrder(this.agentOrder);
    const all = terminals();
    // Each terminal's 7501 report: `report`, or `status` where that's still the record.
    const reports = new Map(all.map((k) => [k.address, k.report ?? (typeof k.status === "object" ? k.status : null)]));
    const ctx = { ps, all, reports, byTab, peeked: focused()?.agent, now, cwds: new Map(ps.map((p) => [p.pane, p.cwd])), cx };
    return v_flex().size_full().min_h(0).bg(t.chrome).text_size(13)
      .child(h_flex().h(31).pl(16).pr(10).flex_none().items_center().justify_between().text_size(11.5).text_color(t.dim)
        .when(!collapsed, (el) => el.child("Spaces"))
        .child(div().id("space-new").size(26).flex_none().flex().items_center().justify_center().rounded(6).hover((s) => s.bg(t.hover).text_color(t.foreground))
          .tooltip("New space")
          .on_click(() => run("space.new")).child(svg("mods/workspace-chrome/plus.svg").size(14))))
      .child(v_flex().id("tree").flex_1().min_h(0).px(collapsed ? 4 : 8).pb(14).overflow_y_scrollbar().mode("always")
        .on_mouse_up("left", (_e, cx) => {
          this.drag = null;
          this.over = null;
          cx.notify();
        })
        .children(this.grouped(rows, t, collapsed, ctx)))
      // On the macOS rail the traffic lights cover the header's toggle: this unfolds it.
      .when(collapsed, (el) => el.child(h_flex().h(28).flex_none().items_center().justify_center()
        .child(div().id("expand").text_size(13).text_color(t.dim).hover((s) => s.text_color(t.foreground)).on_click(toggleSidebar).child("»"))));
  }
}
