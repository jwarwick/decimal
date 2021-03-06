defmodule DecimalTest do
  use ExUnit.Case, async: false

  alias Decimal.Context
  alias Decimal.Error
  require Decimal

  defrecordp :dec, Decimal, [sign: 1, coef: 0, exp: 0]

  defmacrop d(sign, coef, exp) do
    quote do
      dec(sign: unquote(sign), coef: unquote(coef), exp: unquote(exp))
    end
  end

  defmacrop sigil_d(str, _opts) do
    quote do
      Decimal.new(unquote(str))
    end
  end

  test "macros" do
    assert Decimal.is_nan(%d"nan")
    refute Decimal.is_nan(%d"0")

    assert Decimal.is_inf(%d"inf")
    refute Decimal.is_inf(%d"0")

    assert Decimal.is_decimal(%d"nan")
    assert Decimal.is_decimal(%d"inf")
    assert Decimal.is_decimal(%d"0")
    refute Decimal.is_decimal(42)
    refute Decimal.is_decimal("42")

    assert(case %d"42" do
      x when Decimal.is_decimal(x) -> true
      _ -> false
    end)

    refute(case "42" do
      x when Decimal.is_decimal(x) -> true
      _ -> false
    end)
  end

  test "basic conversion" do
    assert Decimal.new(d(-1, 3, 2)) == d(-1, 3, 2)
    assert Decimal.new(123)         == d(1, 123, 0)
  end

  test "float conversion" do
    assert Decimal.new(123.0) == d(1, 1230, -1)
    assert Decimal.new(-1.5)  == d(-1, 15, -1)
  end

  test "string conversion" do
    assert Decimal.new("123")  == d(1, 123, 0)
    assert Decimal.new("+123") == d(1, 123, 0)
    assert Decimal.new("-123") == d(-1, 123, 0)

    assert Decimal.new("123.0")  == d(1, 1230, -1)
    assert Decimal.new("+123.0") == d(1, 1230, -1)
    assert Decimal.new("-123.0") == d(-1, 1230, -1)

    assert Decimal.new("1.5")  == d(1, 15, -1)
    assert Decimal.new("+1.5") == d(1, 15, -1)
    assert Decimal.new("-1.5") == d(-1, 15, -1)

    assert Decimal.new(".0") == d(1, 0, -1)
    assert Decimal.new("0.") == d(1, 0, 0)

    assert Decimal.new("0")  == d(1, 0, 0)
    assert Decimal.new("+0") == d(1, 0, 0)
    assert Decimal.new("-0") == d(-1, 0, 0)

    assert Decimal.new("1230e13")  == d(1, 1230, 13)
    assert Decimal.new("+1230e+2") == d(1, 1230, 2)
    assert Decimal.new("-1230e-2") == d(-1, 1230, -2)


    assert Decimal.new("1230.00e13")     == d(1, 123000, 11)
    assert Decimal.new("+1230.1230e+5")  == d(1, 12301230, 1)
    assert Decimal.new("-1230.01010e-5") == d(-1, 123001010, -10)

    assert Decimal.new("0e0")   == d(1, 0, 0)
    assert Decimal.new("+0e-0") == d(1, 0, 0)
    assert Decimal.new("-0e+0") == d(-1, 0, 0)

    assert Decimal.new("inf") == d(1, :inf, 0)
    assert Decimal.new("infinity") == d(1, :inf, 0)
    assert Decimal.new("-InfInitY") == d(-1, :inf, 0)

    assert Decimal.new("nAn") == d(1, :qNaN, 0)
    assert Decimal.new("-NaN") == d(-1, :qNaN, 0)

    assert Decimal.new("snAn") == d(1, :sNaN, 0)
    assert Decimal.new("-sNaN") == d(-1, :sNaN, 0)
  end

  test "conversion error" do
    assert_raise Error, fn ->
      Decimal.new("")
    end

    assert_raise Error, fn ->
      Decimal.new("test")
    end

    assert_raise Error, fn ->
      Decimal.new("e0")
    end

    assert_raise Error, fn ->
      Decimal.new("42.+42")
    end

    assert_raise FunctionClauseError, fn ->
      Decimal.new(:atom)
    end

    assert_raise Error, fn ->
      Decimal.new("42e0.0")
    end
  end

  test "abs" do
    assert Decimal.abs(%d"123")     == d(1, 123, 0)
    assert Decimal.abs(%d"-123")    == d(1, 123, 0)
    assert Decimal.abs(%d"-12.5e2") == d(1, 125, 1)
    assert Decimal.abs(%d"-42e-42") == d(1, 42, -42)
    assert Decimal.abs(%d"-inf")    == d(1, :inf, 0)
    assert Decimal.abs(%d"nan")     == d(1, :qNaN, 0)

    assert_raise Error, fn ->
      Decimal.abs(%d"snan")
    end
  end

  test "add" do
    assert Decimal.add(%d"0", %d"0")         == d(1, 0, 0)
    assert Decimal.add(%d"1", %d"1")         == d(1, 2, 0)
    assert Decimal.add(%d"1.3e3", %d"2.4e2") == d(1, 154, 1)
    assert Decimal.add(%d"0.42", %d"-1.5")   == d(-1, 108, -2)
    assert Decimal.add(%d"-2e-2", %d"-2e-2") == d(-1, 4, -2)
    assert Decimal.add(%d"-0", %d"0")        == d(1, 0, 0)
    assert Decimal.add(%d"-0", %d"-0")       == d(-1, 0, 0)
    assert Decimal.add(%d"2", %d"-2")        == d(1, 0, 0)
    assert Decimal.add(%d"5", %d"nan")       == d(1, :qNaN, 0)

    Decimal.with_context(Context[precision: 5, rounding: :floor], fn ->
      Decimal.add(%d"2", %d"-2") == d(-1, 0, 0)
    end)

    assert Decimal.add(%d"inf", %d"5")  == d(1, :inf, 0)
    assert Decimal.add(%d"5", %d"-inf") == d(-1, :inf, 0)

    assert_raise Error, fn ->
      Decimal.add(%d"inf", %d"-inf")
    end
    assert_raise Error, fn ->
      Decimal.add(%d"snan", %d"0")
    end
  end

  test "sub" do
    assert Decimal.sub(%d"0", %d"0")         == d(1, 0, 0)
    assert Decimal.sub(%d"1", %d"2")         == d(-1, 1, 0)
    assert Decimal.sub(%d"1.3e3", %d"2.4e2") == d(1, 106, 1)
    assert Decimal.sub(%d"0.42", %d"-1.5")   == d(1, 192, -2)
    assert Decimal.sub(%d"2e-2", %d"-2e-2")  == d(1, 4, -2)
    assert Decimal.sub(%d"-0", %d"0")        == d(-1, 0, 0)
    assert Decimal.sub(%d"-0", %d"-0")       == d(1, 0, 0)
    assert Decimal.add(%d"5", %d"nan")       == d(1, :qNaN, 0)

    Decimal.with_context(Context[precision: 5, rounding: :floor], fn ->
      Decimal.sub(%d"2", %d"2") == d(-1, 0, 0)
    end)

    assert Decimal.sub(%d"inf", %d"5")  == d(1, :inf, 0)
    assert Decimal.sub(%d"5", %d"-inf") == d(1, :inf, 0)

    assert_raise Error, fn ->
      Decimal.sub(%d"inf", %d"inf")
    end
    assert_raise Error, fn ->
      Decimal.sub(%d"snan", %d"0")
    end
  end

  test "compare" do
    assert Decimal.compare(%d"420", %d"42e1") == d(1, 0, 0)
    assert Decimal.compare(%d"1", %d"0")      == d(1, 1, 0)
    assert Decimal.compare(%d"0", %d"1")      == d(-1, 1, 0)
    assert Decimal.compare(%d"0", %d"-0")     == d(1, 0, 0)
    assert Decimal.compare(%d"nan", %d"1")    == d(1, :qNaN, 0)
    assert Decimal.compare(%d"1", %d"nan")    == d(1, :qNaN, 0)

    assert_raise Error, fn ->
      Decimal.compare(%d"snan", %d"0")
    end
  end

  test "div" do
    Decimal.with_context(Context[precision: 5, rounding: :half_up], fn ->
      assert Decimal.div(%d"1", %d"3")       == d(1, 33333, -5)
      assert Decimal.div(%d"42", %d"2")      == d(1, 21, 0)
      assert Decimal.div(%d"123", %d"12345") == d(1, 99635, -7)
      assert Decimal.div(%d"123", %d"123")   == d(1, 1, 0)
      assert Decimal.div(%d"-1", %d"5")      == d(-1, 2, -1)
      assert Decimal.div(%d"-1", %d"-1")     == d(1, 1, 0)
      assert Decimal.div(%d"2", %d"-5")      == d(-1, 4, -1)
    end)

    Decimal.with_context(Context[precision: 2, rounding: :half_up], fn ->
      assert Decimal.div(%d"31", %d"2")      == d(1, 16, 0)
    end)

    Decimal.with_context(Context[precision: 2, rounding: :floor], fn ->
      assert Decimal.div(%d"31", %d"2")      == d(1, 15, 0)
    end)

    assert Decimal.div(%d"0", %d"3")         == d(1, 0, 0)
    assert Decimal.div(%d"-0", %d"3")        == d(-1, 0, 0)
    assert Decimal.div(%d"0", %d"-3")        == d(-1, 0, 0)
    assert Decimal.div(%d"nan", %d"2")       == d(1, :qNaN, 0)

    assert Decimal.div(%d"-inf", %d"-2")     == d(1, :inf, 0)
    assert Decimal.div(%d"5", %d"-inf")      == d(-1, 0, 0)

    assert_raise Error, fn ->
      Decimal.div(%d"inf", %d"inf")
    end
    assert_raise Error, fn ->
      Decimal.div(%d"snan", %d"2")
    end
    assert_raise Error, fn ->
      Decimal.div(%d"-2", %d"-snan")
    end
    assert_raise Error, fn ->
      Decimal.div(%d"0", %d"-0")
    end
  end

  test "div_int" do
    assert Decimal.div_int(%d"1", %d"0.3")   == d(1, 3, 0)
    assert Decimal.div_int(%d"2", %d"3")      == d(1, 0, 0)
    assert Decimal.div_int(%d"42", %d"2")     == d(1, 21, 0)
    assert Decimal.div_int(%d"123", %d"23")   == d(1, 5, 0)
    assert Decimal.div_int(%d"123", %d"-23")  == d(-1, 5, 0)
    assert Decimal.div_int(%d"-123", %d"23")  == d(-1, 5, 0)
    assert Decimal.div_int(%d"-123", %d"-23") == d(1, 5, 0)
    assert Decimal.div_int(%d"1", %d"0.3")    == d(1, 3, 0)

    assert Decimal.div_int(%d"0", %d"3")      == d(1, 0, 0)
    assert Decimal.div_int(%d"-0", %d"3")     == d(-1, 0, 0)
    assert Decimal.div_int(%d"0", %d"-3")     == d(-1, 0, 0)
    assert Decimal.div_int(%d"nan", %d"2")    == d(1, :qNaN, 0)

    assert Decimal.div_int(%d"-inf", %d"-2")  == d(1, :inf, 0)
    assert Decimal.div_int(%d"5", %d"-inf")   == d(-1, 0, 0)

    assert_raise Error, fn ->
      Decimal.div_int(%d"inf", %d"inf")
    end
    assert_raise Error, fn ->
      Decimal.div_int(%d"snan", %d"2")
    end
    assert_raise Error, fn ->
      Decimal.div_int(%d"-2", %d"-snan")
    end
    assert_raise Error, fn ->
      Decimal.div_int(%d"0", %d"-0")
    end
  end

  test "rem" do
    assert Decimal.rem(%d"1", %d"3")      == d(1, 1, 0)
    assert Decimal.rem(%d"42", %d"2")     == d(1, 0, -1)
    assert Decimal.rem(%d"123", %d"23")   == d(1, 8, 0)
    assert Decimal.rem(%d"123", %d"-23")  == d(1, 8, 0)
    assert Decimal.rem(%d"-123", %d"23")  == d(-1, 8, 0)
    assert Decimal.rem(%d"-123", %d"-23") == d(-1, 8, 0)
    assert Decimal.rem(%d"1", %d"0.3")    == d(1, 1, 0)

    assert Decimal.rem(%d"-inf", %d"-2")  == d(-1, 0, 0)
    assert Decimal.rem(%d"5", %d"-inf")   == d(1, :inf, 0)
    assert Decimal.rem(%d"nan", %d"2")    == d(1, :qNaN, 0)

    assert_raise Error, fn ->
      Decimal.rem(%d"inf", %d"inf")
    end
    assert_raise Error, fn ->
      Decimal.rem(%d"snan", %d"2")
    end
    assert_raise Error, fn ->
      Decimal.rem(%d"-2", %d"-snan")
    end
    assert_raise Error, fn ->
      Decimal.rem(%d"0", %d"-0")
    end
  end

  test "max" do
    assert Decimal.max(%d"0", %d"0")      == d(1, 0, 0)
    assert Decimal.max(%d"1", %d"0")      == d(1, 1, 0)
    assert Decimal.max(%d"0", %d"1")      == d(1, 1, 0)
    assert Decimal.max(%d"-1", %d"1")     == d(1, 1, 0)
    assert Decimal.max(%d"1", %d"-1")     == d(1, 1, 0)
    assert Decimal.max(%d"-30", %d"-40")  == d(-1, 30, 0)

    assert Decimal.max(%d"+0", %d"-0")    == d(1, 0, 0)
    assert Decimal.max(%d"2e1", %d"20")   == d(1, 2, 1)
    assert Decimal.max(%d"-2e1", %d"-20") == d(-1, 20, 0)

    assert Decimal.max(%d"-inf", %d"5")   == d(1, 5, 0)
    assert Decimal.max(%d"inf", %d"5")    == d(1, :inf, 0)

    assert Decimal.max(%d"nan", %d"1")    == d(1, 1, 0)
    assert Decimal.max(%d"2", %d"nan")    == d(1, 2, 0)

    assert_raise Error, fn ->
      Decimal.max(%d"snan", %d"2")
    end
  end

  test "min" do
    assert Decimal.min(%d"0", %d"0")      == d(1, 0, 0)
    assert Decimal.min(%d"-1", %d"0")     == d(-1, 1, 0)
    assert Decimal.min(%d"0", %d"-1")     == d(-1, 1, 0)
    assert Decimal.min(%d"-1", %d"1")     == d(-1, 1, 0)
    assert Decimal.min(%d"1", %d"0")      == d(1, 0, 0)
    assert Decimal.min(%d"-30", %d"-40")  == d(-1, 40, 0)

    assert Decimal.min(%d"+0", %d"-0")    == d(-1, 0, 0)
    assert Decimal.min(%d"2e1", %d"20")   == d(1, 20, 0)
    assert Decimal.min(%d"-2e1", %d"-20") == d(-1, 2, 1)

    assert Decimal.min(%d"-inf", %d"5")   == d(-1, :inf, 0)
    assert Decimal.min(%d"inf", %d"5")    == d(1, 5, 0)

    assert Decimal.min(%d"nan", %d"1")    == d(1, 1, 0)
    assert Decimal.min(%d"2", %d"nan")    == d(1, 2, 0)

    assert_raise Error, fn ->
      Decimal.min(%d"snan", %d"2")
    end
  end

  test "minus" do
    assert Decimal.minus(%d"0")   == d(-1, 0, 0)
    assert Decimal.minus(%d"1")   == d(-1, 1, 0)
    assert Decimal.minus(%d"-1")  == d(1, 1, 0)

    assert Decimal.minus(%d"inf") == d(-1, :inf, 0)
    assert Decimal.minus(%d"nan") == d(1, :qNaN, 0)

    assert_raise Error, fn ->
      Decimal.minus(%d"snan")
    end
  end

  test "plus" do
    Decimal.with_context(Context[precision: 2], fn ->
      assert Decimal.plus(%d"0")    == d(1, 0, 0)
      assert Decimal.plus(%d"5")    == d(1, 5, 0)
      assert Decimal.plus(%d"123")  == d(1, 12, 1)
      assert Decimal.plus(%d"nan") == d(1, :qNaN, 0)
    end)

    assert_raise Error, fn ->
      Decimal.plus(%d"snan")
    end
  end

  test "mult" do
    assert Decimal.mult(%d"0", %d"0")      == d(1, 0, 0)
    assert Decimal.mult(%d"42", %d"0")     == d(1, 0, 0)
    assert Decimal.mult(%d"0", %d"42")     == d(1, 0, 0)
    assert Decimal.mult(%d"5", %d"5")      == d(1, 25, 0)
    assert Decimal.mult(%d"-5", %d"5")     == d(-1, 25, 0)
    assert Decimal.mult(%d"5", %d"-5")     == d(-1, 25, 0)
    assert Decimal.mult(%d"-5", %d"-5")    == d(1, 25, 0)
    assert Decimal.mult(%d"42", %d"0.42")  == d(1, 1764, -2)
    assert Decimal.mult(%d"0.03", %d"0.3") == d(1, 9, -3)

    assert Decimal.mult(%d"0", %d"-0")     == d(-1, 0, 0)
    assert Decimal.mult(%d"0", %d"3")      == d(1, 0, 0)
    assert Decimal.mult(%d"-0", %d"3")     == d(-1, 0, 0)
    assert Decimal.mult(%d"0", %d"-3")     == d(-1, 0, 0)

    assert Decimal.mult(%d"inf", %d"-3")   == d(-1, :inf, 0)
    assert Decimal.mult(%d"nan", %d"2")    == d(1, :qNaN, 0)

    assert_raise Error, fn ->
      Decimal.mult(%d"snan", %d"2")
    end
    assert_raise Error, fn ->
      Decimal.mult(%d"-2", %d"-snan")
    end
    assert_raise Error, fn ->
      Decimal.mult(%d"inf", %d"0")
    end
    assert_raise Error, fn ->
      Decimal.mult(%d"0", %d"-inf")
    end
  end

  test "reduce" do
    assert Decimal.reduce(%d"2.1")   == d(1, 21, -1)
    assert Decimal.reduce(%d"2.10")  == d(1, 21, -1)
    assert Decimal.reduce(%d"-2")    == d(-1, 2, 0)
    assert Decimal.reduce(%d"-2.00") == d(-1, 2, 0)
    assert Decimal.reduce(%d"200")   == d(1, 2, 2)
    assert Decimal.reduce(%d"0")     == d(1, 0, 0)
    assert Decimal.reduce(%d"-0")    == d(-1, 0, 0)
    assert Decimal.reduce(%d"-inf")  == d(-1, :inf, 0)
    assert Decimal.reduce(%d"nan")   == d(1, :qNaN, 0)

    assert_raise Error, fn ->
      Decimal.reduce(%d"snan")
    end
  end

  test "to_string normal" do
    assert Decimal.to_string(%d"0", :normal)       == "0"
    assert Decimal.to_string(%d"42", :normal)      == "42"
    assert Decimal.to_string(%d"42.42", :normal)   == "42.42"
    assert Decimal.to_string(%d"0.42", :normal)    == "0.42"
    assert Decimal.to_string(%d"0.0042", :normal)  == "0.0042"
    assert Decimal.to_string(%d"-1", :normal)      == "-1"
    assert Decimal.to_string(%d"-0", :normal)      == "-0"
    assert Decimal.to_string(%d"-1.23", :normal)   == "-1.23"
    assert Decimal.to_string(%d"-0.0123", :normal) == "-0.0123"
    assert Decimal.to_string(%d"nan", :normal)     == "NaN"
    assert Decimal.to_string(%d"-nan", :normal)    == "-NaN"
    assert Decimal.to_string(%d"-inf", :normal)    == "-Infinity"
  end

  test "to_string scientific" do
    assert Decimal.to_string(%d"123", :scientific)      == "123"
    assert Decimal.to_string(%d"-123", :scientific)     == "-123"
    assert Decimal.to_string(%d"123e1", :scientific)    == "1.23E+3"
    assert Decimal.to_string(%d"123e3", :scientific)    == "1.23E+5"
    assert Decimal.to_string(%d"123e-1", :scientific)   == "12.3"
    assert Decimal.to_string(%d"123e-5", :scientific)   == "0.00123"
    assert Decimal.to_string(%d"123e-10", :scientific)  == "1.23E-8"
    assert Decimal.to_string(%d"-123e-12", :scientific) == "-1.23E-10"
    assert Decimal.to_string(%d"0", :scientific)        == "0"
    assert Decimal.to_string(%d"0e-2", :scientific)     == "0.00"
    assert Decimal.to_string(%d"0e2", :scientific)      == "0E+2"
    assert Decimal.to_string(%d"-0", :scientific)       == "-0"
    assert Decimal.to_string(%d"5e-6", :scientific)     == "0.000005"
    assert Decimal.to_string(%d"50e-7", :scientific)    == "0.0000050"
    assert Decimal.to_string(%d"5e-7", :scientific)     == "5E-7"
    assert Decimal.to_string(%d"4321.768", :scientific) == "4321.768"
    assert Decimal.to_string(%d"-0", :scientific)       == "-0"
    assert Decimal.to_string(%d"nan", :scientific)      == "NaN"
    assert Decimal.to_string(%d"-nan", :scientific)     == "-NaN"
    assert Decimal.to_string(%d"-inf", :scientific)     == "-Infinity"
    assert Decimal.to_string(%d"84e-1", :scientific)    == "8.4"
  end

  test "to_string raw" do
    assert Decimal.to_string(%d"2", :raw)        == "2"
    assert Decimal.to_string(%d"300", :raw)      == "300"
    assert Decimal.to_string(%d"4321.768", :raw) == "4321768E-3"
    assert Decimal.to_string(%d"-53000", :raw)   == "-53000"
    assert Decimal.to_string(%d"0.0042", :raw)   == "42E-4"
    assert Decimal.to_string(%d"0.2", :raw)      == "2E-1"
    assert Decimal.to_string(%d"-0.0003", :raw)  == "-3E-4"
    assert Decimal.to_string(%d"-0", :raw)       == "-0"
    assert Decimal.to_string(%d"nan", :raw)      == "NaN"
    assert Decimal.to_string(%d"-nan", :raw)     == "-NaN"
    assert Decimal.to_string(%d"-inf", :raw)     == "-Infinity"
  end

  test "precision down" do
    Decimal.with_context(Context[precision: 2, rounding: :down], fn ->
      assert Decimal.add(%d"0", %d"1.02") == d(1, 10, -1)
      assert Decimal.add(%d"0", %d"102")  == d(1, 10, 1)
      assert Decimal.add(%d"0", %d"-102") == d(-1, 10, 1)
      assert Decimal.add(%d"0", %d"1.1")  == d(1, 11, -1)
    end)
  end

  test "precision ceiling" do
    Decimal.with_context(Context[precision: 2, rounding: :ceiling], fn ->
      assert Decimal.add(%d"0", %d"1.02") == d(1, 11, -1)
      assert Decimal.add(%d"0", %d"102")  == d(1, 11, 1)
      assert Decimal.add(%d"0", %d"-102") == d(-1, 10, 1)
      assert Decimal.add(%d"0", %d"106")  == d(1, 11, 1)
    end)
  end

  test "precision floor" do
    Decimal.with_context(Context[precision: 2, rounding: :floor], fn ->
      assert Decimal.add(%d"0", %d"1.02") == d(1, 10, -1)
      assert Decimal.add(%d"0", %d"1.10") == d(1, 11, -1)
      assert Decimal.add(%d"0", %d"-123") == d(-1, 13, 1)
    end)
  end

  test "precision half up" do
    Decimal.with_context(Context[precision: 2, rounding: :half_up], fn ->
      assert Decimal.add(%d"0", %d"1.02")  == d(1, 10, -1)
      assert Decimal.add(%d"0", %d"1.05")  == d(1, 11, -1)
      assert Decimal.add(%d"0", %d"-1.05") == d(-1, 10, -1)
      assert Decimal.add(%d"0", %d"123")   == d(1, 12, 1)
      assert Decimal.add(%d"0", %d"-123")  == d(-1, 12, 1)
      assert Decimal.add(%d"0", %d"125")   == d(1, 13, 1)
      assert Decimal.add(%d"0", %d"-125")  == d(-1, 12, 1)
    end)
  end

  test "precision half even" do
    Decimal.with_context(Context[precision: 2, rounding: :half_even], fn ->
      assert Decimal.add(%d"0", %d"1.0")   == d(1, 10, -1)
      assert Decimal.add(%d"0", %d"123")   == d(1, 12, 1)
      assert Decimal.add(%d"0", %d"6.66")  == d(1, 67, -1)
      assert Decimal.add(%d"0", %d"9.99")  == d(1, 10, 0)
      assert Decimal.add(%d"0", %d"-6.66") == d(-1, 67, -1)
      assert Decimal.add(%d"0", %d"-9.99") == d(-1, 10, 0)
    end)
  end

  test "precision half down" do
    Decimal.with_context(Context[precision: 2, rounding: :half_down], fn ->
      assert Decimal.add(%d"0", %d"1.02")  == d(1, 10, -1)
      assert Decimal.add(%d"0", %d"1.05")  == d(1, 11, -1)
      assert Decimal.add(%d"0", %d"-1.05") == d(-1, 11, -1)
      assert Decimal.add(%d"0", %d"123")   == d(1, 12, 1)
      assert Decimal.add(%d"0", %d"125")   == d(1, 13, 1)
      assert Decimal.add(%d"0", %d"-125")  == d(-1, 13, 1)
    end)
  end

  test "precision up" do
    Decimal.with_context(Context[precision: 2, rounding: :up], fn ->
      assert Decimal.add(%d"0", %d"1.02") == d(1, 11, -1)
      assert Decimal.add(%d"0", %d"102")  == d(1, 11, 1)
      assert Decimal.add(%d"0", %d"-102") == d(-1, 11, 1)
      assert Decimal.add(%d"0", %d"1.1")  == d(1, 11, -1)
    end)
  end

  test "round special" do
    assert Decimal.round(%d"inf", 2, :down) == d(1, :inf, 0)
    assert Decimal.round(%d"nan", 2, :down) == d(1, :qNaN, 0)

    assert_raise Error, fn ->
      Decimal.round(%d"snan", 2, :down)
    end
  end

  test "round down" do
    round = &Decimal.round(&1, 2, :down)
    roundneg = &Decimal.round(&1, -2, :down)
    assert round.(%d"1.02")    == d(1, 102, -2)
    assert round.(%d"1.029")   == d(1, 102, -2)
    assert round.(%d"-1.029")  == d(-1, 102, -2)
    assert round.(%d"102")     == d(1, 102, 0)
    assert round.(%d"0.001")   == d(1, 0, -2)
    assert round.(%d"-0.001")  == d(-1, 0, -2)
    assert roundneg.(%d"1.02") == d(1, 0, 2)
    assert roundneg.(%d"102")  == d(1, 1, 2)
    assert roundneg.(%d"1099") == d(1, 10, 2)
  end

  test "round ceiling" do
    round = &Decimal.round(&1, 2, :ceiling)
    roundneg = &Decimal.round(&1, -2, :ceiling)
    assert round.(%d"1.02")    == d(1, 102, -2)
    assert round.(%d"1.021")   == d(1, 103, -2)
    assert round.(%d"-1.021")  == d(-1, 102, -2)
    assert round.(%d"102")     == d(1, 102, 0)
    assert roundneg.(%d"1.02") == d(1, 1, 2)
    assert roundneg.(%d"102")  == d(1, 2, 2)
  end

  test "round floor" do
    round = &Decimal.round(&1, 2, :floor)
    roundneg = &Decimal.round(&1, -2, :floor)
    assert round.(%d"1.02")    == d(1, 102, -2)
    assert round.(%d"1.029")   == d(1, 102, -2)
    assert round.(%d"-1.029")  == d(-1, 103, -2)
    assert roundneg.(%d"123")  == d(1, 1, 2)
    assert roundneg.(%d"-123") == d(-1, 2, 2)
  end

  test "round half up" do
    round = &Decimal.round(&1, 2, :half_up)
    roundneg = &Decimal.round(&1, -2, :half_up)
    assert round.(%d"1.02")    == d(1, 102, -2)
    assert round.(%d"1.025")   == d(1, 103, -2)
    assert round.(%d"-1.02")   == d(-1, 102, -2)
    assert round.(%d"-1.025")  == d(-1, 102, -2)
    assert roundneg.(%d"120")  == d(1, 1, 2)
    assert roundneg.(%d"150")  == d(1, 2, 2)
    assert roundneg.(%d"-120") == d(-1, 1, 2)
    assert roundneg.(%d"-150") == d(-1, 1, 2)
  end

  test "round half even" do
    round = &Decimal.round(&1, 2, :half_even)
    roundneg = &Decimal.round(&1, -2, :half_even)
    assert round.(%d"1.03")    == d(1, 103, -2)
    assert round.(%d"1.035")   == d(1, 104, -2)
    assert round.(%d"1.045")   == d(1, 104, -2)
    assert round.(%d"-1.035")  == d(-1, 104, -2)
    assert round.(%d"-1.045")  == d(-1, 104, -2)
    assert roundneg.(%d"130")  == d(1, 1, 2)
    assert roundneg.(%d"150")  == d(1, 2, 2)
    assert roundneg.(%d"250")  == d(1, 2, 2)
    assert roundneg.(%d"-150") == d(-1, 2, 2)
    assert roundneg.(%d"-250") == d(-1, 2, 2)
  end

  test "round half down" do
    round = &Decimal.round(&1, 2, :half_down)
    roundneg = &Decimal.round(&1, -2, :half_down)
    assert round.(%d"1.02")    == d(1, 102, -2)
    assert round.(%d"1.025")   == d(1, 103, -2)
    assert round.(%d"-1.02")   == d(-1, 102, -2)
    assert round.(%d"-1.025")  == d(-1, 103, -2)
    assert roundneg.(%d"120")  == d(1, 1, 2)
    assert roundneg.(%d"150")  == d(1, 2, 2)
    assert roundneg.(%d"-120") == d(-1, 1, 2)
    assert roundneg.(%d"-150") == d(-1, 2, 2)
  end

  test "round up" do
    round = &Decimal.round(&1, 2, :up)
    roundneg = &Decimal.round(&1, -2, :up)
    assert round.(%d"1.02")    == d(1, 102, -2)
    assert round.(%d"1.029")   == d(1, 103, -2)
    assert round.(%d"-1.029")  == d(-1, 103, -2)
    assert round.(%d"102")     == d(1, 102, 0)
    assert round.(%d"0.001")   == d(1, 1, -2)
    assert round.(%d"-0.001")  == d(-1, 1, -2)
    assert roundneg.(%d"1.02") == d(1, 1, 2)
    assert roundneg.(%d"102")  == d(1, 2, 2)
    assert roundneg.(%d"1099") == d(1, 12, 2)
  end

  test "set context flags" do
    Decimal.with_context(Context[precision: 2], fn ->
      assert [] = Decimal.get_context.flags
      Decimal.add(%d"2", %d"2")
      assert [] = Decimal.get_context.flags
      Decimal.add(%d"2.0000", %d"2")
      assert [:rounded] = Decimal.get_context.flags
      Decimal.add(%d"2.0001", %d"2")
      assert :inexact in Decimal.get_context.flags
    end)

    Decimal.with_context(Context[precision: 2], fn ->
      assert [] = Decimal.get_context.flags
      assert_raise Error, fn ->
        assert Decimal.mult(%d"inf", %d"0")
      end
      assert :invalid_operation in Decimal.get_context.flags
    end)
  end

  test "traps" do
    Decimal.with_context(Context[traps: []], fn ->
     assert Decimal.mult(%d"inf", %d"0") == d(1, :qNaN, 0)
     assert Decimal.div(%d"5", %d"0") == d(1, :inf, 0)
     assert :division_by_zero in Decimal.get_context.flags
    end)
  end

  test "error sets result" do
    try do
      Decimal.mult(%d"inf", %d"0")
    rescue x in [Error] ->
      assert x.result == d(1, :sNaN, 0)
    end
  end
end
