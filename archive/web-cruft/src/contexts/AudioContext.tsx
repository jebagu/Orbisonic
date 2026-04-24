import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type PropsWithChildren,
} from 'react';
import * as Tone from 'tone';
import { useProject } from './ProjectContext';
import type { MeterReading, ObjectId, OscillatorType } from '../types';

interface AudioContextValue {
  meters: MeterReading[];
  currentStep: number;
  previewObject: (id: ObjectId) => Promise<void>;
}

const AudioContext = createContext<AudioContextValue | null>(null);

const scaleIntervals = {
  major: [0, 2, 4, 5, 7, 9, 11],
  minor: [0, 2, 3, 5, 7, 8, 10],
  dorian: [0, 2, 3, 5, 7, 9, 10],
  phrygian: [0, 1, 3, 5, 7, 8, 10],
  chromatic: [0, 1, 2, 3, 4, 5, 6],
  pentatonic: [0, 3, 5, 7, 10, 12, 15],
} as const;

function toOscillatorType(type: OscillatorType) {
  return type as any;
}

function getMidiNote(stepValue: number, scaleName: keyof typeof scaleIntervals, octaveRange: number) {
  const intervals = scaleIntervals[scaleName];
  const octave = Math.floor(stepValue / intervals.length) + octaveRange;
  const interval = intervals[((stepValue % intervals.length) + intervals.length) % intervals.length];
  return 60 + octave * 12 + interval;
}

export function AudioProvider({ children }: PropsWithChildren) {
  const { state, setCurrentTime, setPlaying } = useProject();
  const [meters, setMeters] = useState<MeterReading[]>([]);
  const [currentStep, setCurrentStep] = useState(0);
  const rafRef = useRef<number | null>(null);
  const startedAtRef = useRef<number | null>(null);
  const synthRefs = useRef<Record<ObjectId, Tone.PolySynth | null>>({ A: null, B: null });
  const reverbRefs = useRef<Record<ObjectId, Tone.Reverb | null>>({ A: null, B: null });
  const delayRefs = useRef<Record<ObjectId, Tone.FeedbackDelay | null>>({ A: null, B: null });
  const chorusRefs = useRef<Record<ObjectId, Tone.Chorus | null>>({ A: null, B: null });
  const limiterRef = useRef<Tone.Limiter | null>(null);

  useEffect(() => {
    limiterRef.current = new Tone.Limiter(-0.5).toDestination();

    (['A', 'B'] as ObjectId[]).forEach((id) => {
      const reverb = new Tone.Reverb({ wet: 0.22, decay: 2.3 });
      const delay = new Tone.FeedbackDelay({ delayTime: '8n', feedback: 0.3, wet: 0.16 });
      const chorus = new Tone.Chorus({ frequency: 1.4, delayTime: 3.2, depth: 0.42, wet: 0.12 }).start();
      const synth = new Tone.PolySynth(Tone.Synth, {
        oscillator: {
          type: 'triangle',
        },
        envelope: {
          attack: 0.03,
          decay: 0.35,
          sustain: 0.72,
          release: 1.2,
        },
      });

      synth.chain(chorus, delay, reverb, limiterRef.current!);
      synthRefs.current[id] = synth;
      reverbRefs.current[id] = reverb;
      delayRefs.current[id] = delay;
      chorusRefs.current[id] = chorus;
    });

    return () => {
      Tone.Transport.stop();
      Tone.Transport.cancel();
      limiterRef.current?.dispose();
      (['A', 'B'] as ObjectId[]).forEach((id) => {
        synthRefs.current[id]?.dispose();
        reverbRefs.current[id]?.dispose();
        delayRefs.current[id]?.dispose();
        chorusRefs.current[id]?.dispose();
      });
    };
  }, []);

  useEffect(() => {
    Tone.Transport.bpm.value = state.bpm;
  }, [state.bpm]);

  useEffect(() => {
    state.objects.forEach((object) => {
      const synth = synthRefs.current[object.id];
      if (!synth) {
        return;
      }

      synth.set({
        oscillator: {
          type: toOscillatorType(object.synth.waveform),
        },
        detune: object.synth.detune,
        envelope: {
          attack: object.synth.amplitudeEnvelope.attack,
          decay: object.synth.amplitudeEnvelope.decay,
          sustain: object.synth.amplitudeEnvelope.sustain,
          release: object.synth.amplitudeEnvelope.release,
        },
      });

      const reverb = reverbRefs.current[object.id];
      const delay = delayRefs.current[object.id];
      const chorus = chorusRefs.current[object.id];

      if (reverb) {
        reverb.set({
          wet: object.synth.effects.reverb / 100,
          decay: object.synth.effects.decay,
        });
      }

      if (delay) {
        delay.set({
          wet: object.synth.effects.delayMix / 100,
          feedback: object.synth.effects.feedback / 100,
          delayTime: object.synth.effects.delayTime,
        });
      }

      if (chorus) {
        chorus.set({
          wet: object.synth.effects.chorusMix / 100,
          frequency: object.synth.effects.chorusRate,
          depth: object.synth.effects.chorusDepth / 100,
        });
      }
    });
  }, [state.objects]);

  useEffect(() => {
    Tone.Transport.cancel();

    const eighthNoteDuration = 60 / state.bpm / 4;
    Tone.Transport.scheduleRepeat((time) => {
      setCurrentStep((step) => {
        const nextStep = (step + 1) % 16;
        state.objects.forEach((object) => {
          if (object.type !== 'synth' || object.muted) {
            return;
          }

          const gate = object.sequencer.gates[nextStep];
          const probability = (object.sequencer.probability[nextStep] ?? 0) / 100;
          if (!gate || Math.random() > probability) {
            return;
          }

          const synth = synthRefs.current[object.id];
          if (!synth) {
            return;
          }

          const velocity = (object.sequencer.velocity[nextStep] ?? 0) / 127;
          const midi = getMidiNote(object.sequencer.pitch[nextStep] ?? 0, object.sequencer.scale, object.sequencer.octaveRange);
          const frequency = Tone.Frequency(midi, 'midi').toFrequency();
          synth.triggerAttackRelease(frequency, eighthNoteDuration * 0.95, time, Math.max(0.08, velocity));
        });

        return nextStep;
      });
    }, '16n');
  }, [state.bpm, state.objects]);

  useEffect(() => {
    if (!state.playing) {
      if (rafRef.current) {
        cancelAnimationFrame(rafRef.current);
        rafRef.current = null;
      }
      startedAtRef.current = null;
      Tone.Transport.stop();
      Tone.Transport.seconds = 0;
      setCurrentStep(0);
      setMeters(
        [...state.bedChannels, ...state.objects].map((channel) => ({
          id: channel.id,
          label: channel.label,
          accent: channel.accent,
          value: 0,
        })),
      );
      return;
    }

    void Tone.start();
    Tone.Transport.start();
    startedAtRef.current = performance.now() - state.currentTime * 1000;

    const updateClock = () => {
      if (startedAtRef.current == null) {
        return;
      }

      const elapsed = (performance.now() - startedAtRef.current) / 1000;
      if (elapsed >= state.length) {
        setCurrentTime(state.length);
        setPlaying(false);
        return;
      }

      setCurrentTime(elapsed);
      rafRef.current = requestAnimationFrame(updateClock);
    };

    rafRef.current = requestAnimationFrame(updateClock);

    return () => {
      if (rafRef.current) {
        cancelAnimationFrame(rafRef.current);
        rafRef.current = null;
      }
    };
  }, [state.length, state.playing]);

  useEffect(() => {
    const soloActive = [...state.bedChannels, ...state.objects].some((channel) => channel.solo);
    const nextMeters = [...state.bedChannels, ...state.objects].map((channel, index) => {
      const audible = !channel.muted && (!soloActive || channel.solo);
      const phase = state.currentTime * (1.4 + index * 0.13) + index * 0.4;
      const movementBoost = channel.id === 'A' || channel.id === 'B' ? 0.18 : 0.1;
      const baseLevel = state.playing ? Math.abs(Math.sin(phase)) * 0.55 + movementBoost : 0;
      const volume = channel.volume / 100;
      return {
        id: channel.id,
        label: channel.label,
        accent: channel.accent,
        value: audible ? Math.min(1, baseLevel * volume) : 0,
      };
    });
    setMeters(nextMeters);
  }, [state.bedChannels, state.currentTime, state.objects, state.playing]);

  const value: AudioContextValue = {
    meters,
    currentStep,
    previewObject: async (id) => {
      await Tone.start();
      const object = state.objects.find((item) => item.id === id);
      const synth = synthRefs.current[id];
      if (!object || !synth) {
        return;
      }
      const midi = getMidiNote(object.sequencer.pitch[0] ?? 0, object.sequencer.scale, object.sequencer.octaveRange);
      synth.triggerAttackRelease(Tone.Frequency(midi, 'midi').toFrequency(), '8n');
    },
  };

  return <AudioContext.Provider value={value}>{children}</AudioContext.Provider>;
}

export function useAudioEngine() {
  const context = useContext(AudioContext);
  if (!context) {
    throw new Error('useAudioEngine must be used inside AudioProvider');
  }
  return context;
}
