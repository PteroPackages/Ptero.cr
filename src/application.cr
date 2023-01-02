module Ptero
  class Application
    DEFAULT_HEADERS = {
      "User-Agent" => "Ptero.cr Application v#{VERSION}",
      "Content-Type" => "application/json",
      "Accept" => "application/json",
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

    def get_users(*, page : Int32? = nil, per_page : Int32? = nil,
                  filter : {String, String}? = nil, include includes : Array(String)? = nil,
                  sort : String? = nil) : Array(Models::User)
      res = @rest.get "/api/application/users?" + resolve_query(page, per_page, filter, includes, sort)
      model = Models::FractalList(Models::User).from_json res.body

      model.data.map &.attributes
    end

    def get_user(id : Int32, *, page : Int32? = nil, per_page : Int32? = nil,
                 filter : {String, String}? = nil, include includes : Array(String)? = nil,
                 sort : String? = nil) : Models::User
      res = @rest.get "/api/application/users/#{id}?" + resolve_query(page, per_page, filter, includes, sort)
      model = Models::FractalItem(Models::User).from_json res.body

      model.attributes
    end

    def create_user(username : String, email : String, first_name : String, last_name : String,
                    root_admin : Bool, *, language : String? = nil, external_id : String? = nil,
                    password : String? = nil) : Models::User
      data = {
        :username => username,
        :email => email,
        :first_name => first_name,
        :last_name => last_name,
        :root_admin => root_admin,
      }
      data[:language] = language if language
      data[:external_id] = external_id if external_id
      data[:password] = password if password

      res = @rest.post "/api/application/users", data.to_json
      model = Models::FractalItem(Models::User).from_json res.body

      model.attributes
    end

    def update_user(id : Int32, *, username : String? = nil, email : String? = nil,
                    first_name : String? = nil, last_name : String? = nil,
                    root_admin : Bool? = nil, language : String? = nil, external_id : String? = nil,
                    password : String? = nil) : Models::User
      user = get_user id
      data = {
        :username => username || user.username,
        :email => email || user.email,
        :first_name => first_name || user.first_name,
        :last_name => last_name || user.last_name,
        :root_admin => root_admin.nil? ? user.root_admin? : root_admin,
        :language => language || user.language,
        :external_id => external_id || user.external_id,
      }
      data[:password] = password if password

      res = @rest.patch "/api/application/users/#{id}", data.to_json
      model = Models::FractalItem(Models::User).from_json res.body

      model.attributes
    end

    def delete_user(id : Int32) : Nil
      @rest.delete "/api/application/users/#{id}"
    end
  end
end
