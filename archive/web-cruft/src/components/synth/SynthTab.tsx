import { useAudioEngine } from '../../contexts/AudioContext';
import { useProject } from '../../contexts/ProjectContext';
import { Panel } from '../ui/Panel';
import type { FilterType, ObjectId, OscillatorType, ScaleName } from '../../types';

type NumericSequencerRow = 'pitch' | 'velocity' | 'filter' | 'probability';

const rows = [
  { key: 'pitch', label: 'Pitch', min: 0, max: 12 },
  { key: 'velocity', label: 'Velocity', min: 0, max: 127 },
  { key: 'filter', label: 'Filter', min: 0, max: 100 },
  { key: 'probability', label: 'Probability', min: 0, max: 100 },
] as const satisfies Array<{ key: NumericSequencerRow; label: string; min: number; max: number }>;

export function SynthTab() {
  const { state, setSelectedObjectId, updateObjectSynth, updateObjectSequencer, updateSequencerRow, loadPatternSlot, savePatternSlot } =
    useProject();
  const { currentStep, previewObject } = useAudioEngine();
  const object = state.objects.find((item) => item.id === state.selectedObjectId) ?? state.objects[0];

  return (
    <div className="tab-grid synth-grid">
      <Panel
        eyebrow="Synth"
        title="Object Synth Engine"
        className="synth-panel"
        action={
          <div className="mode-toggle">
            {(['A', 'B'] as ObjectId[]).map((id) => (
              <button
                key={id}
                type="button"
                className={`mini-toggle ${object.id === id ? 'is-active' : ''}`}
                onClick={() => setSelectedObjectId(id)}
              >
                OBJ {id}
              </button>
            ))}
          </div>
        }
      >
        <div className="synth-columns">
          <div className="synth-section">
            <h4>Oscillator</h4>
            <label className="control-stack compact">
              <span>Waveform</span>
              <select
                value={object.synth.waveform}
                onChange={(event) =>
                  updateObjectSynth(object.id, { waveform: event.target.value as OscillatorType })
                }
              >
                {['sine', 'triangle', 'sawtooth', 'square'].map((waveform) => (
                  <option key={waveform} value={waveform}>
                    {waveform}
                  </option>
                ))}
              </select>
            </label>
            <label className="control-stack compact">
              <span>Detune</span>
              <input
                type="range"
                min={-100}
                max={100}
                value={object.synth.detune}
                onChange={(event) => updateObjectSynth(object.id, { detune: Number(event.target.value) })}
              />
              <strong>{object.synth.detune} cents</strong>
            </label>
            <label className="control-stack compact">
              <span>Pulse Width</span>
              <input
                type="range"
                min={0}
                max={100}
                value={object.synth.pulseWidth}
                onChange={(event) => updateObjectSynth(object.id, { pulseWidth: Number(event.target.value) })}
              />
              <strong>{object.synth.pulseWidth}%</strong>
            </label>
          </div>

          <div className="synth-section">
            <h4>Filter</h4>
            <label className="control-stack compact">
              <span>Type</span>
              <select
                value={object.synth.filterType}
                onChange={(event) => updateObjectSynth(object.id, { filterType: event.target.value as FilterType })}
              >
                {['lowpass', 'highpass', 'bandpass'].map((filter) => (
                  <option key={filter} value={filter}>
                    {filter}
                  </option>
                ))}
              </select>
            </label>
            <label className="control-stack compact">
              <span>Cutoff</span>
              <input
                type="range"
                min={20}
                max={20000}
                step={10}
                value={object.synth.cutoff}
                onChange={(event) => updateObjectSynth(object.id, { cutoff: Number(event.target.value) })}
              />
              <strong>{Math.round(object.synth.cutoff)} Hz</strong>
            </label>
            <label className="control-stack compact">
              <span>Resonance</span>
              <input
                type="range"
                min={0}
                max={20}
                step={0.1}
                value={object.synth.resonance}
                onChange={(event) => updateObjectSynth(object.id, { resonance: Number(event.target.value) })}
              />
              <strong>{object.synth.resonance.toFixed(1)} dB</strong>
            </label>
          </div>

          <div className="synth-section">
            <h4>Envelope</h4>
            {(['attack', 'decay', 'sustain', 'release'] as const).map((key) => (
              <label key={key} className="control-stack compact">
                <span>{key.toUpperCase()}</span>
                <input
                  type="range"
                  min={0}
                  max={key === 'sustain' ? 1 : 5}
                  step={0.01}
                  value={object.synth.amplitudeEnvelope[key]}
                  onChange={(event) =>
                    updateObjectSynth(object.id, {
                      amplitudeEnvelope: {
                        ...object.synth.amplitudeEnvelope,
                        [key]: Number(event.target.value),
                      },
                    })
                  }
                />
                <strong>{object.synth.amplitudeEnvelope[key].toFixed(2)}</strong>
              </label>
            ))}
          </div>

          <div className="synth-section">
            <h4>Effects</h4>
            {([
              ['reverb', 'Reverb'],
              ['delayMix', 'Delay Mix'],
              ['chorusMix', 'Chorus Mix'],
            ] as const).map(([key, label]) => (
              <label key={key} className="control-stack compact">
                <span>{label}</span>
                <input
                  type="range"
                  min={0}
                  max={100}
                  value={object.synth.effects[key]}
                  onChange={(event) =>
                    updateObjectSynth(object.id, {
                      effects: {
                        ...object.synth.effects,
                        [key]: Number(event.target.value),
                      },
                    })
                  }
                />
                <strong>{object.synth.effects[key]}%</strong>
              </label>
            ))}

            <button type="button" className="transport-button primary" onClick={() => void previewObject(object.id)}>
              Preview Voice
            </button>
          </div>
        </div>
      </Panel>

      <Panel eyebrow="Sequencer" title="16-Step Pattern Matrix" className="sequencer-panel">
        <div className="sequencer-toolbar">
          <label className="control-stack compact">
            <span>Scale</span>
            <select
              value={object.sequencer.scale}
              onChange={(event) =>
                updateObjectSequencer(object.id, { scale: event.target.value as ScaleName })
              }
            >
              {['major', 'minor', 'dorian', 'phrygian', 'chromatic', 'pentatonic'].map((scale) => (
                <option key={scale} value={scale}>
                  {scale}
                </option>
              ))}
            </select>
          </label>
          <label className="control-stack compact">
            <span>Octave Range</span>
            <input
              type="range"
              min={-2}
              max={2}
              value={object.sequencer.octaveRange}
              onChange={(event) =>
                updateObjectSequencer(object.id, { octaveRange: Number(event.target.value) })
              }
            />
            <strong>{object.sequencer.octaveRange}</strong>
          </label>

          <div className="slot-row">
            {object.sequencer.slots.map((_, index) => (
              <button
                key={index}
                type="button"
                className={`mini-toggle ${object.sequencer.activeSlot === index ? 'is-active' : ''}`}
                onClick={() => loadPatternSlot(object.id, index)}
              >
                {index + 1}
              </button>
            ))}
            <button type="button" className="mini-toggle solo" onClick={() => savePatternSlot(object.id, object.sequencer.activeSlot)}>
              Save Slot
            </button>
          </div>
        </div>

        <div className="sequencer-grid">
          {rows.map((row) => {
            const values = object.sequencer[row.key] as number[];
            return (
              <div key={row.key} className="sequencer-row">
                <span className="sequencer-row-label">{row.label}</span>
                {values.map((value, index) => {
                  const isGateRow = row.key === 'probability' ? object.sequencer.gates[index] : true;
                  return (
                    <button
                      key={`${row.key}-${index}`}
                      type="button"
                      className={`step-cell ${currentStep === index ? 'is-current' : ''} ${isGateRow ? '' : 'is-muted'}`}
                      style={{
                        '--step-level': `${(Number(value) / row.max) * 100}%`,
                      } as React.CSSProperties}
                      onClick={() => {
                        const nextValues = [...values];
                        nextValues[index] =
                          ((Number(value) + Math.ceil((row.max - row.min) / 4)) % (row.max + 1 - row.min)) + row.min;
                        updateSequencerRow(object.id, row.key, nextValues);
                      }}
                    >
                      <strong>{value}</strong>
                    </button>
                  );
                })}
              </div>
            );
          })}
          <div className="sequencer-row">
            <span className="sequencer-row-label">Gate</span>
            {object.sequencer.gates.map((gate, index) => (
              <button
                key={`gate-${index}`}
                type="button"
                className={`step-cell gate-cell ${gate ? 'is-active' : ''} ${currentStep === index ? 'is-current' : ''}`}
                onClick={() => {
                  const gates = [...object.sequencer.gates];
                  gates[index] = !gates[index];
                  updateSequencerRow(object.id, 'gates', gates);
                }}
              >
                <strong>{gate ? 'X' : '-'}</strong>
              </button>
            ))}
          </div>
        </div>
      </Panel>
    </div>
  );
}
