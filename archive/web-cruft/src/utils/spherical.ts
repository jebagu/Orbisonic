import type { SphericalPosition, Vector3 } from '../types';

const toRadians = (value: number) => (value * Math.PI) / 180;
const toDegrees = (value: number) => (value * 180) / Math.PI;

export function sphericalToCartesian(position: SphericalPosition): Vector3 {
  const azimuth = toRadians(position.azimuth);
  const elevation = toRadians(position.elevation);
  const radius = position.distance;
  const cosElevation = Math.cos(elevation);

  return {
    x: radius * Math.sin(azimuth) * cosElevation,
    y: radius * Math.sin(elevation),
    z: radius * Math.cos(azimuth) * cosElevation,
  };
}

export function cartesianToSpherical(vector: Vector3): SphericalPosition {
  const distance = Math.max(0.001, Math.sqrt(vector.x ** 2 + vector.y ** 2 + vector.z ** 2));
  const azimuth = toDegrees(Math.atan2(vector.x, vector.z));
  const elevation = toDegrees(Math.asin(vector.y / distance));

  return {
    azimuth: (azimuth + 360) % 360,
    elevation,
    distance,
  };
}

export function clampInsideSphere(vector: Vector3, radius = 3.5): Vector3 {
  const magnitude = Math.sqrt(vector.x ** 2 + vector.y ** 2 + vector.z ** 2);
  if (magnitude <= radius) {
    return vector;
  }

  const scale = radius / magnitude;
  return {
    x: vector.x * scale,
    y: vector.y * scale,
    z: vector.z * scale,
  };
}

export function lerpVector(from: Vector3, to: Vector3, amount: number): Vector3 {
  return {
    x: from.x + (to.x - from.x) * amount,
    y: from.y + (to.y - from.y) * amount,
    z: from.z + (to.z - from.z) * amount,
  };
}

export function vectorToArray(vector: Vector3): [number, number, number] {
  return [vector.x, vector.y, vector.z];
}
