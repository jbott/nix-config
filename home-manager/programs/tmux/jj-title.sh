if ! dir=$(cd -- "$1" 2>/dev/null && pwd -P); then
  printf '%s' "$1"
  exit 0
fi

base=${dir##*/}
base=${base:-/}
root=$dir
while [[ ! -e "$root/.jj/repo" && ! -e "$root/.git" ]]; do
  if [[ "$root" == / ]]; then
    printf '%s' "$base"
    exit 0
  fi
  root=${root%/*}
  root=${root:-/}
done

repo_root=$root
if [[ -f "$root/.jj/repo" ]]; then
  repo_path=$(<"$root/.jj/repo")
  if repo_dir=$(cd -- "$root/.jj" && cd -- "$repo_path" 2>/dev/null && pwd -P); then
    repo_root=${repo_dir%/.jj/repo}
  fi
elif [[ ! -d "$root/.jj/repo" && -f "$root/.git" ]]; then
  git_dir=$(<"$root/.git")
  git_dir=${git_dir#gitdir: }
  if git_dir=$(cd -- "$root" && cd -- "$git_dir" 2>/dev/null && pwd -P) &&
    [[ -f "$git_dir/commondir" ]]; then
    common_dir=$(<"$git_dir/commondir")
    if common_dir=$(cd -- "$git_dir" && cd -- "$common_dir" 2>/dev/null && pwd -P); then
      repo_root=${common_dir%/.git}
    fi
  fi
fi

suffix=""
if [[ "$root" != "$repo_root" ]]; then
  suffix=${root##*/}
fi
if [[ "$dir" != "$root" ]]; then
  suffix="${suffix:+$suffix/}$base"
fi
printf '[%s]%s' "${repo_root##*/}" "${suffix:+ $suffix}"
