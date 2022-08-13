# Securely save your git password when using HTTP(S) access
I have a self-hosted gitlab instance that is presented to the world only via a
Cloudflared tunnel.  Usually, if I want convienient commit access to git, I use
an SSH key and ssh-agent to cache the key (so I only need to enter the password
occasionally).

For a seperate "service", in this case SSH, to be presented publicly by
CloudFlare via a cloudflared tunnel you need to use a different public FQDN.
This seems a bit clunky.  ssh.git.domain.com for ssh, git.domain.com for HTTPS?

Can I just use HTTPS for everything?

**Reference:** https://gist.github.com/maelvls/79d49740ce9208c26d6a1b10b0d95b5e

## Install the libsecret git credential helper
### On Ubuntu (and derivitives)
```
sudo apt install libsecret-1-0 libsecret-1-dev libglib2.0-dev
sudo make --directory=/usr/share/doc/git/contrib/credential/libsecret
```

## Configure git to use the credential helper
```
git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
```

## Install lssecret (optional)
```
git clone https://github.com/gileshuang/lssecret /tmp/lssecret
cd /tmp/lssecret
make && DESTDIR=/usr/local sudo make install
rehash
```