require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  
  # Set the name of the table
  def self.table_name=(table_name)
    @table_name = table_name
  end
  
  # Get the name of the table from the name of the class
  def self.table_name
    @table_name ||= self.name.tableize
  end
  
  # Return an array with the names of table columns
  def self.columns
    return @columns if @columns
    results = DBConnection.execute2(<<-SQL)
    SELECT
    #{ table_name }.*
    FROM
    #{ table_name }    
    SQL
    @columns = results.first.map(&:to_sym)
  end
  
  # Set the attributes hash
  def attributes
    @attributes ||= {}
  end
  
  # Automatically adds getter and setter methods for each columns
  # Finalize will be called at the end of the subclass definition to
  # add the getters/setters.
  def self.finalize!
    self.columns.each do |col|
      define_method "#{col}" do
        self.attributes[col]
      end
      
      define_method "#{col}=" do |val|
        self.attributes[col] = val
      end
    end
  end
  
  def initialize(params = {})
    params.each do |attribute, val|
      attribute = attribute.to_sym
      if self.class.columns.include?(attribute)
        self.send("#{ attribute }=", val)
      else
        raise "unknown attribute '#{attribute}'"
      end
    end
  end
  
  # fetch all the records from the database
  def self.all
    results = DBConnection.execute(<<-SQL)
     SELECT
     #{ table_name }.*
     FROM
     #{ table_name }
     SQL
  # Note: Calling DBConnection will return an array of raw Hash objects 
  # where the keys are column names and the values are column values.
  # Hence, we need to parse the results   
   parse_all(results)
  end
  
  
  def self.parse_all(results)
    results.map { |attributes| self.new(attributes) }
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
    SELECT
      #{ table_name }.*
    FROM
      #{ table_name }
    WHERE
      #{ table_name }.id = ?
    SQL
    parse_all(results).first
  end

  def attribute_values
    self.class.columns.map { |attr| self.send(attr) }
  end

  def insert
    p cols = self.class.columns
    p attribute_values
    col_names = cols.map(&:to_s).join(", ")
    question_marks = (["?"] * cols.count).join(", ")
    DBConnection.execute(<<-SQL, *attribute_values)
    INSERT INTO
      #{ self.class.table_name } (#{ col_names })
    VALUES
      (#{ question_marks })
    SQL
    
    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns
      .map { |attr| "#{ attr } = ?" }.join(", ")
    DBConnection.execute(<<-SQL, *attribute_values, id)
    UPDATE
      #{ self.class.table_name } 
    SET  
      #{ set_line }
    WHERE
      id = ?
    SQL
  end

  def save
    id.nil? ? insert : update
  end
end
