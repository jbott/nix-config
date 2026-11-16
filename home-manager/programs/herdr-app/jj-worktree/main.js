// Herdr's worktree dialog, for jj. jj-menu and jj-new-menu open this in its
// place, with the same props: { space, action: "new" | "open" | "remove" } or
// { folder, machine } for a repo without a space.
// In a checkout jj tracks it makes, lists and removes jj workspaces with jjw.
// Anywhere else it hands the props to Herdr's own dialog, so that one keeps
// its updates.

import { View, div } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, Scrollbar } from "gpui-base";
import { run, props, openOverlay, closeOverlay, theme, spaces, panes, home, checking } from "herdr";
import { jj, jjw, workspace } from "./jj.js";

// The sizes the stock menus open Herdr's dialog at.
const SIZE = { new: { width: 460, height: 280 }, open: { width: 560, height: 480 }, remove: { width: 440, height: 260 } };

// Where a space is now: its first terminal's live folder, else where it was made.
function place(s, all = panes()) {
  if (!s) return null;
  const tabs = new Set((s.tabs ?? []).map((c) => c.id));
  return all.find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder || null;
}

const tilde = (path, userHome) => (userHome && (path === userHome || path.startsWith(`${userHome}/`)) ? `~${path.slice(userHome.length)}` : path);
const ago = (s) => {
  const d = Date.now() / 1000 - s;
  return d < 3600 ? `${Math.max(1, Math.round(d / 60))}m` : d < 86400 ? `${Math.round(d / 3600)}h` : d < 86400 * 60 ? `${Math.round(d / 86400)}d` : `${Math.round(d / 86400 / 30)}mo`;
};

// The jj repo a folder is in: its main workspace's root and the repo's name,
// and the folder's workspace (`ws`, rooted at `top`). null when jj doesn't track it.
async function repoOf(folder, on) {
  const ws = await workspace(folder, on);
  if (!ws) return null;
  const [top, main] = await Promise.all([jj(folder, ["--ignore-working-copy", "workspace", "root"], on), jjw(folder, ["root"], on)]);
  if (!top.ok) throw new Error(top.err || "jj workspace root failed.");
  if (!main.ok) throw new Error(main.err || "jjw root failed.");
  return { top: top.out, main: main.out, name: main.out.split("/").pop(), ws, linked: top.out !== main.out };
}

// Where jjw puts workspaces.
const jjRoot = (repo) => `${repo.main.replace(/\/[^/]+$/, "")}/.worktrees/${repo.name}`;

// The repo's workspaces whose folder exists, the main one first, then the most
// recently changed: { path, name, main, at }.
async function workspaces(repo, on) {
  const [list, stale, mainName, times] = await Promise.all([
    jjw(repo.main, ["-R", repo.main, "ls"], on),
    jjw(repo.main, ["-R", repo.main, "ls", "--stale"], on),
    workspace(repo.main, on),
    jj(repo.main, ["--ignore-working-copy", "workspace", "list", "-T", 'name ++ "\\t" ++ target.committer().timestamp().format("%s") ++ "\\n"'], on),
  ]);
  if (!list.ok) throw new Error(list.err || "jjw ls failed.");
  const rows = (r) => (r.ok ? r.out.split("\n").filter(Boolean).map((l) => l.split("\t")) : []);
  const gone = new Set(rows(stale).map(([name]) => name));
  const when = new Map(rows(times).map(([name, at]) => [name, Number(at) || 0]));
  return rows(list)
    // "-": jj has no path for it (made before jj 0.38). The main one's is the repo's.
    .map(([name, path]) => ({ name, path: path === "-" ? (name === mainName ? repo.main : null) : path }))
    .filter((w) => w.path && !gone.has(w.name))
    .map((w) => ({ ...w, main: w.path === repo.main, at: when.get(w.name) ?? 0 }))
    .sort((a, b) => b.main - a.main || b.at - a.at);
}

// The space showing a workspace: its first terminal is in it (the deepest workspace wins).
function spaceOf(path, all, on, spaceList, paneList) {
  const inside = (p, dir) => p === dir || p.startsWith(`${dir}/`);
  return spaceList.find((s) => (s.machine ?? null) === (on ?? null) && (() => {
    const at = place(s, paneList);
    if (!at || !inside(at, path)) return false;
    return !all.some((c) => c.path !== path && c.path.length > path.length && inside(at, c.path));
  })());
}

export default class Worktree extends View {
  init(_props, cx) {
    this.action = props()?.action;
    this.opening = this.action === "open";
    this.removing = this.action === "remove";
    this.on = this.space()?.machine;
    this.userHome = this.on ? "" : home();
    this.text = "";
    this.list = undefined; // open: the workspaces, once read
    this.at = 0;
    this.input = InputState.new({ value: this.text, placeholder: this.opening ? "filter" : "name" });
    this.input.on("change", (_e, cx) => { this.text = this.input.value(); this.error = ""; this.at = 0; cx.notify(); });
    this.input.on("submit", (_e, cx) => this.go(cx));
    this.inputFocused = true;
    this.input.on("focus", (_e, cx) => { this.inputFocused = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.inputFocused = false; cx.notify(); });
    this.handle = cx.focus_handle();
    this.handle.focus(); // the root is mounted from the first frame: keep the keyboard here while loading
    if (!this.removing) this.input.focus();
    this.busy = false;
    this.error = "";
    this.repo = undefined; // set once known to be jj's
    if (checking()) return;
    cx.spawn(async (cx) => {
      try {
        this.folder = props()?.folder || place(this.space()) || this.userHome;
        const repo = this.folder ? await repoOf(this.folder, this.on) : null;
        if (!repo) return this.handOff();
        if (this.opening) this.list = await workspaces(repo, this.on);
        this.repo = repo;
        cx.notify();
        // The list (and with it the filter input) only mounts once loading is
        // done, so the keyboard must move there now.
        this.handle.focus();
        if (!this.removing) cx.timer.after(100, () => this.input.focus());
      } catch (error) { this.error = String(error); cx.notify(); }
    });
  }

  // Not jj's: Herdr's own dialog, as the menu would have opened it.
  handOff() {
    const { overlay, ...rest } = props();
    closeOverlay(overlay);
    openOverlay({ mod: "worktree", kind: "dialog", ...(SIZE[rest.action] ?? SIZE.new), props: rest });
  }

  space() {
    const p = props() ?? {};
    return spaces().find((s) => s.id === p.space) ?? (p.folder ? { folder: p.folder, machine: p.machine ?? null, name: "" } : undefined);
  }

  close() {
    closeOverlay(props().overlay);
  }

  go(cx) {
    if (this.busy || !this.repo) return;
    cx.spawn(async (cx) => this.work(cx));
  }

  async work(cx) {
    if (this.busy || !this.repo) return;
    this.busy = true;
    this.error = "";
    cx.notify();
    try { this.error = this.removing ? await this.remove() : await this.create(); }
    catch (error) { this.error = String(error); }
    this.busy = false;
    if (!this.error) this.close();
    cx.notify();
  }

  // jjw checks out a bookmark of that name; otherwise start from this workspace's @-.
  async create() {
    const name = this.text.trim();
    if (!name) return "Type a workspace name.";
    const { main, ws } = this.repo;
    const mark = await jj(main, ["--ignore-working-copy", "log", "--no-graph", "-r", `bookmarks(exact:${JSON.stringify(name)})`, "-T", '"x"'], this.on);
    const from = mark.ok && mark.out ? [] : ["-r", `${JSON.stringify(ws)}@-`];
    const r = await jjw(main, ["-R", main, "new", ...from, name], this.on);
    if (!r.ok) return r.err || "jjw new failed.";
    // Unnamed, so the space follows its folder and nests under the repo.
    run("space.new", { folder: r.out.split("\n").pop(), machine: this.on ?? "" });
    return "";
  }

  shown() {
    const f = this.text.trim().toLowerCase();
    return (this.list ?? []).filter((c) => !f || `${c.name} ${c.path}`.toLowerCase().includes(f));
  }

  open(c) {
    if (!c) return;
    this.close();
    const s = spaceOf(c.path, this.list, this.on, spaces(), panes());
    if (s) run("space.select", { id: s.id });
    else run("space.new", { folder: c.path, machine: this.on ?? "" });
  }

  // Snapshot first: forgetting a workspace doesn't, and jjw rm deletes the folder.
  async remove() {
    if (!this.repo.linked) return "This is the repository's main workspace.";
    const snap = await jj(this.repo.top, ["util", "snapshot"], this.on);
    if (!snap.ok) return snap.err || "jj util snapshot failed.";
    run("space.close", { id: this.space().id, confirmed: true });
    const r = await jjw(this.repo.main, ["-R", this.repo.main, "rm", this.repo.ws], this.on);
    return r.ok ? "" : r.err || "jjw rm failed.";
  }

  key(e, cx) {
    if (e.key === "escape") return this.close();
    if (this.opening) {
      const n = this.shown().length;
      if (e.key === "enter") this.open(this.shown()[this.at]);
      else if ((e.key === "down" || e.key === "up") && n) this.at = (this.at + (e.key === "down" ? 1 : n - 1)) % n;
      else return;
      cx.stop_propagation();
      return cx.notify();
    }
    if (e.key === "enter" && this.removing) return this.go(cx);
  }

  frame(t) {
    return v_flex()
      .id("worktree")
      .track_focus(this.handle)
      .on_key_down((e, cx) => this.key(e, cx))
      .size_full()
      .p(16)
      .gap(10)
      .bg(t.popover)
      .text_size(13);
  }

  field(t) {
    return Input.new(this.input).h(32).px(10).items_center().rounded(6).border(1).border_color(this.inputFocused ? t.accent : t.input).bg(t.background).text_color(t.foreground);
  }

  renderOpen(t) {
    const r = this.repo;
    const rows = this.shown();
    const all = this.list ?? [];
    const spaceList = spaces();
    const paneList = panes();
    const row = (c, i) => {
      const on = i === this.at;
      const there = spaceOf(c.path, all, this.on, spaceList, paneList);
      return v_flex()
        .id(`wt-${i}`)
        .flex_none()
        .h(44)
        .px(10)
        .justify_center()
        .rounded(7)
        .cursor_pointer()
        .when(on, (el) => el.bg(t.selected))
        .when(!on, (el) => el.hover((s) => s.bg(t.hover)))
        .on_click(() => this.open(c))
        .child(
          h_flex()
            .gap(8)
            .items_center()
            .child(div().flex_1().min_w(0).truncate().text_color(t.foreground).child(c.name))
            .when(c.main, (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child("main workspace")))
            .when(Boolean(there), (el) => el.child(div().flex_none().text_size(11).text_color(t.accent).child("open")))
            .when(!there && c.at > 0, (el) => el.child(div().flex_none().text_size(11).text_color(t.dim).child(ago(c.at)))),
        )
        .child(div().truncate().text_size(11.5).text_color(t.dim).child(tilde(c.path, this.userHome)));
    };
    const count = rows.length === all.length ? `${all.length} workspaces` : `${rows.length}/${all.length} workspaces`;
    return this.frame(t)
      .child(h_flex().child(div().flex_1().font_semibold().text_color(t.foreground).child(`Open workspace${r ? ` of ${r.name}` : ""}`)).child(div().text_size(11).text_color(t.dim).child(r ? count : "")))
      .when(!r && !this.error, (el) => el.child(div().text_color(t.muted).child("…")))
      .when(Boolean(this.error), (el) => el.child(div().text_color(t.blocked).child(this.error)))
      .when(Boolean(r), (el) =>
        el
          .child(this.field(t))
          .child(
            div()
              .relative()
              .flex_1()
              .min_h(0)
              .child(
                v_flex()
                  .id("wt-list")
                  .size_full()
                  .overflow_y_scroll()
                  .children(rows.map(row))
                  .when(rows.length === 0, (el) => el.child(div().p(10).text_color(t.dim).child("No matching workspaces."))),
              )
              .child(Scrollbar.vertical("wt-list").absolute().inset_0()),
          ),
      )
      .child(h_flex().justify_end().text_size(11).text_color(t.dim).child("↑↓ choose · ↵ open · esc close"));
  }

  render(cx) {
    const t = theme();
    if (this.opening) return this.renderOpen(t);
    const r = this.repo;
    const title = this.removing ? `Remove workspace${r ? ` ${r.ws}` : ""}?` : `New workspace${r ? ` of ${r.name}` : ""}`;
    const detail = !r
      ? "…"
      : this.removing
        ? !r.linked
          ? "This is the repository's main workspace."
          : `Closes the space, forgets jj workspace ${r.ws} and deletes ${tilde(r.top, this.userHome)}. Its commits stay in the repo, uncommitted changes included.`
        : `A new space on a jj workspace in ${tilde(jjRoot(r), this.userHome)}/. A bookmark with that name is checked out; otherwise it starts from here.`;
    const blocked = !r || (this.removing && !r.linked);
    return this.frame(t)
      .child(div().font_semibold().text_color(t.foreground).child(title))
      .child(div().text_color(t.muted).child(detail))
      .when(!this.removing && !blocked, (el) => el.child(this.field(t)))
      .when(Boolean(this.error), (el) => el.child(div().text_color(t.blocked).child(this.error)))
      .child(div().flex_1())
      .child(
        h_flex()
          .justify_end()
          .text_size(11)
          .text_color(t.dim)
          .gap(6)
          .when(this.busy, (el) => el.child(div().frames(["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"], 90)))
          .child(this.busy ? "working…" : blocked ? "esc close" : this.removing ? "↵ remove · esc cancel" : "↵ create · esc cancel"),
      );
  }
}
