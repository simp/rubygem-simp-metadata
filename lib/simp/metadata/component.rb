module Simp
  module Metadata
    class Component
      attr_accessor :engine
      attr_accessor :name
      attr_accessor :release_version

      def initialize(engine, name, version)
        @engine = engine
        @name = name
        @release_version = version
      end

      def to_s
        self.name
      end

      def get_from_component()
        engine.sources.each do |source|
          if (source.components != nil)
            if (source.components.key?(name))
                return source.components[name]
            end
          end
        end
      end

      def get_from_release()
        retval = {}
        engine.sources.each do |source|
          if (source.releases.key?(release_version))
            if (source.releases[release_version].key?(name))
              retval = source.releases[release_version][name]
            end
          else
            if (source.release(release_version).key?(name))
              retval = source.release(release_version)[name]
            end
          end
        end
        return retval
      end

      def type
        get_from_component["type"]
      end

      def extension
        if (self.real_extension == nil)
        case (self.component_type)
          when "logstash-filter"
            "gem"
          when "rubygem"
            "gem"
          when "grafana-plugin"
            "zip"
          else
            ""
        end
        else
          self.real_extension
        end
      end

      def real_extension
        get_from_component["extension"]
      end

      def real_asset_name
        get_from_component["asset_name"]
      end

      def asset_name
        if (self.real_asset_name == nil)
          self.name
        else
          self.real_asset_name
        end
      end

      def real_module_name
        get_from_component["module_name"]
      end

      def module_name
        if (self.real_module_name == nil)
          splitted = self.name.split("-")
          splitted[splitted.size - 1]
        else
          self.real_module_name
        end
      end

      def output_type
        if (self.compiled?)
          return :file
        else
          return :directory
        end
      end

      def output_filename
        if (self.compiled?)
          return "#{self.name}-#{self.version}.#{self.extension}"
        else
          return self.name
        end
      end

      def primary
        self.locations.primary
      end

      def locations
        # XXX: ToDo Allow manifest.yaml to override locations
        # XXX: ToDo Use primary_source and mirrors here if locations is empty
        Simp::Metadata::Locations.new({ "locations" => get_from_component["locations"], "primary_source" => get_from_component["primary_source"], "mirrors" => get_from_component["mirrors"]}, self)
      end

      # XXX: ToDo Generate a filename, and output file type; ie, directory or file


      def format
        get_from_component["format"]
      end

      def component_type
        get_from_component["component-type"]
      end

      def authoritative?
        get_from_component["authoritative"]
      end

      def ref
        get_from_release["ref"]
      end

      def branch
        get_from_release["branch"]
      end

      def tag
        get_from_release["tag"]
      end

      def version
        ver = ""
        ["version", "ref", "branch"].each do |item|
          if (get_from_release[item] != nil)
            ver = get_from_release[item]
          end
        end
        return ver
      end

      def compiled?
        if get_from_release.key?("compiled")
          get_from_release["compiled"]
        else
          false
        end
      end

      def binaryname
        "#{name}-#{ref}.gem"
      end
    end
  end
end
