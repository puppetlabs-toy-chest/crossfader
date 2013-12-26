require 'rake'
require 'fileutils'
require 'pathname'
require 'yaml'
require 'facter'

desc "Show the list of tasks (rake -T)"
task :help do
  sh "rake -T"
end
task :default => :help

class ConfigurationError < StandardError; end

##
# install the crossfader gem.  The runtime needs to be installed for this to
# work.
def install_crossfader
  # Install the crossfader gem into the runtime ruby environment.
  Dir.chdir 'crossfader' do
    rm_rf 'pkg/*'
    sh %{../bin/xfade-run exec gem env}
    sh %{../bin/xfade-run exec gem install bundler -v '~> 1.3.5' --no-ri --no-rdoc}
    sh %{../bin/xfade-run exec rake build}
    sh %{../bin/xfade-run exec gem install pkg/*.gem --no-ri --no-rdoc}
    sh %{../bin/xfade-run exec gem list}
    sh %{../bin/xfade-run exec gem which crossfader}
    sh %{../bin/xfade-run exec which crossfader}
  end
end

##
# configname determines which configuration file will be read from
# `config/<configname>.yaml`.  The default is "master" and can be overridden
# with the CONFIG environment variable.
#
# @api public
#
# @return [String] "master" is the default
def configname
  ENV['CONFIG'] || "master"
end

def config
  @config = Configuration.new(configname)
end

class Configuration
  attr_reader :name

  ##
  # This is the name of this configuration instance.  This will map directly to
  # the files in `config/<name>.yaml`
  def initialize(name)
    @name = name
    @config_file = File.join(File.dirname(__FILE__), "config/#{name}.yaml")
    config_reset
    version
  end

  def file
    @config_file
  end

  def version
    @version ||= `git describe --always`.chomp
  end

  def mac_version
    @mac_version ||= Facter.fact('macosx_productversion_major').value
  end

  def package_id
    name = self[:name]
    if self[:name_suffix]
      "#{name}_#{self[:name_suffix]}"
    else
      name
    end
  end

  def package_name
    name = "#{self[:name]}_#{mac_version}"
    if self[:name_suffix]
      name << "_#{self[:name_suffix]}"
    end
    raise ConfigurationError, "no :name key in configuration #{@config_file}" unless name
    "#{name}-#{self.version}.pkg"
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
      raise IndexError, "Configuration key #{k.inspect} does not exist in #{@config_file}"
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
    begin
      config[key]
    rescue IndexError => detail
      nil
    end
  end

  def root
    config[:root]
  end

  def root_is_prefix?
    !!config[:root_is_prefix]
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
    @prefix ||= @config.root_is_prefix? ? @config.root : "#{@config.root}/#{group}/#{@config[group][:version]}"
  end

  def configure
    sh "bash ./configure --prefix=#{prefix}"
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

class PackageBuilder < GenericBuilder
  def initialize(config, id=:package, group=:ruby)
    super(config, id, group)
  end

  def package
    package_name = config.package_name
    sh 'bash -c "test -d destroot && rm -rf destroot || mkdir destroot"'
    sh "mkdir -p #{File.join('destroot', config.root)}"
    sh "rsync -axH #{config.root}/ #{File.join('destroot', config.root)}/"
    # Add extra stuff to the destroot
    if config[:extras]
      [*config[:extras]].each do |extra|
        sh "rsync -axH #{extra}/ destroot/"
      end
    end
    sh "pkgbuild --identifier com.puppetlabs.#{config.package_id} --root destroot --ownership recommended --version #{config.version} '#{package_name}'"
    sh 'bash -c "test -d pkg || mkdir pkg"'
    move package_name, "pkg/#{package_name}"
  end

  def synthesize
    sh 'test -d artifacts/ || mkdir artifacts/'
    Dir.chdir 'pkg' do
      packages = Dir["*.pkg"].collect() {|p| ['--package', p] }.flatten
      name = "crossfader_#{config.mac_version}-#{config.version}"
      sh "productbuild --synthesize #{packages.join(' ')} #{name}.xml"
      sh "productbuild --distribution #{name}.xml --package-path . ../artifacts/#{name}.pkg"
    end
  end

  def link_extra_packages
    Dir["extra_packages/#{config.mac_version}/*.pkg"].sort.each do |pkg|
      ln pkg, 'pkg/'
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
    sh "bash ./Configure darwin64-x86_64-cc --prefix=#{prefix} -I#{prefix}/include -L#{prefix}/lib zlib no-krb5 shared no-asm"
  end
end

class RubyGemsBuilder < GenericBuilder
  def initialize(config, id=:rubygems, group=:ruby)
    super(config, id, group)
  end

  def build
    puts "Installing #{id} into #{prefix} ..."
    Dir.chdir(config[@id][:src]) do
      sh "#{prefix}/bin/ruby setup.rb"
    end
  end
end

class RubyBuilder < GenericBuilder
  def initialize(config, id=:ruby, group=:ruby)
    super(config, id, group)
  end

  def make
    sh "RDOCFLAGS='--debug' make -j5"
  end

  def configure
    sh "#{prefix}/bin/autoconf"
    sh <<-EOCONFIG
      bash ./configure --prefix=#{prefix} \
        --with-opt-dir=#{prefix} \
        --with-yaml-dir=#{prefix} \
        --with-zlib-dir=#{prefix} \
        --with-openssl-dir=#{prefix} \
        --with-readline-dir=/usr \
        --without-tk --without-tcl
    EOCONFIG
  end

  def bundle_install_path(gemset="crossfader")
    return @bundle_install_path if @bundle_install_path

    if @config.root_is_prefix?
      @bundle_install_path = "#{@config.root}/lib/ruby/gems/1.9.1"
    else
      # /opt/crossfader/gemsets/1.9.3-p448/crossfader
      path = "#{@config.root}/../gemsets/#{@config[group][:version]}/#{gemset}"
      @bundle_install_path = File.expand_path(path)
    end
  end
  private :bundle_install_path

  # If the configuration defines a bundle gemfile, install it
  def install_gems
    # Array of Array's, e.g. [ [ 'bundler', '~> 1.3.5' ] ]
    gemlist_path = File.basename(config.file, '.yaml') + '_gems.yaml'

    if File.exists? gemlist_path
      gemlist = YAML.load(File.read(gemlist_path))
    else
      gemlist = [ [ 'bundler', '~> 1.3.5' ] ]
      puts "##### INFO: #{gemlist_path} does not exist, using default gemlist of: "
      puts gemlist.to_yaml
      puts "##### "
    end

    gem_home_orig = ENV['GEM_HOME']
    gem_path_orig = ENV['GEM_PATH']
    path_orig = ENV['PATH']

    ENV['PATH'] = [ File.join(prefix, 'bin'), ENV['PATH'] ].join(File::PATH_SEPARATOR)
    ENV['GEM_HOME'] = nil
    ENV['GEM_PATH'] = nil

    # Figure out the ruby engine and ruby version used for construction of
    # GEM_PATH and GEM_HOME
    ruby_engine = %x{#{File.join(prefix, 'bin', 'ruby')} -e "puts defined?(RUBY_ENGINE) ? RUBY_ENGINE : %{ruby}"}.chomp
    ruby_version = %x{#{File.join(prefix, 'bin', 'ruby')} -rrbconfig -e 'puts RbConfig::CONFIG["ruby_version"]'}.chomp

    ENV['GEM_HOME'] = File.join(gemset_folder, 'global', ruby_engine, ruby_version)
    ENV['GEM_PATH'] = File.join(prefix, 'lib', 'ruby', 'gems', ruby_version)

    # Finally, install the gems into the global gemset.
    gemlist.each do |gem, version|
      puts "##### INFO: Gem Environment used to install global gemset"
      sh "gem env"
      puts "##### INFO Installing #{gem} version #{version} into #{ENV['GEM_HOME']}"
      sh "gem install #{gem} --version '#{version}' --no-ri --no-rdoc"
      puts "##### INFO Results for #{gem} are:"
      sh "gem list"
      sh "gem which #{gem}"
      puts "##### End of installation for #{gem}"
    end

    ENV['GEM_HOME'] = gem_home_orig
    ENV['GEM_PATH'] = gem_path_orig
    ENV['PATH'] = path_orig
  end

  def build
    puts "Installing #{id} into #{prefix} ..."
    Dir.chdir(config[@id][:src]) do
      configure
      make
      install
      install_gems
    end
  end
end

##
# Custom Tasks
def unpack(name, src, dest, *args)
  args || args = []
  args.insert 0, name

  body = proc {
    FileList[src].each do |f|
      file = File.basename(f)
      puts "Unpacking #{file} in #{dest}"
      Dir.chdir dest do
        sh "tar -xjf #{file}"
      end
    end
  }
  Rake::Task.define_task(*args, &body)
end

##
# Unpack ruby instead of committing it to the source tree because I noticed
# we're getting missing encodings and it seems like we're not the only ones
# according to
# http://www.pressingquestion.com/4210120/What-Causes-A-Encodingconverter
namespace :unpack do
  unpack :ruby, "#{config[:ruby][:src]}.tar.bz2", "src/"
  unpack :openssl, "#{config[:openssl][:src]}.tar.bz2", "src/"
end

##
# File dependencies
openssl = OpenSSLBuilder.new(config)
file "#{openssl.prefix}/bin/openssl" => ["unpack:openssl", "build:zlib"] do
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

autoconf = GenericBuilder.new(config, :autoconf)
file "#{autoconf.prefix}/bin/autoconf" do
  autoconf.build
end

ruby = RubyBuilder.new(config)
file "#{ruby.prefix}/bin/ruby" => ["unpack:ruby", "build:ffi", "build:zlib", "build:yaml", "build:openssl", "build:autoconf"] do
  ruby.build
end

desc "Install gems described in gemfile"
task :gemfile do
  ruby.install_gems
end

if config[:rubygems]
  rubygems = RubyGemsBuilder.new(config, :rubygems)
  file "#{rubygems.prefix}/bin/gem" => ["#{rubygems.prefix}/bin/ruby"] do
    rubygems.build
  end
  namespace "build" do
    desc "Build rubygems"
    task :rubygems => ["#{rubygems.prefix}/bin/gem"]
  end
  namespace "install" do
    task :gems => ["#{rubygems.prefix}/bin/gem"]
  end
end

namespace "build" do
  desc "Build ruby (#{ruby.prefix}/bin/ruby)"
  task :ruby => ["#{ruby.prefix}/bin/ruby"]

  desc "Build autoconf (#{ruby.prefix}/bin/autoconf)"
  task :autoconf => ["#{ruby.prefix}/bin/autoconf"]

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

desc "Build all of the things (CONFIG=#{configname})"
task :build => ["build:openssl", "build:yaml", "build:ffi", "build:ruby"] do
  puts "All Done!"
end

namespace :purge do
  desc "Purge #{config.root}"
  task :root do
    rm_rf config.root
  end
  desc "Purge destroot/"
  task :destroot do
    rm_rf 'destroot/'
  end
end

package_builder = PackageBuilder.new(config)
desc "Package #{config.root} into #{config.package_name}"
task :package do
  package_builder.package
end
desc "Synthesize the packages"
task :synthesize do
  package_builder.synthesize
end
desc "Add extra packages to pkg/"
task :extras do
  package_builder.link_extra_packages
end

desc "Build crossfader package, which builds each config/crossfader_*.yaml config"
task :crossfader do
  rm_rf 'pkg'
  rm_rf 'destroot'
  rm_rf 'artifacts'

  # Build the crossfader runtime.  This is used for the crossfade toolset
  # itself so that end users don't accidentally delete the version the tools
  # require.
  sh %{git clean -fdx src/}
  sh %{git checkout HEAD src/}
  rm_rf '/opt/crossfader/runtime'

  sh %{rake CONFIG=crossfaderuntime build}
  # Install the crossfader gem and dependencies into the runtime build.
  install_crossfader
  # FIXME Link /opt/crossfader/bin/crossfader to /opt/crossfader/runtime/bin/crossfader

  # Package the runtime and installed tools.
  sh %{rake CONFIG=crossfaderuntime package}

  # Each Ruby Configuration
  Dir["config/crossfader_*.yaml"].sort.each do |crossfader_config_file|
    path = Pathname.new(crossfader_config_file)
    config_name = path.basename('.yaml')
    crossfader_config = Configuration.new(config_name)

    rm_rf 'destroot'
    sh %{git clean -fdx src/}
    sh %{git checkout HEAD src/}
    rm_rf crossfader_config.root
    sh %{rake CONFIG=#{config_name} build}
    sh %{rake CONFIG=#{config_name} package}
  end

  # Link extra packages (Command Line Tools, etc...)
  package_builder.link_extra_packages

  # Synthesize the packages
  package_builder.synthesize
end

desc "Reset the build tree"
task :reset do
  rm_rf "destroot"
  Dir["#{config.root}/*"].each do |d|
    rm_rf d
  end
  sh 'git clean -fdx src'
end

namespace :print do
  desc "Print the package name for this configuration"
  task :package_name do
    puts config.package_name
  end
end

namespace :temp do
  desc "Install the crossfader gem"
  task :install do
    install_crossfader
  end
end
