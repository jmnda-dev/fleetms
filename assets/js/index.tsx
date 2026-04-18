import React, { useEffect } from "react";
import { createRoot } from "react-dom/client";
import { initLandingPage } from "./animation";

function App() {
  useEffect(() => {
    const el = document.getElementById("animation-container");
    if (el) return initLandingPage(el);
  }, []);

  return (
    <div className="min-h-screen bg-base-100 text-base-content">
      <div className="max-w-5xl mx-auto px-6 py-12">
        <div className="flex items-center gap-5 mb-8">
          <img
            src="https://raw.githubusercontent.com/ash-project/ash_typescript/main/logos/ash-typescript.png"
            alt="AshTypescript"
            className="w-16 h-16"
          />
          <div>
            <h1 className="text-4xl font-bold">AshTypescript</h1>
            <p className="text-lg opacity-70">End-to-end type safety from Ash to TypeScript</p>
          </div>
        </div>

        <section className="mb-10">
          <div className="flex flex-wrap items-center gap-3 mb-5">
            <h2 className="text-2xl font-bold">Main Features</h2>
            <div className="flex-1"></div>
            <a href="https://hexdocs.pm/ash_typescript" target="_blank" rel="noopener noreferrer" className="btn btn-primary btn-sm">
              <svg xmlns="http://www.w3.org/2000/svg" className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
              Docs
            </a>
            <a href="https://github.com/ash-project/ash_typescript" target="_blank" rel="noopener noreferrer" className="btn btn-ghost btn-sm">
              <svg xmlns="http://www.w3.org/2000/svg" className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
              GitHub
            </a>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
                    <a href="https://hexdocs.pm/ash_typescript/first-rpc-action.html" target="_blank" rel="noopener noreferrer" className="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer">
              <div className="card-body">
                <h3 className="card-title text-base">Type-Safe RPC</h3>
                <p className="text-sm opacity-70">Auto-generated typed functions for every Ash action.</p>
                <div className="text-sm text-primary mt-1">View docs &rarr;</div>
              </div>
            </a>

                    <a href="https://hexdocs.pm/ash_typescript/typed-controllers.html" target="_blank" rel="noopener noreferrer" className="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer">
              <div className="card-body">
                <h3 className="card-title text-base">Typed Controllers</h3>
                <p className="text-sm opacity-70">Typed route helpers for Phoenix controllers.</p>
                <div className="text-sm text-primary mt-1">View docs &rarr;</div>
              </div>
            </a>

                    <a href="https://hexdocs.pm/ash_typescript/typed-channels.html" target="_blank" rel="noopener noreferrer" className="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer">
              <div className="card-body">
                <h3 className="card-title text-base">Typed Channels</h3>
                <p className="text-sm opacity-70">Typed event subscriptions for Phoenix channels.</p>
                <div className="text-sm text-primary mt-1">View docs &rarr;</div>
              </div>
            </a>

                    <a href="https://hexdocs.pm/ash_typescript/form-validation.html" target="_blank" rel="noopener noreferrer" className="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer">
              <div className="card-body">
                <h3 className="card-title text-base">Zod Validation</h3>
                <p className="text-sm opacity-70">Generated Zod schemas for form validation.</p>
                <div className="text-sm text-primary mt-1">View docs &rarr;</div>
              </div>
            </a>

          </div>
        </section>

        <div id="animation-container"></div>
      </div>
    </div>

  );
}

createRoot(document.getElementById("app")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
