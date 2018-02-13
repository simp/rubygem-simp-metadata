require_relative '../commands'
module Simp
  module Metadata
    module Commands
      class Releases < Simp::Metadata::Commands::Base
        def run(argv, engine = nil)

          options = defaults(argv) do |opts|
            opts.banner = "Usage: simp-metadata releases"
          end

          if (engine == nil)
            engine = Simp::Metadata::Engine.new()
          end
          begin
            puts engine.releases.keys
          rescue RuntimeError => e
            Simp::Metadata.critical(e.message)
            exit 5
          end
        end
      end
    end
  end
end
