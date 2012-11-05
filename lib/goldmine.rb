require "rubygems"
require "set"

# Goldmine brings pivot table behavior to Arrays.
module Goldmine

  # Extends Array with a pivot method.
  module ArrayMiner

    # Pivots the Array into a Hash of mined data.
    # Think of it as creating a pivot table or perhaps an OLAP cube.
    #
    # @example Simple pivot
    #   list = [1,2,3,4,5,6,7,8,9]
    #   data = list.pivot { |i| i < 5 }
    #
    #   # resulting data
    #   # {
    #   #   true  => [1, 2, 3, 4],
    #   #   false => [5, 6, 7, 8, 9]
    #   # }
    #
    # @example Named pivot
    #   list = [1,2,3,4,5,6,7,8,9]
    #   data = list.pivot("less than 5") { |i| i < 5 }
    #
    #   # resulting data
    #   # {
    #   #   { "less than 5" => true } => [1, 2, 3, 4],
    #   #   { "less than 5" => false } => [5, 6, 7, 8, 9]
    #   # }
    #
    # @example Chained pivot
    #   list = [1,2,3,4,5,6,7,8,9]
    #   data = list.pivot { |i| i < 5 }.pivot { |i| i % 2 == 0 }
    #
    #   # resulting data
    #   {
    #     [true, false]  => [1, 3],
    #     [true, true]   => [2, 4],
    #     [false, false] => [5, 7, 9],
    #     [false, true]  => [6, 8]
    #   }
    #
    # @param [String] name The named of the pivot.
    # @yield [Object] Yields once for each item in the Array
    # @return [Hash] The pivoted Hash of data.
    def pivot(name=nil, &block)
      reduce({}) do |memo, item|
        value = yield(item)

        if value.is_a?(Array)
          if value.empty?
            memo.assign_mined(name, nil, item)
          else
            value.each { |v| memo.assign_mined(name, v, item) }
          end
        else
          memo.assign_mined(name, value, item)
        end

        memo.goldmine = true
        memo
      end
    end
  end

  # Extends Hash with a pivot method.
  module HashMiner

    attr_accessor :goldmine

    # Further pivots the Hash into mined data.
    # This method is what enables the pivot method chaining.
    #
    # @example Chained pivot
    #   list = [1,2,3,4,5,6,7,8,9]
    #   data = list.pivot { |i| i < 5 }.pivot { |i| i % 2 == 0 }
    #
    #   # resulting data
    #   {
    #     [true, false]  => [1, 3],
    #     [true, true]   => [2, 4],
    #     [false, false] => [5, 7, 9],
    #     [false, true]  => [6, 8]
    #   }
    #
    # @note This method should not be called directly. Call Array#pivot instead.
    #
    # @param [String] name The named of the pivot.
    # @yield [Object] Yields once for each item in the Array
    # @return [Hash] The pivoted Hash of data.
    def pivot(name=nil, &block)
      return self unless goldmine

      reduce({}) do |memo, item|
        key = item.first
        value = item.last
        value.pivot(name, &block).each do |k, v|
          if key.is_a? Hash
            k = { block.to_s => k } unless k.is_a?(Hash)
            new_key = key.merge(k)
          else
            new_key = [key, k].flatten
          end
          memo[new_key] = v
        end
        memo.goldmine = true
        memo
      end
    end

    # Re-arranges the output of a chained pivot call into a 2 dimensional table.
    # This call makes only sense when applied to hash that is the result of 2 chained pivot calls.
    # The values of the first
    # pivot are displayed in the columns, those of the second pivot call in the rows. The cells contain the result
    # of the blocked given to the function. If no block is given, the whole array goes into the cells.
    # Each row and column also displays a total, and the lower right of the table has the total of the totals.
    # The function used to calculate the totals also use the block given to the function.
    # If no block is given, the count is displayed for the totals.
    #
    # @example
    #       list = [1,2,3,4,5,6,7,8,9]
    #       data = list.pivot("less than 5") { |i| i < 5 }.pivot("divisible by 2") { |i| i % 2 == 0 }
    #       data is now {
    #          { "less than 5" => true, "divisible by 2" => false } => [1, 3],
    #          { "less than 5" => true, "divisible by 2" => true}   => [2, 4],
    #          { "less than 5" => false, "divisible by 2" => false} => [5, 7, 9],
    #          { "less than 5" => false, "divisible by 2" => true}  => [6, 8]
    #       }
    #       data.to_2d("count"){|i| i.size} results in:
    #       [ ["divisible by 2/less than 5", "false", "true", "total count"],
    #         ["false", 3, 2, 5],
    #         ["true",  2, 2, 4],
    #         ["total count", 5, 4, 9]
    #       ]
    #
    # @param [String] name Name of the function applied to the values within the cell (which is given by a block).
    #                       If e.g. "count" is given, "total count" will be displayed in the row and column totals.
    # @yield [Object] Yields once for each item in the Array
    # @return [Array[Array]] a 2 dimensional array containing the pivot table
    def to_2d(name, &block)
      return self unless (goldmine && self.keys.first.is_a?(Hash) && self.keys.first.size == 2)

      col_headers = SortedSet.new
      row_headers = SortedSet.new
      cells= {}
      self.each do |key, value|
        col_name =  key.first.last.to_sym
        row_name = key.to_a.last.last.to_s
        col_headers << col_name
        row_headers << row_name
        cell = block_given? ? yield(value) : value
        if cells[row_name]
          cells[row_name][col_name] = cell
        else
          cells[row_name] = {col_name => cell}
        end
      end
      table = [["#{self.first.first.to_a.last.first}/#{self.first.first.first.first}"] + col_headers.to_a.map(&:to_s) << "total #{name}".strip]
      col_totals = {}
      row_headers.each do |row_name|
        row = [row_name]
        col_headers.each do |col_name|
          row << cells[row_name][col_name]
        end
        row_values = row[1..row.size]
        #total = block_given? ? yield(row_values) : row_values.inject(0){|memo, item| memo+=item.size; memo}
        total = row_values.inject(0){|memo, item| memo+=item.to_i; memo}
        cells[row_name][:total] = total
        row << total
        table << row
      end
      total_row = ["total #{name}".strip]
      (col_headers << :total).each do |col_name|
        col = cells.map{ |row_name, row| row[col_name] }
        #total = block_given? ?
        #  yield(col) :
        #  col.inject(0){|memo, item| memo+=item.size; memo}
        total_row << col.inject(0){|memo, item| memo+=item.to_i; memo}
      end
      table << total_row
    end

    # Assigns a key/value pair to the Hash.
    # @param [String] name The name of a pivot (can be null).
    # @param [Object] key The key to use.
    # @param [Object] value The value to assign
    # @return [Object] The result of the assignment.
    def assign_mined(name, key, value)
      goldmine_key = goldmine_key(name, key)
      self[goldmine_key] ||= []
      self[goldmine_key] << value
    end

    # Creates a key for a pivot-name/key combo.
    # @param [String] name The name of a pivot (can be null).
    # @param [Object] key The key to use.
    # @return [Object] The constructed key.
    def goldmine_key(name, key)
      goldmine_key = { name => key } if name
      goldmine_key ||= key
    end

  end
end

::Array.send(:include, Goldmine::ArrayMiner)
::Hash.send(:include, Goldmine::HashMiner)
