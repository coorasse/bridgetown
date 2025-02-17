# frozen_string_literal: true

require "helper"

class TestLocales < BridgetownUnitTest
  context "similar pages in different locales" do
    setup do
      @site = resources_site
      @site.process
      # @type [Bridgetown::Resource::Base]
      @english_resource = @site.collections.pages.resources.find do |page|
        page.relative_path.to_s == "_pages/second-level-page.en.md"
      end
      @french_resource = @site.collections.pages.resources.find do |page|
        page.relative_path.to_s == "_pages/second-level-page.fr.md"
      end
    end

    should "have the correct permalink and locale in English" do
      assert_equal "/second-level-page/", @english_resource.relative_url
      assert_includes @english_resource.output, "<p>Locale: en</p>"
    end

    should "have the correct permalink and locale in French" do
      assert_equal "/fr/second-level-page/", @french_resource.relative_url
      assert_includes @french_resource.output, "<p>C’est <strong>bien</strong>.</p>\n\n<p>Locale: fr</p>"

      assert_includes @french_resource.output, <<-HTML
    <li>I'm a Second Level Page: /second-level-page/</li>
    <li>I'm a Second Level Page in French: /fr/second-level-page/</li>
      HTML
    end
  end

  context "one page which is generated into multiple locales" do
    setup do
      @site = resources_site
      @site.process
      # @type [Bridgetown::Resource::Base]
      @resources = @site.collections.pages.resources.select do |page|
        page.relative_path.to_s == "_pages/multi-page.md"
      end
      @english_resource = @resources.find { |page| page.data.locale == :en }
      @french_resource = @resources.find { |page| page.data.locale == :fr }
    end

    should "have the correct permalink and locale in English" do
      assert_equal "/multi-page/", @english_resource.relative_url
      assert_includes @english_resource.output, 'lang="en"'
      assert_includes @english_resource.output, "<title>Multi-locale page</title>"
      assert_includes @english_resource.output, "<p>English: Multi-locale page</p>"
    end

    should "have the correct permalink and locale in French" do
      assert_equal "/fr/multi-page/", @french_resource.relative_url
      assert_includes @french_resource.output, 'lang="fr"'
      assert_includes @french_resource.output, "<title>Sur mesure</title>"
      assert_includes @french_resource.output, "<p>French: Sur mesure</p>"

      assert_includes @french_resource.output, <<-HTML
    <li>Multi-locale page: /multi-page/</li>
    <li>Sur mesure: /fr/multi-page/</li>
      HTML
    end
  end

  context "locales and a base_path combined" do
    setup do
      @site = resources_site(base_path: "/basefolder")
      @site.process
      # @type [Bridgetown::Resource::Base]
      @resources = @site.collections.pages.resources.select do |page|
        page.relative_path.to_s == "_pages/multi-page.md"
      end
      @english_resource = @resources.find { |page| page.data.locale == :en }
      @french_resource = @resources.find { |page| page.data.locale == :fr }
    end

    should "have the correct permalink and locale in English" do
      assert_equal "/basefolder/multi-page/", @english_resource.relative_url
      assert_includes @english_resource.output, 'lang="en"'
      assert_includes @english_resource.output, "<title>Multi-locale page</title>"
      assert_includes @english_resource.output, "<p>English: Multi-locale page</p>"
    end

    should "have the correct permalink and locale in French" do
      assert_equal "/basefolder/fr/multi-page/", @french_resource.relative_url
      assert_includes @french_resource.output, 'lang="fr"'
      assert_includes @french_resource.output, "<title>Sur mesure</title>"
      assert_includes @french_resource.output, "<p>French: Sur mesure</p>"

      assert_includes @french_resource.output, <<-HTML
    <li>Multi-locale page: /basefolder/multi-page/</li>
    <li>Sur mesure: /basefolder/fr/multi-page/</li>
      HTML
    end
  end
end
