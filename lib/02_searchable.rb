require_relative 'db_connection'
require_relative '01_sql_object'

# Add the ability to search using where
module Searchable
  def where(params)
    where_line = params.keys.map { |attribute| "#{attribute.to_s} = ?" }
                            .join(" AND ") 
    results = DBConnection.execute(<<-SQL, params.values)
    SELECT
      #{ table_name }.*
    FROM
      #{ table_name }
    WHERE
      #{ where_line }
    SQL
    parse_all(results)
  end
end

class SQLObject
  extend Searchable
end
