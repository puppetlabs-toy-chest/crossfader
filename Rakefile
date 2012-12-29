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
    @prefix ||= "#{@config.root}/#{group}/#{@config[group][:version]}"
  end

  def configure
    sh "./configure --prefix=#{prefix}"
  end

  def make
    sh "make -j5"
  end

  def install
    sh "make install"
  end

  ##
  # build will configure, compile, then install a piece of software into the
  # target prefix directory.
  def build
    puts "Installing #{id} into #{prefix} ..."
    Dir.chdir(config[@id][:src]) do
      configure
      make
      install
    end
  end
end

class OpenSSLBuilder < GenericBuilder
  def initialize(config, id=:openssl, group=:ruby)
    super(config, id, group)
  end

  def make
    sh "make"
  end

  def configure
    # FIXME portability from darwin64-x86_64-cc
    sh "./Configure darwin64-x86_64-cc --prefix=#{prefix} -I#{prefix}/include -L#{prefix}/lib zlib no-krb5 shared no-asm"
  end
end

class RubyBuilder < GenericBuilder
  def initialize(config, id=:ruby, group=:ruby)
    super(config, id, group)
  end

  def configure
    sh <<-EOCONFIG
      ./configure --prefix=#{prefix} \
        --with-opt-dir=#{prefix} \
        --with-yaml-dir=#{prefix} \
        --with-zlib-dir=#{prefix} \
        --with-openssl-dir=#{prefix} \
        --with-readline-dir=/usr \
        --without-tk --without-tcl
    EOCONFIG
  end
end


##
# File dependencies
openssl = OpenSSLBuilder.new(config)
file "#{openssl.prefix}/bin/openssl" => ["build:zlib"] do
  openssl.build
end

zlib = GenericBuilder.new(config, :zlib)
file "#{zlib.prefix}/lib/libz.dylib" do
  zlib.build
end

yaml = GenericBuilder.new(config, :yaml)
file "#{yaml.prefix}/lib/libyaml.dylib" do
  yaml.build
end

ffi = GenericBuilder.new(config, :ffi)
file "#{ffi.prefix}/lib/libffi.dylib" do
  ffi.build
end

ruby = RubyBuilder.new(config)
file "#{ruby.prefix}/bin/ruby" => ["build:ffi", "build:zlib", "build:yaml", "build:openssl"] do
  ruby.build
end

namespace "build" do
  desc "Build ruby (#{ruby.prefix}/bin/ruby)"
  task :ruby => ["#{ruby.prefix}/bin/ruby"]

  desc "Build zlib Library (#{zlib.prefix}/lib/libz.dylib)"
  task :zlib => ["#{zlib.prefix}/lib/libz.dylib"]

  desc "Build openssl Library (#{openssl.prefix}/bin/openssl)"
  task :openssl => ["#{openssl.prefix}/bin/openssl"]

  desc "Build yaml Library (#{yaml.prefix}/lib/libyaml.dylib)"
  task :yaml => ["#{yaml.prefix}/lib/libyaml.dylib"]

  desc "Build ffi Library (#{ffi.prefix}/lib/libffi.dylib)"
  task :ffi => ["#{ffi.prefix}/lib/libffi.dylib"]
end

directory "#{config.root}"
directory "#{config.root}/bin"
file "#{config.root}/bin/pvm" => ["uninstall:pvm"] do
  sh 'cp bin/pvm /opt/puppet/versions/bin/pvm'
  sh 'chmod 755 /opt/puppet/versions/bin/pvm'
end

namespace "install" do
  desc "Install pvm script"
  task :pvm => ["#{config.root}/bin/pvm"]
end

namespace "uninstall" do
  desc "Remove pvm script"
  task :pvm do
    sh 'rm -f /opt/puppet/versions/bin/pvm'
  end
end

desc "Build all of the things"
task :build => ["build:openssl", "build:yaml", "build:ffi", "build:ruby"] do
  puts "All Done!"
end

desc "Purge #{config.root}"
task :purge do
  rm_rf config.root
end
