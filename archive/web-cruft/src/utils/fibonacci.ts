import type { Vector3 } from '../types';

export function fibonacciSphere(samples: number, radius = 3.5): Vector3[] {
  const points: Vector3[] = [];
  const phi = Math.PI * (3 - Math.sqrt(5));

  for (let index = 0; index < samples; index += 1) {
    const y = 1 - (index / Math.max(1, samples - 1)) * 2;
    const radial = Math.sqrt(1 - y * y);
    const theta = phi * index;

    points.push({
      x: Math.cos(theta) * radial * radius,
      y: y * radius,
      z: Math.sin(theta) * radial * radius,
    });
  }

  return points;
}
