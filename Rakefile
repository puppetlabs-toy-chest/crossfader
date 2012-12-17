require 'rake'
require 'fileutils'
require 'pathname'
require 'yaml'

desc "Show the list of tasks (rake -T)"
task :help do
  sh "rake -T"
end
task :default => :help

##
# configname determines which configuration file will be read from
# `config/<configname>.yaml`.  The default is "master" and can be overridden
# with the PVM_CONFIG environment variable.
#
# @api public
#
# @return [String] "master" is the default
def configname
  ENV['PVM_CONFIG'] || "master"
end

def config
  @config = Configuration.new(configname)
end

class Configuration
  attr_reader :name
  attr_reader :config

  ##
  # This is the name of this configuration instance.  This will map directly to
  # the files in `config/<name>.yaml`
  def initialize(name)
    @name = name
    @config_file = File.join(File.dirname(__FILE__), "config/#{name}.yaml")
    config_reset
  end

  ##
  # Clean up the PATH and other environment variables
  def setup_environment
    ENV['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin:/usr/X11/bin'
    %w{RUBYLIB GEM_PATH GEM_HOME}.each do |var|
      ENV[var] = nil
    end
  end

  def config_data
    @config_data ||= YAML.load_file(@config_file)
  end
  private :config_data

  def config_reset
    @config = Hash.new() do |h, (k,v)|
      raise KeyError, "Configuration key #{k.inspect} does not exist in #{@config_file}"
    end
  end
  private :config_reset

  ##
  # config returns the configuration Hash
  #
  # @return [Hash] of the configuration keys and values.
  def config
    if @config.empty?
      @config.merge! config_data
    else
      @config
    end
  end

  def [](key)
    config[key]
  end

  def root
    config[:root]
  end
end

##
# GenericBuilder provides a convenient way to reuse ruby methods that implement
# the basic configure, make, make install workflow of building and installing
# software.
#
# In particular, the `build` method provides a public API to compile a generic
# C application like zlib.
class GenericBuilder
  include Rake::FileUtilsExt
  attr_reader :config
  attr_reader :id
  attr_reader :group

  ##
  # @param config [Configuration] the configuration instance to use.
  #
  # @param id [Symbol] the identifier of the software to build, e.g. :zlib
  #
  # @param group [Symbol] the group identifier, e.g. :ruby
  def initialize(config, id, group=:ruby)
    @config = config
    @group = group
    @id = id
  end

  def prefix
    @prefix ||= "#{@config.root}/#{group}/#{group}-#{@config[group][:version]}"
  end

  ##
  # build will configure, compile, then install a piece of software into the
  # target prefix directory.
  def build
    puts "Installing #{id} into #{prefix} ..."
    Dir.chdir(config[@id][:src]) do
      sh "./configure --prefix=#{prefix}"
      sh "make -j5"
      sh "make install"
    end
  end
end

class ZlibBuilder < GenericBuilder
  def initialize(config, id=:zlib)
    super(config, id)
  end
end

namespace "build" do
  desc "Build zlib Library"
  task :zlib do
    ZlibBuilder.new(config).build
  end
end

desc "Build all of the things"
task :build => [ "build:zlib" ] do
  puts "All Done!"
end

desc "Purge #{config.root}"
task :purge do
  rm_rf config.root
end
