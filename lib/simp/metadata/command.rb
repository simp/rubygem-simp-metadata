require 'simp/metadata/commands'
require 'simp/metadata'

module Simp
  module Metadata
    class Command
      def run(argv)
        command = argv[0]
        argv.shift
        # XXX ToDo: Make this dynamic, just instantiate a class named the subcommand
        if command != ''
          if command == '-h' || command == 'help'
            help
          else
            unless command =~ /^#/
              begin
                cmd = Module.const_get("Simp::Metadata::Commands::#{command.tr('-', '_').capitalize}").new

              rescue
                Simp::Metadata.critical("Unable to find command: #{command}")
                help
                exit 4
              end
              cmd.run(argv)
            end
          end
        else
          help
        end
      end

      def help
        puts 'Usage: simp-metadata [command] [options]'

        # XXX: ToDo: make this dynamic...
        subcommands = [
          [
            'clone',
            'Clones one simp release into another'
          ],
          [
            'component',
            'create, view, or update a component'
          ],
          [
            'delete',
            'deletes a release'
          ],
          [
            'pry',
            'opens up pry debugger'
          ],
          [
            'release',
            'views components of a release'
          ],
          [
            'releases',
            'lists all releases'
          ],
          [
            'save',
            'Saves metadata changes'
          ],
          [
            'script',
            'Execute a script containing multiple commands'
          ],
          [
            'search',
            'searches for components based on attributes'
          ],
          [
            'set-write',
            'Sets which metadata repo to write to if there are multiple'
          ],
          [
            'set-write-url',
            'view/update/create a component'
          ],
          [
            'update',
            'updates a components attributes'
          ]
        ]

        subcommands.each do |components|
          output_string = "#{components[0].ljust(38).rjust(42)}#{components[1]}"
          puts output_string
        end
      end
    end
  end
end
