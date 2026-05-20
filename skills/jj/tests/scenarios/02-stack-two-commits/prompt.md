This jj repo has scaffolding in `services/api/handler.py` and
`lib/utils/dates.py`. Two unrelated changes are needed:

1. In `services/api/handler.py`: add input validation that rejects requests
   with no `user` field.
2. In `lib/utils/dates.py`: fix `parse_iso` so it strips a trailing `Z` if
   present (treat it as UTC).

**Your task:** make both edits and create them as **two separate commits**
on top of the current trunk, following the skill's commit-message format.
Do not bundle them.

When done, briefly report:
1. The exact `jj` command(s) you ran (in order)
2. Both commit messages
3. The shape of `trunk()..@` (just descriptions, in order)
