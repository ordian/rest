#!/usr/bin/env ruby
# encoding: utf-8

require 'date'
require 'time'

require './cbr.rb'              # Russian Central Bank exchange rates

require 'sinatra'               # REST API
require 'sinatra/contrib'
require 'slim'                  # HTML template engine
require 'builder'               # XML builder
require 'data_mapper'           # ORM

#####################################################################
############################## database #############################
#####################################################################

DataMapper::Logger.new($stderr, :debug)
DataMapper::setup(:default, "sqlite://#{Dir.pwd}/exchange.db")

class Task
  include DataMapper::Resource
  property   :id,         Serial
  property   :date,       Date,    :required => true
  property   :created_at, DateTime
  property   :updated_at, DateTime
  has n,     :rates,               :constraint => :destroy
end

class Rate
  include DataMapper::Resource
  property   :id,   Serial
  property   :code, String, :length => 3
  property   :rate, Float
  belongs_to :task
end

DataMapper.auto_upgrade!

#####################################################################
############################## helpers ##############################
#####################################################################

register Sinatra::Contrib

SITE_TITLE = "Exchange rates"
COMMANDS   = {
  :get     => '/ or /id',
  :put     => '/year/month/day',
  :post    => '/id/year/month/day',
  :options => '/'
}

def find_task()
  task = Task.get(params[:id])
  unless task
    halt 418
  end
  task
end

def parse_date()
  s = "#{params[:year]} #{params[:month]} #{params[:day]}"
  begin
    date = Date.strptime(s, '%Y %m %d')
  rescue
    halt 400
  end
  date
end

def create_new_rates(date)
  items = Cbr.by_date(date)
  rates = []
  items.each do |k, v|
    rates.push(Rate.create({:code => k, :rate => v}))
  end
  rates
end

def create_new_task(date)
  rates = create_new_rates(date)
  time = Time.now
  task = Task.create({
                       :date       => date,
                       :created_at => time,
                       :updated_at => time,
                       :rates      => rates
                     })
  task
end

def create_task(date)
  task = Task.first({ :date => date })
  unless task
    task = create_new_task(date)
  end
  task
end

#####################################################################
################################ API ################################
#####################################################################

get '/', :provides => [:html] do
  @commands = COMMANDS.to_a
  slim(:usage, :commands => @commands)
end

options '/' do
  "Available commands:\n" + COMMANDS.map { |k, v| "#{k} #{v}" }.join("\n")
end

get '/:id', :provides => [:html, :json, :text, :xml] do
  task = find_task()

  @date  = task.date
  @items = task.rates
  locals = { :date => @date, :items => @items }

  respond_with :tasks, locals do |f|
    f.txt  { "#{@date}\n#{@items.to_a.map { |r| %Q(#{r.code}: #{r.rate}) }.join("\n")}" }
  end
end

put '/:year/:month/:day' do
  date = parse_date()
  create_task(date).id.to_s
end

post '/:id/:year/:month/:day' do
  task = find_task()
  date = parse_date()
  updated = Task.first({ :date => date })

  unless updated
    rates = create_new_rates(date)
    task.rates.destroy
    time = Time.now
    task.update(:date => date, :rates => rates, :updated_at => time)
  else
    updated.id.to_s
  end
end

delete '/:id' do
  task = find_task()
  task.destroy.to_s
end
