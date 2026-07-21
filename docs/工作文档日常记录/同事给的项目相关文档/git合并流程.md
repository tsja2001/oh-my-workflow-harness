  cd /home/t/projects/work-wsl/01zhaocai-end/scm-source-all

  git switch feature/taizhang-yang
  git status --short
  git fetch origin
  git log --oneline origin/feature/taizhang-yang..HEAD
  git push origin feature/taizhang-yang

  git log 应该只显示：

  567fab397 fix: 修复导出时间

  然后合并到 test：

  git switch test
  git pull --ff-only origin test
  git merge --no-ff feature/taizhang-yang -m "fix: 合入导出时间"

  git status --short
  git diff --stat origin/test..test
  git log -3 --oneline

  git push origin test

  最后确认：

  git fetch origin
  git status --short --branch
  git log -1 --oneline origin/test
