export type TabId = 'music' | 'space' | 'synth' | 'render' | 'sphereRender' | 'sphericalPlayer';
export type RenderMode = 'binaural' | 'home51' | 'sonicsphere';
export type HeadSize = 'small' | 'medium' | 'large';
export type ObjectId = 'A' | 'B';
export type BedId = 'B1' | 'B2' | 'B3' | 'B4';
export type ChannelId = BedId | ObjectId;
export type ObjectType = 'sample' | 'synth';
export type MovementMode = 'manual' | 'orbit' | 'updown' | 'through' | 'path';
export type ScaleName =
  | 'major'
  | 'minor'
  | 'dorian'
  | 'phrygian'
  | 'chromatic'
  | 'pentatonic';
export type OscillatorType = 'sine' | 'triangle' | 'sawtooth' | 'square';
export type FilterType = 'lowpass' | 'highpass' | 'bandpass';

export interface Vector3 {
  x: number;
  y: number;
  z: number;
}

export interface SphericalPosition {
  azimuth: number;
  elevation: number;
  distance: number;
}

export interface EnvelopeSettings {
  attack: number;
  decay: number;
  sustain: number;
  release: number;
}

export interface EffectsSettings {
  reverb: number;
  roomSize: number;
  decay: number;
  delayTime: number;
  feedback: number;
  delayMix: number;
  chorusRate: number;
  chorusDepth: number;
  chorusMix: number;
}

export interface SynthSettings {
  waveform: OscillatorType;
  detune: number;
  pulseWidth: number;
  filterType: FilterType;
  cutoff: number;
  resonance: number;
  filterEnvelope: EnvelopeSettings;
  amplitudeEnvelope: EnvelopeSettings;
  effects: EffectsSettings;
}

export interface PatternSlot {
  pitch: number[];
  velocity: number[];
  filter: number[];
  probability: number[];
  gates: boolean[];
}

export interface SequencerPattern {
  pitch: number[];
  velocity: number[];
  filter: number[];
  probability: number[];
  gates: boolean[];
  scale: ScaleName;
  octaveRange: number;
  activeSlot: number;
  slots: PatternSlot[];
}

export interface MovementParams {
  center: Vector3;
  orbitRadius: number;
  orbitSpeed: number;
  orbitAxis: 'xy' | 'xz' | 'yz' | 'custom';
  orbitTilt: number;
  orbitDirection: 1 | -1;
  phaseOffset: number;
  centerElevation: number;
  amplitude: number;
  speed: number;
  axisAzimuth: number;
  axisElevation: number;
  pauseAtEnds: number;
  path: Vector3[];
  pathSmoothness: number;
}

export interface BaseChannel {
  id: ChannelId;
  label: string;
  kind: 'bed' | 'object';
  accent: string;
  volume: number;
  muted: boolean;
  solo: boolean;
  duration: number;
  startTime: number;
  loop: boolean;
  waveform: number[];
  fileName: string | null;
}

export interface BedChannel extends BaseChannel {
  id: BedId;
  kind: 'bed';
  position: SphericalPosition;
  rotationZ: number;
  rotationY: number;
  elevation: number;
}

export interface ObjectChannel extends BaseChannel {
  id: ObjectId;
  kind: 'object';
  type: ObjectType;
  position: Vector3;
  movementMode: MovementMode;
  movementParams: MovementParams;
  movementEnabled: boolean;
  syncToTempo: boolean;
  synth: SynthSettings;
  sequencer: SequencerPattern;
}

export interface OutputSettings {
  headSize: HeadSize;
  crossfade: number;
  sampleRate: '44.1kHz' | '48kHz';
  bitDepth: '16-bit' | '24-bit';
  bypass: boolean;
}

export interface ProjectState {
  activeTab: TabId;
  selectedChannelId: ChannelId;
  selectedObjectId: ObjectId;
  bpm: number;
  currentTime: number;
  length: number;
  masterVolume: number;
  playing: boolean;
  renderMode: RenderMode;
  bedChannels: BedChannel[];
  objects: ObjectChannel[];
  output: OutputSettings;
}

export interface MeterReading {
  id: string;
  label: string;
  accent: string;
  value: number;
}
