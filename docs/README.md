# 小莫划船机 App · 设计与产品文档

为停服的「小莫 / Anytum」划船机自建的替代 App。本目录是高保真原型定稿(v0.3)的完整交付。

## 文档索引

| 文件 | 内容 |
|---|---|
| [`../prototype/index.html`](../prototype/index.html) | **可点击高保真原型**(单文件,17 屏,真实交互、数据自洽)。本地预览见下。 |
| [`PRD.md`](PRD.md) | 产品需求文档:背景、范围、功能需求、验收标准 |
| [`design-spec.md`](design-spec.md) | 设计规范:画布、颜色/字体/间距 token、组件、动效、布局约束(Flutter 还原依据) |
| [`flow.md`](flow.md) | 流程图:总导航主流程、连接状态机、训练数据流(Mermaid) |

## 本地预览原型

零依赖静态服务(Node):配置在 [`../.claude/launch.json`](../.claude/launch.json),启动后访问 `http://localhost:4173`。
或直接用浏览器打开 `prototype/index.html`。

> 评审注意:原型按手机视口(逻辑宽 412,Xiaomi 17 Pro)全屏呈现,**全局无 transform 缩放**——务必用手机尺寸视口查看,点击与显示 1:1 对齐。

## 状态

- ✅ 冒烟版:协议打通 + 物理引擎 + 仪表盘 + 稳定连接
- ✅ 高保真原型定稿:本目录
- ⏭ Flutter 实现:按 PRD/设计规范/流程图落地
