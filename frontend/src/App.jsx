import { useEffect, useState } from "react";

function ExperimentCard({ experiment }) {
  const { title, description, imageUrl, href } = experiment;

  return (
    <article className="card">
      <a
        className="card__link"
        href={href}
        target="_blank"
        rel="noopener noreferrer"
      >
        <div className="card__image-wrap">
          <img
            className="card__image"
            src={imageUrl}
            alt=""
            loading="lazy"
            decoding="async"
          />
          <div className="card__image-veil" aria-hidden />
        </div>
        <div className="card__body">
          <h2 className="card__title">{title}</h2>
          <p className="card__desc">{description}</p>
          <span className="card__cta">
            Open
            <span className="card__cta-arrow" aria-hidden>
              →
            </span>
          </span>
        </div>
      </a>
    </article>
  );
}

export default function App() {
  const [experiments, setExperiments] = useState([]);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch("/api/experiments");
        if (!res.ok) {
          throw new Error(`HTTP ${res.status}`);
        }
        const data = await res.json();
        if (!cancelled) {
          setExperiments(Array.isArray(data.experiments) ? data.experiments : []);
        }
      } catch (e) {
        if (!cancelled) {
          setError(e.message || "Failed to load");
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="page">
      <header className="hero">
        <p className="hero__eyebrow">Ram's Personal lab</p>
        <h1 className="hero__title">
          Experiments<span className="hero__dot">.</span>
        </h1>
        <p className="hero__lead">
          A living wall of side projects, demos, and half-finished ideas. 
        </p>
      </header>

      {loading && <p className="state">Loading…</p>}
      {error && <p className="state state--error">Could not load experiments ({error}).</p>}

      {!loading && !error && experiments.length === 0 && (
        <p className="state">No experiments yet. Add entries to experiments.json.</p>
      )}

      {!loading && !error && experiments.length > 0 && (
        <ul className="grid">
          {experiments.map((exp) => (
            <li key={exp.id} className="grid__item">
              <ExperimentCard experiment={exp} />
            </li>
          ))}
        </ul>
      )}

      <footer className="footer">
        <span>Built with Flask + React</span>
      </footer>
    </div>
  );
}
