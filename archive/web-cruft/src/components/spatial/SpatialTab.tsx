import { Canvas } from '@react-three/fiber';
import { Html, Line, OrbitControls, PerspectiveCamera } from '@react-three/drei';
import * as THREE from 'three';
import { useProject } from '../../contexts/ProjectContext';
import { useSpatial } from '../../contexts/SpatialContext';
import { Panel } from '../ui/Panel';
import { sphericalToCartesian, vectorToArray } from '../../utils/spherical';
import type { ObjectChannel, ObjectId, Vector3 } from '../../types';

function SphereGrid() {
  const latitudeLines = Array.from({ length: 5 }, (_, index) => -60 + index * 30);
  const longitudeLines = Array.from({ length: 12 }, (_, index) => index * 30);

  return (
    <>
      <mesh>
        <sphereGeometry args={[3.5, 36, 24]} />
        <meshBasicMaterial color="#00ff41" transparent opacity={0.16} wireframe />
      </mesh>

      {latitudeLines.map((latitude) => {
        const points = Array.from({ length: 73 }, (_, index) => {
          const angle = (index / 72) * Math.PI * 2;
          const radius = Math.cos((latitude * Math.PI) / 180) * 3.5;
          const y = Math.sin((latitude * Math.PI) / 180) * 3.5;
          return new THREE.Vector3(Math.cos(angle) * radius, y, Math.sin(angle) * radius);
        });
        return <Line key={`lat-${latitude}`} points={points} color="#00ff41" transparent opacity={0.32} lineWidth={0.6} />;
      })}

      {longitudeLines.map((longitude) => {
        const points = Array.from({ length: 61 }, (_, index) => {
          const elevation = (-90 + index * 3) * (Math.PI / 180);
          const azimuth = (longitude * Math.PI) / 180;
          return new THREE.Vector3(
            Math.sin(azimuth) * Math.cos(elevation) * 3.5,
            Math.sin(elevation) * 3.5,
            Math.cos(azimuth) * Math.cos(elevation) * 3.5,
          );
        });
        return <Line key={`lon-${longitude}`} points={points} color="#00ff41" transparent opacity={0.25} lineWidth={0.45} />;
      })}
    </>
  );
}

function BedSpeaker({ position, label, accent }: { position: Vector3; label: string; accent: string }) {
  return (
    <group position={vectorToArray(position)}>
      <mesh>
        <coneGeometry args={[0.12, 0.34, 4]} />
        <meshBasicMaterial color={accent} wireframe />
      </mesh>
      <mesh>
        <sphereGeometry args={[0.05, 10, 10]} />
        <meshBasicMaterial color={accent} />
      </mesh>
      <Html distanceFactor={10}>
        <span className="scene-label">{label}</span>
      </Html>
    </group>
  );
}

function ObjectOrb({
  object,
  position,
  trail,
  selected,
  onSelect,
}: {
  object: ObjectChannel;
  position: Vector3;
  trail: Vector3[];
  selected: boolean;
  onSelect: (id: ObjectId) => void;
}) {
  return (
    <group position={vectorToArray(position)}>
      <mesh onClick={() => onSelect(object.id)}>
        <sphereGeometry args={[selected ? 0.22 : 0.16, 18, 18]} />
        <meshStandardMaterial color={object.accent} emissive={object.accent} emissiveIntensity={0.85} roughness={0.25} />
      </mesh>
      {selected ? (
        <mesh rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[0.32, 0.018, 8, 48]} />
          <meshBasicMaterial color="#ffffff" />
        </mesh>
      ) : null}
      <Html distanceFactor={10}>
        <span className="scene-label">{object.label}</span>
      </Html>
      {trail.length > 1 ? (
        <Line
          points={trail.map((point) => new THREE.Vector3(point.x, point.y, point.z))}
          color={object.id === 'A' ? '#ff00ff' : '#ffff00'}
          transparent
          opacity={0.28}
          lineWidth={1.2}
        />
      ) : null}
    </group>
  );
}

function CompassLabels() {
  const labels = [
    { label: 'F', position: [0, 0, 4.1] },
    { label: 'R', position: [4.1, 0, 0] },
    { label: 'B', position: [0, 0, -4.1] },
    { label: 'L', position: [-4.1, 0, 0] },
    { label: 'TOP', position: [0, 4.3, 0] },
    { label: 'BOTTOM', position: [0, -4.3, 0] },
  ] as const;

  return (
    <>
      {labels.map((item) => (
        <Html key={item.label} position={item.position} distanceFactor={12}>
          <span className="scene-compass">{item.label}</span>
        </Html>
      ))}
    </>
  );
}

function Scene() {
  const { state, setSelectedObjectId, updateObject } = useProject();
  const { animatedObjects, trails } = useSpatial();

  return (
    <>
      <color attach="background" args={['#000000']} />
      <fog attach="fog" args={['#000000', 10, 18]} />
      <PerspectiveCamera makeDefault position={[0, 0, 12]} fov={50} />
      <ambientLight intensity={0.5} />
      <pointLight position={[4, 5, 8]} intensity={18} color="#00ff41" />
      <gridHelper args={[12, 18, '#12442d', '#07110a']} position={[0, -3.5, 0]} />
      <axesHelper args={[1.4]} position={[-4.8, -3.2, -4.8]} />
      <SphereGrid />
      <CompassLabels />

      {state.bedChannels.map((channel) => (
        <BedSpeaker
          key={channel.id}
          position={sphericalToCartesian(channel.position)}
          label={channel.id}
          accent={channel.accent}
        />
      ))}

      {state.objects.map((object) => (
        <ObjectOrb
          key={object.id}
          object={object}
          position={animatedObjects[object.id]}
          trail={trails[object.id]}
          selected={state.selectedObjectId === object.id}
          onSelect={(id) => setSelectedObjectId(id)}
        />
      ))}

      <OrbitControls enablePan enableZoom enableRotate />
    </>
  );
}

function BedControls() {
  const { state, resetBed } = useProject();
  const { updateBedAngles } = useSpatial();

  return (
    <div className="control-column">
      {state.bedChannels.map((channel) => (
        <div key={channel.id} className="control-card">
          <div className="control-card-header">
            <h4>{channel.label}</h4>
            <button type="button" className="mini-toggle" onClick={() => resetBed(channel.id)}>
              Reset
            </button>
          </div>
          <label className="control-stack compact">
            <span>Azimuth</span>
            <input
              type="range"
              min={0}
              max={360}
              value={channel.position.azimuth}
              onChange={(event) =>
                updateBedAngles(channel.id, Number(event.target.value), channel.position.elevation, channel.rotationY)
              }
            />
            <strong>{Math.round(channel.position.azimuth)}deg</strong>
          </label>
          <label className="control-stack compact">
            <span>Elevation</span>
            <input
              type="range"
              min={-90}
              max={90}
              value={channel.position.elevation}
              onChange={(event) =>
                updateBedAngles(channel.id, channel.position.azimuth, Number(event.target.value), channel.rotationY)
              }
            />
            <strong>{Math.round(channel.position.elevation)}deg</strong>
          </label>
          <label className="control-stack compact">
            <span>Tilt</span>
            <input
              type="range"
              min={-45}
              max={45}
              value={channel.rotationY}
              onChange={(event) =>
                updateBedAngles(channel.id, channel.position.azimuth, channel.position.elevation, Number(event.target.value))
              }
            />
            <strong>{Math.round(channel.rotationY)}deg</strong>
          </label>
        </div>
      ))}
    </div>
  );
}

function ObjectControls() {
  const { state, updateObject } = useProject();
  const { updateObjectPosition } = useSpatial();

  return (
    <div className="control-column">
      {state.objects.map((object) => (
        <div key={object.id} className="control-card">
          <div className="control-card-header">
            <h4>{object.label}</h4>
            <div className="mode-toggle">
              {(['manual', 'orbit', 'updown', 'through', 'path'] as const).map((mode) => (
                <button
                  key={mode}
                  type="button"
                  className={`mini-toggle ${object.movementMode === mode ? 'is-active' : ''}`}
                  onClick={() => updateObject(object.id, { movementMode: mode })}
                >
                  {mode}
                </button>
              ))}
            </div>
          </div>

          <div className="vector-grid">
            {(['x', 'y', 'z'] as const).map((axis) => (
              <label key={axis} className="control-stack compact">
                <span>{axis.toUpperCase()}</span>
                <input
                  type="number"
                  min={-3.5}
                  max={3.5}
                  step={0.1}
                  value={object.position[axis]}
                  onChange={(event) =>
                    updateObjectPosition(object.id, {
                      ...object.position,
                      [axis]: Number(event.target.value),
                    })
                  }
                />
              </label>
            ))}
          </div>

          <label className="control-stack compact">
            <span>Movement Speed</span>
            <input
              type="range"
              min={0.1}
              max={10}
              step={0.1}
              value={object.movementParams.speed}
              onChange={(event) =>
                updateObject(object.id, {
                  movementParams: {
                    ...object.movementParams,
                    speed: Number(event.target.value),
                    orbitSpeed: Number(event.target.value),
                  },
                })
              }
            />
            <strong>{object.movementParams.speed.toFixed(1)}</strong>
          </label>
          <label className="control-stack compact">
            <span>Orbit Radius / Amplitude</span>
            <input
              type="range"
              min={0}
              max={3.5}
              step={0.1}
              value={object.movementMode === 'updown' ? object.movementParams.amplitude / 25 : object.movementParams.orbitRadius}
              onChange={(event) =>
                updateObject(object.id, {
                  movementParams: {
                    ...object.movementParams,
                    orbitRadius: Number(event.target.value),
                    amplitude: Number(event.target.value) * 25,
                  },
                })
              }
            />
          </label>

          <div className="toggle-row">
            <button
              type="button"
              className={`mini-toggle ${object.movementEnabled ? 'is-active' : ''}`}
              onClick={() => updateObject(object.id, { movementEnabled: !object.movementEnabled })}
            >
              Movement {object.movementEnabled ? 'On' : 'Off'}
            </button>
            <button
              type="button"
              className={`mini-toggle ${object.syncToTempo ? 'is-active' : ''}`}
              onClick={() => updateObject(object.id, { syncToTempo: !object.syncToTempo })}
            >
              Sync {object.syncToTempo ? 'On' : 'Off'}
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}

export function SpatialTab() {
  return (
    <div className="tab-grid spatial-grid">
      <Panel eyebrow="3D Space" title="Orbisonic Navigator" className="sphere-panel">
        <div className="sphere-stage">
          <Canvas gl={{ antialias: true }}>
            <Scene />
          </Canvas>
          <div className="scanline" />
        </div>
      </Panel>

      <Panel eyebrow="Speakers" title="Bed Controls" className="controls-panel">
        <BedControls />
      </Panel>

      <Panel eyebrow="Objects" title="Motion Controls" className="controls-panel">
        <ObjectControls />
      </Panel>
    </div>
  );
}
