import { PROVENANCE, VOICES } from "../sounds";

/** Where each recording came from and under which license. */
export function Credits() {
  const bySource = new Map(PROVENANCE.sounds.map((s) => [s.id, s]));
  return (
    <section className="credits" aria-label="Sound credits">
      <p className="hint">
        Every alarm sound is a real recording of a real baby, taken from Wikimedia Commons under a license that allows
        redistribution. The only change is loudness normalization and MP3 encoding.
      </p>
      {VOICES.map((v) => {
        const p = bySource.get(v.id)!;
        return (
          <div className="group credit" key={v.id}>
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
          </div>
        );
      })}
      <p className="hint">
        “Kunjappi” is licensed CC BY-SA 4.0: our re-encoded copy is shared under the same license, credited to Manoj
        Karingamadathil.
      </p>
    </section>
  );
}
