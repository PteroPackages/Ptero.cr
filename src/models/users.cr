module Ptero::Models
  struct User
    include JSON::Serializable

    getter id : Int32
    getter external_id : String?
    getter uuid : String
    getter username : String
    getter email : String
    getter first_name : String
    getter last_name : String
    getter language : String
    getter? root_admin : Bool
    @[JSON::Field(key: "2fa")]
    getter? two_factor : Bool
    getter created_at : Time
    getter updated_at : Time?
  end

  struct SubUser
    include JSON::Serializable

    getter id : Int32
    getter user_id : Int32
    getter server_id : Int32
    getter permissions : Array(String)
    getter created_at : Time
    getter updated_at : Time?
  end
end
