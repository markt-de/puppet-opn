# frozen_string_literal: true

# Shared examples for standard opn types with "name@device" namevar pattern.
#
# Required let:
#   :type_name  - Symbol, e.g. :opn_firewall_rule
#   :title      - String, e.g. 'myrule@fw01'
RSpec.shared_examples 'opn type with device parameter' do
  let(:type_class) { Puppet::Type.type(type_name) }

  it 'is a valid type' do
    expect(type_class).not_to be_nil
  end

  it 'has :name as its namevar' do
    expect(type_class.key_attributes).to eq([:name])
  end

  context 'with name@device title' do
    let(:resource) { type_class.new(name: title) }

    it 'extracts device from title' do
      expect(resource[:device]).to eq(title.split('@', 2).last)
    end

    it 'defaults ensure to present' do
      expect(resource[:ensure]).to eq(:present)
    end
  end

  context 'without @ in title' do
    let(:resource) { type_class.new(name: 'simple') }

    it 'defaults device to "default"' do
      expect(resource[:device]).to eq('default')
    end
  end

  it 'rejects empty name' do
    expect { type_class.new(name: '') }.to raise_error(Puppet::Error)
  end

  it 'autorequires the device YAML file' do
    catalog = Puppet::Resource::Catalog.new
    device = title.include?('@') ? title.split('@', 2).last : 'default'
    file_path = "/etc/puppet/opn/#{device}.yaml"
    file_res = Puppet::Type.type(:file).new(name: file_path)
    opn_res = type_class.new(name: title)
    catalog.add_resource(file_res)
    catalog.add_resource(opn_res)
    reqs = opn_res.autorequire
    expect(reqs.size).to eq(1)
    expect(reqs[0].source.to_s).to eq("File[#{file_path}]")
  end
end

# Shared examples for singleton types where namevar = device name (no '@').
#
# Required let:
#   :type_name  - Symbol, e.g. :opn_haproxy_settings
#   :title      - String, e.g. 'fw01'
RSpec.shared_examples 'opn singleton type' do
  let(:type_class) { Puppet::Type.type(type_name) }

  it 'is a valid type' do
    expect(type_class).not_to be_nil
  end

  it 'has :name as its namevar' do
    expect(type_class.key_attributes).to eq([:name])
  end

  context 'with device name title' do
    let(:resource) { type_class.new(name: title) }

    it 'defaults ensure to present' do
      expect(resource[:ensure]).to eq(:present)
    end
  end

  it 'rejects empty name' do
    expect { type_class.new(name: '') }.to raise_error(Puppet::Error)
  end

  it 'autorequires the device YAML file' do
    catalog = Puppet::Resource::Catalog.new
    file_path = "/etc/puppet/opn/#{title}.yaml"
    file_res = Puppet::Type.type(:file).new(name: file_path)
    opn_res = type_class.new(name: title)
    catalog.add_resource(file_res)
    catalog.add_resource(opn_res)
    reqs = opn_res.autorequire
    expect(reqs.size).to eq(1)
    expect(reqs[0].source.to_s).to eq("File[#{file_path}]")
  end
end

# Shared examples for types with a config property that accepts Hash.
#
# Required let:
#   :type_name  - Symbol
#   :title      - String
RSpec.shared_examples 'opn type with config property' do
  let(:type_class) { Puppet::Type.type(type_name) }

  it 'accepts a Hash for config' do
    resource = type_class.new(name: title, config: { 'key' => 'val' })
    expect(resource[:config]).to eq('key' => 'val')
  end

  it 'rejects a String for config' do
    expect { type_class.new(name: title, config: 'notahash') }.to raise_error(Puppet::Error, %r{must be a Hash})
  end

  it 'rejects an Array for config' do
    expect { type_class.new(name: title, config: ['a']) }.to raise_error(Puppet::Error, %r{must be a Hash})
  end
end

# Shared examples for types without config property (e.g. opn_plugin).
#
# Required let:
#   :type_name  - Symbol
#   :title      - String
RSpec.shared_examples 'opn type without config property' do
  let(:type_class) { Puppet::Type.type(type_name) }

  it 'does not have a config property' do
    resource = type_class.new(name: title)
    expect(resource.property(:config)).to be_nil
  end
end
