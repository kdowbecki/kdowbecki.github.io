# Blog

This repository hosts [kdowbecki.github.io](https://kdowbecki.github.io) page.

## Installing

Install `rbenv` package, than use it to install ruby version
```
$ rbenv install "$(cat .ruby-version)" --verbose
```

Append below line to `.bashrc`
```
eval "$(rbenv init - bash)"
```

Reinstall bundler using `rbenv` shims

```
$ gem install bundler
$ bundle install
```

## Running

Execute `./run.sh` and open http://127.0.0.1:4000 to preview.


## Keeping up to date with the template repo

See https://stackoverflow.com/a/56577320/1602555 for one way to do this.

