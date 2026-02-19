# frozen_string_literal: true

require_relative '../test_helper'

class PageTest < Fang::TestCase
  def test_title_required
    page = Fang::Page.new(content: '', status: 'draft')
    refute page.valid?
    assert page.errors[:title].any?
  end

  def test_valid_statuses
    %w[draft published archived].each do |status|
      page = Fang::Page.new(title: "Test #{status}", content: '', status: status)
      assert page.valid?, "Expected status '#{status}' to be valid"
    end
  end

  def test_invalid_status
    page = Fang::Page.new(title: 'Test', content: '', status: 'deleted')
    refute page.valid?
  end

  def test_slug_generation
    page = Fang::Page.create!(title: 'My Cool Page', content: '', status: 'draft')
    assert_equal 'my-cool-page', page.slug
  end

  def test_slug_uniqueness
    Fang::Page.create!(title: 'Same Title', content: '', status: 'draft')
    page2 = Fang::Page.create!(title: 'Same Title', content: '', status: 'draft')
    assert_equal 'same-title-1', page2.slug
  end

  def test_publish!
    page = Fang::Page.create!(title: 'Draft Page', content: '', status: 'draft')
    page.publish!

    assert page.published?
    refute_nil page.published_at
  end

  def test_archive!
    page = Fang::Page.create!(title: 'Published Page', content: '', status: 'published', published_at: Time.current)
    page.archive!

    assert page.archived?
  end

  def test_content_max_length
    page = Fang::Page.new(title: 'Test', content: 'x' * 1_000_001, status: 'draft')
    refute page.valid?
  end
end
