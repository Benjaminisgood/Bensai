---
name: academic-beamer-slides
description: >
  A strict, engineering-style skill for writing academic Beamer slides
  (presentations & defenses) in LaTeX. Focuses on structure stability,
  cognitive load control, overlay discipline, figure-first slides,
  and compile-safe XeLaTeX workflows.
compiler: xelatex
---

# 学术 Beamer 幻灯片 LaTeX Skill（严谨版）

本 skill 用于**学术报告 / 组会 / 开题 / 答辩 / conference talk** 的
Beamer 幻灯片写作与修改，目标是：

> **稳定结构 + 低认知负担 + 不翻车编译 + 可重复复用**

这是一个**presentation engineering skill**，而不是文案生成规则。

---

## 0. 绝对原则（不可违反）

1. **一页 = 一个问题**
   - 每一页只回答一个明确问题
   - 如果一句话讲不清楚这一页在干嘛 → 结构错误

2. **视觉优先于文字**
   - 图 > 表 > 公式 > bullet
   - 能画图绝不堆字

3. **Beamer ≠ 论文**
   - 幻灯片不是线性阅读
   - 不允许“论文段落式文字”

4. **XeLaTeX 统一**
   - 字体、中文、emoji、符号全部统一在 XeLaTeX 体系

---

## 1. 工程结构（推荐且稳定）

```
slides/
├── main.tex              % 入口文件（结构 + 主题）
├── sections/
│   ├── intro.tex
│   ├── method.tex
│   ├── results.tex
│   ├── discussion.tex
│   └── conclusion.tex
├── figures/
│   └── *.pdf / *.png
└── refs.bib              % 可选
```

**规则：**
- `main.tex` 不写学术内容
- 每一部分内容写在 `sections/*.tex`
- 一个 section ≈ 3–8 页 slide

---

## 2. 编译规则

- **引擎**：XeLaTeX
- **最小命令**：
  ```
  xelatex main.tex
  ```
- 若含参考文献：`xelatex → biber → xelatex ×2`

---

## 3. 页面节奏设计（非常关键）

### 3.1 标准学术节奏（推荐）

| 模块 | 页数 |
|----|----|
| Motivation / Background | 2–3 |
| Problem Statement | 1 |
| Method | 3–5 |
| Results | 3–6 |
| Interpretation | 2–3 |
| Conclusion / Outlook | 1–2 |

---

## 4. Frame 设计硬规则

### 4.1 标题规则
```tex
\begin{frame}{What is the bottleneck in XXX?}
```

- 标题必须是 **问题句 / 判断句**
- 禁止：`Introduction`, `Results`, `Experiment`

### 4.2 内容密度规则
- Bullet ≤ 5 条
- 每条 ≤ 1 行
- 超过 → 拆页

---

## 5. Overlay（<1->）使用纪律

Overlay 是 **认知工具，不是动画玩具**。

### 允许：
```tex
\item<1-> Step 1
\item<2-> Step 2
```

### 禁止：
- 超过 5 个 overlay 层
- 同一页图文同时 overlay
- 随机 `<+->` 无逻辑使用

---

## 6. 图像优先模式（强烈推荐）

### 6.1 图占主导的 frame

```tex
\begin{frame}{Key result: adsorption is entropic}
  \centering
  \includegraphics[width=0.8\linewidth]{figures/result1.pdf}
  \\
  \small Entropy dominates binding free energy.
\end{frame}
```

### 6.2 图注规则
- 图下只写 **结论**
- 不写“图中显示……”

---

## 7. 公式页设计

### 7.1 公式出现的前提
- 公式必须被**口头讲解**
- 公式必须在后续被**使用或引用**

### 7.2 推荐写法
```tex
\begin{frame}{Free energy decomposition}
\[
\Delta G = \Delta H - T\Delta S
\]
\begin{itemize}
  \item Enthalpy: surface interactions
  \item Entropy: water release
\end{itemize}
\end{frame}
```

---

## 8. 中文 / 英文混排规则

- 中文报告：标题可中英，正文中文
- 英文报告：**全英文**（不要夹中文）
- 中英混排时：
  - 不在同一句混用
  - 不在同一个 bullet 混用

---

## 9. 字体与主题（稳妥方案）

### 推荐字体
```tex
\usepackage{fontspec}
\setmainfont{Times New Roman}
\setsansfont{Arial}
```

### 主题原则
- 白底 + 深色字
- 高对比
- 禁止渐变、花色背景

---

## 10. 结论页（必备）

结论页必须回答：

1. 我解决了什么问题？
2. 核心 insight 是什么？
3. 下一步是什么？

推荐结构：
```tex
\begin{frame}{Take-home messages}
\begin{itemize}
  \item Insight 1
  \item Insight 2
  \item Outlook
\end{itemize}
\end{frame}
```

---

## 11. 常见错误（明确禁止）

- ❌ 把论文段落直接贴进 slide
- ❌ 一页 2 张不相关图
- ❌ 标题和内容无因果关系
- ❌ 用动画掩盖结构问题
- ❌ 结论页写成“Thank you”

---

## 12. Skill 行为约束（给模型看的）

当此 skill 激活时，模型必须：

- 先判断 **这一页回答什么问题**
- 优先拆页，而不是压缩文字
- 主动建议“这一页应该是一张图”
- 警告：信息密度过高的 frame
- 保持 XeLaTeX / Beamer 兼容
- 永远不生成“论文式段落 slide”

---

## 快速指令示例（你可以直接对我说）

- “给我设计一套 **20 分钟 conference talk 的 Beamer 结构**”
- “把这一页 Results 拆成 3 页，每页一个结论”
- “这一页应该改成图页还是公式页？”
- “帮我把答辩 slide 的逻辑顺一遍，只动结构不改结论”

这是一个 **为科研报告服务的 Beamer skill**，而不是做 PPT 的。