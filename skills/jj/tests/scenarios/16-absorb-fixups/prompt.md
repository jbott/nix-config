The current stack is:

```
@   (3 small one-line fixups in users.py, orders.py, and products.py — no description)
C   services/api: add /v1/products
B   services/api: add /v1/orders
A   services/api: add /v1/users
trunk
```

Each fixup in `@` touches a line that was introduced in the corresponding
ancestor commit (the users fix belongs in A, orders in B, products in C).

**Your task:** distribute the fixups from `@` into the correct ancestor
commits using the appropriate jj tool. After this, `@` should be empty.

When done, briefly report:
1. The exact command(s) you ran
2. Confirm `@` is empty afterwards
