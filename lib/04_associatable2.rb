require_relative '03_associatable'

module Associatable
  # has_one_through combines two belongs_to methods.
  # Example: each supplier has one account, and each account is associated 
  # with one account history
  # class Supplier < SQLObject
  #   belongs_to :account
  #   has_one_through :account_history, :human, :house
  #
  #   finalize!
  # end
  # This method make a join query that uses and combines the options 
  # (table_name, foreign_key, primary_key) of the two constituent associations.
  # This requires us to store the options of a belongs_to association so that
  # has_one_through can latter reference these to build a query.
  
  def has_one_through(name, through_name, source_name)
    define_method(name) do
      # Set the options for :through and :source
      through_options = self.class.assoc_options[through_name]
      source_options =
        through_options.model_class.assoc_options[source_name]
      
      # Set the table_name, foreign_key, primary_key etc for :through
      through_table = through_options.table_name
      through_pk = through_options.primary_key
      through_fk = through_options.foreign_key
      
      # Set the table_name, foreign_key, primary_key etc for :source
      source_table = source_options.table_name
      source_pk = source_options.primary_key
      source_fk = source_options.foreign_key

      # The value to be searched
      key_val = self.send(through_fk)
      
      # Finally, the query...
      results = DBConnection.execute(<<-SQL, key_val)
        SELECT
          #{source_table}.*
        FROM
          #{through_table}
        JOIN
          #{source_table}
        ON
          #{through_table}.#{source_fk} = #{source_table}.#{source_pk}
        WHERE
          #{through_table}.#{through_pk} = ?
      SQL
      
      # Parse the results
      source_options.model_class.parse_all(results).first
    end
  end
end
