{
  git,
  glab,
  jujutsu,
  writeShellApplication,
}:
writeShellApplication {
  name = "glab";
  runtimeInputs = [git jujutsu];
  text = ''
    glab=${glab}/bin/glab
    if [[ ''${1:-} != mr || ( ''${2:-} != view && ''${2:-} != show ) ]]; then
      exec "$glab" "$@"
    fi

    args=("$@")
    shift 2
    while (($#)); do
      case $1 in
        -h | --help) exec "$glab" "''${args[@]}" ;;
        -F | --output | -p | --page | -P | --per-page | -R | --repo | --jq)
          if (($# < 2)); then exec "$glab" "''${args[@]}"; fi
          shift 2
          ;;
        --)
          shift
          if (($#)); then exec "$glab" "''${args[@]}"; fi
          ;;
        -*) shift ;;
        *) exec "$glab" "''${args[@]}" ;;
      esac
    done

    if ! jj --ignore-working-copy workspace root >/dev/null 2>&1 ||
       git symbolic-ref -q HEAD >/dev/null 2>&1; then
      exec "$glab" "''${args[@]}"
    fi

    branch=$(jj --ignore-working-copy --no-pager log \
      -r 'heads(::@ & bookmarks() ~ ::trunk())' --no-graph \
      -T 'local_bookmarks.map(|b| b.name()).join("\n") ++ "\n"')
    if [[ -z $branch || $branch == *$'\n'* ]]; then
      printf '%s\n' 'glab: expected one local jj bookmark on this stack; pass an MR ID or branch explicitly' >&2
      exit 1
    fi
    exec "$glab" "''${args[0]}" "''${args[1]}" "$branch" "''${args[@]:2}"
  '';
}
