import { useAudioEngine } from '../../contexts/AudioContext';
import { useProject } from '../../contexts/ProjectContext';
import { useSpatial } from '../../contexts/SpatialContext';
import { Panel } from '../ui/Panel';

const renderModes = [
  { id: 'binaural', label: 'Binaural', description: 'HRTF headphone render' },
  { id: 'home51', label: 'Home 5.1', description: 'VBAP-style surround foldout' },
  { id: 'sonicsphere', label: 'Sonic Sphere 30.1', description: '31-channel full-sphere renderer' },
] as const;

export function RenderTab() {
  const { state, setRenderMode, updateOutput } = useProject();
  const { meters } = useAudioEngine();
  const { speakerLayout } = useSpatial();
  const speakerCount = state.renderMode === 'binaural' ? 2 : state.renderMode === 'home51' ? 6 : 31;

  return (
    <div className="tab-grid render-grid">
      <Panel eyebrow="Output" title="Renderer Configuration" className="render-mode-panel">
        <div className="render-mode-list">
          {renderModes.map((mode) => (
            <button
              key={mode.id}
              type="button"
              className={`render-mode-button ${state.renderMode === mode.id ? 'is-active' : ''}`}
              onClick={() => setRenderMode(mode.id)}
            >
              <strong>{mode.label}</strong>
              <span>{mode.description}</span>
            </button>
          ))}
        </div>

        <div className="render-settings-grid">
          <label className="control-stack compact">
            <span>Head Size</span>
            <select
              value={state.output.headSize}
              onChange={(event) => updateOutput({ headSize: event.target.value as typeof state.output.headSize })}
            >
              {['small', 'medium', 'large'].map((size) => (
                <option key={size} value={size}>
                  {size}
                </option>
              ))}
            </select>
          </label>
          <label className="control-stack compact">
            <span>Crossfade</span>
            <input
              type="range"
              min={0}
              max={100}
              value={state.output.crossfade}
              onChange={(event) => updateOutput({ crossfade: Number(event.target.value) })}
            />
            <strong>{state.output.crossfade}%</strong>
          </label>
          <label className="control-stack compact">
            <span>Sample Rate</span>
            <select
              value={state.output.sampleRate}
              onChange={(event) => updateOutput({ sampleRate: event.target.value as typeof state.output.sampleRate })}
            >
              {['44.1kHz', '48kHz'].map((rate) => (
                <option key={rate} value={rate}>
                  {rate}
                </option>
              ))}
            </select>
          </label>
          <label className="control-stack compact">
            <span>Bit Depth</span>
            <select
              value={state.output.bitDepth}
              onChange={(event) => updateOutput({ bitDepth: event.target.value as typeof state.output.bitDepth })}
            >
              {['16-bit', '24-bit'].map((depth) => (
                <option key={depth} value={depth}>
                  {depth}
                </option>
              ))}
            </select>
          </label>
        </div>

        <div className="toggle-row">
          <button
            type="button"
            className={`mini-toggle ${!state.output.bypass ? 'is-active' : ''}`}
            onClick={() => updateOutput({ bypass: false })}
          >
            Render
          </button>
          <button
            type="button"
            className={`mini-toggle ${state.output.bypass ? 'is-active danger' : ''}`}
            onClick={() => updateOutput({ bypass: true })}
          >
            Bypass
          </button>
          <button type="button" className="transport-button ghost">
            Export WAV
          </button>
        </div>
      </Panel>

      <Panel eyebrow="Meters" title={`${speakerCount}-Channel Activity`} className="vu-panel">
        <div className="vu-array">
          {Array.from({ length: speakerCount }, (_, index) => {
            const source = meters[index % meters.length];
            return (
              <div key={`speaker-meter-${index}`} className="vu-column">
                <div className="vu-track">
                  <div
                    className="vu-fill"
                    style={{
                      height: `${(source?.value ?? 0) * 100}%`,
                      background: source?.accent ?? '#00ff41',
                    }}
                  />
                </div>
                <span>{index + 1}</span>
              </div>
            );
          })}
        </div>
      </Panel>

      <Panel eyebrow="Visualizer" title="Speaker Field" className="speaker-panel">
        <div className="speaker-visualizer">
          {speakerLayout.slice(0, speakerCount === 31 ? 30 : speakerCount).map((point, index) => {
            const source = meters[index % meters.length];
            const x = 50 + (point.x / 3.5) * 34;
            const y = 50 - (point.y / 3.5) * 34;
            const scale = 0.7 + (source?.value ?? 0) * 1.3;
            return (
              <span
                key={`dot-${index}`}
                className="speaker-dot"
                style={{
                  left: `${x}%`,
                  top: `${y}%`,
                  background: source?.accent ?? '#00ff41',
                  transform: `translate(-50%, -50%) scale(${scale})`,
                }}
              />
            );
          })}
          <div className="speaker-shell" />
        </div>

        <div className="summary-list compact">
          <div>
            <span>Speaker Topology</span>
            <strong>{state.renderMode === 'sonicsphere' ? 'Fibonacci sphere + LFE' : state.renderMode === 'home51' ? 'ITU 5.1' : 'Binaural HRTF'}</strong>
          </div>
          <div>
            <span>Output Path</span>
            <strong>{state.output.bypass ? 'Dry monitor' : 'Spatialized'}</strong>
          </div>
          <div>
            <span>Engine</span>
            <strong>Web Audio + Tone + VBAP scaffold</strong>
          </div>
        </div>
      </Panel>
    </div>
  );
}
