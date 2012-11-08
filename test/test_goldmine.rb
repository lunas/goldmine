require "simplecov"
SimpleCov.start
require "test/unit"
require "turn"
require File.join(File.dirname(__FILE__), "..", "lib", "goldmine")

class TestGoldmine < MiniTest::Unit::TestCase

  def test_simple_pivot
    list = [1,2,3,4,5,6,7,8,9]
    data = list.pivot { |i| i < 5 }

    expected = {
      true  => [1, 2, 3, 4],
      false => [5, 6, 7, 8, 9]
    }

    assert_equal expected, data
  end

  def test_named_pivot
    list = [1,2,3,4,5,6,7,8,9]
    data = list.pivot("less than 5") { |i| i < 5 }

    expected = {
      { "less than 5" => true }  => [1, 2, 3, 4],
      { "less than 5" => false } => [5, 6, 7, 8, 9]
    }

    assert_equal expected, data
  end

  def test_pivot_of_list_values
    list = [
      { :name => "one",   :list => [1] },
      { :name => "two",   :list => [1, 2] },
      { :name => "three", :list => [1, 2, 3] },
      { :name => "four",  :list => [1, 2, 3, 4] },
    ]
    data = list.pivot { |record| record[:list] }

    expected = {
      1 => [ { :name => "one",   :list => [1] },
             { :name => "two",   :list => [1, 2] },
             { :name => "three", :list => [1, 2, 3] },
             { :name => "four",  :list => [1, 2, 3, 4] } ],
      2 => [ { :name => "two",   :list => [1, 2] },
             { :name => "three", :list => [1, 2, 3] },
             { :name => "four",  :list => [1, 2, 3, 4] } ],
      3 => [ { :name => "three", :list => [1, 2, 3] },
             { :name => "four",  :list => [1, 2, 3, 4] } ],
      4 => [ { :name => "four",  :list => [1, 2, 3, 4] } ]
    }

    assert_equal expected, data
  end

  def test_chained_pivots
    list = [1,2,3,4,5,6,7,8,9]
    data = list.pivot { |i| i < 5 }.pivot { |i| i % 2 == 0 }

    expected = {
      [true, false]  => [1, 3],
      [true, true]   => [2, 4],
      [false, false] => [5, 7, 9],
      [false, true]  => [6, 8]
    }

    assert_equal expected, data
  end

  def test_deep_chained_pivots
    list = [1,2,3,4,5,6,7,8,9]
    # list = [2,5,9]
    data = list
      .pivot { |i| i < 3 }
      .pivot { |i| i < 6 }
      .pivot { |i| i < 9 }
      .pivot { |i| i % 2 == 0 }
      .pivot { |i| i % 3 == 0 }

    expected = {
      [true,  true,  true,  false, false] => [1],
      [true,  true,  true,  true,  false] => [2],
      [false, true,  true,  false, true]  => [3],
      [false, true,  true,  false, false] => [5],
      [false, true,  true,  true,  false] => [4],
      [false, false, true,  true,  true]  => [6],
      [false, false, true,  true,  false] => [8],
      [false, false, true,  false, false] => [7],
      [false, false, false, false, true]  => [9]
    }

    assert_equal expected, data
  end

  def test_named_deep_chained_pivots
    list = [1,2,3,4,5,6,7,8,9]
    data = list.pivot("a") { |i| i < 3 }.pivot("b") { |i| i < 6 }.pivot("c") { |i| i < 9 }.pivot("d") { |i| i % 2 == 0 }.pivot("e") { |i| i % 3 == 0 }

    expected = {
      {"a"=>true,  "b"=>true,  "c"=>true,  "d"=>false, "e"=>false} => [1],
      {"a"=>true,  "b"=>true,  "c"=>true,  "d"=>true,  "e"=>false} => [2],
      {"a"=>false, "b"=>true,  "c"=>true,  "d"=>false, "e"=>true}  => [3],
      {"a"=>false, "b"=>true,  "c"=>true,  "d"=>false, "e"=>false} => [5],
      {"a"=>false, "b"=>true,  "c"=>true,  "d"=>true,  "e"=>false} => [4],
      {"a"=>false, "b"=>false, "c"=>true,  "d"=>true,  "e"=>true}  => [6],
      {"a"=>false, "b"=>false, "c"=>true,  "d"=>true,  "e"=>false} => [8],
      {"a"=>false, "b"=>false, "c"=>true,  "d"=>false, "e"=>false} => [7],
      {"a"=>false, "b"=>false, "c"=>false, "d"=>false, "e"=>true}  => [9]
    }

    assert_equal expected, data
  end

  def test_named_chained_pivots
    list = [1,2,3,4,5,6,7,8,9]
    data = list.pivot("less than 5") { |i| i < 5 }.pivot("divisible by 2") { |i| i % 2 == 0 }

    expected = {
      { "less than 5" => true, "divisible by 2" => false } => [1, 3],
      { "less than 5" => true, "divisible by 2" => true}   => [2, 4],
      { "less than 5" => false, "divisible by 2" => false} => [5, 7, 9],
      { "less than 5" => false, "divisible by 2" => true}  => [6, 8]
    }

    assert_equal expected, data
  end

  def test_named_chained_pivots_to_2d_with_cellblock1
    list = [ {name: 'nut', size: 'small', color: 'brown', sales: 3},
             {name: 'melon', size: 'big', color: 'green', sales: 4},
             {name: 'bean', size: 'small', color: 'green', sales: 10},
             {name: 'chestnut', size: 'small', color: 'brown', sales: 2},
             {name: 'zucchini', size: 'big', color: 'green', sales: 2}
    ]
    data = list.pivot("size") {|i| i[:size] }.pivot("color") {|i| i[:color]}.to_2d("count"){|i| i.size }

    expected = [ ["color/size", "big", "small", "total count"],
                 ['brown', nil, 2, 2],
                 ['green', 2, 1, 3],
                 ['total count', 2, 3, 5]
    ]

    assert_equal expected, data
  end

  def test_named_chained_pivots_to_2d_example2
    list = [1,2,3,4,5,6,7,8,9]
    data = list.pivot("less than 5") { |i| i < 5 }.pivot("divisible by 2") { |i| i % 2 == 0 }.to_2d("count"){|i| i.size}
    expected =  [ ["divisible by 2/less than 5", "false", "true", "total count"],
      ["false", 3, 2, 5],
      ["true",  2, 2, 4],
      ["total count", 5, 4, 9]
    ]
    assert_equal expected, data
  end

  def test_named_chained_pivots_to_2d_with_cellblock2
    list = [ {name: 'nut', size: 'small', color: 'brown', sales: 3},
             {name: 'melon', size: 'big', color: 'green', sales: 4},
             {name: 'bean', size: 'small', color: 'green', sales: 10},
             {name: 'chestnut', size: 'small', color: 'brown', sales: 2},
             {name: 'zucchini', size: 'big', color: 'green', sales: 2}
    ]
    data = list.pivot("size") {|i| i[:size] }.pivot("color") {|i| i[:color]}.to_2d("sales sum") do |items|
      items.inject(0){ |result, item| result += item[:sales]; result }
    end

    expected = [ ["color/size", "big", "small", "total sales sum"],
                 ['brown', nil, 5, 5],
                 ['green', 6, 10, 16],
                 ['total sales sum', 6, 15, 21]
    ]

    assert_equal expected, data
  end

  def test_named_chained_pivots_to_2d
    list = [ {name: 'nut', size: 'small', color: 'brown', sales: 3},
             {name: 'melon', size: 'big', color: 'green', sales: 4},
             {name: 'bean', size: 'small', color: 'green', sales: 10},
             {name: 'chestnut', size: 'small', color: 'brown', sales: 2},
             {name: 'zucchini', size: 'big', color: 'green', sales: 2}
    ]
    data = list.pivot("size") {|i| i[:size] }.pivot("color") {|i| i[:color]}.to_2d("count")

    expected = [ ["color/size", "big", "small", "total count"],
                 ['brown', nil, [{name: 'nut', size: 'small', color: 'brown', sales: 3},
                                 {name: 'chestnut', size: 'small', color: 'brown', sales: 2}], 2],
                 ['green', [{name: 'melon', size: 'big', color: 'green', sales: 4},
                            {name: 'zucchini', size: 'big', color: 'green', sales: 2}],
                           [{name: 'bean', size: 'small', color: 'green', sales: 10}], 3],
                 ['total count', 2, 3, 5]
    ]
    assert_equal expected, data
  end

  def test_large_list_to_2d
    attributes = {
      color: %w[blau gruen ocker orange maron rubin jasmin],
      size: [32, 34, 36, 38, 40, 42, 44],
      collection: %w[02 02/03 03 03/04 04 04/05 05 05/06 06 06/07 07 07/08 08 08/09 09 09/10 10 10/11 11 11/12 12 12/13 13],
      fabric: %w[jeans silk cotton kashmir leather],
      sales: [1, 3, 7, 10, 15, 20, 30, 40],
      name: %w[Sputnik Bella Corso Chelsea Cupido Dave Jaguar Lisette Maverick Pride Scott Superking Arlette Bastos Astra Belga],
    }
    list = []
    n = 100000
    n.times do
      # create pieces: {}
      list << attributes.inject({}){ |piece, attr| piece[attr.first] = attr.last.sample; piece }
    end
    start = Time.now
    data = list.pivot("color") {|p| p[:name] }.pivot("name") {|p| p[:color]}.to_2d("count") do |pieces|
      pieces.inject(0){ |result, piece| result += piece[:sales]; result }
    end
    done = Time.now

    data.each do |row|
      puts row.join(" --- ")
    end

    puts "Execution time for #{n} list items: #{done - start} seconds."
  end



end
