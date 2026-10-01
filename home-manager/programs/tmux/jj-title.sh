if ! dir=$(cd -- "$1" 2>/dev/null && pwd -P); then
  printf '%s' "$1"
  exit 0
fi

base=${dir##*/}
base=${base:-/}
root=$dir
while [[ ! -e "$root/.jj/repo" ]]; do
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
fi

suffix=""
if [[ "$root" != "$repo_root" ]]; then
  suffix=${root##*/}
fi
if [[ "$dir" != "$root" ]]; then
  suffix="${suffix:+$suffix/}$base"
fi
printf '[%s]%s' "${repo_root##*/}" "${suffix:+ $suffix}"
