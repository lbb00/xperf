type Point = { x: number; y: number };

export function move(p: Point, dx: number, dy: number): void {
  p.x += dx;
  p.y += dy;
}
