<template>
  <section class="about-page">
    <header class="hero">
      <h1>关于作者</h1>
      <p>个人简历可视化展示（来自 resume.tex）。</p>
    </header>

    <article class="card profile-card">
      <h2>基本信息</h2>
      <div class="profile-grid">
        <div><span class="label">姓名</span><span>***</span></div>
        <div><span class="label">年龄</span><span>24岁</span></div>
        <div><span class="label">现居</span><span>杭州</span></div>
        <div><span class="label">常住</span><span>武汉</span></div>
        <div><span class="label">意向地</span><span>全国</span></div>
        <div><span class="label">邮箱</span><span>mtk20170119@gmail.com</span></div>
      </div>
    </article>

    <article class="card">
      <h2>教育背景</h2>
      <ul class="list">
        <li>
          *** - 计算机科学与技术学院，人工智能（研究生，3.69）
          <span class="date">2023.09 - 2026.05</span>
        </li>
        <li>
          *** - 计算机与人工智能学院，软件工程（本科，3.34）
          <span class="date">2019.09 - 2023.06</span>
        </li>
      </ul>
    </article>

    <article class="card">
      <h2>专业技能</h2>
      <ul class="list">
        <li>语言与系统：C/C++、Python、Linux、MySQL、Redis、SQLite</li>
        <li>网络与并发：TCP/IP、HTTP、epoll + 线程池 Reactor</li>
        <li>视觉与深度学习：机器视觉、视觉SLAM、ORB-SLAM</li>
        <li>数据处理：OCR、数据清洗、LLM RAG</li>
        <li>工程工具：Git、HTML/CSS/JS/Vue、Cursor/Copilot</li>
      </ul>
    </article>

    <article class="card">
      <h2>项目经历</h2>
      <h3>日语智能学习平台（NihonGo Assistant）</h3>
      <p class="links">
        在线地址：
        <a href="https://nihongolab.win/" target="_blank" rel="noreferrer">https://nihongolab.win/</a>
      </p>
      <p class="links">
        讲解视频：
        <a href="https://youtu.be/VVPeLtSSiaA?si=qEzvsFGzyr8kNLDQ" target="_blank" rel="noreferrer">YouTube</a>
      </p>
      <ul class="list">
        <li>独立完成需求、UI、数据库关系、前后端设计与开发、测试与上线</li>
        <li>设计单词/语法/课文/复习/测试/检索模块与动态复习策略</li>
        <li>实现 YOLO + OCR + 解析入库 + 语法标注 + TTS 自动化链路</li>
        <li>在 Google Cloud 部署可访问版本并持续迭代</li>
      </ul>
    </article>

    <article class="card">
      <h2>研究经历</h2>
      <p>
        论文：Semantic-Aware Dynamic Keypoint Filtering and Enhanced Descriptor（排名1/2，期刊审稿中）
      </p>
      <ul class="list">
        <li>聚焦视觉里程计前端的特征点提取与描述模块</li>
        <li>在 ORB-SLAM3 中完成特征与描述模块替换</li>
        <li>支持 TorchScript/ONNX 导出与 C++ 推理集成</li>
      </ul>
    </article>

    <article class="card">
      <h2>证书与其他</h2>
      <ul class="list">
        <li>软考中级：软件设计师</li>
        <li>英语：CET-6</li>
        <li>日语：JLPT N3（87）</li>
        <li>竞赛：2023 全国研究生数学建模国三（1/2）</li>
      </ul>
    </article>

    <article class="card">
      <h2>自我评价</h2>
      <ul class="list">
        <li>具备英文论文阅读、调研和长文本学习能力</li>
        <li>持续学习日语与英语，计划冲刺 JLPT N2 / TOEIC / IELTS</li>
        <li>目标方向：Linux/C/C++ 软件开发与工业软件开发</li>
      </ul>
    </article>
  </section>
</template>

<style scoped>
.about-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.hero {
  background: linear-gradient(135deg, #e0f2fe, #eef2ff 55%, #fef9c3);
  border: 1px solid #cbd5e1;
  border-radius: 16px;
  padding: 22px;
}

.hero h1 {
  margin: 0;
  color: #0f172a;
}

.hero p {
  margin: 6px 0 0;
  color: #334155;
}

.card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 18px;
}

.card h2 {
  margin: 0 0 8px;
  color: #0f172a;
}

.card h3 {
  margin: 6px 0;
  color: #1f2937;
}

.card p {
  margin: 0;
  color: #334155;
  line-height: 1.7;
}

.profile-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 10px;
}

.profile-grid div {
  display: flex;
  justify-content: space-between;
  gap: 8px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 8px 10px;
}

.label {
  color: #64748b;
}

.list {
  margin: 0;
  padding-left: 18px;
  color: #334155;
  line-height: 1.8;
}

.date {
  color: #64748b;
  margin-left: 6px;
}

.links {
  margin-bottom: 6px;
}

.links a {
  color: #2563eb;
  text-decoration: none;
}

.links a:hover {
  text-decoration: underline;
}
</style>
