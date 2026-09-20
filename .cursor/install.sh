#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the github-slideshow Jekyll site.
# Installs Ruby (via rbenv) to match the github-pages/jekyll gem set, the
# locked Bundler, and all gem dependencies. Safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

RUBY_VERSION="$(cat .ruby-version)"
BUNDLER_VERSION="$(awk '/^BUNDLED WITH/{getline; gsub(/ /,""); print}' Gemfile.lock)"
export RBENV_ROOT="${RBENV_ROOT:-$HOME/.rbenv}"

install_rbenv() {
  if [ ! -d "$RBENV_ROOT" ]; then
    git clone --depth 1 https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
  fi
  if [ ! -d "$RBENV_ROOT/plugins/ruby-build" ]; then
    git clone --depth 1 https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
  fi
}

install_build_deps() {
  # Only needed when Ruby has to be compiled from source.
  sudo apt-get update -qq
  sudo apt-get install -y -qq --no-install-recommends \
    autoconf bison build-essential libssl-dev libyaml-dev \
    libreadline-dev zlib1g-dev libncurses-dev libffi-dev \
    libgdbm-dev uuid-dev
}

install_rbenv
export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
eval "$(rbenv init - bash)"

if ! rbenv versions --bare 2>/dev/null | grep -qx "$RUBY_VERSION"; then
  echo "==> Installing Ruby $RUBY_VERSION (compiling from source)…"
  install_build_deps
  rbenv install --skip-existing "$RUBY_VERSION"
fi
rbenv global "$RUBY_VERSION"
rbenv rehash

if ! gem list -i bundler -v "$BUNDLER_VERSION" >/dev/null 2>&1; then
  echo "==> Installing Bundler $BUNDLER_VERSION…"
  gem install bundler -v "$BUNDLER_VERSION" --no-document
  rbenv rehash
fi

echo "==> Installing gem dependencies…"
bundle "_${BUNDLER_VERSION}_" config set --local path 'vendor/bundle'
bundle "_${BUNDLER_VERSION}_" install --jobs 4

# Make rbenv available in interactive login shells (terminals) for the agent.
RC="$HOME/.bashrc"
if ! grep -q 'rbenv init' "$RC" 2>/dev/null; then
  {
    echo ''
    echo '# rbenv (added by .cursor/install.sh)'
    echo 'export RBENV_ROOT="$HOME/.rbenv"'
    echo 'export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"'
    echo 'eval "$(rbenv init - bash)"'
  } >> "$RC"
fi

echo "==> App is now ready to go!"
