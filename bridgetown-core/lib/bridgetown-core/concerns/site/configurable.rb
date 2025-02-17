# frozen_string_literal: true

class Bridgetown::Site
  module Configurable
    # Set the site's configuration. This handles side-effects caused by
    #   changing values in the configuration.
    #
    # @param config [Configuration]
    #   An instance of {Configuration},
    #   containing the new configuration.
    #
    # @return [Configuration]
    #   The processed instance of {Configuration}
    def config=(config)
      @config = config.clone

      # Source and destination may not be changed after the site has been created.
      @root_dir        = File.expand_path(config["root_dir"]).freeze
      @source          = File.expand_path(config["source"]).freeze
      @dest            = File.expand_path(config["destination"]).freeze

      configure_cache
      configure_component_paths
      configure_file_read_opts

      self.permalink_style = (config["permalink"] || "pretty").to_sym

      @config
    end

    def uses_resource?
      config[:content_engine] == "resource"
    end

    # Returns a base path from which the site is served (aka `/cool-site`) or
    # `/` if served from root.
    #
    # @param strip_slash_only [Boolean] set to true if you wish "/" to be returned as ""
    # @return [String]
    def base_path(strip_slash_only: false)
      (config[:base_path] || config[:baseurl]).then do |path|
        strip_slash_only ? path.to_s.sub(%r{^/$}, "") : path
      end
    end

    def baseurl
      Bridgetown::Deprecator.deprecation_message "Site#baseurl is now Site#base_path"
      base_path(strip_slash_only: true).presence
    end

    def defaults_reader
      @defaults_reader ||= Bridgetown::DefaultsReader.new(self)
    end

    # Returns the current instance of {FrontmatterDefaults} or
    #   creates a new instance {FrontmatterDefaults} if it doesn't already exist.
    #
    # @return [FrontmatterDefaults]
    #   Returns an instance of {FrontmatterDefaults}
    def frontmatter_defaults
      @frontmatter_defaults ||= Bridgetown::FrontmatterDefaults.new(self)
    end

    # Returns the current instance of {Publisher} or creates a new instance of
    #   {Publisher} if one doesn't exist.
    #
    # @return [Publisher] Returns an instance of {Publisher}
    def publisher
      @publisher ||= Bridgetown::Publisher.new(self)
    end

    # Prefix a path or paths with the {#root_dir} directory.
    #
    # @see Bridgetown.sanitized_path
    # @param paths [Array<String>]
    #   An array of paths to prefix with the root_dir directory using the
    #   {Bridgetown.sanitized_path} method.
    #
    # @return [Array<String>] Return an array of updated paths if multiple paths given.
    def in_root_dir(*paths)
      paths.reduce(root_dir) do |base, path|
        Bridgetown.sanitized_path(base, path.to_s)
      end
    end

    # Prefix a path or paths with the {#source} directory.
    #
    # @see Bridgetown.sanitized_path
    # @param paths [Array<String>]
    #   An array of paths to prefix with the source directory using the
    #   {Bridgetown.sanitized_path} method.
    # @return [Array<String>] Return an array of updated paths if multiple paths given.
    def in_source_dir(*paths)
      # TODO: this operation is expensive across thousands of iterations. Look for ways
      # to workaround use of this wherever possible...
      paths.reduce(source) do |base, path|
        Bridgetown.sanitized_path(base, path.to_s)
      end
    end

    # Prefix a path or paths with the {#dest} directory.
    #
    # @see Bridgetown.sanitized_path
    # @param paths [Array<String>]
    #   An array of paths to prefix with the destination directory using the
    #   {Bridgetown.sanitized_path} method.
    #
    # @return [Array<String>] Return an array of updated paths if multiple paths given.
    def in_dest_dir(*paths)
      paths.reduce(dest) do |base, path|
        Bridgetown.sanitized_path(base, path)
      end
    end

    # Prefix a path or paths with the {#cache_dir} directory.
    #
    # @see Bridgetown.sanitized_path
    # @param paths [Array<String>]
    #   An array of paths to prefix with the {#cache_dir} directory using the
    #   {Bridgetown.sanitized_path} method.
    #
    # @return [Array<String>] Return an array of updated paths if multiple paths given.
    def in_cache_dir(*paths)
      paths.reduce(cache_dir) do |base, path|
        Bridgetown.sanitized_path(base, path)
      end
    end

    # The full path to the directory that houses all the registered collections
    #  for the current site.
    #
    #  If `@collections_path` is specified use its value.
    #
    #  If `@collections` is not specified and `config["collections_dir"]` is
    #  specified, prepend it with {#source} and assign it to
    #  {#collections_path}.
    #
    #  If `@collections` is not specified and `config["collections_dir"]` is not
    #  specified, assign {#source} to `@collections_path`
    #
    # @return [String] Returns the full path to the collections directory
    # @see #config
    # @see #source
    # @see #collections_path
    # @see #in_source_dir
    def collections_path
      dir_str = config["collections_dir"]
      @collections_path ||= dir_str.empty? ? source : in_source_dir(dir_str)
    end

    def frontend_bundling_path
      in_root_dir(".bridgetown-cache", "frontend-bundling")
    end

    private

    # Disable Marshaling cache to disk in Safe Mode
    def configure_cache
      @cache_dir = in_root_dir(config["cache_dir"]).freeze
      Bridgetown::Cache.cache_dir = File.join(cache_dir, "Bridgetown/Cache")
      Bridgetown::Cache.disable_disk_cache! if config["disable_disk_cache"]
    end

    def configure_component_paths # rubocop:todo Metrics/AbcSize
      # Loop through plugins paths first
      plugin_components_load_paths = Bridgetown::PluginManager.source_manifests
        .filter_map(&:components)

      local_components_load_paths = config["components_dir"].then do |dir|
        dir.is_a?(Array) ? dir : [dir]
      end
      local_components_load_paths.map! do |dir|
        if !!(dir =~ %r!^\.\.?/!)
          # allow ./dir or ../../dir type options
          File.expand_path(dir.to_s, root_dir)
        else
          in_source_dir(dir.to_s)
        end
      end

      config.components_load_paths = plugin_components_load_paths + local_components_load_paths
      # Because "first constant wins" in Zeitwerk, we need to load the local
      # source components _before_ we load any from plugins
      config.autoload_paths += config.components_load_paths.reverse
    end

    def configure_file_read_opts
      self.file_read_opts = {}
      file_read_opts[:encoding] = config["encoding"] if config["encoding"]
      self.file_read_opts = Bridgetown::Utils.merged_file_read_opts(self, {})
    end
  end
end
