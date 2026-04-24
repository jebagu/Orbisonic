import { useMemo, useState, type CSSProperties } from 'react';
import { Panel } from '../ui/Panel';

type SphereLayoutId = 'burningMan' | 'chateauDuFey';

const sphereLayouts = [
  {
    id: 'burningMan',
    name: 'Burning Man Sphere',
    speakers: 52,
    renderer: 'VBAP 3D',
    layoutFile: 'calibration/burning-man-sphere-speaker-layout.json',
    description: 'Measured SPAT layout extracted from LOVEBURN CORRECT.',
  },
  {
    id: 'chateauDuFey',
    name: 'Chateau du Fey Sphere',
    speakers: 30,
    renderer: 'VBAP 3D',
    layoutFile: 'calibration/chateau-du-fey-sphere-speaker-layout.json',
    description: 'Best-guess ring layout numbered from bottom to top.',
  },
] as const;

const routeStages = ['Sonic Sphere renderer', 'BlackHole 64ch', 'Dante Virtual Soundcard'];

export function SphereRenderTab() {
  const [selectedLayoutId, setSelectedLayoutId] = useState<SphereLayoutId>('burningMan');

  const selectedLayout = useMemo(
    () => sphereLayouts.find((layout) => layout.id === selectedLayoutId) ?? sphereLayouts[0],
    [selectedLayoutId],
  );

  return (
    <div className="tab-grid sphere-render-grid">
      <Panel eyebrow="Sonic Sphere" title="Sphere Render" className="sphere-render-panel">
        <div className="sphere-layout-list">
          {sphereLayouts.map((layout) => (
            <button
              key={layout.id}
              type="button"
              className={`sphere-layout-button ${selectedLayoutId === layout.id ? 'is-active' : ''}`}
              aria-pressed={selectedLayoutId === layout.id}
              onClick={() => setSelectedLayoutId(layout.id)}
            >
              <span className="sphere-layout-count">{layout.speakers}</span>
              <span>
                <strong>{layout.name}</strong>
                <small>{layout.description}</small>
              </span>
            </button>
          ))}
        </div>

        <div className="summary-list compact">
          <div>
            <span>Selected Layout</span>
            <strong>{selectedLayout.name}</strong>
          </div>
          <div>
            <span>Calibration File</span>
            <strong>{selectedLayout.layoutFile}</strong>
          </div>
          <div>
            <span>Renderer</span>
            <strong>{selectedLayout.renderer}</strong>
          </div>
        </div>
      </Panel>

      <Panel eyebrow="Output" title="BlackHole 64ch Route" className="sphere-route-panel">
        <div className="sphere-route-chain">
          {routeStages.map((stage, index) => (
            <div key={stage} className="sphere-route-stage">
              <strong>{stage}</strong>
              <span>{index === 0 ? selectedLayout.name : index === 1 ? '64-channel virtual device' : 'DVS network egress'}</span>
            </div>
          ))}
        </div>

        <div className="summary-list compact">
          <div>
            <span>Output Device</span>
            <strong>BlackHole 64ch</strong>
          </div>
          <div>
            <span>Next Hop</span>
            <strong>Dante Virtual Soundcard</strong>
          </div>
          <div>
            <span>Clock</span>
            <strong>48 kHz target</strong>
          </div>
        </div>
      </Panel>

      <Panel
        eyebrow="Placeholder"
        title="Render Binding"
        className="sphere-placeholder-panel"
        action={<span className="panel-chip">Not armed</span>}
      >
        <div className="sphere-placeholder-body">
          <div className="sphere-placeholder-meter">
            {Array.from({ length: Math.min(selectedLayout.speakers, 32) }, (_, index) => (
              <span key={`sphere-placeholder-${index}`} style={{ '--meter-index': index } as CSSProperties} />
            ))}
          </div>
          <button type="button" className="transport-button ghost" disabled>
            Arm Routing
          </button>
        </div>

        <div className="summary-list compact">
          <div>
            <span>Status</span>
            <strong>Menu placeholder only</strong>
          </div>
          <div>
            <span>Binding</span>
            <strong>Audio engine pending</strong>
          </div>
          <div>
            <span>Channel Map</span>
            <strong>{selectedLayout.speakers} to BlackHole 64ch</strong>
          </div>
        </div>
      </Panel>
    </div>
  );
}
