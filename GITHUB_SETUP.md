# 在 GitHub 创建并发布仓库

目标仓库：`https://github.com/<你的账号>/low-latency-vision-fpga-v2`

本机没有 `git` / `gh` 也可以发布。三种方式按手头条件选一种即可。

---

## 方式 A：网页创建 + 上传 zip（最省事）

1. 登录 GitHub，右上角 **+ → New repository**；
2. **Repository name** 填 `low-latency-vision-fpga-v2`；
3. **Description** 建议填：
   `低延时实时视觉处理：安路 HX1P35A + SC500CS + HDMI，边缘/二值化/色彩分块/油画/帧差运动`；
4. 可见性选 **Public**，**不要**勾选 “Add a README file”（避免与本地 README 冲突）；
5. 创建后进入仓库，点 **Add file → Upload files**；
6. 把 `low-latency-vision-fpga-v2.zip` 解压到一个空目录，选中解压后的**内容**（不是外层文件夹）拖进上传区；
7. 提交信息填 `init: low-latency vision v2 on Anlogic PH1P35`，点 **Commit changes**。

> GitHub 网页一次最多上传 100 个文件；本仓库约 75 个文件，可以一次完成。
> 如果浏览器把 `rtl/`、`docs/` 等目录拆开，先上传根目录文件，再按目录分批上传。

---

## 方式 B：安装 Git 后命令行推送

安装 [Git for Windows](https://git-scm.com/download/win)，然后在仓库目录执行：

```powershell
cd low-latency-vision-fpga-v2
git init -b main
git add .
git commit -m "init: low-latency vision v2 on Anlogic PH1P35"
git remote add origin https://github.com/<你的账号>/low-latency-vision-fpga-v2.git
git push -u origin main
```

首次推送会要求输入 GitHub 用户名与 **Personal Access Token**（GitHub 已不接受账户密码）。
token 的权限见方式 C。

如果远端仓库是空的，GitHub 会在推送后把 `main` 设为默认分支；若不是，到
**Settings → Branches → Default branch** 改成 `main`。

---

## 方式 C：私人令牌 + API 脚本（全自动，无需 Git）

### 1. 生成 token

**Classic token：**

1. GitHub 右上角头像 → **Settings** → 左侧 **Developer settings** → **Personal access tokens → Tokens (classic)**；
2. **Generate new token (classic)**；
3. 勾选 `repo`（仓库读写）即可；有效期按需；
4. 复制 token（只显示一次）。

**Fine-grained token（更小权限）：**

1. **Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**；
2. **Repository access** 选 `All repositories`（因为要创建新仓库）；
3. **Permissions** 至少给：
   - `Administration: Read and write`（创建仓库、设置默认分支）；
   - `Contents: Read and write`（提交文件）；
4. 生成并复制。

### 2. 运行脚本

在仓库根目录：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\push_to_github.ps1 -Token "github_pat_xxx"
```

可选参数：

```powershell
-Token "xxx" -Repo "low-latency-vision-fpga-v2" -Branch "main" -Description "低延时实时视觉处理：安路 HX1P35A + SC500CS + HDMI" -Private
```

脚本会：

- `GET /user` 验证 token 并取账号；
- 用 `POST /user/repos` 创建公开仓库（已存在则复用）；
- 把每个文件做成 Git blob，构建一棵 tree、一个 commit；
- 空仓库用 `POST /git/refs` 创建 `refs/heads/main`，已有仓库用 `PATCH` 快进；
- 输出 `https://github.com/<账号>/low-latency-vision-fpga-v2`。

### 3. 安全提醒

- token 只放在命令行参数里，**不要**写进任何文件、README、脚本默认值或提交历史；
- 推送完成后到 **Settings → Developer settings** 删除该 token；
- 脚本不会上传 `.git/`、`__pycache__/`、`td_project/`、`vendor_ip/`、`.zip`、`.bit`、`.db` 等构建产物。

---

## 推送后检查

1. 仓库首页 README 正常渲染，`docs/images/system_arch.svg` 能显示；
2. `docs/`、`rtl/`、`tests/` 的中文文件名显示正常；
3. `LICENSE` 被识别为 **MIT**；
4. 文件树与本地一致（约 75 个文件，不含加密 IP 与比特流）；
5. 默认分支是 `main`；
6. 在 **About** 里补一句简介，建议加 topics：
   `fpga`、`anlogic`、`ph1p35`、`mipi`、`image-processing`、`computer-vision`、`verilog`。

---

## 常见问题

**Q：API 返回 401 `Bad credentials`？**
token 复制不完整、已过期，或用了账户密码。重新生成 token。

**Q：API 返回 403 `Resource not accessible by personal access token`？**
fine-grained token 缺 `Contents: Read and write` 或 `Administration: Read and write`；补齐权限后重试。

**Q：API 返回 422 `Repository creation failed`？**
同名仓库已存在，或账号没有创建仓库权限；脚本会复用已存在的仓库，也可以先手动删掉旧仓库。

**Q：上传中文文件名失败？**
脚本把路径放在 UTF-8 JSON 里，GitHub 支持中文路径；如果仍失败，改用方式 A 的网页上传。

**Q：仓库里出现了 `td_project/` 或 `vendor_ip/`？**
说明本地运行过 TD 或放了 IP。它们已在 `.gitignore` 中；如果已经提交，先 `git rm -r --cached` 再提交。

**Q：Gitee 旧仓库怎么办？**
本仓库是 v2（improve8），与 Gitee 上的 v1 并存。可以在 Gitee 仓库 README 里加一行指向 GitHub v2，
或在 Gitee 设置里绑定 GitHub 镜像。

