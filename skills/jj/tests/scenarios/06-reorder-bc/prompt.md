The current stack on top of trunk is:

```
@   (empty)
C   services/api: add rate limit
B   services/api: add auth middleware
A   services/api: add ping endpoint
trunk
```

Your reviewer prefers rate-limit to land before auth. **Swap B and C** so
the new order (bottom up) is A, C, B — i.e. rate-limit comes before auth.

When done, briefly report:
1. The exact `jj` command(s) you ran
2. The new stack order (descriptions only, bottom up)
