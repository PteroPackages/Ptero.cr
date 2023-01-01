module Pterodactyl
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

    # def resolve_query(page : Int32?, per_page : Int32?) : String
    #   URI::Params.build do |params|
    #     params.add("page", page) if page
    #     params.add("per_page", per_page.min(1).max(100)) if per_page
    #   end
    # end

    def get_users : Array(Models::User)
      res = @rest.get "/api/application/users"
      model = Models::FractalList(Models::User).from_json res.body

      model.data.map &.attributes
    end

    def get_user(id : Int32) : Models::User
      res = @rest.get "/api/application/users/#{id}"
      model = Models::FractalItem(Models::User).from_json res.body

      model.attributes
    end
  end
end
