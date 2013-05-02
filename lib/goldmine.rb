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
    # pivot are displayed in the columns, those of the second pivot call in the rows.
    # The function takes a hash with 3 blocks as an optional argument.
    # If a block named 'cell' is given, the cells of the cross table contain the result returned by this block.
    # If no block is given, the whole array goes into the cells.
    # Each row and column also displays a sum of the cell values as 'total',
    # and the lower right of the table has the total of the totals.
    # The function used to calculate the totals use the block passed to the function in the block hash specified by
    # key row_total and col_total, respectively.
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
    #       cell_block = ->(items){items.size}
    #       count = ->(items){items.size}
    #       count_even  = ->(items){items.size % 2 == 0}
    #       data.to_2d("count", {cell: cell_block, row_total: count, col_total: count_even} ) results in:
    #       [ ["divisible by 2/less than 5", "false", "true", "total count"],
    #         ["false", 3, 2, 2],
    #         ["true",  2, 2, 2],
    #         ["total count", false, true, true]
    #       ]
    #
    # @param [String] name Name of the function applied to the values within the cell (which is given by a block).
    #                       If e.g. "count" is given, "total count" will be displayed in the row and column totals.
    # @yield [Object] Yields once for each item in the Array
    # @return [Array[Array]] a 2 dimensional array containing the pivot table
    def to_2d(name, blocks = {})
      return self unless (goldmine && self.keys.first.is_a?(Hash) && self.keys.first.size == 2)

      col_headers, row_headers, cells = build_crosstab(blocks[:cell])

      table = build_header_row(col_headers, name)
      row_headers.each do |row_name|
        cells[row_name]["total"], row = build_row(row_name, cells, col_headers, blocks[:row_total])
        table << row
      end
      table << build_total_row(name, col_headers, cells, blocks[:col_total])
    end

    def build_crosstab(cell_block)
      col_headers = SortedSet.new
      row_headers = SortedSet.new
      cells= {}
      self.each do |key, value|
        col_name =  key.first.last.to_s
        row_name = key.to_a.last.last.to_s
        col_headers << col_name
        row_headers << row_name
        cell = cell_block.nil? ? value : cell_block.call(value)
        if cells[row_name]
          cells[row_name][col_name] = cell
        else
          cells[row_name] = {col_name => cell}
        end
      end
      [col_headers, row_headers, cells]
    end

    def build_header_row(col_headers, name)
      [top_left_label + col_headers.to_a.map(&:to_s) << "total #{name}".strip]
    end

    def top_left_label
       ["#{self.first.first.to_a.last.first}/#{self.first.first.first.first}"]
    end

    def build_row(row_name, cells, col_headers, row_total_block)
      row = [row_name]
      col_headers.each do |col_name|
        row << cells[row_name][col_name]
      end
      row_values = row[1..row.size]
      if row_total_block.nil?
        total = calculate_total(row_values)
      else
        total = row_total_block.call(row_values)
      end
      row << total
      [total, row]
    end

    def build_total_row(name, col_headers, cells, col_total_block)
      total_row = ["total #{name}".strip]
      (col_headers.to_a << "total").each do |col_name|
        col = cells.map{ |row_name, row| row[col_name] }
        if col_total_block.nil?
          total_row << calculate_total(col)
        else
          total_row << col_total_block.call(col)
        end
      end
      total_row
    end

    def calculate_total(array)
      array.inject(0) do |memo, item|
        if item.is_a?(Array)
          memo += item.size
        else
          memo+= item.nil? ? 0 : item.to_i
        end
      end
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
