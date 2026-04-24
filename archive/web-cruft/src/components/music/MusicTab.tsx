import { ChangeEvent } from 'react';
import { useAudioEngine } from '../../contexts/AudioContext';
import { useProject } from '../../contexts/ProjectContext';
import { Panel } from '../ui/Panel';
import { Transport } from '../layout/Transport';
import { WaveformDisplay } from './WaveformDisplay';
import type { ChannelId, ObjectType } from '../../types';

function formatDuration(duration: number) {
  const minutes = Math.floor(duration / 60)
    .toString()
    .padStart(2, '0');
  const seconds = Math.floor(duration % 60)
    .toString()
    .padStart(2, '0');
  return `${minutes}:${seconds}`;
}

function MeterStrip({ value, accent }: { value: number; accent: string }) {
  return (
    <div className="meter-strip">
      <div className="meter-strip-fill" style={{ height: `${Math.max(6, value * 100)}%`, background: accent }} />
    </div>
  );
}

export function MusicTab() {
  const {
    state,
    setSelectedChannelId,
    setSelectedObjectId,
    updateBed,
    updateObject,
    toggleMute,
    toggleSolo,
    loadAudioFile,
  } = useProject();
  const { meters } = useAudioEngine();
  const channels = [...state.bedChannels, ...state.objects];

  const handleFileChange = async (id: ChannelId, event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) {
      return;
    }

    await loadAudioFile(id, file);
  };

  return (
    <div className="tab-grid music-grid">
      <Panel eyebrow="Transport" title="Master Control" className="transport-panel">
        <Transport />
      </Panel>

      <Panel
        eyebrow="Music"
        title="Bed + Object Decks"
        className="channel-panel"
        action={<span className="panel-chip">6 Channels</span>}
      >
        <div className="channel-list">
          {channels.map((channel) => {
            const isObject = channel.kind === 'object';
            const meter = meters.find((item) => item.id === channel.id)?.value ?? 0;

            return (
              <article
                key={channel.id}
                className={`channel-strip ${state.selectedChannelId === channel.id ? 'is-selected' : ''}`}
                onClick={() => {
                  setSelectedChannelId(channel.id);
                  if (channel.id === 'A' || channel.id === 'B') {
                    setSelectedObjectId(channel.id);
                  }
                }}
              >
                <div className="channel-left">
                  <div className="channel-heading">
                    <div className="channel-title-wrap">
                      <span className="channel-led" style={{ background: channel.accent }} />
                      <div>
                        <h4>{channel.label}</h4>
                        <p>{channel.kind === 'bed' ? 'Looping bed channel' : 'Spatial object'}</p>
                      </div>
                    </div>
                    {isObject ? (
                      <div className="mode-toggle">
                        {(['sample', 'synth'] as ObjectType[]).map((type) => (
                          <button
                            key={type}
                            type="button"
                            className={`mini-toggle ${channel.type === type ? 'is-active' : ''}`}
                            onClick={(event) => {
                              event.stopPropagation();
                              updateObject(channel.id, { type });
                            }}
                          >
                            {type}
                          </button>
                        ))}
                      </div>
                    ) : (
                      <span className="channel-badge">BED</span>
                    )}
                  </div>

                  <WaveformDisplay
                    waveform={channel.waveform}
                    accent={channel.accent}
                    active={state.playing}
                    label={channel.fileName ?? (isObject && channel.type === 'synth' ? 'SYNTH ENGINE' : 'DROP AUDIO FILE')}
                  />

                  <div className="channel-controls-row">
                    <label className="control-stack compact">
                      <span>Start</span>
                      <input
                        type="number"
                        min={0}
                        step={0.1}
                        value={channel.startTime}
                        onChange={(event) =>
                          isObject
                            ? updateObject(channel.id, { startTime: Number(event.target.value) })
                            : undefined
                        }
                        disabled={!isObject}
                      />
                    </label>

                    <label className="control-stack compact">
                      <span>Loop</span>
                      <button
                        type="button"
                        className={`mini-toggle ${channel.loop ? 'is-active' : ''}`}
                        onClick={(event) => {
                          event.stopPropagation();
                          if (isObject) {
                            updateObject(channel.id, { loop: !channel.loop });
                          }
                        }}
                      >
                        {channel.loop ? 'On' : 'Off'}
                      </button>
                    </label>

                    <label className="control-stack compact">
                      <span>Volume</span>
                      <input
                        type="range"
                        min={0}
                        max={100}
                        value={channel.volume}
                        onChange={(event) =>
                          isObject
                            ? updateObject(channel.id, { volume: Number(event.target.value) })
                            : updateBed(channel.id, { volume: Number(event.target.value) })
                        }
                      />
                    </label>

                    <div className="file-actions">
                      <label className="transport-button ghost file-picker">
                        {channel.fileName ? 'Replace File' : 'Load Audio'}
                        <input
                          type="file"
                          accept=".wav,.mp3,.ogg,.flac"
                          onChange={(event) => void handleFileChange(channel.id, event)}
                        />
                      </label>
                      {isObject ? <span className="panel-chip">Automation</span> : null}
                    </div>
                  </div>
                </div>

                <div className="channel-right">
                  <MeterStrip value={meter} accent={channel.accent} />
                  <div className="channel-stats">
                    <div>
                      <span>Duration</span>
                      <strong>{formatDuration(channel.duration)}</strong>
                    </div>
                    <div>
                      <span>Mode</span>
                      <strong>{isObject ? channel.type.toUpperCase() : 'LOOP'}</strong>
                    </div>
                  </div>
                  <div className="channel-button-stack">
                    <button type="button" className={`mini-toggle ${channel.muted ? 'is-active danger' : ''}`} onClick={() => toggleMute(channel.id)}>
                      Mute
                    </button>
                    <button type="button" className={`mini-toggle ${channel.solo ? 'is-active solo' : ''}`} onClick={() => toggleSolo(channel.id)}>
                      Solo
                    </button>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      </Panel>

      <Panel eyebrow="Project" title="Studio Notes" className="summary-panel">
        <ul className="summary-list">
          <li>The four bed channels define project length and default atmosphere.</li>
          <li>Objects can operate as sample lanes or tempo-synced synth voices.</li>
          <li>Upload parsing reads duration and draws a real waveform when the browser can decode the file.</li>
          <li>Use the demo project to populate the sphere with moving synth voices immediately.</li>
        </ul>
      </Panel>
    </div>
  );
}
