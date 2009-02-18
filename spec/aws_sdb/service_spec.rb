require File.dirname(__FILE__) + '/../spec_helper.rb'

require 'digest/sha1'
require 'net/http'
require 'rexml/document'

require 'rubygems'
require 'uuidtools'

include AwsSdb

# Setting this to false slows down the specs (by recreating the domain each
# time) but makes things cleaner
reuse_test_domain = true

def uuid
  UUID.random_create.to_s.gsub('-', '_')
end

def delete_test_domain
  @domain = "test_#{uuid}"
  domains = @service.list_domains[0]
  domains.each do |d|
    @service.delete_domain(d) if d =~ /^test/
  end
end

describe Service, "when creating a new domain" do
  before(:all) do
    @service = AwsSdb::Service.new
    delete_test_domain
  end

  after(:all) do
    @service.delete_domain(@domain)
  end

  it "should not raise an error if a valid new domain name is given" do
    lambda {
      @service.create_domain("test_#{uuid}")
    }.should_not raise_error
  end

  it "should not raise an error if the domain name already exists" do
    domain = "test_#{uuid}"
    lambda {
      @service.create_domain(domain)
      @service.create_domain(domain)
    }.should_not raise_error
  end

  it "should raise an error if an a nil or '' domain name is given" do
    lambda {
      @service.create_domain('')
    }.should raise_error(InvalidParameterValueError)
    lambda {
      @service.create_domain(nil)
    }.should raise_error(InvalidParameterValueError)
    lambda {
      @service.create_domain('     ')
    }.should raise_error(InvalidParameterValueError)
  end

  it "should raise an error if the domain name length is < 3 or > 255" do
    lambda {
      @service.create_domain('xx')
    }.should raise_error(InvalidParameterValueError)
    lambda {
      @service.create_domain('x'*256)
    }.should raise_error(InvalidParameterValueError)
  end

  it "should only accept domain names with a-z, A-Z, 0-9, '_', '-', and '.' " do
    lambda {
      @service.create_domain('@$^*()')
    }.should raise_error(InvalidParameterValueError)
  end

  it "should only accept a maximum of 100 domain names"

  it "should not have to call amazon to determine domain name correctness"
end

describe Service, "when listing domains" do
  before(:all) do
    @service = AwsSdb::Service.new
    delete_test_domain
    @service.create_domain(@domain)
  end

  after(:all) do
    @service.delete_domain(@domain)
  end

  it "should return a complete list" do
    result = nil
    lambda { result = @service.list_domains[0] }.should_not raise_error
    result.should_not be_nil
    result.should_not be_empty
    result.include?(@domain).should == true
  end
end

describe Service, "when deleting domains" do
  before(:all) do
    @service = AwsSdb::Service.new
    delete_test_domain
    @service.create_domain(@domain)
  end

  after do
    @service.delete_domain(@domain)
  end

  it "should be able to delete an existing domain" do
    lambda { @service.delete_domain(@domain) }.should_not raise_error
  end

  it "should not raise an error trying to delete a non-existing domain" do
    lambda {
      @service.delete_domain(uuid)
    }.should_not raise_error
  end
end

describe Service, "when managing items" do
  before(:all) do
    @service = AwsSdb::Service.new
    unless reuse_test_domain
      delete_test_domain
      @service.create_domain(@domain)
      @item = "test_#{uuid}"
    else
      @domain = "test_service_spec"
      @service.create_domain(@domain) unless @service.list_domains[0].member?(@domain)
      @item = "test_foo"
    end
    @attributes = {
      :question => 'What is the answer?',
      :answer => [ true, 'testing123', 4.2, 42, 420 ]
    }
  end

  after(:all) do
    @service.delete_domain(@domain) unless reuse_test_domain
  end

  it "should be able to put attributes" do
    lambda {
      @service.put_attributes(@domain, @item, @attributes)
    }.should_not raise_error
  end

  it "should be able to get attributes" do
    result = nil
    lambda {
      result = @service.get_attributes(@domain, @item)
    }.should_not raise_error
    result.should_not be_nil
    result.should_not be_empty
    result.has_key?('answer').should == true
    @attributes[:answer].each do |v|
      result['answer'].include?(v.to_s).should == true
    end
  end

  it "should be able to query" do
    # NOTE: depends on the "should be able to put attributes" running before it
    result = nil
    lambda {
      result = @service.query(@domain, "[ 'answer' = '42' ]")[0]
    }.should_not raise_error
    result.should_not be_nil
    result.should_not be_empty
    result.should_not be_nil
    result.include?(@item).should == true
  end

  it "should be able to select" do
    # NOTE: depends on the "should be able to put attributes" running before it
    result = nil
    lambda {
      result = @service.select("select * from #{@domain} where answer = '42'")[0]
    }.should_not raise_error
    result.should_not be_nil
    result.should_not be_empty
    result.should_not be_nil

    result[0]["Name"].should == @item
  end

  it "should be able to query with attributes"

  it "should be able to delete attributes" do
    lambda {
      @service.delete_attributes(@domain, @item)
    }.should_not raise_error
  end
end


# Unlike the above specs, these specs don't actually call SimpleDB

describe Service, "#query" do
  before(:all) do
    @service = AwsSdb::Service.new
    @service.stub! :call
    @domain = 'foo'
  end

  it "should query" do
    params = {"Action"=>"Query", "QueryExpression"=>"[ 'answer' = '42' ]", "DomainName"=>"foo"}
    @service.should_receive(:call).with(:get, params).and_return(REXML::Document.new())
    result = @service.query(@domain, "[ 'answer' = '42' ]")[0]
    result.should == []
  end
end

describe Service, "#select" do
  before(:all) do
    @service = AwsSdb::Service.new
    @service.stub! :call
  end

  it "should select" do
    params = {"Action"=>"Select", "SelectExpression"=>"select * from foo where Name = 'bar'"}
    @service.should_receive(:call).with(:get, params).and_return(REXML::Document.new())
    result = @service.select("select * from foo where Name = 'bar'")
  end
end

# TODO Pull the specs from the amazon docs and write more rspec
# 100 attributes per each call
# 256 total attribute name-value pairs per item
# 250 million attributes per domain
# 10 GB of total user data storage per domain
# ...etc...
