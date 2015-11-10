require 'spec_helper'
describe 'webservices' do

  context 'with defaults for all parameters' do
    it { should contain_class('webservices') }
  end
end
