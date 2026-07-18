## Panel completion contract

Finish a complete panel response with this exact final non-empty line:

```text
<!-- multi-model-panel-complete:v1 -->
```

Do not emit the marker before the analysis is complete. Output without the
final marker is rejected as incomplete even when the provider request and child
process otherwise report success.
