# Ms Beau Ave — Omnichannel Skincare Commerce & Operations Platform

- **[`Spec.md`](Spec.md)** — the full platform specification (single source of truth).
- **[`docs/`](docs/)** — the demo as a **static one-page app** (no server needed),
  ready for GitHub Pages and Vercel:
  - **GitHub Pages**: Settings → Pages → *Deploy from a branch* → `main` + `/docs`
    → live at `https://msbeauicafe.github.io/Ms-Beau-Ave/`
  - **Vercel**: import this repo at [vercel.com/new](https://vercel.com/new) —
    `vercel.json` already points the deployment at `docs/`, no settings needed
- **[`demo/`](demo/)** — the same demo as a runnable, zero-dependency **local server**
  (in-memory store, no database):

  ```bash
  node demo/server.js
  # Back office:  http://localhost:4200/
  # Landing page: http://localhost:4200/landing.html
  ```

  See [`demo/README.md`](demo/README.md) for a 5-minute guided demo script mapped
  to the spec's acceptance criteria.
