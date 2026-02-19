# frozen_string_literal: true

require_relative '../test_helper'

class SkillRecordTest < Fang::TestCase
  def test_validations
    sr = Fang::SkillRecord.new
    refute sr.valid?
    assert sr.errors[:name].any?
    assert sr.errors[:file_path].any?
  end

  def test_name_uniqueness
    Fang::SkillRecord.create!(name: 'test_skill', file_path: 'skills/test.rb')
    sr = Fang::SkillRecord.new(name: 'test_skill', file_path: 'skills/test2.rb')
    refute sr.valid?
  end

  def test_set_defaults
    sr = Fang::SkillRecord.create!(name: 'my_skill', file_path: 'skills/my_skill.rb')
    assert_equal({}, sr.metadata)
    assert_equal 0, sr.usage_count
  end

  def test_derive_class_name
    sr = Fang::SkillRecord.create!(name: 'send_email', file_path: 'skills/send_email.rb')
    assert_equal 'SendEmail', sr.class_name
  end

  def test_derive_class_name_skips_python
    sr = Fang::SkillRecord.create!(name: 'py_skill', file_path: 'skills/py_skill.py', language: 'python')
    assert_nil sr.class_name
  end

  def test_increment_usage!
    sr = Fang::SkillRecord.create!(name: 'test', file_path: 'skills/test.rb')
    sr.increment_usage!
    assert_equal 1, sr.reload.usage_count
  end

  def test_full_file_path
    sr = Fang::SkillRecord.new(file_path: 'skills/test.rb')
    expected = File.join(Fang.root, 'skills/test.rb')
    assert_equal expected, sr.full_file_path
  end

  def test_by_usage_scope
    sr1 = Fang::SkillRecord.create!(name: 'low', file_path: 'skills/low.rb', usage_count: 1)
    sr2 = Fang::SkillRecord.create!(name: 'high', file_path: 'skills/high.rb', usage_count: 10)

    result = Fang::SkillRecord.by_usage
    assert_equal sr2.id, result.first.id
  end
end
