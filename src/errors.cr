module Ptero
  class Error < Exception
  end

  # Raised when a request fails to be authenticated. This can either be a 401 (unauthorized) error
  # or a 403 (forbidden) error.
  class AuthFailedError < Error
    getter status : Int32

    def initialize(@status)
      super(@status == 401 ? "the API key could not be authenticated" : "the API was not valid")
    end
  end

  # Raised when a specific resource is not found (404 status code).
  class NotFoundError < Error
    def initialize
      super "the resource was not found"
    end
  end

  # Raised when there is a conflict in process between one or more resources in the panel and/or
  # Wings (409 status code).
  class ConflictError < Error
    def initialize
      # TODO: extract from response
      super "resource is conflicting with another process"
    end
  end
end
