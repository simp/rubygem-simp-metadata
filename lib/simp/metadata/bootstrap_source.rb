require 'yaml'
require 'uri'

module Simp
  module Metadata
    class Bootstrap_source

      attr_accessor :url
      attr_accessor :cachepath
      attr_accessor :components
      attr_accessor :releases
      attr_accessor :basename
      attr_accessor :data
      attr_accessor :components
      attr_accessor :edition

      def initialize(edition)
        @releases = {}
        @components = {}
        @edition = edition

        case edition
          when "enterprise"
            @data = {
                "components" => {
                    "simp-metadata" => {
                        "component-type" => "simp-metadata",
                        "authoritative" => true,
                        "locations" => [
                            {
                                "url" => "https://github.com/simp/simp-metadata",
                                "method" => "git",
                                "primary" => true,
                            }
                        ],
                    },
                    "enterprise-metadata" => {
                        "component-type" => "simp-metadata",
                        "authoritative" => true,
                        "locations" => [
                            {
                                "url" => "simp-enterprise:///enterprise-metadata?version=master&filetype=tgz",
                                "method" => "file",
                                "extract" => true,
                                "primary" => true,
                            }
                        ]
                    }
                }
            }
          when "enterprise-only"
            @data = {
                "components" => {
                    "enterprise-metadata" => {
                        "component-type" => "simp-metadata",
                        "authoritative" => true,
                        "locations" => [
                            {
                                "url" => "simp-enterprise:///enterprise-metadata?version=master&filetype=tgz",
                                "method" => "file",
                                "extract" => true,
                                "primary" => true,
                            }
                        ]
                    }
                }
            }
          else
            @data = {
                "components" => {
                    "simp-metadata" => {
                        "component-type" => "simp-metadata",
                        "authoritative" => true,
                        "locations" => [
                            {
                                "url" => "https://github.com/simp/simp-metadata",
                                "method" => "git",
                                "primary" => true,
                            }
                        ],
                    }
                }
            }
        end
        @components = @data['components']
      end

      def release(version)
        case edition
          when "enterprise"
            {
                "simp-metadata" => {
                    "branch" => "master"
                },
                "enterprise-metadata" => {
                    "version" => "master",
                }
            }
          when "enterprise-only"
            {
                "enterprise-metadata" => {
                    "version" => "master",
                }
            }
          else
            {
                "simp-metadata" => {
                    "branch" => "master"
                }
            }
        end
      end
      # Stub out 'writing' methods as they don't apply to bootstrap_source
      def create_release(destination, source = 'master')

      end
      def writable?()
        false
      end
      def dirty?()
        false
      end
      def save()
        true
      end
      def cleanup()
      end
      def to_s()
        self.name
      end
      def name()
        "bootstrap_metadata"
      end
    end
  end
end

