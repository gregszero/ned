class AddLanguageToSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :skills, :language, :string, default: 'ruby', null: false
  end
end
