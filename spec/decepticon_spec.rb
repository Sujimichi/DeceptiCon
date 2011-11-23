require 'spec_helper'
require 'fileutils'


class RSpec::Core::Probe
  attr_accessor :data, :format, :block, :request_type
end


Struct.new("Request", :env)
Struct.new("Response", :success?)

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
    p.data(args[1..args.size-1])
  end

  def it test_message, &blk
    p = RSpec::Core::Probe.new
    p.data(test_message)
    unless @block_yield
      yield
    end
  end

  def request
    Struct::Request.new({'HTTP_ACCEPT' => ""})  
  end

  def response
    r = Struct::Response.new
  end



end

class TestObject
end

class String
  def underscore #replaces the rails underscore method which is not available in this test env
    self.split(/[a-z]/).select{|s| !s.empty?}.zip(self.split(/[A-Z]/).select{|s| !s.empty?}).map{|a| a.join}.join("_").downcase
  end
end

#Writing tests in rspec which test a method that creates rspec(rails) tests.
#

include DeceptiCon 
describe DeceptiCon do 
  before(:each) do 
    @probe = RSpec::Core::Probe.new
    @probe.stub!(:data)
    RSpec::Core::Probe.stub!(:new => @probe)
    @all_actions = [:index, :show, :new, :create, :edit, :update, :destroy]
  end


  describe "assert_mapping" do 
    before(:each) do 
      @request = Struct::Request.new({'HTTP_ACCEPT' => ""})  
      @resp = Struct::Response.new  
      Struct::Response.stub!(:new => @resp)
    end

    describe "calling 'it'" do 
      before(:each) do 
        @action_mapping = {
          :index => {:html => true,  :ajax => false}, 
          :show =>  {:html => true,  :ajax => true},
          :new =>   {:html => false, :ajax => false},
          :create =>{:html => true,  :ajax => false},
          :edit =>  {:html => false, :ajax => true},
          :update =>{:html => true,  :ajax => true},
          :destroy=>{:html => true,  :ajax => true},
        }
        @block_yield = true #don't yield the block passed to 'it' method
      end

      it "should call 'it' with the correct text" do 
        @probe.should_receive(:data).with("should respond to index:html") 
        @probe.should_receive(:data).with("should NOT respond to index:ajax")

        @probe.should_receive(:data).with("should respond to show:html")
        @probe.should_receive(:data).with("should respond to show:ajax")

        @probe.should_receive(:data).with("should NOT respond to new:html")
        @probe.should_receive(:data).with("should NOT respond to new:ajax")

        @probe.should_receive(:data).with("should respond to create:html")
        @probe.should_receive(:data).with("should NOT respond to create:ajax")

        @probe.should_receive(:data).with("should NOT respond to edit:html")
        @probe.should_receive(:data).with("should respond to edit:ajax")

        @probe.should_receive(:data).with("should respond to update:html")
        @probe.should_receive(:data).with("should respond to update:ajax")

        @probe.should_receive(:data).with("should respond to destroy:html")
        @probe.should_receive(:data).with("should respond to destroy:ajax")        

        assert_mapping    
      end
    end

    describe "asserting response" do 

      [:index, :show, :new, :create, :edit, :update, :destroy].each do |action|
        describe "#{action}" do 
          before(:each){ 
            @skip_actions = @all_actions - [action] 
            should_receive(:fetch).exactly(4).times
          }
          after( :each){ assert_mapping }

          it 'should require the expected boolean from response.succsess?' do 
            @action_mapping = {action => {:html => true, :ajax => false, :xml => false, :json => false}}
            @resp.should_receive(:success?).once.and_return(true)
            @resp.should_receive(:success?).once.and_return(false)
            @resp.should_receive(:success?).once.and_return(false)
            @resp.should_receive(:success?).once.and_return(false)
          end
          it 'should require the expected boolean from response.succsess?' do 
            @action_mapping = {action => {:html => false, :ajax => true, :xml => false, :json => false}}
            @resp.should_receive(:success?).once.and_return(false)
            @resp.should_receive(:success?).once.and_return(true)
            @resp.should_receive(:success?).once.and_return(false)
            @resp.should_receive(:success?).once.and_return(false)
          end
          it 'should require the expected boolean from response.succsess?' do 
            @action_mapping = {action => {:html => false, :ajax => false, :xml => true, :json => false}}
            @resp.should_receive(:success?).once.and_return(false)
            @resp.should_receive(:success?).once.and_return(false)
            @resp.should_receive(:success?).once.and_return(true)
            @resp.should_receive(:success?).once.and_return(false)
          end
          it 'should require the expected boolean from response.succsess?' do 
            @action_mapping = {action => {:html => false, :ajax => false, :xml => false, :json => true}}
            @resp.should_receive(:success?).once.and_return(false)
            @resp.should_receive(:success?).once.and_return(false)
            @resp.should_receive(:success?).once.and_return(false)
            @resp.should_receive(:success?).once.and_return(true)
          end

        end
      end
    end

    describe "defaults and over-riding default values" do 
      before(:each) do 
        obj = TestObject.new
        obj.stub!(:valid? => true, :save! => true, :id => 42, :attributes => {:name => nil,:text => nil} )
        should_receive(:valid_test_object).any_number_of_times.and_return(obj) #assert the valid_object method is called and return a valid object
        @object = TestObject
      end

      it 'should test all actions and formats as false when none are given' do 
        @action_mapping = {} #no mappings set
        should_receive(:fetch).exactly(7*4).times  #for each 7 actions for each 4 formats
        @resp.should_receive(:success?).exactly(7*4).times.and_return(false)
        assert_mapping
      end
      it 'should test all actions and formats as false except those specified' do 
        @action_mapping = {:create => {:html => true}} #no mappings set
        should_receive(:fetch).exactly(7*4).times  #for each 7 actions for each 4 formats
        @resp.should_receive(:success?).exactly(12).times.and_return(false) #first 12 return false
        @resp.should_receive(:success?).exactly(1).times.and_return(true)   #13th (for html#create) returns true
        @resp.should_receive(:success?).exactly(15).times.and_return(false) #rest return false
        assert_mapping
      end

      it 'should skip tests for given actions' do 
        @action_mapping = {} #no mappings set
        @skip_actions = [:index, :show, :update]

        [:html, :ajax, :xml, :json].each do |format|
          should_not_receive(:fetch).with(format, :index, {})
          should_not_receive(:fetch).with(format, :show, {})
          should_receive(:fetch).exactly(1).times.with(format, :new, {})
          should_receive(:fetch).exactly(1).times.with(format, :create,  {:test_object => {:name => nil, :text => nil}})
          should_receive(:fetch).exactly(1).times.with(format, :edit, {:id => 1})
          should_not_receive(:fetch).with(format, :update, {})
          should_receive(:fetch).exactly(1).times.with(format, :destroy, {:id => 1  })
        end       
        @resp.should_receive(:success?).exactly(16).and_return(false)
        assert_mapping
      end

      it 'should only tests specified formats when given' do 
        @action_mapping = {} #no mappings set
        @test_formats = [:html, :json]

        [:html, :json].each do |format|
          should_receive(:fetch).exactly(1).times.with(format, :index, {})
          should_receive(:fetch).exactly(1).times.with(format, :show, {:id => 1})
          should_receive(:fetch).exactly(1).times.with(format, :new, {})
          should_receive(:fetch).exactly(1).times.with(format, :create,  {:test_object => {:name => nil, :text => nil} })
          should_receive(:fetch).exactly(1).times.with(format, :edit, {:id => 1})
          should_receive(:fetch).exactly(1).times.with(format, :update, {:test_object => {:name => nil, :text => nil}, :id => 42})
          should_receive(:fetch).exactly(1).times.with(format, :destroy, {:id => 1  })
        end       

        [:xml, :ajax].each do |format|
          should_not_receive(:fetch).with(format, :index, {})
          should_not_receive(:fetch).with(format, :show, {:id => 1})
          should_not_receive(:fetch).with(format, :new, {})
          should_not_receive(:fetch).with(format, :create,  {:test_object => {:name => nil, :text => nil} })
          should_not_receive(:fetch).with(format, :edit, {:id => 1})
          should_not_receive(:fetch).with(format, :update, {:test_object => {:name => nil, :text => nil}, :id => 42})
          should_not_receive(:fetch).with(format, :destroy, {:id => 1  })
        end       

        @resp.should_receive(:success?).exactly(14).and_return(false)
        assert_mapping

      end
    end


    describe "calling fetch with format, args and action:" do 
      before(:each) do 
        obj = TestObject.new
        obj.stub!(:valid? => true, :save! => true, :id => 42, :attributes => {:name => nil,:text => nil} )
        should_receive(:valid_test_object).any_number_of_times.and_return(obj) #assert the valid_object method is called and return a valid object
        @object = TestObject
        @resp.should_receive(:success?).exactly(4).times.and_return(true)
      end

      describe "index" do 
        before(:each){ @skip_actions = @all_actions - [:index] }
        it 'should call fetch for each format with args for index' do 
          @action_mapping = {:index => {:html => true, :ajax => true, :xml => true, :json => true}}
          should_receive(:fetch).once.ordered.with(:html, :index, {})
          should_receive(:fetch).once.ordered.with(:ajax, :index, {})
          should_receive(:fetch).once.ordered.with(:xml, :index, {})
          should_receive(:fetch).once.ordered.with(:json, :index, {})
          assert_mapping    
        end
      end

      describe "show" do 
        before(:each){ @skip_actions = @all_actions - [:show] }
        it 'should call fetch for each format with args for show' do 
          @action_mapping = {:show => {:html => true, :ajax => true, :xml => true, :json => true}}
          should_receive(:fetch).once.with(:html, :show, {:id => 42})
          should_receive(:fetch).once.with(:ajax, :show, {:id => 42})
          should_receive(:fetch).once.with(:xml,  :show, {:id => 42})
          should_receive(:fetch).once.with(:json, :show, {:id => 42})
          assert_mapping
        end 
      end      

      describe "new" do 
        before(:each){ @skip_actions = @all_actions - [:new] }
        it 'should call fetch for each format with args for new' do 
          @action_mapping = {:new => {:html => true, :ajax => true, :xml => true, :json => true}}
          should_receive(:fetch).once.with(:html, :new, {})
          should_receive(:fetch).once.with(:ajax, :new, {})
          should_receive(:fetch).once.with(:xml,  :new, {})
          should_receive(:fetch).once.with(:json, :new, {})
          assert_mapping
        end 
      end      

      describe "create" do 
        before(:each){ @skip_actions = @all_actions - [:create] }
        it 'should call fetch for each format with args for create' do 
          @action_mapping = {:create => {:html => true, :ajax => true, :xml => true, :json => true}}
          should_receive(:fetch).once.with(:html, :create, {:test_object => {:name => nil, :text => nil} })
          should_receive(:fetch).once.with(:ajax, :create, {:test_object => {:name => nil, :text => nil} })
          should_receive(:fetch).once.with(:json, :create, {:test_object => {:name => nil, :text => nil} })
          should_receive(:fetch).once.with(:xml,  :create, {:test_object => {:name => nil, :text => nil} })
          assert_mapping
        end 
      end

      describe "edit" do 
        before(:each){ @skip_actions = @all_actions - [:edit] }
        it 'should call fetch for each format with args for edit' do 
          @action_mapping = {:edit => {:html => true, :ajax => true, :xml => true, :json => true}}
          should_receive(:fetch).once.with(:html, :edit, {:id => 42})
          should_receive(:fetch).once.with(:ajax, :edit, {:id => 42})
          should_receive(:fetch).once.with(:xml,  :edit, {:id => 42})
          should_receive(:fetch).once.with(:json, :edit, {:id => 42})
          assert_mapping
        end 
      end      

      describe "update" do 
        before(:each){ @skip_actions = @all_actions - [:update] }
        it 'should call fetch for each format with args for update' do 
          @action_mapping = {:update => {:html => true, :ajax => true, :xml => true, :json => true}}
          should_receive(:fetch).once.with(:html, :update, {:test_object => {:name => nil, :text => nil}, :id => 42 })
          should_receive(:fetch).once.with(:ajax, :update, {:test_object => {:name => nil, :text => nil}, :id => 42 })
          should_receive(:fetch).once.with(:json, :update, {:test_object => {:name => nil, :text => nil}, :id => 42 })
          should_receive(:fetch).once.with(:xml,  :update, {:test_object => {:name => nil, :text => nil}, :id => 42 })
          assert_mapping
        end 
      end

      describe "destroy" do 
        before(:each){ @skip_actions = @all_actions - [:destroy] }
        it 'should call fetch for each format with args for edit' do 
          @action_mapping = {:destroy => {:html => true, :ajax => true, :xml => true, :json => true}}
          should_receive(:fetch).once.with(:html, :destroy, {:id => 42})
          should_receive(:fetch).once.with(:ajax, :destroy, {:id => 42})
          should_receive(:fetch).once.with(:xml,  :destroy, {:id => 42})
          should_receive(:fetch).once.with(:json, :destroy, {:id => 42})
          assert_mapping
        end 
      end     
    end
  end

  describe "fetch" do 
    before(:each) do 
      @request = Class.new
      @request.stub!(:env => {})
    end
    describe "ajax and js are interchangeable" do 
      it 'should work for ajax' do 
        @probe.should_receive(:request_type=).with(:get)
        @probe.should_receive(:format=).with("application/js")
        @probe.should_receive(:data).with([:index])
        fetch :ajax, :index
      end
      it 'should work for js' do 
        @probe.should_receive(:request_type=).with(:get)
        @probe.should_receive(:format=).with("application/js")
        @probe.should_receive(:data).with([:index])
        fetch :js, :index
      end

    end

    [:html, :ajax, :xml, :json].each do |format|


      describe "GET, POST, PUT and DELETE requests for #{format}" do 
        before(:each) do 
          @probe.should_receive(:format=).with("application/#{format.eql?(:ajax) ? :js : format}")
        end

        it 'should call get with index' do 
          @probe.should_receive(:request_type=).with(:get)
          @probe.should_receive(:data).with([:index])
          fetch format, :index
        end

        it 'should call get with index and args' do 
          @probe.should_receive(:request_type=).with(:get)
          @probe.should_receive(:data).with([:index, {:limit => 10}, nil, {:message => "yo"}])
          fetch format, :index, {:limit => 10}, nil, {:message => "yo"}
        end

        it 'should call get with show and args' do 
          @probe.should_receive(:request_type=).with(:get)
          @probe.should_receive(:data).with([:show, {:id => 2}, {:user_id => 42}, {:message => "flash message"}])
          fetch format, :show, {:id => 2}, {:user_id => 42}, {:message => "flash message"}
        end

        it 'should call get with new and args' do 
          @probe.should_receive(:request_type=).with(:get)
          @probe.should_receive(:data).with([:new, {:id => 2}, {:user_id => 42}, {:message => "flash message"}])
          fetch format, :new , {:id => 2}, {:user_id => 42}, {:message => "flash message"}
        end

        it 'should call get with edit and args' do 
          @probe.should_receive(:request_type=).with(:get)
          @probe.should_receive(:data).with([:edit, {:id => 2}, {:user_id => 42}, {:message => "flash message"}])
          fetch format, :edit, {:id => 2}, {:user_id => 42}, {:message => "flash message"}
        end

        it 'should call post with create and args' do 
          @probe.should_receive(:request_type=).with(:post)
          @probe.should_receive(:data).with([:create, {:object => {:name => "test"}, :opt => "something"}])
          fetch format, :create, {:object => {:name => "test"}, :opt => "something"}
        end

        it 'should call put with update and args' do 
          @probe.should_receive(:request_type=).with(:put)
          @probe.should_receive(:data).with([:update, {:object => {:name => "test"}, :id => 12}])
          fetch format, :update, {:object => {:name => "test"}, :id => 12}
        end

        it 'should call post with destroy and args' do 
          @probe.should_receive(:request_type=).with(:delete)
          @probe.should_receive(:data).with([:destroy, {:object => {:name => "test"}, :opt => "something"}])
          fetch format, :destroy, {:object => {:name => "test"}, :opt => "something"}
        end

      end      


    end

  end

end
