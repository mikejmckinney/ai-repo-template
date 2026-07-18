export const DEFAULT_CURSOR_MODEL = "cursor-grok-4.5-medium";

export async function buildCursorModelConfig(id, listModels) {
  if (id === DEFAULT_CURSOR_MODEL) {
    const catalog = await listModels();
    const grok = catalog.find((candidate) => candidate.id === "grok-4.5");
    const medium = grok?.variants?.find(
      (variant) =>
        variant.params.some(
          (parameter) => parameter.id === "effort" && parameter.value === "medium",
        ) &&
        variant.params.some(
          (parameter) => parameter.id === "fast" && parameter.value === "false",
        ),
    );
    if (!grok || !medium) {
      throw new Error(
        `Cursor SDK catalog does not expose Grok 4.5 Medium non-fast: ${JSON.stringify(grok ?? null)}`,
      );
    }
    return { id: grok.id, params: medium.params };
  }
  if (id === "composer-2.5-fast") {
    return { id: "composer-2.5", params: [{ id: "fast", value: "true" }] };
  }
  if (id === "composer-2.5") {
    return { id: "composer-2.5", params: [{ id: "fast", value: "false" }] };
  }
  return { id };
}

export function cursorBillingTier(model, observedModel) {
  const fast = model.params?.find((parameter) => parameter.id === "fast")?.value;
  if (model.id === "grok-4.5") {
    const effort =
      model.params?.find((parameter) => parameter.id === "effort")?.value ?? "unknown";
    return `grok-4.5-${effort}${fast === "true" ? "-fast" : ""}`;
  }
  if (observedModel.includes("fast") || fast === "true") return "composer-2.5-fast";
  if (fast === "false") return "composer-2.5-standard";
  return "unknown";
}
