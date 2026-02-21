# frozen_string_literal: true

require_relative '../test_helper'

# Load resources (not auto-loaded by bootstrap like tools)
require_relative '../../fang/resources/guide_resource'

class GuideResourceTest < Fang::TestCase
  def test_index_content_lists_all_topics
    resource = Fang::Resources::GuideResource.new
    content = resource.content

    Fang::Resources::GuideResource::TOPICS.each_key do |topic|
      assert_includes content, "guide://#{topic}"
    end
  end

  def test_topic_resources_exist
    Fang::Resources::GuideResource::TOPICS.each_key do |topic|
      const_name = "Guide_#{topic.tr('-', '_').capitalize}"
      assert Fang::Resources::GuideResource.const_defined?(const_name),
        "Expected constant #{const_name} to be defined for topic '#{topic}'"
    end
  end

  def test_gmail_guide_content
    klass = Fang::Resources::GuideResource::Guide_Gmail
    resource = klass.new
    content = resource.content

    assert_includes content, 'gmail_search'
  end

  def test_missing_guide_file
    # Create a resource class pointing to a non-existent topic
    klass = Class.new(FastMcp::Resource) do
      uri 'guide://nonexistent'
      resource_name 'Guide: nonexistent'
      description 'Test missing guide'

      define_method(:content) do
        path = File.join(Fang::Resources::GuideResource::GUIDES_DIR, 'nonexistent.md')
        File.exist?(path) ? File.read(path) : "Guide not found: nonexistent"
      end
    end

    resource = klass.new
    assert_includes resource.content, 'Guide not found'
  end
end
