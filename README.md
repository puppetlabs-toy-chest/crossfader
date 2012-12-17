Overview
====

Puppet Version Manager (identified as `puppet_version_manager`) is intended to
minimize the disruption that comes along with running multiple versions of
Puppet.  Specifically, it should be no problem whatsoever to switch between two
arbitrary versions of Puppet.

This capability makes it possible to eliminate much of the risk associated with
trying out new versions of Puppet.  This, in turn, allows Puppet Labs to make
incompatible changes at a high frequency.

Related Work
====

Previous and related works are the [Ruby Version Manager][rvm], [rbenv][rbenv],
and [Python Virtual Env][virtualenv].

[rbenv]: https://github.com/sstephenson/rbenv
[rmv]: https://rvm.io/
[virtualenv]: https://github.com/pypa/virtualenv/

Filesystem Layout
====

The overall strategy is to reorganize the entire system to eliminate all
roadblocks to running multiple versions of Puppet on the same host.

`=>` denotes linked library dependencies for Mac OS X as an example.

    /opt/puppet/versions/mri/1.9.3-p194/bin/ruby
      => /usr/lib/libSystem.B.dylib
      => /usr/lib/libobjc.A.dylib
    /opt/puppet/versions/mri/1.8.7-p358

Known Dependencies
====

This section is just a checklist of required dependencies we need to make sure
we're managing in an effective way.  The absolute paths in these examples are
only a starting point.  We take as much control of dependent software versions
as is necessary while being mindful of the cost of managing these dependencies.

MRI Ruby 1.9.3
----

 * `psych` => `/Users/jeff/.rbenv/versions/1.9.3-p194/lib/libyaml-0.2.dylib`
 * `openssl` => `/opt/local/lib/lib{ssl,crypto}.1.0.0.dylib` (OpenSSL 1.0.1c)
 * `md5`, `sha1`, `sha2`, `rmd160` => `/opt/local/lib/libcrypto.1.0.0.dylib`
   (OpenSSL 1.0.1c)
 * `fiddle` => `/opt/local/lib/libffi.6.dylib`
 * `zlib` => `/usr/lib/libz.1.dylib`
 * `curses` => `/usr/lib/libncurses.5.4.dylib`
 * `readline` => `/usr/lib/libncurses.5.4.dylib`, `/usr/lib/libedit.3.dylib`
 * `iconv` => `/usr/lib/libiconv.2.dylib`
 * `pty` => `/usr/lib/libutil.dylib`
 * `tcltk` => Lots of stuff in `/System/Library/Frameworks` (Omit?)

Current Status
====

After installing Ruby 1.9.3-p327, basic gemsets are possible by simply using
the `GEM_HOME` and `GEM_PATH` environment variables.  I currently set these to
named folders inside of the `gemsets` directory of the runtime.  For example:

First, install the global gems:

    export GEM_HOME=/opt/puppet/versions/ruby/1.9.3-p327/gemsets/global
    gem install rake

Next, install the gems specific to your activity.  In general, development
activities have a lot more dependencies than runtime dependencies.  This
organization scheme is very similar to a Bundler bundle.

    PATH=/opt/puppet/versions/ruby/1.9.3-p327/gemsets/global/bin:$PATH
    PATH=/opt/puppet/versions/ruby/1.9.3-p327/gemsets/dev/bin:$PATH
    PATH=/opt/puppet/versions/ruby/1.9.3-p327/bin:$PATH
    GEM_PATH=/opt/puppet/versions/ruby/1.9.3-p327/gemsets/global
    GEM_HOME=/opt/puppet/versions/ruby/1.9.3-p327/gemsets/dev
    export PATH GEM_PATH GEM_HOME

Then install the Puppet dependencies:

    gem install rspec -v '~> 2.10.0'
    gem install mocha -v '~> 0.10.0'
    gem install json  -v 1.5.4
    gem install rack  -v 1.4.1
    gem install yard
    gem install watchr
    gem install pry
    gem install wirb
    gem install irbtools
    gem install terminal-notifier

And we can see the specific locations load properly using only `GEM_HOME` and
`GEM_PATH`.

    $ gem which rake
    /opt/puppet/versions/ruby/1.9.3-p327/lib/ruby/1.9.1/rake.rb
    $ gem which rspec
    /opt/puppet/versions/ruby/1.9.3-p327/gemsets/dev/gems/rspec-2.10.0/lib/rspec.rb

With all of these Gems installed, we now have a complete set of tools to run
the example behavior suite:

    RUBYLIB=/workspace/puppet/src/hiera/lib
    RUBYLIB=/workspace/puppet/src/facter/lib:$RUBYLIB
    RUBYLIB=/workspace/puppet/src/puppet/lib:$RUBYLIB
    export RUBYLIB

    $ cd puppet
    $ rake spec
