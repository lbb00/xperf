export function clearFlag(obj: Record<string, unknown>, key: string) {
  obj[key] = undefined;
}
