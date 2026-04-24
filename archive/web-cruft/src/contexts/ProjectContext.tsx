import {
  createContext,
  startTransition,
  useContext,
  useMemo,
  useState,
  type PropsWithChildren,
} from 'react';
import { createDefaultProject, createDemoProject, deriveProjectLength } from '../utils/project';
import type {
  BedChannel,
  ChannelId,
  ObjectChannel,
  ObjectId,
  OutputSettings,
  ProjectState,
  SequencerPattern,
  SynthSettings,
  TabId,
} from '../types';

interface ProjectContextValue {
  state: ProjectState;
  setActiveTab: (tab: TabId) => void;
  setSelectedChannelId: (channelId: ChannelId) => void;
  setSelectedObjectId: (objectId: ObjectId) => void;
  setPlaying: (playing: boolean) => void;
  togglePlayback: () => void;
  resetTransport: () => void;
  setCurrentTime: (time: number) => void;
  setBpm: (bpm: number) => void;
  setMasterVolume: (volume: number) => void;
  setRenderMode: (mode: ProjectState['renderMode']) => void;
  updateOutput: (patch: Partial<OutputSettings>) => void;
  updateBed: (id: BedChannel['id'], patch: Partial<BedChannel>) => void;
  resetBed: (id: BedChannel['id']) => void;
  updateObject: (id: ObjectId, patch: Partial<ObjectChannel>) => void;
  updateObjectSynth: (id: ObjectId, patch: Partial<SynthSettings>) => void;
  updateObjectSequencer: (id: ObjectId, patch: Partial<SequencerPattern>) => void;
  updateSequencerRow: (
    id: ObjectId,
    row: keyof Pick<SequencerPattern, 'pitch' | 'velocity' | 'filter' | 'probability' | 'gates'>,
    steps: number[] | boolean[],
  ) => void;
  loadPatternSlot: (id: ObjectId, slotIndex: number) => void;
  savePatternSlot: (id: ObjectId, slotIndex: number) => void;
  toggleMute: (id: ChannelId) => void;
  toggleSolo: (id: ChannelId) => void;
  loadAudioFile: (id: ChannelId, file: File) => Promise<void>;
  loadDemoProject: () => void;
}

const ProjectContext = createContext<ProjectContextValue | null>(null);
const defaultProject = createDefaultProject();

function cloneDefaultBed(id: BedChannel['id']): BedChannel {
  return defaultProject.bedChannels.find((channel) => channel.id === id) ?? defaultProject.bedChannels[0];
}

function updateProjectLength(state: ProjectState): ProjectState {
  return {
    ...state,
    length: deriveProjectLength(state.bedChannels),
  };
}

async function extractWaveform(file: File): Promise<{ duration: number; waveform: number[] }> {
  const arrayBuffer = await file.arrayBuffer();
  let waveform = Array.from({ length: 64 }, (_, index) => {
    const bytes = new Uint8Array(arrayBuffer);
    const start = Math.floor((index / 64) * bytes.length);
    const end = Math.floor(((index + 1) / 64) * bytes.length);
    let total = 0;
    for (let cursor = start; cursor < end; cursor += 1) {
      total += bytes[cursor] ?? 0;
    }
    const average = total / Math.max(1, end - start);
    return Math.max(0.04, average / 255);
  });

  let duration = Math.max(3, Math.round(file.size / 90000));

  if (typeof window !== 'undefined' && 'AudioContext' in window) {
    const audioContext = new window.AudioContext();
    try {
      const audioBuffer = await audioContext.decodeAudioData(arrayBuffer.slice(0));
      duration = audioBuffer.duration;
      const channel = audioBuffer.getChannelData(0);
      waveform = Array.from({ length: 64 }, (_, index) => {
        const start = Math.floor((index / 64) * channel.length);
        const end = Math.floor(((index + 1) / 64) * channel.length);
        let peak = 0;
        for (let cursor = start; cursor < end; cursor += 1) {
          peak = Math.max(peak, Math.abs(channel[cursor] ?? 0));
        }
        return Math.max(0.03, peak);
      });
    } catch {
      // If decoding fails we still preserve a useful waveform proxy from the file bytes.
    } finally {
      await audioContext.close();
    }
  }

  return {
    duration,
    waveform,
  };
}

export function ProjectProvider({ children }: PropsWithChildren) {
  const [state, setState] = useState<ProjectState>(() => createDefaultProject());

  const value = useMemo<ProjectContextValue>(
    () => ({
      state,
      setActiveTab: (tab) => {
        setState((current) => ({ ...current, activeTab: tab }));
      },
      setSelectedChannelId: (channelId) => {
        setState((current) => ({
          ...current,
          selectedChannelId: channelId,
          selectedObjectId: channelId === 'A' || channelId === 'B' ? channelId : current.selectedObjectId,
        }));
      },
      setSelectedObjectId: (objectId) => {
        setState((current) => ({
          ...current,
          selectedObjectId: objectId,
          selectedChannelId: objectId,
        }));
      },
      setPlaying: (playing) => {
        setState((current) => ({ ...current, playing }));
      },
      togglePlayback: () => {
        setState((current) => ({ ...current, playing: !current.playing }));
      },
      resetTransport: () => {
        setState((current) => ({ ...current, playing: false, currentTime: 0 }));
      },
      setCurrentTime: (time) => {
        setState((current) => ({ ...current, currentTime: Math.max(0, Math.min(time, current.length)) }));
      },
      setBpm: (bpm) => {
        setState((current) => ({ ...current, bpm }));
      },
      setMasterVolume: (volume) => {
        setState((current) => ({ ...current, masterVolume: volume }));
      },
      setRenderMode: (mode) => {
        setState((current) => ({ ...current, renderMode: mode }));
      },
      updateOutput: (patch) => {
        setState((current) => ({
          ...current,
          output: {
            ...current.output,
            ...patch,
          },
        }));
      },
      updateBed: (id, patch) => {
        setState((current) =>
          updateProjectLength({
            ...current,
            bedChannels: current.bedChannels.map((channel) =>
              channel.id === id ? { ...channel, ...patch } : channel,
            ),
          }),
        );
      },
      resetBed: (id) => {
        setState((current) => ({
          ...current,
          bedChannels: current.bedChannels.map((channel) => (channel.id === id ? cloneDefaultBed(id) : channel)),
        }));
      },
      updateObject: (id, patch) => {
        setState((current) => ({
          ...current,
          objects: current.objects.map((object) => (object.id === id ? { ...object, ...patch } : object)),
        }));
      },
      updateObjectSynth: (id, patch) => {
        setState((current) => ({
          ...current,
          objects: current.objects.map((object) =>
            object.id === id
              ? {
                  ...object,
                  synth: {
                    ...object.synth,
                    ...patch,
                  },
                }
              : object,
          ),
        }));
      },
      updateObjectSequencer: (id, patch) => {
        setState((current) => ({
          ...current,
          objects: current.objects.map((object) =>
            object.id === id
              ? {
                  ...object,
                  sequencer: {
                    ...object.sequencer,
                    ...patch,
                  },
                }
              : object,
          ),
        }));
      },
      updateSequencerRow: (id, row, steps) => {
        setState((current) => ({
          ...current,
          objects: current.objects.map((object) =>
            object.id === id
              ? {
                  ...object,
                  sequencer: {
                    ...object.sequencer,
                    [row]: steps,
                  },
                }
              : object,
          ),
        }));
      },
      loadPatternSlot: (id, slotIndex) => {
        setState((current) => ({
          ...current,
          objects: current.objects.map((object) =>
            object.id === id
              ? {
                  ...object,
                  sequencer: {
                    ...object.sequencer,
                    activeSlot: slotIndex,
                    ...object.sequencer.slots[slotIndex],
                  },
                }
              : object,
          ),
        }));
      },
      savePatternSlot: (id, slotIndex) => {
        setState((current) => ({
          ...current,
          objects: current.objects.map((object) =>
            object.id === id
              ? {
                  ...object,
                  sequencer: {
                    ...object.sequencer,
                    activeSlot: slotIndex,
                    slots: object.sequencer.slots.map((slot, index) =>
                      index === slotIndex
                        ? {
                            pitch: [...object.sequencer.pitch],
                            velocity: [...object.sequencer.velocity],
                            filter: [...object.sequencer.filter],
                            probability: [...object.sequencer.probability],
                            gates: [...object.sequencer.gates],
                          }
                        : slot,
                    ),
                  },
                }
              : object,
          ),
        }));
      },
      toggleMute: (id) => {
        setState((current) => ({
          ...current,
          bedChannels: current.bedChannels.map((channel) =>
            channel.id === id ? { ...channel, muted: !channel.muted } : channel,
          ),
          objects: current.objects.map((object) => (object.id === id ? { ...object, muted: !object.muted } : object)),
        }));
      },
      toggleSolo: (id) => {
        setState((current) => ({
          ...current,
          bedChannels: current.bedChannels.map((channel) =>
            channel.id === id ? { ...channel, solo: !channel.solo } : { ...channel, solo: false },
          ),
          objects: current.objects.map((object) =>
            object.id === id ? { ...object, solo: !object.solo } : { ...object, solo: false },
          ),
        }));
      },
      loadAudioFile: async (id, file) => {
        const analysis = await extractWaveform(file);

        setState((current) =>
          updateProjectLength({
            ...current,
            bedChannels: current.bedChannels.map((channel) =>
              channel.id === id
                ? {
                    ...channel,
                    fileName: file.name,
                    duration: analysis.duration,
                    waveform: analysis.waveform,
                  }
                : channel,
            ),
            objects: current.objects.map((object) =>
              object.id === id
                ? {
                    ...object,
                    fileName: file.name,
                    duration: analysis.duration,
                    waveform: analysis.waveform,
                    type: 'sample',
                  }
                : object,
            ),
          }),
        );
      },
      loadDemoProject: () => {
        startTransition(() => {
          setState(createDemoProject());
        });
      },
    }),
    [state],
  );

  return <ProjectContext.Provider value={value}>{children}</ProjectContext.Provider>;
}

export function useProject() {
  const context = useContext(ProjectContext);
  if (!context) {
    throw new Error('useProject must be used inside ProjectProvider');
  }
  return context;
}
