import type {
  BedChannel,
  MovementParams,
  ObjectChannel,
  ProjectState,
  SequencerPattern,
  SynthSettings,
  Vector3,
} from '../types';

function generateWaveform(seed: number, length = 48): number[] {
  return Array.from({ length }, (_, index) => {
    const normalized = index / length;
    const harmonic = Math.sin((normalized + seed * 0.07) * Math.PI * 6);
    const overtone = Math.cos((normalized + seed * 0.19) * Math.PI * 13) * 0.4;
    const pulse = Math.sin((normalized + seed * 0.11) * Math.PI * 2);
    return Math.max(0.06, Math.abs(harmonic * 0.58 + overtone * 0.25 + pulse * 0.17));
  });
}

function createMovementParams(position: Vector3): MovementParams {
  return {
    center: { x: 0, y: 0, z: 0 },
    orbitRadius: 2.1,
    orbitSpeed: 0.8,
    orbitAxis: 'xz',
    orbitTilt: 15,
    orbitDirection: 1,
    phaseOffset: 0,
    centerElevation: 0,
    amplitude: 28,
    speed: 0.65,
    axisAzimuth: 0,
    axisElevation: 0,
    pauseAtEnds: 0.2,
    path: [
      position,
      { x: position.x + 0.7, y: position.y + 0.9, z: position.z - 0.3 },
      { x: position.x - 1.1, y: position.y + 0.2, z: position.z - 1.1 },
      { x: position.x + 0.5, y: position.y - 0.7, z: position.z + 0.7 },
    ],
    pathSmoothness: 0.65,
  };
}

function createSequencer(seed: number): SequencerPattern {
  const pitch = Array.from({ length: 16 }, (_, index) =>
    index % 4 === 0 ? 7 + ((seed + index) % 5) : index % 2 === 0 ? 3 : 0,
  );
  const velocity = Array.from({ length: 16 }, (_, index) => (index % 4 === 0 ? 95 : 62 + ((index + seed) % 12)));
  const filter = Array.from({ length: 16 }, (_, index) => 25 + ((index * 11 + seed * 7) % 70));
  const probability = Array.from({ length: 16 }, (_, index) => (index % 3 === 0 ? 100 : 72));
  const gates = Array.from({ length: 16 }, (_, index) => index % 5 !== 3);

  const slot = { pitch, velocity, filter, probability, gates };
  return {
    ...slot,
    scale: seed % 2 === 0 ? 'dorian' : 'minor',
    octaveRange: 0,
    activeSlot: 0,
    slots: Array.from({ length: 8 }, (_, slotIndex) => ({
      pitch: pitch.map((value, index) => value + ((slotIndex + index) % 3)),
      velocity: velocity.map((value, index) => Math.min(127, value + ((slotIndex + index) % 8))),
      filter: filter.map((value, index) => Math.min(100, value + ((slotIndex * 7 + index) % 10))),
      probability,
      gates: gates.map((gate, index) => (slotIndex % 2 === 0 ? gate : index % 2 === 0)),
    })),
  };
}

function createSynthSettings(waveform: SynthSettings['waveform']): SynthSettings {
  return {
    waveform,
    detune: 0,
    pulseWidth: 45,
    filterType: 'lowpass',
    cutoff: 3200,
    resonance: 4,
    filterEnvelope: {
      attack: 0.08,
      decay: 0.6,
      sustain: 0.52,
      release: 1.2,
    },
    amplitudeEnvelope: {
      attack: 0.03,
      decay: 0.35,
      sustain: 0.72,
      release: 1.4,
    },
    effects: {
      reverb: 22,
      roomSize: 44,
      decay: 2.3,
      delayTime: 0.5,
      feedback: 32,
      delayMix: 18,
      chorusRate: 1.4,
      chorusDepth: 42,
      chorusMix: 16,
    },
  };
}

function createBedChannel(
  id: BedChannel['id'],
  label: string,
  accent: string,
  azimuth: number,
  elevation: number,
  duration: number,
  seed: number,
): BedChannel {
  return {
    id,
    label,
    kind: 'bed',
    accent,
    volume: 72,
    muted: false,
    solo: false,
    duration,
    startTime: 0,
    loop: true,
    waveform: generateWaveform(seed),
    fileName: null,
    position: {
      azimuth,
      elevation,
      distance: 3.5,
    },
    rotationZ: (azimuth + 360) % 360,
    rotationY: 0,
    elevation,
  };
}

function createObjectChannel(
  id: ObjectChannel['id'],
  label: string,
  accent: string,
  position: Vector3,
  waveform: SynthSettings['waveform'],
  seed: number,
): ObjectChannel {
  return {
    id,
    label,
    kind: 'object',
    accent,
    volume: 80,
    muted: false,
    solo: false,
    duration: 84,
    startTime: id === 'A' ? 0 : 4,
    loop: id === 'A',
    waveform: generateWaveform(seed),
    fileName: null,
    type: 'synth',
    position,
    movementMode: id === 'A' ? 'orbit' : 'path',
    movementParams: createMovementParams(position),
    movementEnabled: true,
    syncToTempo: id === 'A',
    synth: createSynthSettings(waveform),
    sequencer: createSequencer(seed),
  };
}

export function deriveProjectLength(bedChannels: BedChannel[]): number {
  const longest = bedChannels.reduce((max, channel) => Math.max(max, channel.duration), 0);
  return Math.max(24, Math.round(longest));
}

export function createDefaultProject(): ProjectState {
  const bedChannels = [
    createBedChannel('B1', 'BED 1', '#00d4ff', 315, 30, 96, 1),
    createBedChannel('B2', 'BED 2', '#00d4ff', 45, 30, 96, 2),
    createBedChannel('B3', 'BED 3', '#00d4ff', 135, -15, 96, 3),
    createBedChannel('B4', 'BED 4', '#00d4ff', 225, -15, 96, 4),
  ];

  return {
    activeTab: 'music',
    selectedChannelId: 'A',
    selectedObjectId: 'A',
    bpm: 118,
    currentTime: 0,
    length: deriveProjectLength(bedChannels),
    masterVolume: 82,
    playing: false,
    renderMode: 'binaural',
    bedChannels,
    objects: [
      createObjectChannel('A', 'OBJ A', '#ff00ff', { x: 1.2, y: 0.8, z: 1.6 }, 'triangle', 8),
      createObjectChannel('B', 'OBJ B', '#ffff00', { x: -1.6, y: 1.1, z: -0.8 }, 'sawtooth', 13),
    ],
    output: {
      headSize: 'medium',
      crossfade: 78,
      sampleRate: '48kHz',
      bitDepth: '24-bit',
      bypass: false,
    },
  };
}

export function createDemoProject(): ProjectState {
  const project = createDefaultProject();
  return {
    ...project,
    bpm: 124,
    playing: false,
    activeTab: 'music',
    bedChannels: project.bedChannels.map((channel, index) => ({
      ...channel,
      fileName: `demo-bed-${index + 1}.wav`,
      volume: 68 + index * 4,
      waveform: generateWaveform(index + 21, 72),
    })),
    objects: project.objects.map((object, index) => ({
      ...object,
      type: 'synth',
      fileName: null,
      waveform: generateWaveform(index + 31, 72),
      movementMode: index === 0 ? 'orbit' : 'through',
      movementEnabled: true,
      syncToTempo: true,
    })),
  };
}
