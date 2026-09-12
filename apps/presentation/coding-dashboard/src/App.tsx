import { useState } from "react";

type TabId = "current" | "detail" | "overall";

const tabs: Array<{ id: TabId; label: string; description: string }> = [
  {
    id: "current",
    label: "当前任务",
    description: "关注正在执行的 Agent、任务状态、验证结果和是否需要人工干预。",
  },
  {
    id: "detail",
    label: "任务详情",
    description: "查看单个任务的执行历史、Evidence、Token、Cache、重试和评价。",
  },
  {
    id: "overall",
    label: "整体任务",
    description: "查看完整任务拆分、依赖关系、执行者与项目整体进度。",
  },
];

export function App() {
  const [activeTab, setActiveTab] = useState<TabId>("current");
  const active = tabs.find((tab) => tab.id === activeTab) ?? tabs[0];

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">LoopX · AI-Coding Platform</p>
          <h1>AI-Coding Dashboard</h1>
          <p className="subtitle">Coding Projection 尚未接入；当前页面用于固定产品信息架构与独立运行边界。</p>
        </div>
        <div className="status" aria-label="platform status">
          <span className="status-dot" />
          Platform bootstrap
        </div>
      </header>

      <nav className="tabs" aria-label="AI-Coding Dashboard tabs">
        {tabs.map((tab) => (
          <button
            className={tab.id === activeTab ? "tab active" : "tab"}
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            type="button"
          >
            {tab.label}
          </button>
        ))}
      </nav>

      <section className="panel">
        <div className="panel-heading">
          <div>
            <p className="section-kicker">Phase 0</p>
            <h2>{active.label}</h2>
          </div>
          <span className="badge">Projection pending</span>
        </div>
        <p className="panel-description">{active.description}</p>

        <div className="placeholder-grid">
          <article className="placeholder-card">
            <span>Control Plane</span>
            <strong>LoopX</strong>
            <small>Goal / Todo / Gate / Evidence / Quota</small>
          </article>
          <article className="placeholder-card">
            <span>Primary Agent</span>
            <strong>Codex</strong>
            <small>Interaction / Planning / Review</small>
          </article>
          <article className="placeholder-card">
            <span>Workers</span>
            <strong>Kiro · Qwen · Claude</strong>
            <small>统一 Agent Run Contract</small>
          </article>
        </div>
      </section>
    </main>
  );
}
