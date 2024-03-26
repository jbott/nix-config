self: super: {
  pip-tools = super.pip-tools.overridePythonAttrs {
    patches = [];
  };
}
