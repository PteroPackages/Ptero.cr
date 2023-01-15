module Ptero::Models
  struct FractalItem(M)
    include JSON::Serializable

    getter object : String
    getter attributes : M
  end

  struct FractalList(M)
    include JSON::Serializable

    getter object : String
    getter data : Array(FractalItem(M))
    @[JSON::Field(key: "meta", root: "pagination")]
    getter pagination : Pagination
  end

  struct Pagination
    include JSON::Serializable

    getter count : Int32
    getter total : Int32
    getter current_page : Int32
    getter total_pages : Int32
    getter per_page : Int32
    getter links : Hash(String, String)
  end
end
