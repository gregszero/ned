# frozen_string_literal: true

require_relative '../test_helper'

class BuildCanvasToolTest < Fang::ToolTestCase
  def test_grid_layout_positions
    conv = Fang::Conversation.create!(title: 'Grid Test', source: 'web')
    ENV['CONVERSATION_ID'] = conv.id.to_s

    tool = Fang::Tools::BuildCanvasTool.new
    result = tool.call(
      title: 'Grid Dashboard',
      components: [
        { type: 'card', content: 'A' },
        { type: 'card', content: 'B' },
        { type: 'card', content: 'C' },
        { type: 'card', content: 'D' }
      ],
      layout: 'grid'
    )

    assert result[:success]
    assert_equal 4, result[:components_created]

    positions = result[:components]
    # Row 0: col 0 and col 1
    assert_equal 60, positions[0][:x]
    assert_equal 60, positions[0][:y]
    assert_equal 480, positions[1][:x]
    assert_equal 60, positions[1][:y]
    # Row 1: col 0 and col 1
    assert_equal 60, positions[2][:x]
    assert_equal 460, positions[2][:y]
    assert_equal 480, positions[3][:x]
    assert_equal 460, positions[3][:y]
  ensure
    ENV.delete('CONVERSATION_ID')
  end

  def test_stack_layout_positions
    conv = Fang::Conversation.create!(title: 'Stack Test', source: 'web')
    ENV['CONVERSATION_ID'] = conv.id.to_s

    tool = Fang::Tools::BuildCanvasTool.new
    result = tool.call(
      title: 'Stack Page',
      components: [
        { type: 'card', content: 'First' },
        { type: 'card', content: 'Second' },
        { type: 'card', content: 'Third' }
      ],
      layout: 'stack'
    )

    assert result[:success]
    assert_equal 3, result[:components_created]

    positions = result[:components]
    # All in single column at x=60, y spaced by 400
    positions.each { |p| assert_equal 60, p[:x] }
    assert_equal 60, positions[0][:y]
    assert_equal 460, positions[1][:y]
    assert_equal 860, positions[2][:y]
  ensure
    ENV.delete('CONVERSATION_ID')
  end

  def test_freeform_layout_passes_coordinates
    conv = Fang::Conversation.create!(title: 'Freeform Test', source: 'web')
    ENV['CONVERSATION_ID'] = conv.id.to_s

    tool = Fang::Tools::BuildCanvasTool.new
    result = tool.call(
      title: 'Freeform Page',
      components: [
        { type: 'card', content: 'A', x: 100, y: 200 },
        { type: 'card', content: 'B', x: 500, y: 300 }
      ],
      layout: 'freeform'
    )

    assert result[:success]
    assert_equal 100.0, result[:components][0][:x]
    assert_equal 200.0, result[:components][0][:y]
    assert_equal 500.0, result[:components][1][:x]
    assert_equal 300.0, result[:components][1][:y]
  ensure
    ENV.delete('CONVERSATION_ID')
  end

  def test_creates_page_when_none_exists
    conv = Fang::Conversation.create!(title: 'No Page', source: 'web')
    assert_nil conv.page
    ENV['CONVERSATION_ID'] = conv.id.to_s

    tool = Fang::Tools::BuildCanvasTool.new
    result = tool.call(
      title: 'New Page',
      components: [{ type: 'card', content: 'Hello' }]
    )

    assert result[:success]
    page = Fang::Page.find(result[:page_id])
    assert_equal 'New Page', page.title
    assert_equal 'published', page.status
    assert_equal page.id, conv.reload.page_id
  ensure
    ENV.delete('CONVERSATION_ID')
  end

  def test_reuses_existing_page
    page = Fang::Page.create!(title: 'Existing', content: '', status: 'published', published_at: Time.current)
    conv = Fang::Conversation.create!(title: 'Has Page', source: 'web', page: page)
    ENV['CONVERSATION_ID'] = conv.id.to_s

    tool = Fang::Tools::BuildCanvasTool.new
    result = tool.call(
      title: 'Ignored Title',
      components: [{ type: 'card', content: 'Added' }]
    )

    assert result[:success]
    assert_equal page.id, result[:page_id]
  ensure
    ENV.delete('CONVERSATION_ID')
  end

  def test_default_component_type_is_card
    conv = Fang::Conversation.create!(title: 'Default Type', source: 'web')
    ENV['CONVERSATION_ID'] = conv.id.to_s

    tool = Fang::Tools::BuildCanvasTool.new
    result = tool.call(
      title: 'Defaults',
      components: [{ content: 'No type specified' }]
    )

    assert result[:success]
    assert_equal 'card', result[:components][0][:type]
  ensure
    ENV.delete('CONVERSATION_ID')
  end

  def test_component_count_matches
    conv = Fang::Conversation.create!(title: 'Count Test', source: 'web')
    ENV['CONVERSATION_ID'] = conv.id.to_s

    tool = Fang::Tools::BuildCanvasTool.new
    result = tool.call(
      title: 'Count Page',
      components: [
        { content: 'One' },
        { content: 'Two' },
        { content: 'Three' }
      ]
    )

    assert result[:success]
    assert_equal 3, result[:components_created]
    assert_equal 3, result[:components].size
  ensure
    ENV.delete('CONVERSATION_ID')
  end
end
