import { useEffect, useRef } from 'react';

interface WaveformDisplayProps {
  waveform: number[];
  active: boolean;
  accent: string;
  label: string;
}

export function WaveformDisplay({ waveform, active, accent, label }: WaveformDisplayProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) {
      return;
    }

    const context = canvas.getContext('2d');
    if (!context) {
      return;
    }

    const width = canvas.width;
    const height = canvas.height;
    context.clearRect(0, 0, width, height);

    const gradient = context.createLinearGradient(0, 0, width, 0);
    gradient.addColorStop(0, 'rgba(0, 255, 65, 0.1)');
    gradient.addColorStop(1, `${accent}88`);
    context.fillStyle = gradient;
    context.fillRect(0, 0, width, height);

    context.strokeStyle = 'rgba(255,255,255,0.08)';
    context.lineWidth = 1;
    for (let row = 1; row < 4; row += 1) {
      const y = (height / 4) * row;
      context.beginPath();
      context.moveTo(0, y);
      context.lineTo(width, y);
      context.stroke();
    }

    const barWidth = width / waveform.length;
    context.fillStyle = accent;
    waveform.forEach((value, index) => {
      const barHeight = Math.max(4, value * (height - 8));
      const x = index * barWidth;
      const y = (height - barHeight) / 2;
      context.fillRect(x + 1, y, Math.max(2, barWidth - 2), barHeight);
    });

    if (active) {
      const sweep = ((Date.now() / 14) % width) + 8;
      const sweepGradient = context.createLinearGradient(sweep - 18, 0, sweep + 18, 0);
      sweepGradient.addColorStop(0, 'rgba(0,255,65,0)');
      sweepGradient.addColorStop(0.5, 'rgba(0,255,65,0.5)');
      sweepGradient.addColorStop(1, 'rgba(0,255,65,0)');
      context.fillStyle = sweepGradient;
      context.fillRect(0, 0, width, height);
    }

    context.fillStyle = 'rgba(255,255,255,0.75)';
    context.font = '11px "IBM Plex Mono", monospace';
    context.fillText(label, 10, 18);
  }, [accent, active, label, waveform]);

  return <canvas className="waveform" ref={canvasRef} width={520} height={86} />;
}
