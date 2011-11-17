module DeceptiCon

  def test_mapping
    formats = [:html, :ajax]
    @action_mapping.each do |action, mapping|  #action must be one of [:index, :show, :new, :create, :edit, :update, :destroy]
      object_class = @object  #@object is a class ie Entity or JvrModel
      class_name = object_class.to_s.underscore
      mapping.each do |format, expected_outcome|

        next unless formats.include?(format) #do I even need to comment this line.  Ruby is basicaly runnable comments!

        it "should #{expected_outcome.eql?(false) ? 'NOT ' : '' }respond to #{action}:#{format}" do #start an rspec test

          request.env["HTTP_REFERER"] = "/" #set a link for :back to point at
          valid_obj = send("valid_#{class_name}") unless object_class.nil? #create a valid object for the object_class.  Assumes methods for each resourse ie valid_entity, valid_jvr_model etc. 

          unless [:index, :new].include?(action) #only :index and create actions do not require an :id to be supplied
            args = {:id => valid_obj.id} if valid_obj #set the id of the valid_object created.
            args = {:id => 1} unless valid_obj && expected_outcome #If the controller is for a non DB resource (so no valid_obj) and the expected_outcome is false, then just use '1' for the :id
          end
          if action.eql?(:create) #create requires that the params have the object included ie {:entity => {attributes} }
            object_class.stub!(:new => valid_obj) if valid_obj#force the return of a valid object from new
            args = {class_name.to_sym => object_class.new.attributes} unless object_class.nil? #include attributes for the object in the params 
          end
          if action.eql?(:update) #upate requires both an :id and the object attributes to update.
            args = {:id => valid_obj.id, class_name.to_sym => valid_obj.attributes} if valid_obj
            #in some cases a :jvr_model_id is needed by some controllers update actions.  it is included here, and therefore sent to other controllers but they will ignore it if they dont need it.
          end
          args ||= {}

          mapping[:args] ||= {}
          mapping[:args].merge!(mapping["#{format}_args".to_sym]) if mapping.has_key?("#{format}_args".to_sym) #merge mapping[:args] with args for format, ie: mapping[:ajax_args]

          a_args = mapping[:args].map{|k,v| {k => (v.is_a?(String) ? eval(v) : v)} }.inject{|i,j| i.merge(j)} #args which are strings are eval'd.  This allows methods like with valid_object to be called here so they are in scope.
          args.merge!(a_args) unless a_args.nil? #merge the args from mapping with the base args.
          
          fetch(format, action, args) #Call the request using fetch.  format is either :html or :ajax 
          expected_outcome.eql?(true) ? (response.should be_success) : (response.should_not be_success) #make assertion on the response.  
        end
      end
    end
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

  def fetch format, action, *args
    @al ||= get_action_lookup
    @al[action][format].call(*args)
  end  

end
