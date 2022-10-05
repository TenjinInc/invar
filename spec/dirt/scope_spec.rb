# frozen_string_literal: true

require 'spec_helper'

module Dirt
   module Envelope
      describe Scope do
         describe '#initialize' do
            let(:scope) { described_class.new }

            it 'should freeze scopes' do
               expect(scope).to be_frozen
            end
         end

         # Slash operator
         describe '#/' do
            let(:data) do
               {
                     domain:   'example.com',
                     database: {
                           name: 'test_db',
                           host: 'localhost',
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
         end
      end
   end
end
