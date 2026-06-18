# Validation Notes

Initial hardware validation was performed on an Intel `MacBookPro16,1`.

## Observed Behavior

With AlDente exited:

1. `BCLM=100` allowed charging.
2. The battery charged from 80% to 82% UI state of charge.
3. Writing `BCLM=15` as root stopped battery charging.
4. Stable post-write state:

```text
82%; AC attached; not charging
ChargingCurrent=0
NotChargingReason=14
IsCharging=No
BCLM=15
```

## MVP Policy

For Intel MacBooks that behave like the validated machine:

- At or above target percentage: write `BCLM=15`.
- At or below target minus hysteresis: write `BCLM=100`.
- Inside the hysteresis window: hold the current SMC value.

The default hysteresis is 2%.
