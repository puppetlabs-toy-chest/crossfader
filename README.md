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

Quick Start (Install)
====

Crossfader is basically a set of command line tools to configure your shell
environment for use with specific Ruby versions.  Install the package to get
started, configure your shell, then start using bundler.

This quick start process works toward running the full suite of unit tests for
core Puppet.

Download the package for your OS version.  You can check the OS version with the
`sw_vers` command.

  * [Crossfader for Mac OS X 10.8](http://links.puppetlabs.com/crossfader_10.8.pkg)
  * [Crossfader for Mac OS X 10.9](http://links.puppetlabs.com/crossfader_10.9.pkg)

Install the package from the command line.  The GUI Installer.app gives an
error message, "You need to have administrative privileges to install this
software" but the shell `installer` command works with sudo.

    $ sudo installer -target / -pkg crossfader_*.pkg

Modify your shell initialization files to load the default ruby version.  This
example is for ZSH but any Bourne compatible shell will work fine.  For Bash
append the line to `~/.bash_profile` instead of `~/.zshenv`.

    $ echo '[ -x /opt/crossfader/bin/crossfader ] && eval "$(/opt/crossfader/bin/crossfader shellinit)"' >> ~/.zshenv

NOTE: If you'd like to use some other ruby version other than the default,
simply provide --ruby and optionally --gemset to the shellinit subcommand, like
this

    $ echo '[ -x /opt/crossfader/bin/crossfader ] && eval "$(/opt/crossfader/bin/crossfader --ruby 2.1.0 --gemset playground shellinit)"' >> ~/.zshenv

Load crossfader in the current shell or close the current shell and start a new
one:

    $ eval "$(/opt/crossfader/bin/crossfader shellinit)"

Now, when working with your project, e.g. puppet, simply install the bundle of
gems into the project directory.

    $ mkdir ~/src
    $ cd ~/src
    $ git clone https://github.com/puppetlabs/puppet.git
    Cloning into 'puppet'...
    remote: Reusing existing pack: 155034, done.
    remote: Counting objects: 167, done.
    remote: Compressing objects: 100% (150/150), done.
    remote: Total 155201 (delta 77), reused 43 (delta 13)
    Receiving objects: 100% (155201/155201), 35.07 MiB | 3.67 MiB/s, done.
    Resolving deltas: 100% (110340/110340), done.
    Checking connectivity... done.
    git clone https://github.com/puppetlabs/puppet.git  5.28s user 4.79s system 52% cpu 19.131 total

Use bundler to install Puppet's dependencies:

    $ bundle install --path .bundle/gems/
    Fetching gem metadata from https://rubygems.org/.....
    Fetching gem metadata from https://rubygems.org/..
    Resolving dependencies...
    Installing rake (10.1.1)
    ...
    Using puppet (3.4.3) from source at /Users/jeff/src/puppet
    Using bundler (1.3.6)
    Your bundle is complete!
    It was installed into ./.bundle/gems
    bundle install --path .bundle/gems/  9.51s user 2.76s system 38% cpu 31.488 total

Finally run the spec test suite, which takes a few minutes:

    $ bundle exec rake spec
    rspec spec
    ...

Ruby versions can be listed with `crossfader list` and activated by passing the
version string to `crossfader --ruby ... shellinit`.  Gemsets can be created by
simply specifying a new gemset when installing a gem, e.g. `crossfader --gemset
foo exec gem install bundler`.

Quick Start (Build Tools)
====

NOTE, if you're looking to install crossfader rather than build the crossfader
packages please see the Quick Start to Install.

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
using zsh then add `crossfader shellinit` to `~/.zshrc` like so:

    echo '[ -x /opt/crossfader/bin/crossfader ] && eval "$(/opt/crossfader/bin/crossfader shellinit)"' >> ~/.zshrc

Or if you're using BASH add `crossfader shellinit` to `~/.bash_profile` like
so:

    echo '[ -x /opt/crossfader/bin/crossfader ] && eval "$(/opt/crossfader/bin/crossfader shellinit)"' >> ~/.bash_profile

Related Work
====

Previous and related works are the [Ruby Version Manager][rvm], [rbenv][rbenv],
and [Python Virtual Env][virtualenv].

[rbenv]: https://github.com/sstephenson/rbenv
[rvm]: https://rvm.io/
[virtualenv]: https://github.com/pypa/virtualenv/
