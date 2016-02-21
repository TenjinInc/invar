require 'spec_helper'

describe Dirt::Envelope do
  it 'has a version number' do
    expect(Dirt::Envelope::VERSION).not_to be nil
  end

end
