The current stack on top of trunk is:

```
@   (empty)
C   services/api: add health check
B   docs: fix typo in README
A   services/api: scaffold service
trunk
```

The `docs: fix typo in README` commit (B) is unrelated to the API work —
it should land directly on trunk, not be part of this stack. Move only B
onto trunk; leave A and C stacked.

When done, briefly report:
1. The exact `jj` command you ran
2. Confirm: B is now a child of `trunk()`
3. Confirm: A and C are still stacked, with `@` empty
