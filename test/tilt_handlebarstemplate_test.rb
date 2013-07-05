require 'bundler'
Bundler.setup

require 'minitest/autorun'
require 'minitest/spec'

require 'tilt'
require 'tilt/handlebars'

def make_template(text)
  Tilt::HandlebarsTemplate.new { |t| text }
end

describe Tilt::HandlebarsTemplate do
  it 'renders from file' do
    template = Tilt.new('test/hello.hbs')
    template.render(nil, name: 'Joe', emotion: 'happy').must_equal "Hello, Joe. I'm happy to meet you.\n"
  end

  it 'is registered for .hbs files' do
    Tilt['test.hbs'].must_equal Tilt::HandlebarsTemplate
  end

  it 'is registered for .handlebars files' do
    Tilt['test.handlebars'].must_equal Tilt::HandlebarsTemplate
  end

  it 'renders static template' do
    template = make_template "Hello World!" 
    template.render.must_equal "Hello World!"
  end

  it "can be rendered more than once" do
    template = make_template "Hello World!" 
    3.times { template.render.must_equal "Hello World!" }
  end

  it "substitutes locals in template" do
    template = make_template "Hey {{ name }}!" 
    template.render(nil, :name => 'Joe').must_equal "Hey Joe!"
  end

  it "displays nested properties" do
    template = make_template "Hey {{ person.name }}!" 
    template.render(nil, :person => { :name => 'Joe' }).must_equal "Hey Joe!"
  end

  it "displays text from block" do
    template = make_template "Deck the halls. Fa {{ yield }}."
    rendered = template.render(nil) { "la la la la"}
    rendered.must_equal "Deck the halls. Fa la la la la."
  end


  describe "arrays" do
   shopping_list = %w[milk eggs flour sugar]

   it "displays element from array" do
      template = make_template "Don't forget the {{ shopping_list.[1] }}!"
      template.render(nil, :shopping_list => shopping_list).must_equal "Don't forget the eggs!"
    end

    it "displays elements in an array in a loop" do
      template = make_template 'Items to buy:{{#each shopping_list}} {{ this }}{{/each}}' 
      template.render(nil, :shopping_list => shopping_list).must_equal "Items to buy: milk eggs flour sugar"
    end

    it "displays alternate text when array is empty" do
      template = make_template 'Items to buy:{{#each shopping_list}} {{ this }}{{else}} All done!{{/each}}' 
      template.render(nil, :shopping_list => []).must_equal "Items to buy: All done!"
    end  
  end

  describe "conditionals" do
    template = make_template '{{#if morning}}Good morning{{else}}Hello{{/if}}, {{ name }}'

    it "displays text if value is true" do
      template.render(nil, :name => 'Joe', :morning => true).must_equal "Good morning, Joe"
    end

    it "displays alternate text if value is false" do
      template.render(nil, :name => 'Joe', :morning => false).must_equal "Hello, Joe"
    end

    it "displays alternate text if value is missing" do
      template.render(nil, :name => 'Joe').must_equal "Hello, Joe"
    end
  end

  describe "unless expressions" do
    template = make_template 'Hello, {{ name }}.{{#unless weekend}} Time to go to work.{{/unless}}'

    it "displays text if value is false" do
      template.render(nil, :name => 'Joe', :weekend => false).must_equal "Hello, Joe. Time to go to work."
    end

    it "does not display text if value is true" do
      template.render(nil, :name => 'Joe', :weekend => true).must_equal "Hello, Joe."
    end

    it "displays text if value is missing" do
      template.render(nil, :name => 'Joe').must_equal "Hello, Joe. Time to go to work."
    end
  end

  describe "escape HTML" do
    it "escapes HTML characters" do
      template = make_template "Hey {{ name }}!" 
      template.render(nil, :name => '<b>Joe</b>' ).must_equal "Hey &lt;b&gt;Joe&lt;/b&gt;!"
    end

    it "does not escape HTML characters in triple-stash" do
      template = make_template "Hey {{{ name }}}!" 
      template.render(nil, :name => '<b>Joe</b>' ).must_equal "Hey <b>Joe</b>!"
    end
  end

  describe "helpers" do
    it "applies helper to static text" do
      template = make_template '{{#upper}}Hello, World.{{/upper}}'
      template.register_helper(:upper) do |this, block|
        block.fn(this).upcase
      end

      template.render.must_equal "HELLO, WORLD."
    end      

    it "applies helper to nested values" do
      template = make_template '{{#upper}}Hey {{name}}{{/upper}}!'
      template.register_helper(:upper) do |this, block|
        block.fn(this).upcase
      end

      template.render(nil, :name => 'Joe').must_equal "HEY JOE!"
    end      

    it "displays properties from object using 'with' helper" do
      template = make_template '{{#with person}}Hello, {{ first_name }} {{ last_name }}{{/with}}'
      joe = Person.new "Joe", "Blow"
      template.render(nil, :person => joe).must_equal "Hello, Joe Blow"    
    end

  end

  describe "using scope object to render template" do
    class Person
      attr_reader :first_name, :last_name

      def initialize(first_name, last_name)
        @first_name = first_name
        @last_name = last_name
      end
    end

    class HashPerson
      attr_reader :first_name, :last_name

      def initialize(first_name, last_name)
        @first_name = first_name
        @last_name = last_name
      end

      def to_h
        { first_name: @first_name, last_name: @last_name }
      end
    end

    joe = Person.new "John", "Doe"

    it "displays properties of object passed as scope" do
      template = make_template "Hello, {{ first_name }} {{ last_name }}."
      template.render(joe).must_equal "Hello, John Doe."
    end

    it "merges scope object properties with locals" do
      template = make_template "{{ greeting }}, {{ first_name }} {{ last_name }}."
      template.render(joe, :greeting => "Salut").must_equal "Salut, John Doe."
    end

    it "prefers locals over scope object properties with same name" do
      template = make_template "Hello, {{ first_name }} {{ last_name }}."
      template.render(joe, :first_name => "Jane").must_equal "Hello, Jane Doe."
    end

    it "prefers locals over scope object properties with same name when object defines to_h" do
      joe_hash = HashPerson.new "John", "Doe"

      template = make_template "Hello, {{ first_name }} {{ last_name }}."
      template.render(joe_hash, :first_name => "Jane").must_equal "Hello, Jane Doe."
    end
  end

  describe "comments" do
    it "does not render comments" do
      template = make_template "Hello world{{! what a wonderful world }}"
      template.render.must_equal "Hello world"   
    end

    it "does not render comments, alternative syntax" do
      template = make_template "Hello world{{!-- what a wonderful world --}}"
      template.render.must_equal "Hello world"   
    end
  end

  describe "partials" do
    it "displays content of partial" do
      template = make_template "{{> greeting}}. Nice to meet you."
      template.register_partial :greeting, "Hey, {{name}}"
      template.render(nil, :name => "Joe").must_equal "Hey, Joe. Nice to meet you."      
    end

    it "calls registeded method if partial is missing" do
      template = make_template "{{> where}} I've been looking for you."
      template.partial_missing do |partial_name|
        "Where have you been, {{name}}?" if partial_name == 'where'
      end
      template.render(nil, :name => "Joe").must_equal "Where have you been, Joe? I've been looking for you."
    end
  end
end


