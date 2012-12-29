Troubleshooting
====

Symbol not found: `_rb_intern2`
----

The following error message has been encountered trying to run `rspec` from
within Vim.

    lazy symbol binding failed: Symbol not found: _rb_intern2

This problem arose because Vim was starting the rspec command from within a zsh
sub shell.  Unfortunately, the sub-shell had a re-ordered PATH variable because
of the shell initialization in ~/.zshrc  The re-ordering caused the wrong
version of Ruby to be invoked, but it was still loading compiled gems from the
`GEM_HOME` and `GEM_PATH` environment variables.

The problem can be worked around by making sure the Puppet Version Manager
shell initialization happens last in the shell initialization process, for
example in `zsh`:

    echo 'eval "$(/opt/puppet/versions/bin/pvm init -)"' >> ~/.zshenv

The path ordering problem can be verified with the following commands:

    $ ruby -ryaml -e 'puts ENV["PATH"].split(":").to_yaml' > path1.yml
    $ echo ruby -ryaml -e "\"puts ENV['PATH'].split(':').to_yaml\"" | zsh > path2.yml
    $ diff -U4 path{1,2}.yml
    --- path1.yml   2012-12-29 11:46:23.000000000 -0800
    +++ path2.yml   2012-12-29 11:49:48.000000000 -0800
    @@ -1,19 +1,18 @@
    ----
    -- /opt/puppet/versions/bin
    -- /opt/puppet/versions/ruby/1.9.3-p327/bin
    -- /opt/puppet/versions/ruby/1.9.3-p327/gemsets/dev/bin
    -- /opt/puppet/versions/ruby/1.9.3-p327/gemsets/global/bin
    -- /usr/local/heroku/bin
    -- /opt/local/bin
    +--- 
     - /usr/bin
     - /bin
     - /usr/sbin
     - /sbin
     - /usr/local/bin
     - /opt/X11/bin
     - /usr/local/go/bin
    +- /opt/puppet/versions/bin
    +- /opt/puppet/versions/ruby/1.9.3-p327/bin
    +- /opt/puppet/versions/ruby/1.9.3-p327/gemsets/dev/bin
    +- /opt/puppet/versions/ruby/1.9.3-p327/gemsets/global/bin
     - /usr/local/heroku/bin
    +- /opt/local/bin
     - /Users/jeff/customization/bin
     - /Users/jeff/bin
     - /usr/X11/bin
     - /opt/local/sbin

Re-initializing the environment will restore Puppet Version Manager to the
front of the PATH.

EOF
