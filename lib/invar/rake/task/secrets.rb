# frozen_string_literal: true

require_relative 'namespaced'

module Invar
   module Rake
      module Task
         # Rake task handler for actions on the secrets file.
         class SecretsFileHandler < NamespacedFileTask
            # Instructions hint for how to handle secret keys.
            SECRETS_INSTRUCTIONS = <<~INST
               Generated key. Save this key to a secure password manager, you will need it to edit the secrets.yml file:
            INST

            SWAP_EXT = 'tmp'

            # Creates a new encrypted secrets file and prints the generated encryption key to STDOUT
            def create(content: SECRETS_TEMPLATE)
               encryption_key = Lockbox.generate_key

               write_encrypted_file(file_path,
                                    encryption_key: encryption_key,
                                    content:        content,
                                    permissions:    PrivateFile::DEFAULT_PERMISSIONS)

               warn SECRETS_INSTRUCTIONS
               puts encryption_key
            end

            # Updates the file with new content.
            #
            # Either the content is provided over STDIN or the default editor is opened with the decrypted contents of
            # the secrets file. After closing the editor, the file will be updated with the new encrypted contents.
            def edit
               content = $stdin.stat.pipe? ? $stdin.read : nil

               edit_encrypted_file(secrets_file, content: content)

               warn "File saved to #{ secrets_file }"
            end

            def rotate
               file_path = secrets_file

               decrypted = read_encrypted_file(file_path, encryption_key: determine_key(file_path))

               swap_file = file_path.dirname / [file_path.basename, SWAP_EXT].join('.')
               file_path.rename swap_file

               begin
                  create content: decrypted
                  swap_file.delete
               rescue StandardError
                  swap_file.rename file_path.to_s
               end
            end

            private

            def secrets_file
               @locator.find 'secrets.yml'
            rescue ::Invar::FileLocator::FileNotFoundError => e
               warn <<~ERR
                  Abort: #{ e.message }. Searched in: #{ @locator.search_paths.join(', ') }
                  #{ CREATE_SUGGESTION }
               ERR
               exit 1
            end

            def filename
               'secrets.yml'
            end

            def read_encrypted_file(file_path, encryption_key:)
               lockbox = build_lockbox(encryption_key)
               lockbox.decrypt(file_path.binread)
            end

            def write_encrypted_file(file_path, encryption_key:, content:, permissions: nil)
               lockbox = build_lockbox(encryption_key)

               encrypted_data = lockbox.encrypt(content)

               config_dir.mkpath
               # TODO: replace File.opens with photo_path.binwrite(uri.data) once FakeFS can handle it
               File.open(file_path.to_s, 'wb') { |f| f.write encrypted_data }
               file_path.chmod permissions if permissions

               warn "Saved file: #{ file_path }"
            end

            def edit_encrypted_file(file_path, content: nil)
               encryption_key = determine_key(file_path)

               content ||= invoke_editor(file_path, encryption_key: encryption_key)

               write_encrypted_file(file_path, encryption_key: encryption_key, content: content)
            end

            def invoke_editor(file_path, encryption_key:)
               Tempfile.create(file_path.basename.to_s) do |tmp_file|
                  decrypted = read_encrypted_file(file_path, encryption_key: encryption_key)

                  tmp_file.write(decrypted)
                  tmp_file.rewind # rewind needed because file does not get closed after write
                  system ENV.fetch('EDITOR', 'editor'), tmp_file.path, exception: true
                  tmp_file.read
               end
            end

            def determine_key(file_path)
               encryption_key = Lockbox.master_key

               if encryption_key.nil? && $stdin.tty?
                  warn "Enter master key to decrypt #{ file_path }:"
                  encryption_key = $stdin.noecho(&:gets).strip
               end

               encryption_key
            end

            def build_lockbox(encryption_key)
               Lockbox.new(key: encryption_key)
            rescue ArgumentError => e
               raise SecretsFileEncryptionError, e
            end
         end
      end
   end
end
