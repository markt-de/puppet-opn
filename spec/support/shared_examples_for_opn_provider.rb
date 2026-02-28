# frozen_string_literal: true

# Shared examples for all opn providers.
#
# Required let:
#   :type_name      - Symbol, e.g. :opn_firewall_rule
#   :provider_class - the provider class under test
RSpec.shared_examples 'opn provider basics' do
  it 'is registered as a provider' do
    expect(provider_class).not_to be_nil
  end

  it 'responds to :instances' do
    expect(provider_class).to respond_to(:instances)
  end

  it 'responds to :prefetch' do
    expect(provider_class).to respond_to(:prefetch)
  end

  context '#exists?' do
    it 'returns false when property_hash is empty' do
      provider = provider_class.new({})
      expect(provider.exists?).to be false
    end

    it 'returns true when ensure is :present' do
      provider = provider_class.new(ensure: :present)
      expect(provider.exists?).to be true
    end
  end
end

# Shared examples for providers that manage a config property.
#
# Required let:
#   :provider_class - the provider class under test
RSpec.shared_examples 'opn provider with config property' do
  it '#config returns property_hash[:config]' do
    provider = provider_class.new(config: { 'key' => 'val' })
    expect(provider.config).to eq('key' => 'val')
  end

  it '#config= stores pending config' do
    provider = provider_class.new({})
    provider.config = { 'new' => 'val' }
    # Verify the instance variable was set
    expect(provider.instance_variable_get(:@pending_config)).to eq('new' => 'val')
  end
end
