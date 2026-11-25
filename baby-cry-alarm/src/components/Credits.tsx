import { PROVENANCE, VOICES } from "../sounds";

export function Credits({ onClose }: { onClose: () => void }) {
  const bySource = new Map(PROVENANCE.sounds.map((s) => [s.id, s]));
  return (
    <div className="sheet" role="dialog" aria-label="Sound credits">
      <header className="sheet-head">
        <span />
        <h2>The babies</h2>
        <button type="button" className="link strong" onClick={onClose}>
          Done
        </button>
      </header>
      <div className="sheet-body">
        <p className="hint">
          Every alarm sound is a real recording of a real baby, taken from {PROVENANCE.repository} under a license that
          allows redistribution. The only change is loudness normalization and MP3 encoding.
        </p>
        {VOICES.map((v) => {
          const p = bySource.get(v.id)!;
          return (
            <section className="group credit" key={v.id}>
              <div className="group-title">
                {v.emoji} {v.name}
              </div>
              <dl>
                <dt>Recording</dt>
                <dd>
                  <a href={v.sourcePage} target="_blank" rel="noreferrer">
                    {p.source.title.replace(/^File:/, "")}
                  </a>
                </dd>
                <dt>By</dt>
                <dd>{v.author}</dd>
                <dt>License</dt>
                <dd>
                  <a href={v.licenseUrl} target="_blank" rel="noreferrer">
                    {v.license}
                  </a>
                </dd>
                <dt>Recorded</dt>
                <dd>{p.source.recorded}</dd>
                <dt>Via</dt>
                <dd>{p.source.upstream}</dd>
              </dl>
            </section>
          );
        })}
        <p className="hint">
          “Kunjappi” is licensed CC BY-SA 4.0: our re-encoded copy is shared under the same license, credited to Manoj
          Karingamadathil.
        </p>
      </div>
    </div>
  );
}
