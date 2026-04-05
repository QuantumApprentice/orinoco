How do I run this?

```bash
./dc_dev up -d
cd railsapp
./bin/dev
```
if on windows,

```bash
./dc_dev up -d
cd railsapp
dev.sh server
# and in another window
dev.sh bridge
```

rbenv will help you manage ruby installations. It's a fancy way of being able to install ruby of various versions and have your PATH updated as needed.

install rbenv via git

[rbenv installation instructions](https://github.com/rbenv/rbenv?tab=readme-ov-file#basic-git-checkout)

once you have your shell updated and reloaded according to those instructions,

`rbenv install 4.0.1`

which will install ruby 4.0.1

`rbenv global 4.0.1`

which will set ruby 4.0.1 as the version you use globally

`ruby --version`

will show that the right version of ruby is active.

a gem is a ruby library.

bundler will help you install multiple gems at the same time via Gemfile / Gemfile.lock, which is a lot like npm's package.json

[Docker Desktop install on Linux](https://docs.docker.com/desktop/setup/install/linux/debian/)

dev environment:

this will build the rails docker image
./dc_dev build

this will start the containers
./dc_dev up -d

dev container is cool, but for actually hacking on code you'll want to run rails directly.
to do this

    cd railsapp
    bundle install
    ./bin/dev

The reason for this is we don't have the dev container setup to load the source code, so it will always be out of date.
If we change to a bind mount and make sure the config is correct we should be able to get rid of this and just dev in
the container, but that's not where we are yet.

the environment variables are used to configure services wiring to each other.

For docker, the environment variables are in test.env, development.env, and production.env

For foreman, the environment variables are in rails/.env.dev.orinoco and railsapp/.env.test.orinoco

in the orinoco directory (the rails app)
./r_dev is a script wrapper like dc_dev - this one runs rails with the orinoco service environment variables set from .env.dev.orinoco

[Docker Orinoco](http://localhost:31050/)

[Foreman Orinoco](http://localhost:33230/)
