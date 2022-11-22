# Cherry-pick a PR
## Install Github CLI
```
type -p curl >/dev/null || sudo apt install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
&& sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y
```

## Fetch remote
```
vim .git/config
```
add below line under [remote "remote_name"]
```
fetch = +refs/pull/*/head:refs/remotes/remote_name/pr/*
```

```
git fetch --all
```

## Cherry-picking all the commits from a pull request
```
gh pr diff --patch PRNUMBER | git am
```



