module Sass
  module Tree
    # A static node that is the root node of the Sass document.
    class RootNode < Node
      # The Sass template from which this node was created
      #
      # @param template [String]
      attr_reader :template

      attr_reader :source_mapping

      # @param template [String] The Sass template from which this node was created
      def initialize(template)
        super()
        @template = template
      end

      # Runs the dynamic Sass code *and* computes the CSS for the tree.
      # @see #to_s
      def render
        pre_css_visitors_result.css
      end

      # Runs the dynamic Sass code *and* computes the CSS for the tree along with the sourcemap.
      # @see #render
      def render_with_sourcemap
        pre_css_visitors_result.css_with_sourcemap
      end

      private

      def pre_css_visitors_result
        Visitors::CheckNesting.visit(self)
        result = Visitors::Perform.visit(self)
        Visitors::CheckNesting.visit(result) # Check again to validate mixins
        result, extends = Visitors::Cssize.visit(result)
        Visitors::Extend.visit(result, extends)
        result
      end
    end
  end
end
