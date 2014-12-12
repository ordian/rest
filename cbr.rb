#!/usr/bin/env ruby
# encoding: utf-8

require 'ox'
require 'open-uri'

module Cbr
  class Handler < ::Ox::Sax
    def initialize(rates)
      @rates = rates
      @is_name = false
      @is_value = false
      @name = ''
    end

    def start_element(name)
      name = name.to_s
      if name == "CharCode"
        @is_name = true
      elsif name == "Value"
        @is_value = true
      end
    end

    def text(value)
      if @is_name
        @name = value.to_s
        @is_name = false
      elsif @is_value
        @rates[@name] = value.to_s.gsub(',', '.').to_f
        @is_value = false
      end
    end
  end

  def Cbr.by_date(date)
    xml = open("http://www.cbr.ru/scripts/XML_daily.asp?date_req=" +
               date.strftime("%d/%m/%Y"))
    result = {}
    Ox.sax_parse(Handler.new(result), xml)
    result
  end
end
