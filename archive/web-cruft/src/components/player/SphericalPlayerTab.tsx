import { useMemo, useRef, useState } from 'react';
import { Panel } from '../ui/Panel';

declare global {
  interface Window {
    webkitAudioContext?: typeof AudioContext;
  }
}

type PlayerStatus = 'ready' | 'decoding' | 'playing' | 'stopped' | 'unsupported' | 'error';

interface FileMetadata {
  container: 'WAV' | 'FLAC' | 'Unknown';
  channels: number | null;
  sampleRate: number | null;
  duration: number | null;
  bitDepth: number | null;
}

interface PlayerFile {
  id: string;
  name: string;
  size: number;
  status: PlayerStatus;
  metadata: FileMetadata;
  message: string;
}

const MAX_CHANNELS = 64;

const emptyMetadata: FileMetadata = {
  container: 'Unknown',
  channels: null,
  sampleRate: null,
  duration: null,
  bitDepth: null,
};

function readAscii(bytes: Uint8Array, start: number, length: number) {
  return String.fromCharCode(...bytes.slice(start, start + length));
}

function parseWavHeader(buffer: ArrayBuffer): FileMetadata | null {
  const bytes = new Uint8Array(buffer);
  const view = new DataView(buffer);
  const riffId = readAscii(bytes, 0, 4);
  const waveId = readAscii(bytes, 8, 4);

  if ((riffId !== 'RIFF' && riffId !== 'RF64') || waveId !== 'WAVE') {
    return null;
  }

  let offset = 12;
  let channels: number | null = null;
  let sampleRate: number | null = null;
  let bitDepth: number | null = null;
  let byteRate: number | null = null;
  let dataBytes: number | null = null;

  while (offset + 8 <= buffer.byteLength) {
    const chunkId = readAscii(bytes, offset, 4);
    const chunkSize = view.getUint32(offset + 4, true);
    const chunkStart = offset + 8;

    if (chunkId === 'fmt ' && chunkStart + 16 <= buffer.byteLength) {
      channels = view.getUint16(chunkStart + 2, true);
      sampleRate = view.getUint32(chunkStart + 4, true);
      byteRate = view.getUint32(chunkStart + 8, true);
      bitDepth = chunkStart + 16 <= buffer.byteLength ? view.getUint16(chunkStart + 14, true) : null;
    }

    if (chunkId === 'data') {
      dataBytes = chunkSize;
    }

    offset = chunkStart + chunkSize + (chunkSize % 2);
  }

  return {
    container: 'WAV',
    channels,
    sampleRate,
    duration: dataBytes && byteRate ? dataBytes / byteRate : null,
    bitDepth,
  };
}

function findFlacMarker(bytes: Uint8Array) {
  for (let index = 0; index <= bytes.length - 4; index += 1) {
    if (readAscii(bytes, index, 4) === 'fLaC') {
      return index;
    }
  }
  return -1;
}

function parseFlacHeader(buffer: ArrayBuffer): FileMetadata | null {
  const bytes = new Uint8Array(buffer);
  const marker = findFlacMarker(bytes);

  if (marker < 0 || marker + 42 > bytes.length) {
    return null;
  }

  let offset = marker + 4;
  while (offset + 4 <= bytes.length) {
    const blockHeader = bytes[offset];
    const blockType = blockHeader & 0x7f;
    const blockLength = (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
    const blockStart = offset + 4;

    if (blockType === 0 && blockLength >= 34 && blockStart + 34 <= bytes.length) {
      const streamInfo = bytes.slice(blockStart, blockStart + 34);
      const sampleRate = (streamInfo[10] << 12) | (streamInfo[11] << 4) | ((streamInfo[12] & 0xf0) >> 4);
      const channels = ((streamInfo[12] & 0x0e) >> 1) + 1;
      const bitDepth = (((streamInfo[12] & 0x01) << 4) | ((streamInfo[13] & 0xf0) >> 4)) + 1;
      const totalSamples =
        Number(streamInfo[13] & 0x0f) * 2 ** 32 +
        streamInfo[14] * 2 ** 24 +
        streamInfo[15] * 2 ** 16 +
        streamInfo[16] * 2 ** 8 +
        streamInfo[17];

      return {
        container: 'FLAC',
        channels,
        sampleRate,
        duration: sampleRate > 0 && totalSamples > 0 ? totalSamples / sampleRate : null,
        bitDepth,
      };
    }

    offset = blockStart + blockLength;
  }

  return null;
}

async function readFileMetadata(file: File): Promise<FileMetadata> {
  const header = await file.slice(0, 512 * 1024).arrayBuffer();
  return parseWavHeader(header) ?? parseFlacHeader(header) ?? emptyMetadata;
}

function getAudioContext() {
  const AudioContextConstructor = window.AudioContext || window.webkitAudioContext;
  return new AudioContextConstructor();
}

function formatDuration(duration: number | null) {
  if (duration == null || !Number.isFinite(duration)) {
    return 'unknown';
  }
  const minutes = Math.floor(duration / 60)
    .toString()
    .padStart(2, '0');
  const seconds = Math.floor(duration % 60)
    .toString()
    .padStart(2, '0');
  return `${minutes}:${seconds}`;
}

function formatBytes(bytes: number) {
  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function formatChannels(channels: number | null) {
  return channels == null ? 'unknown' : `${channels} ch`;
}

export function SphericalPlayerTab() {
  const [files, setFiles] = useState<PlayerFile[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const sourceRef = useRef<AudioBufferSourceNode | null>(null);
  const buffersRef = useRef<Map<string, AudioBuffer>>(new Map());

  const selectedFile = useMemo(
    () => files.find((file) => file.id === selectedId) ?? files[0] ?? null,
    [files, selectedId],
  );

  async function addFiles(fileList: FileList | null) {
    if (!fileList?.length) {
      return;
    }

    const incoming = Array.from(fileList).filter((file) => /\.(wav|wave|flac)$/i.test(file.name));
    const pending: PlayerFile[] = incoming.map((file) => ({
      id: `${file.name}-${file.size}-${file.lastModified}-${crypto.randomUUID()}`,
      name: file.name,
      size: file.size,
      status: 'decoding',
      metadata: emptyMetadata,
      message: 'Reading file metadata',
    }));

    setFiles((current) => [...current, ...pending]);
    setSelectedId((current) => current ?? pending[0]?.id ?? null);

    await Promise.all(
      incoming.map(async (file, index) => {
        const item = pending[index];
        if (!item) {
          return;
        }

        try {
          const metadata = await readFileMetadata(file);
          if (metadata.channels != null && metadata.channels > MAX_CHANNELS) {
            setFiles((current) =>
              current.map((entry) =>
                entry.id === item.id
                  ? {
                      ...entry,
                      status: 'unsupported',
                      metadata,
                      message: `File has ${metadata.channels} channels; maximum supported is ${MAX_CHANNELS}.`,
                    }
                  : entry,
              ),
            );
            return;
          }

          const context = audioContextRef.current ?? getAudioContext();
          audioContextRef.current = context;
          const audioBuffer = await context.decodeAudioData(await file.arrayBuffer());
          const decodedChannels = audioBuffer.numberOfChannels;
          if (decodedChannels > MAX_CHANNELS) {
            setFiles((current) =>
              current.map((entry) =>
                entry.id === item.id
                  ? {
                      ...entry,
                      status: 'unsupported',
                      metadata: {
                        ...metadata,
                        channels: decodedChannels,
                        sampleRate: audioBuffer.sampleRate,
                        duration: audioBuffer.duration,
                      },
                      message: `Decoded ${decodedChannels} channels; maximum supported is ${MAX_CHANNELS}.`,
                    }
                  : entry,
              ),
            );
            return;
          }

          buffersRef.current.set(item.id, audioBuffer);
          setFiles((current) =>
            current.map((entry) =>
              entry.id === item.id
                ? {
                    ...entry,
                    status: 'ready',
                    metadata: {
                      ...metadata,
                      channels: decodedChannels,
                      sampleRate: audioBuffer.sampleRate,
                      duration: audioBuffer.duration,
                    },
                    message: 'Ready for local playback',
                  }
                : entry,
            ),
          );
        } catch (error) {
          setFiles((current) =>
            current.map((entry) =>
              entry.id === item.id
                ? {
                    ...entry,
                    status: 'error',
                    message: error instanceof Error ? error.message : 'Could not decode this file.',
                  }
                : entry,
            ),
          );
        }
      }),
    );
  }

  async function playFile(fileId: string) {
    const audioBuffer = buffersRef.current.get(fileId);
    if (!audioBuffer) {
      return;
    }

    const context = audioContextRef.current ?? getAudioContext();
    audioContextRef.current = context;
    await context.resume();

    sourceRef.current?.stop();
    const source = context.createBufferSource();
    const gain = context.createGain();
    gain.gain.value = 0.88;
    gain.channelInterpretation = 'discrete';
    source.buffer = audioBuffer;
    source.channelInterpretation = 'discrete';
    source.connect(gain).connect(context.destination);
    source.onended = () => {
      setFiles((current) =>
        current.map((entry) => (entry.id === fileId && entry.status === 'playing' ? { ...entry, status: 'ready' } : entry)),
      );
    };
    source.start();
    sourceRef.current = source;
    setSelectedId(fileId);
    setFiles((current) =>
      current.map((entry) => ({
        ...entry,
        status: entry.id === fileId ? 'playing' : entry.status === 'playing' ? 'ready' : entry.status,
      })),
    );
  }

  function stopPlayback() {
    sourceRef.current?.stop();
    sourceRef.current = null;
    setFiles((current) =>
      current.map((entry) => (entry.status === 'playing' ? { ...entry, status: 'ready' } : entry)),
    );
  }

  function removeFile(fileId: string) {
    buffersRef.current.delete(fileId);
    setFiles((current) => current.filter((entry) => entry.id !== fileId));
    setSelectedId((current) => (current === fileId ? null : current));
  }

  const readyCount = files.filter((file) => file.status === 'ready' || file.status === 'playing').length;
  const maxChannels = files.reduce((max, file) => Math.max(max, file.metadata.channels ?? 0), 0);

  return (
    <div className="tab-grid spherical-player-grid">
      <Panel
        eyebrow="Library"
        title="Spherical Player"
        className="spherical-library-panel"
        action={
          <label className="transport-button file-picker compact-picker">
            Add Files
            <input
              type="file"
              accept=".wav,.wave,.flac,audio/wav,audio/x-wav,audio/flac"
              multiple
              onChange={(event) => void addFiles(event.currentTarget.files)}
            />
          </label>
        }
      >
        <div className="spherical-file-list">
          {files.length === 0 ? (
            <div className="spherical-empty-state">
              <strong>No local multichannel files loaded</strong>
              <span>Drop in WAV or FLAC files. The player accepts decoded files up to 64 channels.</span>
            </div>
          ) : null}

          {files.map((file) => (
            <button
              key={file.id}
              type="button"
              className={`spherical-file-row ${selectedFile?.id === file.id ? 'is-selected' : ''}`}
              onClick={() => setSelectedId(file.id)}
            >
              <span>
                <strong>{file.name}</strong>
                <small>{file.message}</small>
              </span>
              <span>{formatChannels(file.metadata.channels)}</span>
              <span>{file.metadata.container}</span>
              <span>{formatDuration(file.metadata.duration)}</span>
              <span className={`spherical-status is-${file.status}`}>{file.status}</span>
            </button>
          ))}
        </div>
      </Panel>

      <Panel eyebrow="Deck" title="Local Playback" className="spherical-deck-panel">
        <div className="spherical-deck">
          <div>
            <span>Selected File</span>
            <strong>{selectedFile?.name ?? 'None'}</strong>
          </div>
          <div>
            <span>Format</span>
            <strong>{selectedFile ? `${selectedFile.metadata.container} / ${formatChannels(selectedFile.metadata.channels)}` : 'No file'}</strong>
          </div>
          <div>
            <span>Sample Rate</span>
            <strong>{selectedFile?.metadata.sampleRate ? `${selectedFile.metadata.sampleRate} Hz` : 'unknown'}</strong>
          </div>
          <div>
            <span>Size</span>
            <strong>{selectedFile ? formatBytes(selectedFile.size) : '0 KB'}</strong>
          </div>
        </div>

        <div className="toggle-row spherical-player-controls">
          <button
            type="button"
            className="transport-button primary"
            disabled={!selectedFile || selectedFile.status !== 'ready'}
            onClick={() => selectedFile && void playFile(selectedFile.id)}
          >
            Play
          </button>
          <button type="button" className="transport-button ghost" disabled={!selectedFile} onClick={stopPlayback}>
            Stop
          </button>
          <button
            type="button"
            className="transport-button ghost"
            disabled={!selectedFile}
            onClick={() => selectedFile && removeFile(selectedFile.id)}
          >
            Remove
          </button>
        </div>
      </Panel>

      <Panel eyebrow="Capability" title="64-Channel Readiness" className="spherical-capability-panel">
        <div className="spherical-capability-grid">
          <div>
            <span>Max File Channels</span>
            <strong>{MAX_CHANNELS}</strong>
          </div>
          <div>
            <span>Loaded Files</span>
            <strong>{files.length}</strong>
          </div>
          <div>
            <span>Ready Files</span>
            <strong>{readyCount}</strong>
          </div>
          <div>
            <span>Widest File</span>
            <strong>{maxChannels || 'none'}</strong>
          </div>
        </div>

        <div className="summary-list compact">
          <div>
            <span>Accepted Containers</span>
            <strong>WAV, FLAC</strong>
          </div>
          <div>
            <span>Channel Handling</span>
            <strong>Discrete decode up to 64 ch</strong>
          </div>
          <div>
            <span>Output Note</span>
            <strong>Use system output routing for multichannel hardware</strong>
          </div>
        </div>
      </Panel>
    </div>
  );
}
