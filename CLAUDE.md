# 划船机 App — 开发流程(每个 session 必读必守)

为停服的小莫/Anytum 划船机自建的 Flutter 桌面 App。
仓库:`xfang9528-glitch/-rower-app`(**个人仓**,默认分支 `main`)。

本仓**没有** PetWebOrg 那套 GitHub Actions 钩子 / 飞书通知 / 每日简报 / issue-patrol —— 全砍。
状态流转、送审、上线**全部手动**按本文件执行。

---

## 黄金流程(一个新功能 / 一个修改的完整生命周期)

严格按序,**绝不跳步**:

1. **接单 #N** — `gh issue edit N --add-assignee @me`,标签 `status:todo → doing`
2. **开发** — 在 git worktree 里改(分支名 `claude/*` 或 `chore/*` 等)
3. **出 debug 版给房总实测** —— ⚠️ 不是先推 PR!改完先给可运行的 debug 产物 + 复现验证指引,停下等房总实测
4. **房总实测确认"没问题"** → 才 `git push` + `gh pr create`,PR body **必须**写 `Fixes #N`(光在标题写 `(#N)` 不会自动关闭 issue)
5. **review**
6. **合并到 main**(房总明确说合并才合;**不自合并**)
7. **release 打包** —— **只在最后,且房总明确说"打包 / 出包 / 发版"才做**

红线:没经房总实测不推 PR;没合并不打包;不自合并;`flutter test` + `flutter analyze` 没过不交付。

---

## 状态机(手动维护,四态互斥,先删旧再加新)

`REPO=xfang9528-glitch/-rower-app`

| 时机 | 命令 |
|---|---|
| 建 issue | 默认 `status:todo` |
| 接/开工 #N | `gh issue edit N --repo $REPO --add-assignee @me --remove-label status:todo --add-label status:doing` |
| 推 PR(房总实测过后) | `gh issue edit N --repo $REPO --remove-label status:doing --add-label status:review` |
| PR merge 后 | `gh issue edit N --repo $REPO --remove-label status:review --add-label status:shipped && gh issue close N --repo $REPO` |

停在 `todo`/`doing` = 看板显示没人做 / 没送审,所以每步都要 flip。

---

## 标签规范(建 issue 时自动推测,body 末尾追加 `🤖 CC 推测:P? / feat:? / 类型`,房总可纠正)

- **状态**(互斥):`status:todo` `status:doing` `status:review` `status:shipped`
- **优先级**(互斥,推不出 → `need-triage`):
  - `P0` 崩溃 / 核心不可用 / 数据错 ・ `P1` 次要功能 bug,尽快 ・ `P2` 一般需求,两周内 ・ `P3` 长尾 nice-to-have
- **功能域**:
  - `feat:ble` 连接 / 小莫 Anytum BLE 协议 / 心率
  - `feat:goal` 训练目标设置
  - `feat:dashboard` 训练仪表盘 / 实时指标
  - `feat:history` 训练记录 / 详情 / 分段 / 趋势
  - `feat:metrics` 指标引擎:功率 / 配速 / 卡路里 / 桨频换算
  - `feat:user` 多用户 / 档案 / 切换
  - `feat:infra` 构建 / CI / 打包 / 环境 / 工具
- **类型**:`bug` `enhancement` `question` `documentation`

---

## 构建(重要环境坑 —— 每次出包必看)

仓库路径 `E:\划船机` **含中文**。`flutter build windows` 时 MSVC/CMake 自定义构建步会把中文路径搞成乱码(`E:\锟斤拷锟斤拷锟斤拷\…`)→ 读不到 `app.dill` → 构建失败。**与代码无关,纯路径编码问题。**

解决:在 **ASCII 路径**的 git worktree 出包:

```bash
git worktree add --detach E:/rower_ascii_build <commit-or-branch>
cd E:/rower_ascii_build
flutter test && flutter analyze   # 必须先过
flutter build windows --debug     # 实测产物
# 或 flutter build windows --release  # 仅房总最后明示打包时
```

- debug 实测产物:`E:\rower_ascii_build\build\windows\x64\runner\Debug\rower_app.exe`
- release 产物:`…\runner\Release\rower_app.exe`
- 临时 worktree 用完 `git worktree remove`(或留着复用,别忘清理)

---

## 多窗口区分

多 worktree 并行时桌面窗口长一样分不清 → 用 `flutter-issue-tag-badge`:标题栏显示当前 worktree 对应的 `#N` 徽章。新 worktree 跑起来认徽章即知是哪个 issue。

---

## Session 启动

- 看分支名 / worktree 目录判断当前在哪个 `#N`,不确定再问房总。
- 不做 PetWebOrg 那套知识库同步 / 排期 / 简报(本仓无关)。
