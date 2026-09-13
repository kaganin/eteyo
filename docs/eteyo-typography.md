# eteyo typography

Tracking is proportional to font size: `size × (0.2 / 15)`, in logical iOS points.
Use `EtEyoTypography.tracking(for:)` without rounding at call sites. Keep native
line height; use container padding/spacing for layout.

| Size (pt) | Additional tracking (pt, rounded here only) |
| --- | --- |
| 13 | 0.173 |
| 14 | 0.187 |
| 15 | 0.200 |
| 16 | 0.213 |
| 17 | 0.227 |
| 18 | 0.240 |
| 22 | 0.293 |
| 30 | 0.400 |

- Chat/location cells: title 16, subtitle 14.
- Main screen titles: 30; preserve existing weight.
- Conversation navigation header: title 16, subtitle 13.
- Message bubbles and composer: 16. The earlier 16/17 experiment is finished;
  the More menu no longer offers a font-size picker.
- Settings: body text uses 16 at the default Dynamic Type size; preserve smaller
  native header/footer styles. Tracking scales with Dynamic Type.

These are custom tracking values, not Apple's native font tracking metrics.
