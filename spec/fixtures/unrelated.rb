require 'base64'
class Unrelated < ActiveRecord::Base
  class MySerializer
    def initialize(val)
      @val = val
    end

    def self.dump(obj)
      Base64.encode64(Marshal.dump(obj))
    end

    def self.load(str)
      if str
        Marshal.load(Base64.decode64(str))
      end
    end
  end

  serialize :for_yaml
  serialize :for_custom_serialize, MySerializer
end
