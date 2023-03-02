# Test your Gitlab CI/CD pipleine execution locally

>>>
This article is still a work in progress
>>>

Lately I have worked mostly on GitLab CI/CD Pipelines.  The process of debugging
a pipeline can become a bit tedious when the pipeline has many steps and takes a
long time to get to the part you're testing.  Then you find that you have made a
minor typo.  Every tweak and test also requires a commit and push.  If someone
was to read my commit history for the pipeline work, I'd look like (show that I
am) an idiot.

It is possible to use a locally installed `gitlab-runner` to run pipeline steps
locally, without needing to commit and push to GitLab.

## Prerequisites
TODO: Expand
* gitlab-runner package installed
* docker installed

### gitlab-runner Config Tweaks
* pull policy

#### Wireguard tunnel inside Gitlab docker runner
In the default configuration, Gitlab runners will not be able to create
Wireguard tunnels.  You will get an error message like the following:
```
RTNETLINK answers: Operation not permitted
Unable to access interface: Operation not permitted
```

* Edit `/etc/gitlab-runner/config.toml`
* In the `[[runners]]` -> `[runners.docker]` section, add:
```
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    cap_add = ["NET_ADMIN"]
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
    pull_policy = "if-not-present"
```

### Docker Config Tweaks

### OCI registries
If your pipeline makes use of OCI Images hosted in GitLab (maybe in the same
project you're testing) your pipeline that usually has direct access to these
images now doesn't.  You need to add the remote GitLab registry to you're local
Docker instance.

In GitLab, in the project hosting the Image, create a token:
* Maintainer
* read_registry

```
docker login registry-git.orro.dev -u token -p <token>
cat ~/.docker/config.json
```

## Committed vs Uncommitted source
The gitlab-runner still expects that it's supposed to run the latest committed
version of the source.  One of my goals is to be able to test uncommitted code.
I made a script that replaces the committed code that the gitlab-runner has
placed in the build container with the latest uncommitted code from my project.
```bash
#!/usr/bin/env bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

printf "${GREEN}\$ The gitlab-runner has kindly checked out the latest committed source for us but, that is going to be deleted in favor of using the latest uncommitted source. ${NC}\n"
rm -fr /builds/project-0
mkdir /builds/project-0
cp -r /builds/source.tmp/. /builds/project-0
cp -r /builds/artifacts/. /builds/project-0
```

```bash
cat <<"EOF"
--env VAULT_TOKEN=hvs.CAESIEigrMb95Tqb6KQV_aGcZwGpYlWet9ctN4239arzexvaGh4KHGh2cy5rVjJBMEtlMzBPTUI0VGd1ZmttbDk2ZDg
--env GITLAB_TOKEN=goBxAtCRs3R-h-Ssozcg
--env CI_COMMIT_BRANCH=main
--env FORCE_CI_PROJECT_ID=247
--env CI_ARTIFACTS_DIR=/builds/artifacts
EOF
printf '%s\n' "--docker-volumes $(pwd)/.gitlab-ci.artifacts:/builds/artifacts"
printf '%s\n' "--docker-volumes $(pwd):/builds/source.tmp:ro"
#printf '%s\n' "--docker-volumes $(pwd)/.gitlab-ci.cache:/builds/.cache"
#printf '%s\n' "--cache-dir=/builds/.cache"
printf '%s' '--post-clone-script '
printf '%s\n' '/builds/source.tmp/scripts/test-uncommitted-source'

```

## Differences when running jobs locally
### `gitlab-ci.yml` issues
The gitlab-runner must normally receive the job configuration from the GitLab
server with some of the YAML processing already completed.  This means that some
`gitlab-ci.yml` features don't work as expected when using the gitlab-runner.

#### `extends`
`extends` doesn't seem to work at all.  This is sad because I recently started
making greater use of this feature.

#### Numeric Environment Variables
The gitlab-runner doesn't seem to like numeric environment variables unless they
are encapsulated in quotes.  For example:
```yaml
variables:
  JOB_NUMBER: 10
```
doesn't work but
```yaml
variables:
  JOB_NUMBER: "10"
```
works fine.

### Missing environment variables
Obviously, some of the GitLab injected environment variables are going to be
missing or the vaules will be different.

* `CI_PROJECT_ID`: Always set to 0  
  To work around this, I set a hard coded value into `FORCE_CI_PROJECT_ID` and
  have my `before_script` look for `FORCE_CI_PROJECT_ID` not being blank.  If it
  has a value, it is pushed into `CI_PROJECT_ID`.
  ```bash
  if [ "${FORCE_CI_PROJECT_ID}" != "" ]; then
    export CI_PROJECT_ID="${FORCE_CI_PROJECT_ID}"
  fi
  ```
* `CI_JOB_TOKEN`: always blank.  I use this for detecting if my CI/CD scripts
  are running in the local gitlab-runner.
* `CI_JOB_JWT`: not defined.  If you use this for authenticating with external
  systems (e.g. Hashicorp Vault) you will need to use an alternative method when
  running in the gitlab-runner.