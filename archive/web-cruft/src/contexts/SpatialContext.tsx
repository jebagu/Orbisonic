import { createContext, useContext, useEffect, useState, type PropsWithChildren } from 'react';
import { useProject } from './ProjectContext';
import { fibonacciSphere } from '../utils/fibonacci';
import { clampInsideSphere, sphericalToCartesian } from '../utils/spherical';
import type { BedId, ObjectId, Vector3 } from '../types';

interface SpatialContextValue {
  animatedObjects: Record<ObjectId, Vector3>;
  trails: Record<ObjectId, Vector3[]>;
  speakerLayout: Vector3[];
  updateBedAngles: (id: BedId, azimuth: number, elevation: number, tilt: number) => void;
  updateObjectPosition: (id: ObjectId, position: Vector3) => void;
}

const SpatialContext = createContext<SpatialContextValue | null>(null);

function computeOrbit(position: Vector3, radius: number, phase: number, tiltDegrees: number): Vector3 {
  const tilt = (tiltDegrees * Math.PI) / 180;
  const base = {
    x: Math.cos(phase) * radius,
    y: Math.sin(phase) * radius * Math.sin(tilt),
    z: Math.sin(phase) * radius * Math.cos(tilt),
  };

  return {
    x: position.x + base.x,
    y: position.y + base.y,
    z: position.z + base.z,
  };
}

export function SpatialProvider({ children }: PropsWithChildren) {
  const { state, updateBed, updateObject } = useProject();
  const [animatedObjects, setAnimatedObjects] = useState<Record<ObjectId, Vector3>>({
    A: state.objects[0].position,
    B: state.objects[1].position,
  });
  const [trails, setTrails] = useState<Record<ObjectId, Vector3[]>>({
    A: [state.objects[0].position],
    B: [state.objects[1].position],
  });
  const speakerLayout = fibonacciSphere(30);

  useEffect(() => {
    const nextPositions = state.objects.reduce<Record<ObjectId, Vector3>>((result, object) => {
      const rhythmFactor = object.syncToTempo ? state.bpm / 120 : 1;
      const phase =
        ((state.currentTime * Math.max(0.12, object.movementParams.speed) * rhythmFactor) / 60) * Math.PI * 2 +
        (object.movementParams.phaseOffset * Math.PI) / 180;
      let nextPosition = object.position;

      if (!object.movementEnabled) {
        result[object.id] = nextPosition;
        return result;
      }

      switch (object.movementMode) {
        case 'manual':
          nextPosition = object.position;
          break;
        case 'orbit': {
          const direction = object.movementParams.orbitDirection;
          const center = object.movementParams.center;
          nextPosition = computeOrbit(center, object.movementParams.orbitRadius, phase * direction, object.movementParams.orbitTilt);
          break;
        }
        case 'updown': {
          const amplitude = (object.movementParams.amplitude / 90) * 2.5;
          const center = object.movementParams.center;
          nextPosition = {
            x: center.x,
            y: center.y + Math.sin(phase) * amplitude,
            z: center.z + Math.cos(phase) * 0.8,
          };
          break;
        }
        case 'through': {
          const azimuth = (object.movementParams.axisAzimuth * Math.PI) / 180;
          const elevation = (object.movementParams.axisElevation * Math.PI) / 180;
          const travel = Math.sin(phase) * 3.1;
          nextPosition = {
            x: Math.sin(azimuth) * Math.cos(elevation) * travel,
            y: Math.sin(elevation) * travel,
            z: Math.cos(azimuth) * Math.cos(elevation) * travel,
          };
          break;
        }
        case 'path': {
          const path = object.movementParams.path;
          if (path.length < 2) {
            nextPosition = object.position;
          } else {
            const progress = ((phase / (Math.PI * 2)) % 1 + 1) % 1;
            const scaled = progress * path.length;
            const index = Math.floor(scaled) % path.length;
            const nextIndex = (index + 1) % path.length;
            const amount = scaled - Math.floor(scaled);
            nextPosition = {
              x: path[index].x + (path[nextIndex].x - path[index].x) * amount,
              y: path[index].y + (path[nextIndex].y - path[index].y) * amount,
              z: path[index].z + (path[nextIndex].z - path[index].z) * amount,
            };
          }
          break;
        }
      }

      result[object.id] = clampInsideSphere(nextPosition);
      return result;
    }, {} as Record<ObjectId, Vector3>);

    setAnimatedObjects(nextPositions);
    setTrails((current) => ({
      A: [...current.A, nextPositions.A].slice(-32),
      B: [...current.B, nextPositions.B].slice(-32),
    }));
  }, [state.bpm, state.currentTime, state.objects]);

  const value: SpatialContextValue = {
    animatedObjects,
    trails,
    speakerLayout,
    updateBedAngles: (id, azimuth, elevation, tilt) => {
      updateBed(id, {
        position: {
          azimuth,
          elevation,
          distance: 3.5,
        },
        rotationZ: azimuth,
        rotationY: tilt,
        elevation,
      });
    },
    updateObjectPosition: (id, position) => {
      updateObject(id, {
        position: clampInsideSphere(position),
        movementParams: {
          ...state.objects.find((object) => object.id === id)!.movementParams,
          center: clampInsideSphere(position),
        },
      });
    },
  };

  return <SpatialContext.Provider value={value}>{children}</SpatialContext.Provider>;
}

export function useSpatial() {
  const context = useContext(SpatialContext);
  if (!context) {
    throw new Error('useSpatial must be used inside SpatialProvider');
  }
  return context;
}
