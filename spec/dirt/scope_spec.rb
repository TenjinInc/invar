# frozen_string_literal: true

require 'spec_helper'

module Dirt
   module Envelope
      describe Scope do
         describe '#initialize' do
            it 'should freeze scopes' do
               expect(described_class.new).to be_frozen
            end
         end

         # Slash operator
         describe '#/' do
            let(:data) do
               {
                     domain:   'example.com',
                     database: {
                           name: 'test_db',
                           host: 'localhost'
                     },
                     party:    {
                           name: 'Birthday',
                           host: 'Bilbo Baggins'
                     }
               }
            end
            let(:scope) { described_class.new data }

            it 'should fetch values with a symbol' do
               expect(scope / :domain).to eq 'example.com'
            end

            it 'should fetch values with a string' do
               expect(scope / 'domain').to eq 'example.com'
            end

            it 'should scope into subsections with a symbol' do
               expect(scope / :database / :host).to eq 'localhost'
            end

            it 'should scope into subsections with a string' do
               expect(scope / 'database' / 'host').to eq 'localhost'
            end

            it 'should alias #fetch' do
               expect(scope.fetch(:party).fetch(:host)).to eq 'Bilbo Baggins'
            end

            it 'should alias #[]' do
               expect(scope[:party][:host]).to eq 'Bilbo Baggins'
            end

            # easier to know if your key is totally wrong or if it's missing
            it 'should say the existing keys on key missing' do
               expect do
                  scope / :database / :another_key
               end.to raise_error KeyError, 'key not found: :another_key. Known keys are :name, :host'
            end
         end

         describe '#override' do
            let(:data) do
               {
                     event: 'Birthday',
                     host:  'Bilbo Baggins'
               }
            end
            let(:scope) { described_class.new data }

            it 'should override a data field' do
               scope.override(event: 'Disappearance')
            end

            it 'should override multiple data fields' do
               scope.override(event: 'Fireworks', host: 'Gandalf')

               expect(scope / :event).to eq 'Fireworks'
               expect(scope / :host).to eq 'Gandalf'
            end
         end
      end
   end
end
