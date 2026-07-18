# 分支开发、PR 审核与 main 分支保护规范

## 强制规则

- 所有日常代码开发必须在 `dev` 分支或从 `dev` 派生的功能分支进行。
- `dev` 分支必须通过 Pull Request 提交，且必须经过仓库作者本人审核后才能合并。
- `main` 分支只用于稳定版本、发布准备和作者本人确认发布的代码。
- 除仓库作者本人外，任何人不得直接向 `main` 分支提交、推送或合并代码。
- 仓库作者本人有权在代码验证通过后，手动将 `dev` 或发布分支中的代码合并到 `main`。
- 如果非授权人员尝试向 `main` 分支提交、推送或合并代码，必须自动拒绝。

## 开发流程

1. 开始开发前切换到 `dev`：

   ```bash
   git switch dev
   ```

2. 从 `dev` 创建功能分支，或在作者允许时直接基于 `dev` 准备变更：

   ```bash
   git switch -c feature/<name>
   ```

3. 完成开发、测试和提交：

   ```bash
   git status --short --branch
   swift test
   git add <files>
   git commit -m "<message>"
   git push
   ```

4. 创建 Pull Request，目标分支必须是 `dev`。

5. PR 必须通过 CI，并由仓库作者本人审核通过后才能合并到 `dev`。

6. 需要进入 `main` 的代码，只能由仓库作者本人在验证通过后手动合并。

## 提交规则

### 面向 dev 的规则

- 默认开发入口是 `dev`。
- 协作者不得直接推送到 `dev`。
- 所有进入 `dev` 的变更必须通过 Pull Request。
- PR 必须由仓库作者本人审核通过。
- PR 必须通过 CI 验证。

### 面向 main 的规则

- `main` 不接受普通开发提交。
- 非作者不得直接 push 到 `main`。
- 非作者不得将 PR 合并到 `main`。
- `main` 只允许仓库作者本人在验证通过后手动合并。
- `main` 必须保留为可发布、可回滚、可追踪的稳定分支。

### 作者权限

仓库作者本人保留以下权限：

- 审核并合并目标为 `dev` 的 PR。
- 在验证通过后，将 `dev` 或发布分支合并到 `main`。
- 发布版本、打标签、触发 Release workflow。
- 在紧急修复场景下直接维护 `main`，但仍应补充说明和验证记录。

## 本地提交拦截

仓库提供了本地 Git hook 模板，可在本机拒绝直接提交到 `main` 和 `dev`。

安装方式：

```bash
mkdir -p .git/hooks
cp scripts/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

安装后，如果当前分支是 `main` 或 `dev`，`git commit` 会被拒绝，并提示从 `dev` 创建功能分支。

作者本人如遇发布维护、紧急修复等需要直接维护受保护分支的场景，可显式设置绕过变量：

```bash
CVSTICKY_ALLOW_PROTECTED_BRANCH_COMMIT=1 git commit -m "<message>"
```

该绕过方式只应由作者本人使用，并应在提交说明或开发日志中补充原因和验证结果。

## GitHub 远程强制规则

本地 hook 只能保护当前开发者机器，不能替代 GitHub 远程保护。要实现“提交到 `main` 自动拒绝”和“`dev` 必须经过作者 PR”，必须在 GitHub 仓库中启用 Branch Protection 或 Rulesets。

### main 分支规则

- 保护分支：`main`
- 禁止直接 push 到 `main`
- 只允许仓库作者本人绕过限制
- 要求通过 Pull Request 合并
- 要求 CI 状态检查通过后才能合并
- 可选：要求线性历史、禁止强制推送、禁止删除分支

建议规则：

```text
Branch name pattern: main
Restrict updates: enabled
Allowed actors: repository owner only
Require a pull request before merging: enabled
Require review from Code Owners: enabled
Require status checks to pass: enabled
Block force pushes: enabled
Block deletions: enabled
```

### dev 分支规则

- 保护分支：`dev`
- 禁止直接 push 到 `dev`
- 要求所有变更通过 Pull Request
- 要求仓库作者本人审核通过
- 要求 CI 状态检查通过后才能合并
- 禁止强制推送和删除分支

建议规则：

```text
Branch name pattern: dev
Restrict updates: enabled
Require a pull request before merging: enabled
Require review from Code Owners: enabled
Require status checks to pass: enabled
Block force pushes: enabled
Block deletions: enabled
```

## 仓库内辅助文件

- `.github/CODEOWNERS`：将仓库作者设置为默认代码所有者，用于要求作者审核。
- `.github/pull_request_template.md`：要求提交者确认目标分支、验证结果和 main 分支限制。
- `scripts/hooks/pre-commit`：本地拒绝在 `main` 和 `dev` 分支直接提交。

GitHub Rulesets / Branch Protection 是最终强制入口；仓库文档、CODEOWNERS、PR 模板和本地 hook 负责让所有开发者在提交前看到并遵守同一套规则。
