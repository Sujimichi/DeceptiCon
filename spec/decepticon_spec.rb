require 'spec_helper'

#Ok, these tests are nearly as insane as me, or as stupid, I'm not sure.  In anycase they need some explaination.
#
#The +fetch+ method (which everything else depends on) just allows arguments of a comparible structure to be passed to the appropriate 'get', 'put', 'post', 'delete', or 'xhr' method.
#For example 
# fetch :html, :show,    {:id => 42} --> get :show, {:id => 42}
# fetch :html, :destroy, {:id => 42} --> delete :show, {:id => 42}
# fetch :ajax, :edit,    {:id => 42} --> xhr :get, :edit, {:id => 42}
#
#So the tests for +fetch+ just need to ensure that given certain args it calls the appropriate method with the correct args.  However....
#'get', 'put', 'post', 'delete', and 'xhr' are methods provided by rspec-rails, they are not available here, which is fine, but the tests need to have a handel on whatever object those methods are called on (which I'm sure someone wiser would just know!).  
#I have to confess this was not true TTD, I had to get it working till it was trying to call a method and then see what object was throwing an undefined method error.  This is what I got.
# undefined method `get' for #<RSpec::Core::ExampleGroup::Nested_1::Nested_2::Nested_5:0x00000003716be8>
#
#wtf is a Nested_n?  And its not always the same n.  Skipping merryily arround my ignorance, I found that if I defined the get method on RSpec::Core::ExampleGroup it would get called.
#However because it was called on a Nested_whatever I could not do something like this;
# instance = Nested_1.new
# instance.should_receive(:get).with(<stuff>) 
# Nested_1.stub!(:new => instance)
#
#I could not get a handle on the instance of whatever get was called on.  While I could raise the args being sent to the method defined on RSpec::Core::ExampleGroup, as it is not an instance of RSpec::Core::ExampleGroup that has the method called on it I could not use this to get a handel on the instance. This is where my approch is perhaps a little nutts.
#
#I have a Probe class defined and a new instance of a probe is called in each of the methods I defined on RSpec::Core::ExampleGroup.  The probe is passed the args of the method and the name of the method (and maybe some other stuff) and thats it.  Oh wait, no its not;
#Before each test a new instance of Probe is assigned to @probe and that instance is stubbed to be returned from Probe.new.  So when the methods on RSpec::Core::ExampleGroup invoke a new Probe it's actually @probe that they get.  Therefore assertions can be made about what is passed to the probe. ie;
# @probe.should_receive(:data).with(:show, {:id => 42})
# @probe.request_type.should == :get
#
#The Probe class is terrifyingly complex as you can see.  It really is just a class with some attr_accessors.  The only reason +data+ is a defined method is that I wanted to be able to write 
# @probe.should_receive(:data).with(:show, {:id => 42})
#
#rather than
# @probe.should_receive(:data=).with(:show, {:id => 42})
#
#The main method of DeceptiCon is the assert_mapping method which generates the tests.  The aim of test for this method is to assert that the rspec method 'it' is called with a message and a block.
#Again I have used a probe inside a methods 'it' defined on RSpec::Core::ExampleGroup.  It only passes the message text to the probe.  yield is called on the block, unless a var @dont_yield is set to true.  The probe can be used for to make assertions about the message text.  As far as the block goes, we are now using rspec to test code which itself writes rspec tests.  
#
#The generated test needs to call to either response.should be_success or response.should_not be_success.  By again defining a response method on RSpec::Core::ExampleGroup I could get a handel on response and stub in an object that assertions can be made on.  The assertion is that it should receive :success? but how to test if it is should or should_not.  By setting what success? returns the assertions in the test being tested will throw exceptions if they don't get what they expect.  
#So if the test is that the response should be successful then on the object returned from response, ie @resp I put;
# @resp.should_receive(:success?).and_return(true)
#If false was used then the test would fail, becuase the test being tested would fail.  If the expectation is for the response to not be_success, then @resp needs to return false. 
#
#
class RSpec::Core::Probe
  attr_accessor :format, :block, :request_type
  def data *args
    @data = args
  end
end


Struct.new("Request", :env)
Struct.new("Response", :success?)

class RSpec::Core::ExampleGroup
  def get *args
    p = RSpec::Core::Probe.new
    p.request_type = :get #This is set here so that last I can assert that the probe in question is infact the one assigned to this method.
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
    unless @dont_yield
      yield
    end
  end

  def request
    Struct::Request.new({'HTTP_ACCEPT' => ""})  
  end

  def response
    r = Struct::Response.new
  end

  def assert_response args
    p = RSpec::Core::Probe.new
    p.data(args)   
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

include DeceptiCon 

describe DeceptiCon do 
  before(:each) do 
    @probe = RSpec::Core::Probe.new
    RSpec::Core::Probe.stub!(:new => @probe)
    @all_actions = [:index, :show, :new, :create, :edit, :update, :destroy]
  end

  describe "fetch" do 
    before(:each) do 
      @request = Class.new
      @request.stub!(:env => {})
    end

    [:html, :ajax, :xml, :json].each do |format|

      describe "GET, POST, PUT and DELETE requests for #{format}" do 
        before(:each) do 
          @probe.should_receive(:format=).with("application/#{format.eql?(:ajax) ? :js : format}")
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
    
  end

  describe "assert_mapping" do 
    before(:each) do 
      @request = Struct::Request.new({'HTTP_ACCEPT' => ""})  
      @resp = Struct::Response.new  
      Struct::Response.stub!(:new => @resp)
    end

    describe "calling the method 'it' with the correct message text" do 
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
        @dont_yield = true #don't yield the block passed to 'it' method
        @probe.stub!(:data)
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


    #
    describe "expected response" do 
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

      [:index, :show, :new, :create, :edit, :update, :destroy].each do |action|
        describe "assert redirect" do 
        
          before(:each){ 
            @action = action
            @skip_actions = @all_actions - [@action] 
            should_receive(:fetch).exactly(4).times
          }
          after(:each){ assert_mapping }

          it "should assert the response was redirected (#{action})" do 
            @action_mapping = {@action => {:html => :redirect, :ajax => :redirect, :xml => :redirect, :json => :redirect}}
            @probe.should_receive(:data).with("should redirect requests to #{@action}:html")
            @probe.should_receive(:data).with("should redirect requests to #{@action}:ajax")
            @probe.should_receive(:data).with("should redirect requests to #{@action}:xml")
            @probe.should_receive(:data).with("should redirect requests to #{@action}:json")
            @probe.should_receive(:data).with(:redirect).exactly(4).times
            @resp.should_not_receive(:success?)
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

end
