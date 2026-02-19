# frozen_string_literal: true

require_relative '../test_helper'

class HasStatusTest < Fang::TestCase
  def test_status_predicates
    page = Fang::Page.create!(title: 'Test', content: '', status: 'draft')
    assert page.draft?
    refute page.published?
    refute page.archived?
  end

  def test_status_scopes
    Fang::Page.create!(title: 'Draft', content: '', status: 'draft')
    Fang::Page.create!(title: 'Published', content: '', status: 'published', published_at: Time.current)
    Fang::Page.create!(title: 'Archived', content: '', status: 'archived')

    assert_equal 1, Fang::Page.draft.count
    assert_equal 1, Fang::Page.published.count
    assert_equal 1, Fang::Page.archived.count
  end
end
