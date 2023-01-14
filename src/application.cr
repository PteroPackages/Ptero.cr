module Ptero
  # A class for interacting with the application API.
  class Application
    DEFAULT_HEADERS = {
      "User-Agent"   => "Ptero.cr Application v#{VERSION}",
      "Content-Type" => "application/json",
      "Accept"       => "application/json",
    }

    getter url : String
    getter key : String
    getter rest : Crest::Resource

    def initialize(url : String | URI, @key : String, rest : Crest::Resource? = nil)
      @url = url.to_s
      @rest = rest || Crest::Resource.new(
        @url,
        headers: {"Authorization" => "Bearer #{@key}"}.merge!(DEFAULT_HEADERS),
      )
    end

    # Resolves a query string from the given parameters. This function applies its own validation
    # rules for certain arguments silently instead of raising an exception.
    #
    # ```
    # app.resolve_query(per_page: 20, include: ["foo", "bar"]) # => "per_page=20&include=foo,bar"
    # app.resolve_query(page: 0, per_page: 150)                # => "page=1&per_page=100"
    # ```
    def resolve_query(page : Int32?, per_page : Int32?, filter : {String, String}?,
                      includes : Array(String)?, sort : String?) : String
      URI::Params.build do |params|
        params.add("page", page.to_s) if page
        if value = per_page
          value = 1 if value < 1
          value = 100 if value > 100
          params.add("per_page", value.to_s)
        end
        params.add("filter[#{filter[0]}]", filter[1]) if filter
        params.add("include", includes.join) if includes
        params.add("sort", sort) if sort
      end
    end

    # Resolves a library-specific error from a failed HTTP request (error response).
    def resolve_error(ex : Crest::RequestFailed) : NoReturn
      case ex.http_code
      when 401, 403
        raise AuthFailedError.new(ex.http_code)
      when 404
        raise NotFoundError.new
      when 409
        raise ConflictError.new
        # when 429
        # TODO: implement ratelimiter, for now just raise
      else
        raise ex
      end
    end

    # Gets a list of users from the panel with the specified query parameters (if set).
    #
    # ## Parameters
    #
    # * page: the page number to fetch from (default is 1)
    # * per_page: the number of user objects to return (default is 50).
    # * filter: an argument tuple to filter users from, the first being the field and the second
    # being the value to query
    # * include: additional resources to include in the response
    # * sort: an argument to sort users in the response by
    def get_users(*, page : Int32? = nil, per_page : Int32? = nil,
                  filter : {String, String}? = nil, include includes : Array(String)? = nil,
                  sort : String? = nil) : Array(Models::User)
      res = @rest.get "/api/application/users?" + resolve_query(page, per_page, filter, includes, sort)
      model = Models::FractalList(Models::User).from_json res.body

      model.data.map &.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Gets a specific user by its ID.
    #
    # ## Parameters
    #
    # * include: additional resources to include in the response
    def get_user(id : Int32, *, include includes : Array(String)? = nil) : Models::User
      res = @rest.get "/api/application/users/#{id}?" + resolve_query(nil, nil, nil, includes, nil)
      model = Models::FractalItem(Models::User).from_json res.body

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Gets a specific user by its external identifier.
    def get_user(id : String) : Models::User
      res = @rest.get "/api/application/users/external/" + id
      model = Models::FractalItem(Models::User).from_json res.body

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Creates a user on the panel with the given fields.
    #
    # ## Fields
    #
    # * username: the username for the user
    # * email: the email for the user
    # * first_name: the first name of the user
    # * last_name: the last name of the user
    # * root_admin: whether the user should have administrative privileges
    # * language (optional): the language or locale for the user
    # * external_id (optional): an external identifier for the user
    # * password (optional): the password for the user
    #
    # ```
    # user = app.create_user(
    #   username: "example",
    #   email: "test@example.com",
    #   first_name: "example",
    #   last_name: "user",
    #   root_admin: false
    # )
    # pp user # => Ptero::Models::User(
    # #  @created_at=2022-01-01 16:04:03.0 +00:00,
    # #  @email="test@example.com",
    # #  @external_id=nil,
    # #  @first_name="example",
    # #  @id=7,
    # #  @language="en",
    # #  @last_name="user",
    # #  @root_admin=false,
    # #  @two_factor=false,
    # #  @updated_at=2022-01-01 16:04:03.0 +00:00,
    # #  @username="example",
    # #  @uuid="530d7e97-5a35-40b4-a0a8-68ea487bd384")
    # ```
    def create_user(*, username : String, email : String, first_name : String, last_name : String,
                    root_admin : Bool, language : String? = nil, external_id : String? = nil,
                    password : String? = nil) : Models::User
      data = {
        :username   => username,
        :email      => email,
        :first_name => first_name,
        :last_name  => last_name,
        :root_admin => root_admin,
      }
      data[:language] = language if language
      data[:external_id] = external_id if external_id
      data[:password] = password if password

      res = @rest.post "/api/application/users", data.to_json
      model = Models::FractalItem(Models::User).from_json res.body

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Updates a user specified by its ID with the given fields (same as the fields for
    # `create_user`). Any fields that aren't specified will be filled with the existing value
    # from the panel.
    def update_user(id : Int32, *, username : String? = nil, email : String? = nil,
                    first_name : String? = nil, last_name : String? = nil,
                    root_admin : Bool? = nil, language : String? = nil, external_id : String? = nil,
                    password : String? = nil) : Models::User
      user = get_user id
      data = {
        :username    => username || user.username,
        :email       => email || user.email,
        :first_name  => first_name || user.first_name,
        :last_name   => last_name || user.last_name,
        :root_admin  => root_admin.nil? ? user.root_admin? : root_admin,
        :language    => language || user.language,
        :external_id => external_id || user.external_id,
      }
      data[:password] = password if password

      res = @rest.patch "/api/application/users/#{id}", data.to_json
      model = Models::FractalItem(Models::User).from_json res.body

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Deletes a user by its ID.
    def delete_user(id : Int32) : Nil
      @rest.delete "/api/application/users/#{id}"
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Gets a list of servers from the panel with the specified query parameters (if set).
    #
    # ## Parameters
    #
    # * page: the page number to fetch from (default is 1)
    # * per_page: the number of user objects to return (default is 50).
    # * filter: an argument tuple to filter servers from, the first being the field and the second
    # being the value to query
    # * include: additional resources to include in the response
    # * sort: an argument to sort servers in the response by
    def get_servers(*, page : Int32? = nil, per_page : Int32? = nil,
                    filter : {String, String}? = nil, include includes : Array(String)? = nil,
                    sort : String? = nil) : Array(Models::AppServer)
      res = @rest.get "/api/application/servers?" + resolve_query(page, per_page, filter, includes, sort)
      model = Models::FractalList(Models::AppServer).from_json res.body

      model.data.map &.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Gets a specific server by its ID.
    #
    # ## Parameters
    #
    # * include: additional resources to include in the response
    def get_server(id : Int32, *, include includes : Array(String)? = nil) : Models::AppServer
      res = @rest.get "/api/application/servers/#{id}?" + resolve_query(nil, nil, nil, includes, nil)
      model = Models::FractalItem(Models::AppServer).from_json res.body

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Gets a specific server by its external identifier.
    def get_server(id : String) : Models::AppServer
      res = @rest.get "/api/application/servers/external/" + id
      model = Models::FractalItem(Models::AppServer).from_json res.body

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Creates a user on the panel with the given fields, using the allocation object to select the
    # node and additional allocations if specified.
    #
    # ## Fields
    #
    # * name: the name of the server
    # * description (optional): the description of the server
    # * external_id (optional): an external identifier for the server
    # * user: the ID of the user the server will belong to
    # * egg: the ID of the egg to use for the server
    # * docker_image: the docker image to use for the server
    # * startup: the startup command for the server
    # * oom_disabled: whether the OOM killer should be disabled for the server
    # * limits: an object containing the server limits
    # * feature_limits: an object containing the server feature limits
    # * allocation: an object containing allocation data including where the server will be created
    # * start_on_completion: whether the server should start once installed
    #
    # ```
    # server = app.create_server(
    #   name: "crystal bot",
    #   user: 5,
    #   egg: 30,
    #   docker_image: "ghcr.io/parkervcp/yolks:crystal_1.6",
    #   startup: %(crystal run {{CRYSTAL_FILE}}}),
    #   environment: {"USER_UPLOAD" => false, "AUTO_UPDATE" => false, "CRYSTAL_FILE" => "src/main.cr"},
    #   limits: Ptero::Models::Limits.new(memory: 1024, disk: 1024, swap: 0, cpu: 100, io: 500),
    #   feature_limits: Ptero::Models::FeatureLimits.new(0, 0, 0),
    #   allocation: Ptero::Models::AllocationData.new(1),
    #   start_on_completion: false,
    # ) # => Ptero::Models::AppServer(@id=7, @external_id=nil, @uuid="...", ...)
    # ```
    def create_server(*, name : String, description : String? = nil, external_id : String? = nil,
                      user : Int32, egg : Int32, docker_image : String, startup : String,
                      environment : Hash(String, String | Int32 | Bool | Nil), skip_scripts : Bool,
                      oom_disabled : Bool, limits : Models::Limits,
                      feature_limits : Models::FeatureLimits, allocation : Models::AllocationData,
                      start_on_completion : Bool) : Models::AppServer
      data = {
        name:                name,
        description:         description,
        external_id:         external_id,
        user:                user,
        egg:                 egg,
        docker_image:        docker_image,
        startup:             startup,
        environment:         environment,
        skip_scripts:        skip_scripts,
        oom_disabled:        oom_disabled,
        limits:              limits,
        feature_limits:      feature_limits,
        allocation:          allocation,
        start_on_completion: start_on_completion,
      }
      res = @rest.post "/api/application/servers", data.to_json
      model = Models::FractalItem(Models::AppServer).from_json res.body

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Creates a user on the panel with the given fields, using the deploy object to find node
    # suitable to deploy the server onto.
    #
    # ## Fields
    #
    # * name: the name of the server
    # * description (optional): the description of the server
    # * external_id (optional): an external identifier for the server
    # * user: the ID of the user the server will belong to
    # * egg: the ID of the egg to use for the server
    # * docker_image: the docker image to use for the server
    # * startup: the startup command for the server
    # * oom_disabled: whether the OOM killer should be disabled for the server
    # * limits: an object containing the server limits
    # * feature_limits: an object containing the server feature limits
    # * deploy: an object containing deployment data including location and port information
    # * start_on_completion: whether the server should start once installed
    #
    # ```
    # server = app.create_server(
    #   name: "crystal bot",
    #   user: 5,
    #   egg: 30,
    #   docker_image: "ghcr.io/parkervcp/yolks:crystal_1.6",
    #   startup: %(crystal run {{CRYSTAL_FILE}}}),
    #   environment: {"USER_UPLOAD" => false, "AUTO_UPDATE" => false, "CRYSTAL_FILE" => "src/main.cr"},
    #   limits: Ptero::Models::Limits.new(memory: 1024, disk: 1024, swap: 0, cpu: 100, io: 500),
    #   feature_limits: Ptero::Models::FeatureLimits.new(0, 0, 0),
    #   deploy: Ptero::Models::DeployData.new([2, 3], ["5000-5030"], false),
    #   start_on_completion: false,
    # ) # => Ptero::Models::AppServer(@id=7, @external_id=nil, @uuid="...", ...)
    # ```
    def create_server(*, name : String, description : String? = nil, external_id : String? = nil,
                      user : Int32, egg : Int32, docker_image : String, startup : String,
                      environment : Hash(String, String | Int32 | Bool | Nil), skip_scripts : Bool,
                      oom_disabled : Bool, limits : Models::Limits,
                      feature_limits : Models::FeatureLimits, deploy : Models::DeployData,
                      start_on_completion : Bool) : Models::AppServer
      data = {
        name:                name,
        description:         description,
        external_id:         external_id,
        user:                user,
        egg:                 egg,
        docker_image:        docker_image,
        startup:             startup,
        environment:         environment,
        skip_scripts:        skip_scripts,
        oom_disabled:        oom_disabled,
        limits:              limits,
        feature_limits:      feature_limits,
        deploy:              deploy,
        start_on_completion: start_on_completion,
      }
      res = @rest.post "/api/application/servers", data.to_json
      model = Models::FractalItem(Models::AppServer).from_json res.body

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Updates the build configuration for a specified server. Fields that are not specified will
    # fallback to their current values if set.
    #
    # ## Fields
    #
    # * allocation_id (optional): the ID of the primary allocation the server should use
    # * oom_disabled (optional): whether the OOM killer should be disabled
    # * limits (optional): the limits of the server
    # * feature_limits (optional): the feature limits of the server
    # * add_allocations (optional): a set of allocations to add to the server
    # * remove_allocations (optional): a set of allocations to remove from the server
    def update_server_build(id : Int32, *, allocation_id : Int32? = nil,
                            oom_disabled : Bool? = nil, limits : Limits? = nil,
                            feature_limits : FeatureLimits? = nil,
                            add_allocations : Set(Int32) = Set(Int32).new,
                            remove_allocations : Set(Int32) = Set(Int32).new) : Models::AppServer
      server = get_server id
      data = {
        allocation_id:      allocation_id || server.allocation,
        oom_disabled:       oom_disabled || server.limits.oom_disabled,
        limits:             limits || server.limits,
        feature_limits:     feature_limits || server.feature_limits,
        add_allocations:    add_allocations,
        remove_allocations: remove_allocations,
      }
      model = @rest.patch "/api/application/servers/#{id}/build", data.to_json

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Updates a specified server's details. Fields that are not specified will fallback to their
    # current values if set.
    #
    # ## Fields
    #
    # * external_id (optional): the external identifier for the server, set to an empty string to
    # remove it
    # * name (optional): the name of the server
    # * description (optional): a description of the server, set to an empty string to remove it
    # * user (optional): the ID of the server owner
    def update_server_details(id : Int32, *, external_id : String? = nil, name : String? = nil,
                              description : String? = nil, user : Int32? = nil) : Models::AppServer
      server = get_server id
      data = {
        external_id: external_id != "" ? external_id : server.external_id,
        name:        name || server.name,
        description: description != "" ? description : server.description,
        user:        user || server.user,
      }
      model = @rest.patch "/api/application/servers/#{id}/details", data.to_json

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Updates a specified servers' startup configuration. For environment variables, unset fields
    # will be replaced with the default values from the panel if set.
    #
    # ## Fields
    # * startup (optional): the startup command for the server
    # * environment (optional): a hash of environment variables to set for the server
    # * egg (optional): the ID of the egg to use for the server
    # * image (optional): the docker image to use for the server
    def update_server_startup(id : Int32, *, startup : String? = nil,
                              environment : Hash(String, String | Int32 | Bool | Nil)? = nil,
                              egg : Int32? = nil, image : String? = nil) : Models::AppServer
      server = get_server id
      env = environment.try(&.merge(server.container.environment)) || server.container.environment
      data = {
        startup:     server.container.startup,
        environment: env,
        egg:         egg || server.egg,
        image:       image || server.container.image,
      }
      model = @rest.patch "/api/application/servers/#{id}/startup", data.to_json

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Suspends a specified server.
    def suspend_server(id : Int32) : Nil
      @rest.post "/api/application/servers/#{id}/suspend"
    end

    # Unsuspends a specified server.
    def unsuspend_server(id : Int32) : Nil
      @rest.post "/api/application/servers/#{id}/unsuspend"
    end

    # Triggers the reinstall process for a specified server.
    def reinstall_server(id : Int32) : Nil
      @rest.post "/api/application/servers/#{id}/reinstall"
    end

    # Deletes a server by its ID.
    def delete_server(id : Int32, *, with_force : Bool = false) : Nil
      @rest.delete "/api/application/servers/#{id}" + (with_force ? "/force" : "")
    end

    # Gets a list of nodes from the panel with the specified query parameters (if set).
    #
    # ## Parameters
    #
    # * page: the page number to fetch from (default is 1)
    # * per_page: the number of node objects to return (default is 50).
    # * filter: an argument tuple to filter nodes from, the first being the field and the second
    # being the value to query
    # * include: additional resources to include in the response
    # * sort: an argument to sort nodes in the response by
    def get_nodes(*, page : Int32? = nil, per_page : Int32? = nil,
                  filter : {String, String}? = nil, include includes : Array(String)? = nil,
                  sort : String? = nil) : Array(Models::Node)
      res = @rest.get "/api/application/nodes?" + resolve_query(page, per_page, filter, includes, sort)
      model = Models::FractalList(Models::Node).from_json res.body

      model.data.map &.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Gets a specific node by its ID.
    #
    # ## Parameters
    #
    # * include: additional resources to include in the response
    def get_node(id : Int32, *, include includes : Array(String)? = nil) : Models::Node
      res = @rest.get "/api/application/nodes/#{id}?" + resolve_query(nil, nil, nil, includes, nil)
      model = Models::FractalItem(Models::Node).from_json res.body

      model.attributes
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end

    # Gets the configuration structure for a specific node.
    def get_node_configuration(id : Int32) : Models::NodeConfiguration
      res = @rest.get "/api/application/nodes/#{id}/configuration"

      Models::NodeConfiguration.from_json res.body
    rescue ex : Crest::RequestFailed
      resolve_error ex
    end
  end
end
