// Shared by jj-worktree and jj-sidebar (mods can't import each other).
// Reads pass --ignore-working-copy: a snapshot writes under .git, which would
// wake the sidebar's watch again.

import { exec } from "herdr";

// The app's PATH can be bare (a Finder launch).
const FIND = `
  p=$(command -v "$1" 2>/dev/null) && case $p in /*) printf '%s\\n' "$p"; exit 0;; esac
  p=$("\${SHELL:-sh}" -lc 'command -v "$0"' "$1" 2>/dev/null) && case $p in /*) printf '%s\\n' "$p"; exit 0;; esac
  for d in /run/current-system/sw/bin "/etc/profiles/per-user/$USER/bin" "$HOME/.nix-profile/bin" /opt/homebrew/bin /usr/local/bin; do
    [ -x "$d/$1" ] && { printf '%s\\n' "$d/$1"; exit 0; }
  done
  exit 1`;

// A machine that couldn't be reached isn't cached.
const bins = new Map();
function bin(name, on) {
  const key = `${on ?? ""}\u0000${name}`;
  if (!bins.has(key)) {
    bins.set(key, exec("sh", ["-c", FIND, "sh", name], { on }).then(
      (r) => (r.code === 0 ? r.stdout.trim().split("\n")[0] : null),
      () => { bins.delete(key); return null; },
    ));
  }
  return bins.get(key);
}

async function call(name, cwd, args, on) {
  const path = await bin(name, on);
  if (!path) return { ok: false, out: "", err: `${name} isn't installed${on ? ` on ${on}` : ""}.` };
  const r = await exec(path, args, { cwd, on });
  return { ok: r.code === 0, out: (r.stdout ?? "").trim(), err: (r.stderr || r.stdout || "").trim() };
}

export const jj = (cwd, args, on) => call("jj", cwd, ["--no-pager", "--color=never", ...args], on);
export const jjw = (cwd, args, on) => call("jjw", cwd, args, on);

// null when jj doesn't track the checkout.
export async function workspace(top, on) {
  const r = await jj(top, ["--ignore-working-copy", "workspace", "list", "-T", 'if(target.current_working_copy(), name ++ "\\n")'], on);
  return r.ok && r.out ? r.out.split("\n")[0] : null;
}

// jj keeps git's HEAD detached, so the sidebar's branch is the nearest
// bookmarks, and ahead/behind are against trunk(). No remote (trunk() is the
// root commit) means no counts.
const REVS = "latest(trunk()..@ ~ empty(), 100) | latest(@..trunk(), 100) | heads(::@ & bookmarks()) | trunk()";
const TPL = [
  'if(self.contained_in("trunk()") && self.root(), "R\\n")',
  'if(self.contained_in("heads(::@ & bookmarks())"), "B" ++ local_bookmarks.map(|b| b.name()).join(", ") ++ "\\n")',
  'if(self.contained_in("trunk()..@ ~ empty()"), "A\\n", if(self.contained_in("@..trunk()"), "D\\n"))',
].join(" ++ ");

export async function status(cwd, on) {
  const r = await jj(cwd, ["--ignore-working-copy", "log", "--no-graph", "-r", REVS, "-T", TPL], on);
  if (!r.ok) return null;
  const lines = r.out.split("\n");
  const count = (tag) => (lines.includes("R") ? 0 : lines.filter((l) => l === tag).length);
  const branch = lines.filter((l) => l.length > 1 && l.startsWith("B")).map((l) => l.slice(1)).join(", ");
  return { branch, ahead: count("A"), behind: count("D") };
}
