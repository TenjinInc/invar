require 'spec_helper'

describe Dirt::Envelope do
   it 'has a version number' do
      expect(Dirt::Envelope::VERSION).not_to be nil
   end

   it 'should define ENVELOPE as soon as the file is required'

   describe 'initialize' do
      it 'should default namespace to app_'
   end

   describe '#[]=' do
      it 'should assign the variable in the wrapped env'
      it 'should assign using namespace'
      it 'should translate symbol keys into strings'
   end

   describe '#[]' do
      it 'should lookup the variable in the wrapped env'
      it 'should lookup using namespace'
      it 'should translate symbol keys into strings'

      context 'optional_prefix on' do
         it 'should lookup without namespace if not found under namespace'
      end

      context 'optional_prefix off' do
         it 'should return nil if nothing found with subgroup prefix'
      end
   end

   describe '#namespace' do
      it 'should return a clone with the given namespace'
      it 'should interpret nil as empty string'
   end

   describe 'require' do
      it 'should explode when expected env var is empty string (? or maybe just when provided on CLI? scratch this feature?)'

      # What about a CLI asking for missing variables? This would make running dev commands nicer.
   end

   describe 'expect' do
      it 'should explode if a smartenv var is `expect`-ed after being `require`-ed'
   end
end
