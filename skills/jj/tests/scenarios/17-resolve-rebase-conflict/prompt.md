Trunk has advanced while you were working. The new trunk tip
(`docs/team: change MAX_RETRIES to 5`) touches the same line of
`src/config.py` that your in-flight commit
(`src/config: bump MAX_RETRIES to 10`) touches.

**Your task:** rebase your stack onto the new trunk. There will be a
conflict on `src/config.py`. Resolve it by preferring **your** value
(`MAX_RETRIES = 10`) over the trunk value.

When done, briefly report:
1. The `jj` commands you ran
2. How you resolved the conflict
3. The final value of `MAX_RETRIES` at `@-`
