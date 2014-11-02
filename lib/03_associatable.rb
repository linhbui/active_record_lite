require_relative '02_searchable'
require 'active_support/inflector'

class AssocOptions
  attr_accessor :foreign_key, :class_name, :primary_key

  # Take a class name and return the class object 
  def model_class
    @class_name.constantize
  end
  
  # Return the name of the table
  def table_name
    model_class.table_name
  end
end

# Provide default values to the important attributes: foreign_key, class_name,
# primary_key
class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    # Set the default values
    # A common belongs_to example: many posts belongs to a user
    # belongs_to(
    #   :user, 
    #   class_name: 'User', 
    #   foreign_key: :user_id,
    #   primary_key: :id
    # )
    default_values = {
      foreign_key: "#{ name }_id".to_sym,
      class_name: name.to_s.camelcase,
      primary_key: :id
    }
    
    # If the values of foreign_key, primary_key and class_name are provided in 
    # the options hash then take them, else take the values of the default hash
    default_values.keys.each do |key|
      self.send("#{key}=", options[key] || default_values[key])
    end
  end
end

# Provide default values to the important attributes: foreign_key, class_name,
# primary_key
class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    # Set the default values
    # A common has_many example: a user has many posts
    # has_many(
    #   :posts, 
    #   class_name: 'Post', 
    #   foreign_key: :user_id,
    #   primary_key: :id
    # )
    default_values = {
      foreign_key: "#{ self_class_name.underscore }_id".to_sym,
      class_name: name.to_s.singularize.camelcase,
      primary_key: :id
    }
    
    # If the values of foreign_key, primary_key and class_name are provided in 
    # the options hash then take them, else take the values of the default hash
    default_values.keys.each do |key|
      self.send("#{key}=", options[key] || default_values[key])
    end
  end
end

module Associatable
  def belongs_to(name, options = {})
    self.assoc_options[name] = BelongsToOptions.new(name, options)

    define_method(name) do
      options = self.class.assoc_options[name]
      # get the value of the foreign key
      key_val = self.send(options.foreign_key)
      # Get the target model class then select the models where the
      # primary_key column is equal to the foreign key value
      options
        .model_class 
        .where(options.primary_key => key_val)
        .first
    end
  end

  def has_many(name, options = {})
    self.assoc_options[name] =
      HasManyOptions.new(name, self.name, options)

    define_method(name) do
      options = self.class.assoc_options[name]
      # get the value of the foreign key
      key_val = self.send(options.primary_key)
      # Get the target model class then select the models where the
      # foreign_key column is equal to the primary key value
      options
        .model_class
        .where(options.foreign_key => key_val)
    end
  end

  # Especially helpful for complex queries like has_many_through etc
  def assoc_options
    @assoc_options ||= {}
    @assoc_options
  end
end

class SQLObject
  extend Associatable
end
