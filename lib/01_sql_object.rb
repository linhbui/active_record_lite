require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    results = DBConnection.execute2(<<-SQL)
    SELECT
    #{ table_name }.*
    FROM
    #{ table_name }    
    SQL
    results.first.map(&:to_sym)
  end

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

  def self.table_name=(table_name)
    @table_name = table_name.tableize
  end

  def self.table_name
    @table_name ||= self.name.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
     SELECT
     #{ table_name }.*
     FROM
     #{ table_name }
     SQL
   parse_all(results)
  end

  def self.parse_all(results)
    results.map do |attributes|
      self.new(attributes)
    end
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

  def initialize(params = {})
    params.each do |name, val|
      name = name.to_sym
      if self.class.columns.include?(name)
        self.send("#{ name }=", val)
      else
        raise "unknown attribute '#{name}'"
      end
    end
  end

  def attributes
    @attributes ||= {}
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
