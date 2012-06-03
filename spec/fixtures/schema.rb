ActiveRecord::Schema.define do
  create_table "tags", :force => true do |t|
    t.string :name
    t.timestamps
  end

  create_table "items", :force => true do |t|
    t.string :value
    t.integer_array :tag_ids,  :default => [1, 2]
    t.string_array :tag_names, :default => %w{as so}
    t.text :for_yaml
  end

  create_table "bulks", :force => true do |t|
    t.string :value, :default => "'"
    t.integer_array :ints,  :default => [1, 2]
    t.string_array :strings, :default => %w{as so}
    t.timestamp_array :times,  :default => %w{2010-01-01 2010-02-01}
    t.float_array :floats,     :default => [1.0, 1.2]
    t.decimal_array :decimals, :default => [1.0, 1.2]
    t.text_array :texts, :default => [nil, 'Text', 'NULL', 'Text with nil', 'Text with , nil, !"\\', 'nil']
  end

  create_table "unrelateds", :force => true do |t|
    t.text :for_yaml
    t.text :for_custom_serialize
  end
end
