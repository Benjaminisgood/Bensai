---
name: shtuthesis-academic-thesis
description: >
  A comprehensive, reference-accurate skill for writing academic theses/papers
  using the user's shtuthesis-based LaTeX project structure (Thesis.tex + Tex/*),
  including frontmatter/mainmatter/appendix/backmatter workflow, XeLaTeX build
  rules, bibliography, nomenclature/symbol list, and chapter modularization.
compiler: xelatex
project_layout: Thesis.tex + Style/ + Tex/ + Biblio/
---

# 学术论文 / 学位论文 LaTeX Skill（严格匹配你的项目结构）

本 skill **严格按你当前工程的真实文件组织与入口文件**来约束写作与改动方式：
- 主入口：`Thesis.tex`
- 文档类：`Style/shtuthesis`
- 文档设置：`Style/artratex`（你启用了 `authoryear,list` 选项）
- 自定义命令：`Style/artracom`
- 内容拆分：`Tex/Frontinfo.tex`、`Tex/Frontmatter.tex`、`Tex/Mainmatter.tex`、`Tex/Appendix.tex`、`Tex/Backmatter.tex`，以及章节文件如 `Tex/Chap_Intro.tex`、`Tex/Chap_Guide.tex`

**目标：**
1) 任何新增内容都不破坏版式与学校模板要求  
2) 任何编辑都遵循“入口文件只负责结构，章节文件只负责内容”  
3) 永远保持可编译（XeLaTeX）+ 参考文献可生成 + 目录/书签正常

---

## 0. 绝对规则（不讨论）

1. **只用 XeLaTeX 编译**  
   - 你的工程依赖模板封装与字体/中文体系（并且说明文档也明确支持 XeLaTeX 流程）。
2. **不改 `Style/` 下的类文件与模板包**  
   - 除非你明确要“改学校规范/版式”——否则一律当作只读依赖。
3. **所有学术内容写在 `Tex/` 下的分文件里**  
   - `Thesis.tex` 只做“加载、顺序、切换 front/main/appendix/back”。
4. **每次改动必须保证：能从干净环境一键编译通过**  
   - 不能靠“我本地缓存文件”才能编译。

---

## 1. 工程入口与内容流（必须保持一致）

### 1.1 入口文件：`Thesis.tex`
你当前 `Thesis.tex` 的角色是“总控”：
- 声明文档类：`\documentclass[twoside]{Style/shtuthesis}`
- 加载设置：`\usepackage[authoryear,list]{Style/artratex}`
- 加载自定义命令：`\usepackage{Style/artracom}`
- 先 `\input{Tex/Frontinfo}` 写封面信息
- `\begin{document}` 后按顺序切换：
  - `\frontmatter`（前置部分）
  - `\mainmatter`（正文部分）
  - `\appendix`（附录部分）
  - `\backmatter`（文后部分）
- 参考文献使用：`\bibliography{Biblio/ref}`

**编辑准则：**
- 允许改：章节 include 的顺序、是否 `\includeonly` 做局部编译、是否插入新章节文件
- 不允许改：`\documentclass` 与 `Style/*` 加载逻辑（除非你明确要改模板）

---

## 2. 你当前每个 Tex 分文件的“职责说明”（写作时按职责放内容）

### 2.1 `Tex/Frontinfo.tex`（封面与元信息：中英文）
只放元信息宏，例如：
- 中文：题目、作者、导师、学位、学院、日期、校徽等
- 英文：TITLE/AUTHOR/ADVISOR/DEGREE/MAJOR/DATE 等

**规则：**
- 不写任何正文段落
- 不写引用、公式、图表
- 只改字段值，不改字段接口名（宏名）

### 2.2 `Tex/Frontmatter.tex`（前置：封面/声明/摘要等）
你当前文件已包含以下逻辑入口：
- 中文封面：`\maketitle`
- 英文封面：`\MAKETITLE`
- 声明页：`\makedeclaration`
- 摘要：中文 `摘 要` + 英文 `Abstract`
- 关键词：中文 `\keywords{...}` 与英文 `\KEYWORDS{...}`
- 页码切换：`\pagenumbering{Roman}` 等

**规则：**
- 摘要写“问题-方法-结果-意义”四段式，避免过长
- 关键词建议 3–6 个，使用领域规范名词
- 前置部分尽量不出现太多公式/图（除非学校要求）

### 2.3 `Tex/Mainmatter.tex`（正文总索引）
你的 Mainmatter 目前是“章节 include 列表”，例如：
- `\input{Tex/Chap_Intro}`
- `\input{Tex/Chap_Guide}`

**规则：**
- 这里只写 `\input{...}` 列表，不写正文内容
- 新增章节：新增 `Tex/Chap_XXX.tex`，然后在这里按顺序 `\input`

### 2.4 `Tex/Chap_*.tex`（章节正文：唯一允许大量写内容的地方）
例如 `Tex/Chap_Intro.tex`、`Tex/Chap_Guide.tex`。

**规则：**
- 每个章节文件以 `\chapter{...}\label{chap:...}` 开始
- 章节内用 `\section`/`\subsection` 分层
- 图表与公式都放在章节文件中（或章节自己的子文件夹，见“图表规范”）

### 2.5 `Tex/Appendix.tex`（附录）
你当前附录已经示例了：
- `\chapter{...}`
- 数学公式编号与复杂符号书签处理（例如 `\texorpdfstring{...}{...}`）
- 特定宏例如 `\adddotsbeforeeqnnum` 的用法

**规则：**
- 附录只放“正文太打断叙事但又必须给”的材料：推导细节、额外实验、额外图、规范原文等
- 附录也必须可引用：`\label` + 正文 `\ref`

### 2.6 `Tex/Backmatter.tex`（文后：简历/成果/致谢等）
你当前 Backmatter 已包含：
- 作者简历与成果章节
- 致谢（带 `\chapter[目录]{标题}\chaptermark{页眉}` 的写法）
- 针对页眉的 `\thispagestyle{noheaderstyle}` 示例

**规则：**
- 成果列表：按“论文/专利/项目/获奖”分组，条目化
- 致谢：不写技术细节，写人、资源、平台支持即可

---

## 3. 编译与调试规则（按你的工程习惯写成“可执行”流程）

### 3.1 推荐编译方式
- 直接对 `Thesis.tex` 选择 XeLaTeX 编译
- 或使用你工程附带脚本（如项目说明里常见的 `artratex` 脚本）

### 3.2 常见编译失败的定位顺序
1. **先看第一个 error**（不是最后一个）
2. 检查是否：
   - `\input{Tex/...}` 路径拼写错
   - 图片文件不存在 / 扩展名不对
   - 引用的 `\label` 没写或重名
   - 参考文献条目键不存在（cite key 写错）
3. 如果是目录/引用更新问题：再编译一次（LaTeX 常见特性）

---

## 4. 引用与参考文献（严格对齐你的配置：authoryear）

你在 `Style/artratex` 里启用了 `authoryear`（作者-年份）风格，并且通过：
```tex
\bibliography{Biblio/ref}
```
加载 `Biblio/ref.bib`。

### 4.1 写作规则
- 章节内引用使用模板支持的引用命令（通常是 `\citep`/`\citet` 风格）
- 同一句话里多个引用：合并写在同一个 cite 命令里，减少噪音
- 每段落尽量只放最关键的 1–3 个引用

### 4.2 Bib 条目规则
- 每篇文章至少保证：author/title/journal/year
- DOI/URL 可选，但建议加上便于追溯

---

## 5. 图、表、公式规范（保证“学位论文级别”的可读性）

### 5.1 图片组织（建议）
- 所有图片放在统一目录（例如 `Figures/` 或 `Tex/Figures/`），并在章节中引用
- 文件名统一：`fig_intro_overview.png` 这种可读命名

### 5.2 图注写法（硬规则）
图注回答三件事：
1) 这是什么图（对象/条件）  
2) 主要观察到什么（趋势/差异）  
3) 结论是什么（与假设或结论的关系）

### 5.3 公式写法
- 每个可引用的重要公式都要 `\label{eq:...}`
- 不要在公式里堆 3 行以上的复杂表达；复杂推导放附录
- 单位和符号统一（见下一节：符号表）

---

## 6. 符号表 / 缩写表（严格按你已有用法扩展）

你工程里 `Prematter.tex` 已示范了符号表条目形式（`\nomenclatureitem` 等接口）以及按“字符/算子/缩写”分组的写法。

### 6.1 增补规则
- 新引入的核心符号必须进入符号表（尤其是跨章节出现的）
- 对同名符号但不同含义必须区分（加上下标或改符号）

### 6.2 单位写法
- 单位写在符号表里，正文尽量保持一致格式
- 如果正文中出现单位，使用模板/宏体系保持统一（不要混用手写格式）

---

## 7. 章节写作框架（论文内容层面的“可落地模板”）

每个技术章节建议使用以下固定骨架（让论文更像论文）：

1) **Problem / Motivation**：这一章解决什么问题，为什么值得  
2) **Method / Setup**：怎么做的（实验/计算/理论）  
3) **Results**：主要发现  
4) **Discussion**：解释机制、对比文献、局限性  
5) **Mini-summary**：本章小结（为下一章铺垫）

---

## 8. 编辑策略（让 AI 参与写作时不破坏工程）

当你让模型改论文时，必须遵循：

1. **先问清楚“改结构还是改内容”**
   - 改结构：只改 `Thesis.tex` / `Mainmatter.tex` / include 顺序
   - 改内容：只改 `Tex/Chap_*.tex` 或 `Frontmatter/Backmatter/Appendix`
2. **任何宏/环境不确定时：先在 `Chap_Guide.tex` 查已有示例再写**
3. **新增功能优先写成“局部可删的块”**
   - 例如新增一个 block/环境先放在某个章节尾部，确认编译再扩散

---

## 9. Skill 的“输出标准”（你每次要我生成/改 LaTeX 时，我应当交付什么）

- ✅ 交付：可直接粘贴进现有工程的 `Tex/*.tex` 内容
- ✅ 交付：新增章节时同时给出 `Mainmatter.tex` 的 `\input` 修改片段
- ✅ 交付：涉及引用时，给出 `\cite...` 与需要的 `.bib` 条目键名（不凭空造 DOI）
- ✅ 交付：任何可能溢出/版式风险点的提醒（例如过长标题、过宽公式、超大图）

---

## 10. 你这个工程的“最小改动原则”（保命）

- 不改 `Style/`（除非你明确说“我要改学校版式”）
- 不把正文写进 `Thesis.tex`
- 不把章节写进 `Frontinfo.tex`
- 不在 `Mainmatter.tex` 写任何段落
- 保持 `frontmatter/mainmatter/appendix/backmatter` 的顺序不乱

---

## 快速指令（你可以直接对我说）

- “新增一章 **方法**，文件名 `Tex/Chap_Method.tex`，并接在引言后面”
- “把第 2 章写成论文风格：背景-方法-结果-讨论-小结（保留现有 label）”
- “给我把符号表补全：把本章出现的符号都加进去（不要改接口）”
- “把参考文献从少到多补齐：每段最多 2 个 cite（authoryear）”