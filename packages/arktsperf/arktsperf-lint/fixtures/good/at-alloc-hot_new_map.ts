export function indexById(rows: { id: string }[]): Map<string, { id: string }> {
  const m = new Map<string, { id: string }>();
  for (const row of rows) {
    m.set(row.id, row);
  }
  return m;
}
