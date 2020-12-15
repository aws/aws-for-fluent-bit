  219  git remote -v
  220  git status
  221  git remote add upstream https://github.com/grafana/loki.git
  222  git remote -v
  223  git status
  224  git fetch upstream
  225  git fetch --tags upstream
  226  git status
  227  git merge upstream/v1.6.1
  228  git merge v1.6.1
  229  ls
  230  git chekout master
  231  git checkout main
  232  git checkout master
  233  git merge upstream/623858df0df92e7b704c1f734e7b781983a41551
  234  git fetch
  235  git rebase --onto $(git rev-list -n1 v1.6.1)
  236  git status
  237  git rebase --onto $(git rev-list -n1 v1.6.1)
  238  git status
  239  git rebase --continue
  240  git status
  241  git pull
