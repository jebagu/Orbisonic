import { useProject } from '../../contexts/ProjectContext';
import type { TabId } from '../../types';

const tabs: Array<{ id: TabId; label: string; number: string }> = [
  { id: 'music', label: 'Music', number: '01' },
  { id: 'space', label: '3D Space', number: '02' },
  { id: 'synth', label: 'Synth', number: '03' },
  { id: 'render', label: 'Render', number: '04' },
  { id: 'sphereRender', label: 'Sphere Render', number: '05' },
  { id: 'sphericalPlayer', label: 'Spherical Player', number: '06' },
];

export function TabBar() {
  const { state, setActiveTab } = useProject();

  return (
    <nav className="tab-bar">
      <div className="brand-lockup">
        <img className="brand-mark" src="/orbisonic-logo.svg" alt="Orbisonic" />
        <div>
          <p className="brand-eyebrow">Spatial Audio Workstation</p>
          <h1 className="brand-title">Orbisonic</h1>
        </div>
      </div>

      <div className="tab-buttons">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            type="button"
            className={`tab-button ${state.activeTab === tab.id ? 'is-active' : ''}`}
            onClick={() => setActiveTab(tab.id)}
          >
            <span>{tab.number}</span>
            {tab.label}
          </button>
        ))}
      </div>

      <div className="tab-meta">
        <div>
          <span>Render</span>
          <strong>{state.renderMode === 'home51' ? '5.1 HOME' : state.renderMode.toUpperCase()}</strong>
        </div>
        <div>
          <span>Length</span>
          <strong>{formatTime(state.length)}</strong>
        </div>
      </div>
    </nav>
  );
}

function formatTime(time: number) {
  const minutes = Math.floor(time / 60)
    .toString()
    .padStart(2, '0');
  const seconds = Math.floor(time % 60)
    .toString()
    .padStart(2, '0');
  return `${minutes}:${seconds}`;
}
