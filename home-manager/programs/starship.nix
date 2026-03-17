{pkgs, ...}:
let
  starship-jj-dir = pkgs.writeShellScript "starship-jj-dir" ''
    if root=$(realpath "$(${pkgs.jujutsu}/bin/jj workspace root 2>/dev/null)"); then
      cwd=$(realpath "$PWD")
      repo=$(basename "$root")
      rel=''${cwd#"$root"}
      printf '%s' "$repo$rel"
    else
      printf '%s' "''${PWD/#$HOME/~}"
    fi
  '';
in
{
  home.packages = [pkgs.jj-starship];

  programs.starship = {
    enable = true;
    settings = {
      # Disable git modules — jj-starship handles both jj and colocated git
      git_branch.disabled = true;
      git_status.disabled = true;
      git_commit.disabled = true;

      # Disable nix shell indicator — always shows "impure" which isn't useful
      nix_shell.disabled = true;

      # Disable all language/runtime indicators
      buf.disabled = true;
      bun.disabled = true;
      c.disabled = true;
      cmake.disabled = true;
      cobol.disabled = true;
      crystal.disabled = true;
      daml.disabled = true;
      dart.disabled = true;
      deno.disabled = true;
      dotnet.disabled = true;
      elixir.disabled = true;
      elm.disabled = true;
      erlang.disabled = true;
      fennel.disabled = true;
      fortran.disabled = true;
      gleam.disabled = true;
      golang.disabled = true;
      gradle.disabled = true;
      haskell.disabled = true;
      haxe.disabled = true;
      java.disabled = true;
      julia.disabled = true;
      kotlin.disabled = true;
      lua.disabled = true;
      meson.disabled = true;
      mojo.disabled = true;
      nim.disabled = true;
      nodejs.disabled = true;
      ocaml.disabled = true;
      odin.disabled = true;
      opa.disabled = true;
      package.disabled = true;
      perl.disabled = true;
      php.disabled = true;
      purescript.disabled = true;
      python.disabled = true;
      quarto.disabled = true;
      raku.disabled = true;
      red.disabled = true;
      rlang.disabled = true;
      ruby.disabled = true;
      rust.disabled = true;
      scala.disabled = true;
      solidity.disabled = true;
      swift.disabled = true;
      typst.disabled = true;
      vlang.disabled = true;
      zig.disabled = true;

      # Replace directory module with jj-aware version
      # Placing ${custom.dir} explicitly excludes it from $all, avoiding duplication
      format = "\${custom.dir}$all";
      directory.disabled = true;

      custom.dir = {
        when = "true";
        shell = ["${starship-jj-dir}"];
        style = "bold cyan";
        format = "[$output]($style) ";
      };

      # Jujutsu VCS status via jj-starship
      custom.jj = {
        when = "jj-starship detect";
        shell = ["jj-starship"];
        format = "$output ";
      };
    };
  };
}
