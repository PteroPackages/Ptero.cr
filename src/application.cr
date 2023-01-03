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
    # ```crystal
    # app.resolve_query(per_page: 20, include: ["foo", "bar"]) # => "per_page=20&include=foo,bar"
    # app.resolve_query(page: 0, per_page: 150) # => "page=1&per_page=100"
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
    # * per_page: the numer of user objects to return (default is 50).
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
    # ```crystal
    # user = app.create_user("example", "test@example.com", "example", "user", false)
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
    def create_user(username : String, email : String, first_name : String, last_name : String,
                    root_admin : Bool, *, language : String? = nil, external_id : String? = nil,
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
    # * per_page: the numer of user objects to return (default is 50).
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

    # def create_server

    # def update_server_build

    # def update_server_details

    # def update_server_startup

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
  end
end
