{
  jujutsu,
  writeShellApplication,
}:
writeShellApplication {
  name = "jjw";
  runtimeInputs = [jujutsu];
  text = builtins.readFile ./jjw.sh;
}
