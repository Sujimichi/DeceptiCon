require 'spec_helper'
require 'fileutils'


class RSpec::Core::Probe
  attr_accessor :format
  def data *args
  end
end


class RSpec::Core::ExampleGroup
  def get *args
    p = RSpec::Core::Probe.new
    p.request_type = :get
    p.format = @request.env['HTTP_ACCEPT'] || "application/html"
    p.data(args)
  end
  def post *args
    p = RSpec::Core::Probe.new
    p.request_type = :post
    p.format = @request.env['HTTP_ACCEPT'] || "application/html"
    p.data(args)
  end
  def put *args
    p = RSpec::Core::Probe.new
    p.request_type = :put
    p.format = @request.env['HTTP_ACCEPT'] || "application/html"
    p.data(args)
  end
  def delete *args
    p = RSpec::Core::Probe.new
    p.request_type = :delete
    p.format = @request.env['HTTP_ACCEPT'] || "application/html"
    p.data(args)
  end
  
  def xhr *args
    p = RSpec::Core::Probe.new
    p.request_type = args[0].to_sym
    p.format = "application/js"
    p.data(args)
  end
  
end




include DeceptiCon 
describe DeceptiCon do 


  describe "fetch" do 
    before(:each) do 
      @probe = RSpec::Core::Probe.new
      RSpec::Core::Probe.stub!(:new => @probe)
      @request.stub!(:env => {})
    end



    describe "html requests" do 

      describe "GET requests" do 
        before(:each) do 
          @probe.should_receive(:request_type=).with(:get)
          @probe.should_receive(:format=).with("application/html")
        end

        it 'should call get with index' do 
          @probe.should_receive(:data).with([:index])
          fetch :html, :index
        end

        it 'should call get with index and args' do 
          @probe.should_receive(:data).with([:index, {:limit => 10}, nil, {:message => "yo"}])
          fetch :html, :index, {:limit => 10}, nil, {:message => "yo"}
        end

        it 'should call get with show and args' do 
          @probe.should_receive(:data).with([:show, {:id => 2}, {:user_id => 42}, {:message => "flash message"}])
          fetch :html, :show, {:id => 2}, {:user_id => 42}, {:message => "flash message"}
        end

        it 'should call get with new and args' do 
          @probe.should_receive(:data).with([:new, {:id => 2}, {:user_id => 42}, {:message => "flash message"}])
          fetch :html, :new , {:id => 2}, {:user_id => 42}, {:message => "flash message"}
        end

        it 'should call get with edit and args' do 
          @probe.should_receive(:data).with([:edit, {:id => 2}, {:user_id => 42}, {:message => "flash message"}])
          fetch :html, :edit, {:id => 2}, {:user_id => 42}, {:message => "flash message"}
        end
      end
      describe "POST requests" do 
        before(:each) do 
          @probe.should_receive(:request_type=).with(:post)
        end

        it 'should call post with create' do 
          @probe.should_receive(:data).with([:create, {:object => {:name => "test"}, :opt => "something"}])
          fetch :html, :create, {:object => {:name => "test"}, :opt => "something"}
        end
      end      

    end
    describe "ajax requests" do 
      describe "GET requests" do 
        before(:each) do 
          @probe.should_receive(:request_type=).with(:get)
          @probe.should_receive(:format=).with("application/js")
        end

        it 'should call get with index' do 
          @probe.should_receive(:data).with([:get, :index])
          fetch :ajax, :index
        end
      end
    end

   describe "json requests" do 
      describe "GET requests" do 
        before(:each) do 
          @probe.should_receive(:request_type=).with(:get)
          @probe.should_receive(:format=).with("application/json")
        end

        it 'should call get with index' do 
          @probe.should_receive(:data).with([:index])
          fetch :json, :index
        end
      end
    end

  end

end
