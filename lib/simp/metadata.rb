# vim: set expandtab ts=2 sw=2:
require 'open3'
require 'tempfile'
require 'tmpdir'
require 'net/http'
require 'uri'
require 'openssl'
require 'json'
require 'simp/metadata/engine'
require 'simp/metadata/fake_uri'

require 'simp/metadata/source'
require 'simp/metadata/bootstrap_source'

require 'simp/metadata/releases'
require 'simp/metadata/release'

require 'simp/metadata/components'
require 'simp/metadata/component'

require 'simp/metadata/locations'
require 'simp/metadata/location'

module Simp
  module Metadata

    def self.directory_name(component, options)
      if (options["target"] != nil)
        basedir = options["target"]
      else
        raise "Must specify 'target'"
      end
      case component.class.to_s
        when "String"
          "#{basedir}/#{component}"
        when "Simp::Metadata::Component"
          "#{basedir}/#{component.output_filename}"
      end
    end
    # XXX: ToDo this entire logic stream is crappy.
    #      We need to replace this with a much more simplified version.
    def self.download_component(component, options)
      directory_name = self.directory_name(component, options)
      retval = {}
      case component.class.to_s
        when "String"

          retval["path"] = self.directory_name(component, options)
          # XXX: ToDo We can bootstrap this with a hard coded source in the simp engine
          bootstrapped_components = {
              "simp-metadata" => {
                  "url" => "https://github.com/simp/simp-metadata",
                  "method" => "git"
              },
              "enterprise-metadata" => {
                  "url" => "simp-enterprise:///enterprise-metadata?version=master&filetype=tgz",
                  "method" => "file",
                  "extract" => true,
              },
          }
          # All this should be removed and be based on component.file_type
          componentspec = bootstrapped_components[component]
          if (componentspec["extract"] == true)
            tarball = "#{directory_name}.tgz"
            fetch_from_url(componentspec, tarball, nil, options)
            unless Dir.exists?(retval["path"])
              Dir.mkdir(retval["path"])
            end
            `tar -xvpf #{tarball} -C #{retval["path"]}`
          else
            fetch_from_url(componentspec, retval["path"], nil, options)
          end
        when "Simp::Metadata::Component"
          retval["path"] = directory_name
          if (options["url"])
            location = component.primary
            location.url = options["url"]
            urlspec = location
            location.method = "git"
          else
            urlspec = component.primary
          end
          fetch_from_url(urlspec, retval["path"], component, options)
        else
          raise "component.class=#{component.class.to_s}, #{component.class.to_s} is not in ['String', 'Simp::Metadata::Component']"
      end
      return retval
    end

    def self.uri(url)
      case url
        when /git@/
          uri = Simp::Metadata::FakeURI.new(uri)
          uri.scheme = "ssh"
          uri
        else
          URI(url)
      end
    end

    def self.fetch_from_url(urlspec, target, component = nil, options)
      case urlspec.class.to_s
        when "Simp::Metadata::Location"
          url = urlspec.url
          uri = uri(url)
          method = urlspec.method
        when "Hash"
          url = urlspec["url"]
          uri = uri(urlspec["url"])
          if (urlspec.key?("method"))
            method = urlspec["method"]
          else
            # XXX ToDo remove once the upstream simp-metadata has been updated so type != method
            if (urlspec.key?("type"))
              if (urlspec["type"] == "git")
                method = "git"
              else
                method = "file"
              end
            else
              method = "file"
            end
          end
        when "String"
          url = urlspec
          uri = uri(urlspec)
          method = "file"
      end
      case method
        when "git"
          unless (Dir.exists?(target))
            info("Cloning from #{url}")
            run("git clone #{url} #{target}")
          else
            Dir.chdir(target) do
              info("Updating from #{url}")
              run("git pull origin")
            end
          end
        when "file"
          case uri.scheme
            when "simp-enterprise"
              fetch_simp_enterprise(url, target, component, urlspec, options)
            when "http"
              fetch_simp_enterprise(url, target, component, urlspec, options)
            when "https"
              fetch_simp_enterprise(url, target, component, urlspec, options)
            else
              raise "unsupported url type #{uri.scheme}"
          end
      end
    end
    def self.get_license_data(filename)
      ret_filename = nil
      ret_data = ""
      license_data = ENV.fetch('SIMP_LICENSE_KEY', nil)
      if (license_data != nil)
        # Environment data trumps all
        ret_data = license_data
        if ($simp_license_temp == nil)
          $simp_license_temp = Tempfile.new('license_data')
          $simp_license_temp.write(license_data)
        end
        ret_filename = $simp_license_temp.path
      else
        if (filename.class.to_s == "String")
          # Attempt to load from the filename passed
          ret_filename = filename
        else
          # Try to load from /etc/simp/license.key file
          ret_filename = "/etc/simp/license.key"
        end
        if (File.exists?(ret_filename))
          ret_data = File.read(ret_filename)
	      else
          if ($simp_license_temp == nil)
            $simp_license_temp = Tempfile.new('license_data')
            $simp_license_temp.write("")
          end
          ret_filename = $simp_license_temp.path
        end
      end
      return ret_filename, ret_data
    end

    def self.fetch_simp_enterprise(url, destination, component, location = nil, options)
      if (location.class.to_s == "Simp::Metadata::Location")
        extract = location.extract
      else
        extract = false
      end
      uri = uri(url)
      case uri.scheme
        when "simp-enterprise"
          scheme = "https"
          host = 'enterprise-download.simp-project.com'
          filetype = 'tgz'
          if (component != nil)
            if (component.extension != "")
              filetype = component.extension
            end
          end
          version = 'latest'
          if (component != nil)
            if (component.version != "")
              version = component.version
            end
          end
          if (uri.query != nil)
            uri.query.split("&").each do |element|
              if (element.class.to_s == "String")
                elements = element.split("=")
                if (elements.size > 1)
                  case elements[0]
                    when "version"
                      version = elements[1]
                    when "filetype"
                      filetype = elements[1]
                  end
                end
              end
            end
          end
          if (component != nil)
            name = "/#{component.asset_name}"
          else
            name = uri.path
          end
          path = "/products/simp-enterprise#{uri.path}#{name}-#{version}.#{filetype}"
        else
          scheme = uri.scheme
          host = uri.host
          path = uri.path
      end
      port = uri.port ? uri.port : 443
      http = Net::HTTP.new(host, port)
      case scheme
        when "https"
          http.use_ssl = true
          case uri.scheme
            when "simp-enterprise"
              filename, data = self.get_license_data(options["license"])
              unless (filename == nil)
                http.ca_file = filename
              end
              unless (data == nil)
                http.cert = OpenSSL::X509::Certificate.new(data)
                http.key = OpenSSL::PKey::RSA.new(data)
                http.verify_mode = OpenSSL::SSL::VERIFY_PEER
              end
          end
      end
      info("Fetching from #{scheme}://#{host}:#{port}#{path}")
      req = Net::HTTP::Get.new(path)
      response = http.request(req)
      case response.code
        when '200'
          if (extract == true)
            File.open("#{destination}.tgz", 'w') do |f|
              f.write response.body
            end
            FileUtils.mkdir_p(destination)
            run("tar -xvpf #{destination}.tgz -C #{destination}")
          else
            File.open(destination, 'w') do |f|
              f.write response.body
            end
          end
        when '302'
          fetch_simp_enterprise(response['location'], destination, component, location)
        when '301'
          fetch_simp_enterprise(response['location'], destination, component, location)
        else
          $errorcode = response.code.to_i
          raise "HTTP Error Code: #{response.code}"
      end
    end
    def self.run(command)
      exitcode = nil
      Open3.popen3(command) do |stdin, stdout, stderr, thread|
        pid = thread.pid
        Simp::Metadata.debug2(stdout.read.chomp)
        Simp::Metadata.debug1(stderr.read.chomp)
        exitcode = thread.value
      end
      exitcode
    end
    def self.level?(level)
      setlevel = Simp::Metadata.convert_level($simp_metadata_debug_level)
      checklevel = Simp::Metadata.convert_level(level)
      if (checklevel <= setlevel)
        true
      else
        false
      end
    end
    def self.convert_level(level)
      case level
        when 'disabled'
          0
        when 'critical'
          1
        when 'error'
          2
        when 'warning'
          3
        when 'info'
          4
        when 'debug1'
          5
        when 'debug2'
          6
        else
          3
      end
    end
    def self.print_message(prefix, message)
      message.split("\n").each do |line|
        output = "#{prefix}: #{line}"
        unless ($simp_metadata_debug_output_disabled == true)
          STDERR.puts output
        end
      end
    end
    def self.debug1(message)
      if Simp::Metadata.level?('debug1')
        Simp::Metadata.print_message("DEBUG1", message)
      end
    end
    def self.debug2(message)
      if Simp::Metadata.level?('debug2')
        Simp::Metadata.print_message("DEBUG2", message)
      end
    end
    def self.info(message)
      if Simp::Metadata.level?('info')
        Simp::Metadata.print_message("INFO", message)
      end
    end
    def self.warning(message)
      if Simp::Metadata.level?('warning')
        Simp::Metadata.print_message("WARN", message)
      end
    end
    def self.error(message)
      if Simp::Metadata.level?('error')
        Simp::Metadata.print_message("ERROR", message)
      end
    end
    def self.critical(message)
      if Simp::Metadata.level?('critical')
        Simp::Metadata.print_message("CRITICAL", message)
      end
    end
  end
end
