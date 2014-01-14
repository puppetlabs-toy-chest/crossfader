Overview
====

Crossfader provides pre-compiled, packaged versions of Ruby and a command line
tool to easily switch between them.  This project aims to solve many of the
same problems [Ruby Version Manager][rvm] and [rbenv][rbenv] aim to solve, but
in a different manner building upon pre-compiled packages and a simple command
line rubygem.

Why Crossfader?
====

We built Crossfader at Puppet Labs to address a number of problems:

 * It takes a long time for newly hired developers to build their toolchain
   from source.  Installing from packages is faster than compiling.
 * Developers had divergent tool chains since they were built at different
   times in different ways.  Installing from packages is more consistent.
 * Developers have to maintain their own toolchain which takes time from
   their primary goals.  Installing from packages makes it easier to maintain
   an updated system.


Quick Start
====

This repository is a build system composed of rake tasks.  The system produces
the crossfader packages in `pkg/`.  First, clone this project into a build
workspace.

Install the dependencies into the local project:

    bundle install --path .

To build all of the packages that compose the distribution, use the `rake
crossfader` task.  This task builds the crossfader runtime in
`/opt/crossfader/runtime/bin` then iterates over the
`config/crossfader_*.yaml`, building each one with a prefix of
`/opt/crossfader/versions/<interpreter>/<version>`, for example
`/opt/crossfader/versions/ruby/1.9.3p448/bin/ruby`.

    bundle exec rake crossfader

Individual builds

This package will install into the system and is usable from a shell
environment.  For example:

    eval "$(/opt/crossfader/bin/crossfader shellinit)"

This could be added to the shell initialization files.  For example if you're
using zsh then add this line to `~/.zshrc`:

    echo '[ -x /opt/crossfader/bin/crossfader ] && eval "$(/opt/crossfader/bin/crossfader shellinit)"' >> ~/.zshrc

Or if you're using BASH add this line to your `~/.bash_profile`:

    echo '[ -x /opt/crossfader/bin/crossfader ] && eval "$(/opt/crossfader/bin/crossfader shellinit)"' >> ~/.bash_profile

Related Work
====

Previous and related works are the [Ruby Version Manager][rvm], [rbenv][rbenv],
and [Python Virtual Env][virtualenv].

[rbenv]: https://github.com/sstephenson/rbenv
[rvm]: https://rvm.io/
[virtualenv]: https://github.com/pypa/virtualenv/
