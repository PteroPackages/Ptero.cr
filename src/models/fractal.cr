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
  end
end
