# frozen_string_literal: true

module Dirt
   module Envelope
      # Rake task implementation.
      #
      # The actual rake tasks themselves are thinly defined in dirt/envelope/rake.rb (so that the external include
      # path is nice and short)
      module RakeTasks
         CONFIG_TEMPLATE = SECRETS_TEMPLATE = <<~YML
            ---
         YML

         NAMESPACE_ERR        = 'namespace argument required'
         SECRETS_INSTRUCTIONS = <<~INST
            Save this key to a secure password manager. You will need it to edit the secrets.yml file.
         INST

         def self.create_config(namespace)
            if namespace.nil?
               raise ArgumentError,
                     "#{ NAMESPACE_ERR }. Run with: bundle exec rake envelope:configs:create[namespace_here]"
            end

            locator = Dirt::Envelope::FileLocator.new(namespace)

            config_dir = locator.search_paths.first
            config_dir.mkpath

            file = config_dir / 'config.yml'
            if file.exist?
               warn <<~MSG
                  Abort: File exists. (#{ file })
                  Maybe you meant to edit the file with bundle exec rake envelope:secrets:edit[#{ namespace }]?
               MSG
               exit 1
            end

            file.write CONFIG_TEMPLATE

            warn "Created file: #{ file }"
         end

         def self.edit_config(namespace)
            if namespace.nil?
               raise ArgumentError,
                     "#{ NAMESPACE_ERR }. Run with: bundle exec rake envelope:configs:edit[namespace_here]"
            end

            locator = Dirt::Envelope::FileLocator.new(namespace)

            configs_file = begin
                              locator.find('config.yml')
                           rescue Dirt::Envelope::FileLocator::FileNotFoundError => e
                              warn <<~YML
                                 Abort: #{ e.message }. Searched in: #{ locator.search_paths.join(', ') }
                                 Maybe you used the wrong namespace or need to create the file with bundle exec rake envelope:configs:create?
                              YML
                              exit 1
                           end

            system(ENV.fetch('EDITOR', 'editor'), configs_file.to_s, exception: true)

            warn "File saved to: #{ configs_file }"
         end

         def self.create_secret(namespace)
            if namespace.nil?
               raise ArgumentError,
                     "#{ NAMESPACE_ERR }. Run with: bundle exec rake envelope:secrets:create[namespace_here]"
            end

            config_dir = Dirt::Envelope::FileLocator.new(namespace).search_paths.first
            config_dir.mkpath

            file = config_dir / 'secrets.yml'

            if file.exist?
               warn <<~MSG
                  Abort: File exists. (#{ file })
                  Maybe you meant to edit the file with bundle exec rake envelope:secrets:edit[#{ namespace }]?
               MSG
               exit 1
            end

            encryption_key = Lockbox.generate_key

            write_encrypted_file(file, encryption_key, SECRETS_TEMPLATE)

            warn "Created file #{ file }"

            warn SECRETS_INSTRUCTIONS
            warn 'Generated key is:'
            puts encryption_key
         end

         def self.edit_secret(namespace)
            if namespace.nil?
               raise ArgumentError,
                     "#{ NAMESPACE_ERR }. Run with: bundle exec rake envelope:secrets:edit[namespace_here]"
            end

            # TODO: better to use the actual path search mechanism
            secrets_file = config_dir / namespace / 'secrets.yml'

            master_key = ENV.fetch 'LOCKBOX_KEY' do
               $stderr.puts 'Enter master key:'
               $stdin.noecho(&:gets).strip
            end

            lockbox = Lockbox.new(key: master_key)

            file_str = Tempfile.create(secrets_file.basename.to_s) do |tmp_file|
               decrypted = lockbox.decrypt(secrets_file.binread)

               tmp_file.write(decrypted)
               tmp_file.rewind # rewind seems to be needed before system call for some reason?
               # TODO: is exception good here? thought is to avoid clobbering exiting file on error.
               system(ENV.fetch('EDITOR', 'editor'), tmp_file.path, exception: true)
               tmp_file.read
            end

            # TODO: it should warn about file unchanged. hint maybe you forgot to hit save?
            # TODO: should avoid writing empty string. tell them to delete the file if that is what they want
            secrets_file.binwrite(lockbox.encrypt(file_str))

            warn "File saved to #{ secrets_file }"
         end

         def self.write_encrypted_file(file_path, decryption_key, content)
            lockbox = Lockbox.new(key: decryption_key)

            encrypted_data = lockbox.encrypt(content)

            # TODO: replace File.opens with photo_path.binwrite(uri.data) once FakeFS can handle it
            File.open(file_path.to_s, 'wb') { |f| f.write encrypted_data }
         end
      end
   end
end
