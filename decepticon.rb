module DeceptiCon
  
  Actions = [:index, :show, :new, :create, :edit, :update, :destroy]
  Formats = [:html, :ajax, :xml, :json] #:js and :ajax are synonymouse (and L is for dyslexcia)

  def assert_mapping
    formats = @test_formats #allow over-ride of formats to test
    formats ||= $default_test_formats
    formats ||= Formats #otherwise use default set.
    defaults = default_mapping(formats) #get a default mapping for the given formats. Default has all expectations as false ie should_not be_success
    @skip_actions ||= []
    actions = Actions - @skip_actions
    actions.each do |action| 
      @action_mapping[action] ||= {} #in case action has not been supplied
      mapping = defaults[action].merge(@action_mapping[action]) #merge supplied mapping for action over defaults for action
      #mapping must be a hash with {format => true/false} for each format, and optional args to be passed in with the params.  args can be on the keys :args or <format>_args where format is one of the allowed formats.
      object_class = @object  #@object is a class ie Entity or JvrModel.  
      #@object and @action_mapping should be defined in the controller which is being tested.

      class_name = object_class.to_s.underscore
      mapping.each do |format, expected_outcome|
        next unless formats.include?(format) #do I even need to comment this line.  Ruby is basicaly runnable comments!

        it "should #{expected_outcome.eql?(false) ? 'NOT ' : '' }respond to #{action}:#{format}" do #Define an rspec test step

          request.env["HTTP_REFERER"] = "/" #set somewhere for :back to point at if any actions redirect_to :back
          #valid_obj = send("valid_#{class_name}") unless object_class.nil? #create a valid object for the object_class.  Assumes methods for each resourse ie valid_entity, valid_jvr_model etc. 
          valid_obj = get_valid_object_for_class(object_class, class_name) unless object_class.nil?

          params = {} #params is an empty hash by default.
          unless [:index, :new].include?(action) #only :index and create actions do not require an :id to be supplied
            params = {:id => valid_obj.id} if valid_obj #set the id of the valid_object in the params
            params = {:id => 1} unless valid_obj && expected_outcome #If the controller is for a non DB resource (so no valid_obj) and the expected_outcome is false, then just use '1' for the :id
          end
          if action.eql?(:create) #create requires that the params have the object included ie {:entity => {attributes} }
            object_class.stub!(:new => valid_obj) if valid_obj  #force the return of a valid object from Object.new
            params = {class_name.to_sym => object_class.new.attributes} unless object_class.nil? #include attributes for the object in the params 
          end
          if action.eql?(:update) #upate requires both an :id and the object attributes to update.
            params = {:id => valid_obj.id, class_name.to_sym => valid_obj.attributes} if valid_obj
          end

          mapping[:args] ||= {}
          mapping[:args].merge!(mapping["#{format}_args".to_sym]) if mapping.has_key?("#{format}_args".to_sym) #merge mapping[:args] with args for format, ie: mapping[:ajax_args]
          #args which are strings are eval'd.  this allows methods like with valid_object to be called here so they are in scope.  Its not ideal.  Actualy string need to be passed inside string ie "'foo'"
          extra_params = mapping[:args].map{|k,v| v.is_a?(String) ? { k => eval(v) } : {k => v} }.inject{|i,j| i.merge(j)} 
          params.merge!(extra_params) unless extra_params.nil? #merge the args from mapping with the base args.
  
          fetch(format, action, params) #Call the request using fetch.  format is either :html or :ajax, action is one of [:index, :show, :new, :create, :edit, :update, :destroy], params is a hash to supply in request.
          if expected_outcome.eql?(:redirect)
            assert_response(:redirect) 
          else
            expected_outcome.eql?(true) ? (response.should be_success) : (response.should_not be_success) #make assertion on the response.  
          end          
        end
      end
    end
  end

  def get_valid_object_for_class object_class, class_name
    begin
      obj = send("valid_#{class_name}") #attempt to call a method valid_<class_name.underscore> which should return a Factory object, ie; valid_entity or valid_jvr_model 
    rescue
      begin
        obj = Factory.build(class_name.to_sym, {}) #if a valid_<object> method was not found, try to use a Factory
        obj.save
      rescue
        obj = nil
      end
    end
    return obj if obj && obj.valid?

    puts "Warning - Neither the method 'valid_#{class_name}' or a Factory for #{class_name} could be found.  Add a Factory to build a valid #{class_name}.  Will Attempt to construct object nativly" unless obj
    puts "Warning - Generated #{class_name} was not valid #{obj.errors.inspect}.  #{class_name} must be valid, adjust your Factory.  Will add strings and integers to attributes to attempt to make valid" if obj
      
    obj ||= object_class.new
    obj.valid?
    begin
      obj.errors.each do |attr, err|
        obj.send("#{attr.to_s}=", "a string") #attempt to add a string
        obj.send("#{attr}=", 42) if obj.send("#{attr}").eql?(0) #or add an int if the string failed.
      end
    rescue
    end
    obj.valid? ? obj.save! : (raise "Unable to create a valid #{class_name}.  You must add a Factory or 'valid_#{class_name}' method.")
    obj
  end

  def get_action_lookup
    {
      :index => {:html => Proc.new{|*args| get :index, *args},      :ajax => Proc.new{|*args| xhr :get, :index, *args}}, 
      :show =>  {:html => Proc.new{|*args| get :show, *args},       :ajax => Proc.new{|*args| xhr :get, :show, *args}}, 
      :new =>   {:html => Proc.new{|*args| get :new, *args},        :ajax => Proc.new{|*args| xhr :get, :new, *args}}, 
      :create =>{:html => Proc.new{|*args| post :create, *args},    :ajax => Proc.new{|*args| xhr :post, :create, *args}}, 
      :edit =>  {:html => Proc.new{|*args| get :edit, *args},       :ajax => Proc.new{|*args| xhr :get, :edit, *args}}, 
      :update =>{:html => Proc.new{|*args| put :update, *args},     :ajax => Proc.new{|*args| xhr :put, :update, *args}}, 
      :destroy=>{:html => Proc.new{|*args| delete :destroy, *args}, :ajax => Proc.new{|*args| xhr :delete, :destroy, *args}}, 
    }
  end

  def default_mapping(formats)
    fmts = formats.map{|format| {format => false} }.inject{|i,j| i.merge(j)}
    Actions.map{|action| {action => fmts } }.inject{|i,j| i.merge(j)}
  end

  def fetch format, action, *args
    format = :ajax if format.eql?(:js)
    if [:json, :xml].include?(format)
      @request.env['HTTP_ACCEPT'] = "application/#{format}"
      format = :html
    end

    @al ||= get_action_lookup
    @al[action][format].call(*args)
  end  

end

