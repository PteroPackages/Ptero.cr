module Ptero
  class Error < Exception
  end

  class AuthFailedError < Error
    getter status : Int32

    def initialize(@status)
      super(@status == 401 ? "the API key could not be authenticated" : "the API was not valid")
    end
  end

  class NotFoundError < Error
    def initialize
      super "the resource was not found"
    end
  end

  class ConflictError < Error
    def initialize
      # TODO: extract from response
      super "resource is conflicting with another process"
    end
  end
end
