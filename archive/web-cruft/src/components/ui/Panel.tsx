import type { PropsWithChildren, ReactNode } from 'react';

interface PanelProps extends PropsWithChildren {
  title?: string;
  eyebrow?: string;
  action?: ReactNode;
  className?: string;
}

export function Panel({ title, eyebrow, action, className, children }: PanelProps) {
  return (
    <section className={`panel ${className ?? ''}`.trim()}>
      {(title || eyebrow || action) && (
        <header className="panel-header">
          <div>
            {eyebrow ? <p className="panel-eyebrow">{eyebrow}</p> : null}
            {title ? <h3 className="panel-title">{title}</h3> : null}
          </div>
          {action ? <div>{action}</div> : null}
        </header>
      )}
      {children}
    </section>
  );
}
