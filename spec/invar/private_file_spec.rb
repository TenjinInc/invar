# frozen_string_literal: true

require 'spec_helper'

module Invar
   describe PrivateFile do
      # describe '#initialize' do
      #
      # end

      describe '#read' do
         let(:file_path) { Pathname.new('invar_test_file') }
         let(:private_file) { described_class.new file_path }

         before(:each) do
            file_path.write ''
            file_path.chmod(0o600)
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
            # Generating each test instance separately to be very explicit about each one being tested.
            # Could have gotten fancy and calculate it, but tests should be clear.
            # Testing each mode segment individually and not testing the combos because that is a bit slow
            # and redundant.
            # Each is an octal mode triplet [User, Group, Others].
            illegal_modes = [0o000, 0o001, 0o002, 0o003, 0o004, 0o005, 0o006, 0o007, # world / others
                             0o000, 0o010, 0o020, 0o030, 0o050, 0o070, # group
                             0o000, 0o100, 0o200, 0o300, 0o500, 0o700] # user
            illegal_modes.each do |mode|
               it "should complain when file has mode #{ format('%04o', mode) }" do
                  file_path.chmod(mode)

                  msg = "File '#{ file_path }' has improper permissions"

                  # '%04o' is string formatter speak for "4-digit octal"
                  mode_msg = format("%<mode>04o", mode: mode)

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
