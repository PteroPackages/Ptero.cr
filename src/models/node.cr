module Ptero::Models
  struct APIConfiguration
    include JSON::Serializable

    getter host : String
    getter port : Int32
    getter ssl : SSLConfiguration
    getter upload_limit : Int32
  end

  struct Node
    include JSON::Serializable

    getter id : Int32
    getter name : String
    getter description : String?
    getter location_id : Int32
    getter? public : Bool
    getter fqdn : String
    getter scheme : String
    getter? behind_proxy : Bool
    getter memory : Int32
    getter memory_overallocate : Int32
    getter disk : Int32
    getter disk_overallocate : Int32
    getter daemon_base : String
    getter daemon_sftp : Int32
    getter daemon_listen : Int32
    getter? maintenance_mode : Bool
    getter upload_size : Int32
    getter allocated_resources : NodeResources
    getter created_at : Time
    getter updated_at : Time?
  end

  struct NodeConfiguration
    include JSON::Serializable

    getter debug : Bool
    getter uuid : String
    getter token_id : String
    getter token : String
    getter api : APIConfiguration
    getter system : SystemConfiguration
    getter allowed_mounts : Array(String)
    getter remote : String
  end

  struct NodeResources
    include JSON::Serializable

    getter memory : Int32
    getter disk : Int32
  end

  struct SFTPConfiguration
    include JSON::Serializable

    getter bind_port : Int32
  end

  struct SSLConfiguration
    include JSON::Serializable

    getter enabled : Bool
    getter cert : String
    getter key : String
  end

  struct SystemConfiguration
    include JSON::Serializable

    getter data : String
    getter sftp : SFTPConfiguration
  end
end
