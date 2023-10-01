# frozen_string_literal: true

require 'spec_helper'

module Invar
   describe PrivateFile do
      # describe '#initialize' do
      #
      # end

      describe 'ALLOWED_MODES' do
         let(:user_mask) { 0o700 }
         let(:group_mask) { 0o070 }

         it 'should allow user read only' do
            user_modes = PrivateFile::ALLOWED_MODES.collect { |m| m & user_mask }.uniq

            expect(user_modes).to eq [0o600, 0o400]
         end

         it 'should allow user read write' do
            user_modes = PrivateFile::ALLOWED_MODES.collect { |m| m & user_mask }.uniq

            expect(user_modes).to eq [0o600, 0o400]
         end

         it 'should allow group read only' do
            user_modes = PrivateFile::ALLOWED_MODES.collect { |m| m & group_mask }.uniq

            expect(user_modes).to eq [0o060, 0o040, 0o000]
         end

         it 'should allow group read write' do
            user_modes = PrivateFile::ALLOWED_MODES.collect { |m| m & group_mask }.uniq

            expect(user_modes).to eq [0o060, 0o040, 0o000]
         end
      end

      describe '#read' do
         let(:file_path) { test_safe_path 'invar_test_file' }
         let(:private_file) { described_class.new file_path }

         before(:each) do
            file_path.dirname.mkpath
            file_path.write ''
            file_path.chmod 0o600
         end

         it 'should NOT complain when the file has proper permissions' do
            PrivateFile::ALLOWED_MODES.each do |mode|
               file_path.chmod(mode)

               expect do
                  private_file.read
               end.to_not raise_error
            end
         end

         it 'should forward the read call to the wrapped pathname' do
            expect(file_path).to receive(:read)

            private_file.read
         end

         context 'improper permissions' do
            # Each is an octal mode triplet [User, Group, Others].
            illegal_modes = (0o000..0o777).to_a - PrivateFile::ALLOWED_MODES

            illegal_modes.each do |mode|
               it "should complain when file has mode #{ format('%04o', mode) }" do
                  file_path.chmod mode

                  msg = "File '#{ file_path }' has improper permissions"

                  # '%04o' is string formatter speak for "4-digit octal"
                  mode_msg = format '%<mode>04o', mode: mode

                  expect do
                     private_file.read
                  end.to raise_error PrivateFile::FilePermissionsError,
                                     include(msg).and(include(mode_msg)).and(include('chmod 600'))
               end
            end
         end
      end
   end
end
