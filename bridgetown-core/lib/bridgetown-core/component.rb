# frozen_string_literal: true

module Bridgetown
  class Component
    extend Forwardable

    def_delegators :@view_context, :liquid_render, :partial

    # @return [Bridgetown::Site]
    attr_reader :site # will be nil unless you explicitly set a `@site` ivar

    # @return [Bridgetown::RubyTemplateView, Bridgetown::Component]
    attr_reader :view_context

    class << self
      attr_accessor :source_location

      def inherited(child)
        # Code cribbed from ViewComponent by GitHub:
        # Derive the source location of the component Ruby file from the call stack
        child.source_location = caller_locations(1, 10).reject do |l|
          l.label == "inherited"
        end[0].absolute_path

        super
      end

      # Return the appropriate template renderer for a given extension.
      # TODO: make this extensible
      #
      # @param ext [String] erb, slim, etc.
      def renderer_for_ext(ext, &block)
        @_tmpl ||= case ext.to_s
                   when "erb"
                     Tilt::ErubiTemplate.new(component_template_path,
                                             outvar: "@_erbout",
                                             bufval: "Bridgetown::OutputBuffer.new",
                                             engine_class: Bridgetown::ERBEngine,
                                             &block)
                   when "serb"
                     Tilt::SerbeaTemplate.new(component_template_path, &block)
                   when "slim" # requires bridgetown-slim
                     Slim::Template.new(component_template_path, &block)
                   when "haml" # requires bridgetown-haml
                     Tilt::HamlTemplate.new(component_template_path, &block)
                   else
                     raise NameError
                   end
      rescue NameError, LoadError
        raise "No component rendering engine could be found for .#{ext} templates"
      end

      # Find the first matching template path based on source location and extension.
      #
      # @return [String]
      def component_template_path
        @_tmpl_path ||= begin
          stripped_path = File.join(
            File.dirname(source_location),
            File.basename(source_location, ".*")
          )
          supported_template_extensions.each do |ext|
            test_path = "#{stripped_path}.#{ext}"
            break test_path if File.exist?(test_path)

            test_path = "#{stripped_path}.html.#{ext}"
            break test_path if File.exist?(test_path)
          end
        end

        unless @_tmpl_path.is_a?(String)
          raise "#{name}: no matching template could be found in #{File.dirname(source_location)}"
        end

        @_tmpl_path
      end

      # Read the template file.
      #
      # @return [String]
      def component_template_content
        @_tmpl_content ||= File.read(component_template_path)
      end

      # A list of extensions supported by the renderer
      # TODO: make this extensible
      #
      # @return [Array<String>]
      def supported_template_extensions
        %w(erb serb slim haml)
      end

      def path_for_errors
        component_template_path
      rescue RuntimeError
        source_location
      end
    end

    # If a content block was originally passed into via `render`, capture its output.
    #
    # @return [String] or nil
    def content
      @_content ||= (view_context.capture(self, &@_content_block) if @_content_block)
    end

    # Provide a render helper for evaluation within the component context.
    #
    # @param item [Object] a component supporting `render_in` or a partial name
    # @param options [Hash] passed to the `partial` helper if needed
    # @return [String]
    def render(item, options = {}, &block)
      if item.respond_to?(:render_in)
        result = ""
        capture do # this ensures no leaky interactions between BT<=>VC blocks
          result = item.render_in(self, &block)
        end
        result&.html_safe
      else
        partial(item, options, &block)&.html_safe
      end
    end

    # This is where the magic happens. Render the component within a view context.
    #
    # @param view_context [Bridgetown::RubyTemplateView]
    def render_in(view_context, &block)
      @view_context = view_context
      @_content_block = block

      if render?
        before_render
        template
      else
        ""
      end
    rescue StandardError => e
      Bridgetown.logger.error "Component error:",
                              "#{self.class} encountered an error while "\
                              "rendering `#{self.class.path_for_errors}'"
      raise e
    end

    # Subclasses can override this method to return a string from their own
    # template handling.
    def template
      call || _renderer.render(self)
    end

    # Typically not used but here as a compatibility nod toward ViewComponent.
    def call
      nil
    end

    # Subclasses can override this method to perform tasks before a render.
    def before_render; end

    # Subclasses can override this method to determine if the component should
    # be rendered based on initialized data or other logic.
    def render?
      true
    end

    def _renderer
      @_renderer ||= begin
        ext = File.extname(self.class.component_template_path).delete_prefix(".")
        self.class.renderer_for_ext(ext) { self.class.component_template_content }.tap do |rn|
          self.class.include(rn.is_a?(Tilt::SerbeaTemplate) ? Serbea::Helpers : ERBCapture)
        end
      end
    end

    def helpers
      @helpers ||= Bridgetown::RubyTemplateView::Helpers.new(
        self, view_context&.site || Bridgetown::Current.site
      )
    end

    def method_missing(method, *args, **kwargs, &block)
      if helpers.respond_to?(method.to_sym)
        helpers.send method.to_sym, *args, **kwargs, &block
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      helpers.respond_to?(method.to_sym, include_private) || super
    end
  end
end
