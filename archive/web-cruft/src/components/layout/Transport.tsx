import { useProject } from '../../contexts/ProjectContext';

function formatClock(time: number) {
  const minutes = Math.floor(time / 60)
    .toString()
    .padStart(2, '0');
  const seconds = Math.floor(time % 60)
    .toString()
    .padStart(2, '0');
  const millis = Math.floor((time % 1) * 1000)
    .toString()
    .padStart(3, '0');
  return `${minutes}:${seconds}.${millis}`;
}

export function Transport() {
  const { state, togglePlayback, resetTransport, setBpm, setMasterVolume, loadDemoProject } = useProject();

  return (
    <div className="transport">
      <div className="transport-cluster">
        <button type="button" className="transport-button primary" onClick={togglePlayback}>
          {state.playing ? 'Pause' : 'Play'}
        </button>
        <button type="button" className="transport-button" onClick={resetTransport}>
          Stop
        </button>
        <button type="button" className="transport-button ghost" onClick={loadDemoProject}>
          Load Demo
        </button>
      </div>

      <label className="control-stack">
        <span>BPM</span>
        <input
          type="range"
          min={60}
          max={180}
          value={state.bpm}
          onChange={(event) => setBpm(Number(event.target.value))}
        />
        <strong>{state.bpm}</strong>
      </label>

      <label className="control-stack">
        <span>Master Volume</span>
        <input
          type="range"
          min={0}
          max={100}
          value={state.masterVolume}
          onChange={(event) => setMasterVolume(Number(event.target.value))}
        />
        <strong>{state.masterVolume}%</strong>
      </label>

      <div className="transport-readout">
        <div>
          <span>Current</span>
          <strong>{formatClock(state.currentTime)}</strong>
        </div>
        <div>
          <span>Project Length</span>
          <strong>{formatClock(state.length)}</strong>
        </div>
      </div>
    </div>
  );
}
