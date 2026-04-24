import { useEffect } from 'react';
import { useProject } from '../contexts/ProjectContext';

function shouldIgnoreTarget(target: EventTarget | null) {
  if (!(target instanceof HTMLElement)) {
    return false;
  }

  return ['INPUT', 'TEXTAREA', 'SELECT', 'BUTTON'].includes(target.tagName) || target.isContentEditable;
}

export function useKeyboardShortcuts() {
  const { state, setActiveTab, togglePlayback, resetTransport, toggleMute, toggleSolo } = useProject();

  useEffect(() => {
    const handleKeydown = (event: KeyboardEvent) => {
      if (shouldIgnoreTarget(event.target)) {
        return;
      }

      if (event.code === 'Space') {
        event.preventDefault();
        togglePlayback();
        return;
      }

      if (event.key === 'Escape') {
        resetTransport();
        return;
      }

      if (event.key === '1') {
        setActiveTab('music');
      }
      if (event.key === '2') {
        setActiveTab('space');
      }
      if (event.key === '3') {
        setActiveTab('synth');
      }
      if (event.key === '4') {
        setActiveTab('render');
      }
      if (event.key === '5') {
        setActiveTab('sphereRender');
      }
      if (event.key === '6') {
        setActiveTab('sphericalPlayer');
      }
      if (event.key.toLowerCase() === 'm') {
        toggleMute(state.selectedChannelId);
      }
      if (event.key.toLowerCase() === 's') {
        toggleSolo(state.selectedChannelId);
      }
    };

    window.addEventListener('keydown', handleKeydown);
    return () => window.removeEventListener('keydown', handleKeydown);
  }, [resetTransport, setActiveTab, state.selectedChannelId, toggleMute, togglePlayback, toggleSolo]);
}
