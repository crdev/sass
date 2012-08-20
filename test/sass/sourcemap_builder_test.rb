#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/scss/test_helper'
require 'sass/engine'

class SourcemapBuilderTest < Test::Unit::TestCase

  def setup
    @builder = Sass::Tree::SourcemapBuilder.new

    def @builder.encode_vlq_publicly(*args)
      encode_vlq(*args)
    end

    def @builder.decode_vlq_publicly(*args)
      decode_vlq(*args)
    end
  end

  def test_base64
    for i in (0..63) do
      assert_equal i, Sass::Tree::SourcemapBuilder::BASE64_DIGIT_MAP[Sass::Tree::SourcemapBuilder::BASE64_DIGITS[i]]
    end
  end

  def test_base64_vlq
    for i in (0..1000) do
      assert_vlq_encode i
    end
  end

  def test_base64_vlq_twoway
    assert_vlq_twoway [0], "A"
    assert_vlq_twoway [15], "e"
    assert_vlq_twoway [16], "gB"
    assert_vlq_twoway [120], "wH"
    assert_vlq_twoway [120, 0, 120, 120], "wHAwHwH"
    assert_vlq_twoway [4, 2, 0, 2], "IEAE"
  end

  private

  def assert_vlq_encode(decimal)
    assert_equal decimal, @builder.decode_vlq_publicly(@builder.encode_vlq_publicly(decimal))[0]
  end

  def assert_vlq_twoway(decimal_array, vlq)
    vlq_from_decimal_array = decimal_array.map {|d| @builder.encode_vlq_publicly(d)}.join
    decimal_array_from_vlq = @builder.decode_vlq_publicly(vlq)
    assert_equal vlq, vlq_from_decimal_array
    assert_equal decimal_array, decimal_array_from_vlq
  end
end
