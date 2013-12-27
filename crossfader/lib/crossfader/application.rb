require 'crossfader'
require 'rubygems'
require 'trollop'
require 'json'
require 'rbconfig'

class Crossfader::Application
  attr_reader :env, :argv, :opts, :home, :environment

  def version
    Crossfader::VERSION
  end

  ##
  # build_version reads and returns the first line without trailing newline
  # which should be a version string.  The file read is located at
  # `/opt/crossfader/version.txt`.  If the file does not exist then "UNKNOWN"
  # is returned.
  def build_version
    return @build_version if @build_version
    version_file = "/opt/crossfader/version.txt"
    if File.exists?(version_file)
      @build_version = File.open(version_file) {|f| f.readline}.chomp
    else
      @build_version = 'UNKNOWN'
    end
  end

  def initialize(opts = {})
    @env = opts[:env] || ENV.to_hash
    @argv = opts[:argv] || ARGV.dup
    @home = opts[:home] || '/opt/crossfader'
    save_environment!
    parse_options!
  end

  def parse_options!
    version = version()
    build_version = build_version()
    env = env()
    @opts = Trollop.options(argv) do
      stop_on_unknown
      version "crossfader #{build_version} (c) 2013 Puppet Labs"
      banner BANNER

      opt :ruby, "Ruby version to use {CROSSFADER_RUBY}",
        :default => env['CROSSFADER_RUBY'] || '1.9.3-p448',
        :type    => :string

      opt :gemset, "Gemset to use {CROSSFADER_GEMSET}",
        :default => env['CROSSFADER_GEMSET'] || 'crossfader',
        :type    => :string

      opt :debug, "Enable debug messages", :type => :boolean
    end
  end

  ##
  # prefix returns the prefix used to install the selected ruby version
  #
  # @api private
  #
  # @return [String] the full path of the ruby installation prefix.
  def prefix
    @prefix ||= "#{home}/versions/ruby/#{opts[:ruby]}"
  end

  ##
  # gem_system_dir returns the path to the ruby system gem installation
  # location.  This is the location where bundled gems like bigdecimal and json
  # are installed.
  #
  # @return [String] the full path to the system gem location
  def gem_system_dir
    @gem_system_dir ||= "#{prefix}/lib/#{ruby_engine}/gems/#{ruby_version}"
  end

  ##
  # ruby returns the full path to the ruby executable of the selected ruby
  #
  # @return [String] the full path to the ruby executable
  def ruby
    @ruby ||= "#{prefix}/bin/ruby"
  end

  ##
  # ruby_engine returns the string indentifying the ruby engine of the selected
  # ruby version.  If the ruby version does not define the RUBY_ENGINE constant
  # then the string "ruby" is returned.
  #
  # @return [String] the ruby engine, usually "ruby"
  def ruby_engine
    # Ruby 1.8.7 does not define the RUBY_ENGINE constant.
    @ruby_engine ||= %x{#{ruby} -e "puts defined?(RUBY_ENGINE) ? RUBY_ENGINE : %{ruby}"}.chomp
  end

  ##
  # ruby_version returns the binary compatibility version of the ruby engine.
  # This will be "1.9.1" or "1.8" in most cases.  This method is useful to
  # construct GEM_HOME and GEM_PATH values.
  #
  # @return [String] the ruby ABI compatibility version
  def ruby_version
    @ruby_version ||= %x{#{ruby} -rrbconfig -e 'puts RbConfig::CONFIG["ruby_version"]'}.chomp
  end

  ##
  # gemset_dir returns the path for the named gemset suitable for use with
  # `bundle install --path`.  This path is not suitable for use with GEM_HOME
  # or GEM_PATH because the interpreter and version path elements are not
  # included.  For example bundle install --path /tmp/foo is usable only if
  # /tmp/foo/ruby/1.9.1 is added to GEM_PATH for Ruby 1.9.3.
  #
  # @param [String] gemset The name of the gemset to generate a path for
  #
  # @api private
  #
  # @return [String] the path for the gemset suitable for use with `bundle
  #   install --path`.
  def gemset_dir(gemset)
    "#{prefix}/gemsets/#{gemset}"
  end

  ##
  # gem_dir returns the path for the named gemset suitable for use with
  # GEM_HOME and GEM_PATH.  This includes the ruby runtime version information
  # obtained from the selected ruby version.
  def gem_dir(gemset)
    "#{prefix}/gemsets/#{gemset}/#{ruby_engine}/#{ruby_version}"
  end

  ##
  # path returns the value for PATH given the user supplied ruby version and
  # gemset.  This PATH will search the selected gemset, the global gemset, and
  # the ruby runtime bin directory.
  #
  # @return [String] the desired value for the PATH environment variable.
  def path
    @path ||= [
      "#{home}/bin",
      "#{gem_home}/bin",
      "#{gem_dir('global')}/bin",
      "#{prefix}/bin",
      env['XFADE_PATH_ORIG'] || env['PATH'],
    ].join(File::PATH_SEPARATOR)
  end

  ##
  # gem_home returns a string value suitable for use as the new GEM_HOME value.
  #
  # @return [String] The desired value for GEM_HOME.
  def gem_home
    @gem_home ||= gem_dir(opts[:gemset])
  end

  ##
  # gem_path returns a string value suitable for use as the new GEM_PATH value.
  #
  # @return [String] The desired value for GEM_PATH.
  def gem_path
    if @gem_path
      return @gem_path
    else
      @gem_path = [gem_dir('global'), gem_system_dir].join(File::PATH_SEPARATOR)
      if env['HOME']
        @gem_path << ":#{env['HOME']}/.gem/#{ruby_engine}/#{ruby_version}"
      end
    end
    return @gem_path
  end

  ##
  # print_env prints out a bourn SH compatible script.  The intent is to eval
  # the result in a shell.  For example, in bash: eval "$(crossfader shellinit)"
  def print_env
    %w{PATH GEM_HOME GEM_PATH}.each do |key|
      if ENV["XFADE_#{key}_ORIG"]
        puts "export XFADE_#{key}_ORIG='" + ENV["XFADE_#{key}_ORIG"] + "'"
      end
    end

    puts "export PATH='#{path}'"
    puts "export GEM_HOME='#{gem_home}'"
    puts "export GEM_PATH='#{gem_path}'"
    puts "export CROSSFADER_RUBY='#{opts[:ruby]}'"
    puts "export CROSSFADER_GEMSET='#{opts[:gemset]}'"
  end

  def run
    cmd = argv.shift
    case cmd
    when 'shellinit'
      print_env
    when 'list'
      print_list
    when 'exec'
      exec *argv
    else
      Trollop.die "unknown crossfader subcommand `#{(cmd || "")}`"
    end
  end

  ##
  # Debug log a message if `--debug` is true
  def debug(msg)
    return unless opts[:debug]
    $stderr.puts "Crossfader Debug: #{msg}"
  end

  ##
  # exec executes a system command using the configured environment.  For
  # example, this may be used to install gems into a specific gemset: `sudo
  # /opt/crossfader/bin/crossfader --gemset=puppet exec gem install puppet`
  def exec(*args)
    ENV['CROSSFADER_RUBY'] = opts[:ruby]
    debug "CROSSFADER_RUBY='#{ENV['CROSSFADER_RUBY']}'"
    ENV['CROSSFADER_GEMSET'] = opts[:gemset]
    debug "CROSSFADER_GEMSET='#{ENV['CROSSFADER_GEMSET']}'"
    ENV['PATH'] = path
    debug "PATH='#{ENV['PATH']}'"
    ENV['GEM_HOME'] = gem_home
    debug "GEM_HOME='#{ENV['GEM_HOME']}'"
    ENV['GEM_PATH'] = gem_path
    debug "GEM_PATH='#{ENV['GEM_PATH']}'"

    debug "Executing: #{args.inspect}"
    Kernel.exec(*args)
  end

  ##
  # list_ruby_versions returns a sorted array of strings.  Each element
  # represents an installed Ruby version suitable for use with the `--ruby`
  # option.
  #
  # @return [Array<String>] List of installed Ruby Versions
  def installed_ruby_versions
    @installed_ruby_versions ||= Dir["#{home}/versions/ruby/*"].collect do |d|
      File.basename(d)
    end.sort
  end

  ##
  # installed_gemsets returns a hash of installed ruby versions and gemsets for
  # each version.  The primary key of the hash is the ruby version and value is
  # a nested hash with a key of 'gemsets'.  The value of the gemsets key is a
  # sorted array of the gemsets available for that ruby version.
  def installed_gemsets
    @installed_gemsets ||= installed_ruby_versions.inject({}) do |memo, ruby|
      gemset_dir = "#{home}/versions/ruby/#{ruby}/gemsets"
      gemsets = Dir["#{gemset_dir}/*"].collect { |d| File.basename(d) }.sort
      memo[ruby] = { 'gemsets' => gemsets }
      memo
    end
  end

  ##
  # print_list prints out a list of gemsets currently present on the system.
  def print_list
    data = { 'ruby' => installed_gemsets }
    puts JSON.pretty_generate(data)
  end


  ##
  # save_environment! saves a copy of the existing environment variables that
  # will be modified in the subprocess.  The PATH, GEM_HOME and GEM_PATH
  # enviornment variables will be saved into XFADE_PATH_ORIG,
  # XFADE_GEM_HOME_ORIG, and XFADE_GEM_PATH_ORIG respectively.
  #
  # Existing XFADE_* variables will not be overwritten in order to preserve the
  # original values.
  def save_environment!
    %w{PATH GEM_HOME GEM_PATH}.each do |key|
      if env[key]
        ENV["XFADE_#{key}_ORIG"] ||= env[key]
      end
    end
  end

  BANNER = <<-'EOBANNER'
usage: crossfader [GLOBAL OPTIONS] COMMAND [ARGS]
Commands:
   exec       Execute a system command (exec puppet --version)
   list       List available tool versions
   shellinit  Generate bourne shell environment on stdout.

Quick Start:
Add this line to your shell initialization scripts.

    eval "$(/opt/crossfader/bin/crossfader shellinit)"

Gemsets:
To install a gem into a specific gemset:

    $ crossfader --gemset=puppet exec gem install puppet

Environment:
In an effort to avoid large command line argument lists, some options will take
their default value from the environment.  If an option lists an environment
variable in all caps in curly braces ({}), then the default value of that
option will depend on the value of the environment variable.

Global options:
  EOBANNER
end

