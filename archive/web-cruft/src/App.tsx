import { AudioProvider } from './contexts/AudioContext';
import { ProjectProvider, useProject } from './contexts/ProjectContext';
import { SpatialProvider } from './contexts/SpatialContext';
import { useKeyboardShortcuts } from './hooks/useKeyboardShortcuts';
import { TabBar } from './components/layout/TabBar';
import { MusicTab } from './components/music/MusicTab';
import { SpatialTab } from './components/spatial/SpatialTab';
import { SynthTab } from './components/synth/SynthTab';
import { RenderTab } from './components/render/RenderTab';
import { SphereRenderTab } from './components/sphere/SphereRenderTab';
import { SphericalPlayerTab } from './components/player/SphericalPlayerTab';

function AppShell() {
  const { state } = useProject();
  useKeyboardShortcuts();

  return (
    <div className="app-shell">
      <div className="ambient-glow ambient-glow-left" />
      <div className="ambient-glow ambient-glow-right" />
      <header className="app-header">
        <TabBar />
      </header>
      <main className="app-main">
        {state.activeTab === 'music' ? <MusicTab /> : null}
        {state.activeTab === 'space' ? <SpatialTab /> : null}
        {state.activeTab === 'synth' ? <SynthTab /> : null}
        {state.activeTab === 'render' ? <RenderTab /> : null}
        {state.activeTab === 'sphereRender' ? <SphereRenderTab /> : null}
        {state.activeTab === 'sphericalPlayer' ? <SphericalPlayerTab /> : null}
      </main>
      <footer className="status-bar">
        <span>Hotkeys: Space, Esc, 1-6, M, S</span>
        <span>Selected: {state.selectedChannelId}</span>
        <span>Status: {state.playing ? 'Running' : 'Idle'}</span>
      </footer>
    </div>
  );
}

export default function App() {
  return (
    <ProjectProvider>
      <SpatialProvider>
        <AudioProvider>
          <AppShell />
        </AudioProvider>
      </SpatialProvider>
    </ProjectProvider>
  );
}
