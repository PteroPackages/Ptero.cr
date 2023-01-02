module Ptero::Models
  class AppServer
    include JSON::Serializable

    getter id : Int32
    getter external_id : String?
    getter uuid : String
    getter identifier : String
    getter name : String
    getter description : String?
    getter status : ServerStatus?
    getter? suspended : Bool
    getter limits : Limits
    getter feature_limits : FeatureLimits
    getter user : Int32
    getter node : Int32
    getter allocation : Int32
    getter nest : Int32
    getter egg : Int32
    getter container : Container
    getter created_at : Time
    getter updated_at : Time?
  end

  struct Container
    include JSON::Serializable

    getter startup_command : String
    getter image : String
    getter installed : Int8
  end

  class FeatureLimits
    include JSON::Serializable

    property allocations : Int32
    property backups : Int32
    property databases : Int32

    def initialize(@allocations : Int32, @backups : Int32, @databases : Int32)
    end
  end

  class Limits
    include JSON::Serializable

    property memory : Int32
    property swap : Int32
    property disk : Int32
    property io : Int32?
    property cpu : Int32
    property threads : String?
    property? oom_disabled : Bool?

    def initialize(@memory : Int32, @swap : Int32, @disk : Int32, @cpu : Int32, *,
                   @io : Int32? = nil, @threads : String? = nil, @oom_disabled : Bool? = nil)
    end
  end

  enum ServerStatus
    Installing
    InstallFailed
    Suspended
    RestoringBackup
  end
end
