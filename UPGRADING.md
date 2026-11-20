# Upgrading

## Upgrading to Version 0.2.0

Update the gem and reusable workflow to matching 0.2.0 versions. If you use `rspec-options`, rename it to `test-options`; the value remains a JSON array of RSpec arguments.

Before:

```yaml
with:
  rspec-options: '["--seed","123"]'
```

After:

```yaml
with:
  test-options: '["--seed","123"]'
```

RSpec worker checks now include `Shard Tests` in their names, for example `Test / Shard Tests / 1 of 8` instead of `Test / 1 of 8`. Update any required branch-protection checks accordingly.
