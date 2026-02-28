# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/api_client'

describe PuppetX::Opn::ApiClient do
  let(:url) { 'https://fw.example.com/api' }
  let(:api_key) { 'testkey' }
  let(:api_secret) { 'testsecret' }

  describe '#initialize' do
    it 'stores parameters' do
      client = described_class.new(url: url, api_key: api_key, api_secret: api_secret)
      expect(client.instance_variable_get(:@url)).to eq('https://fw.example.com/api')
      expect(client.instance_variable_get(:@api_key)).to eq('testkey')
      expect(client.instance_variable_get(:@api_secret)).to eq('testsecret')
    end

    it 'strips trailing slash from URL' do
      client = described_class.new(url: 'https://fw/api/', api_key: 'k', api_secret: 's')
      expect(client.instance_variable_get(:@url)).to eq('https://fw/api')
    end

    it 'defaults ssl_verify to true' do
      client = described_class.new(url: url, api_key: 'k', api_secret: 's')
      expect(client.instance_variable_get(:@ssl_verify)).to be true
    end

    it 'defaults timeout to 60' do
      client = described_class.new(url: url, api_key: 'k', api_secret: 's')
      expect(client.instance_variable_get(:@timeout)).to eq(60)
    end
  end

  describe '.from_device' do
    let(:config_dir) { Dir.mktmpdir }
    let(:device_config) do
      {
        'url'        => 'https://fw01.example.com/api',
        'api_key'    => 'key1',
        'api_secret' => 'secret1',
        'ssl_verify' => false,
        'timeout'    => 30,
      }
    end

    before(:each) do
      allow(described_class).to receive(:config_base_dir).and_return(config_dir)
    end

    after(:each) { FileUtils.rm_rf(config_dir) }

    it 'creates client from YAML' do
      File.write(File.join(config_dir, 'fw01.yaml'), YAML.dump(device_config))
      client = described_class.from_device('fw01')
      expect(client.instance_variable_get(:@url)).to eq('https://fw01.example.com/api')
      expect(client.instance_variable_get(:@api_key)).to eq('key1')
      expect(client.instance_variable_get(:@ssl_verify)).to be false
      expect(client.instance_variable_get(:@timeout)).to eq(30)
    end

    it 'raises on missing file' do
      expect { described_class.from_device('nonexistent') }.to raise_error(
        Puppet::Error, %r{config file not found}
      )
    end

    it 'raises on malformed file' do
      File.write(File.join(config_dir, 'bad.yaml'), 'just a string')
      expect { described_class.from_device('bad') }.to raise_error(
        Puppet::Error, %r{not a valid YAML hash}
      )
    end

    it 'falls back to DEFAULT_URL when url is missing' do
      File.write(File.join(config_dir, 'nourl.yaml'), YAML.dump({ 'api_key' => 'k', 'api_secret' => 's' }))
      client = described_class.from_device('nourl')
      expect(client.instance_variable_get(:@url)).to eq('http://localhost:80/api')
    end
  end

  describe '.device_names' do
    let(:config_dir) { Dir.mktmpdir }

    before(:each) do
      allow(described_class).to receive(:config_base_dir).and_return(config_dir)
    end

    after(:each) { FileUtils.rm_rf(config_dir) }

    it 'returns names from YAML files' do
      File.write(File.join(config_dir, 'fw01.yaml'), '')
      File.write(File.join(config_dir, 'fw02.yaml'), '')
      expect(described_class.device_names).to contain_exactly('fw01', 'fw02')
    end

    it 'returns empty array when no files' do
      expect(described_class.device_names).to eq([])
    end
  end

  # Helper to build a mock Net::HTTP and wire it into the client
  shared_context 'with mocked http' do
    let(:mock_http) { instance_double(Net::HTTP) }
    let(:client) { described_class.new(url: url, api_key: api_key, api_secret: api_secret) }

    before(:each) do
      allow(Net::HTTP).to receive(:new).and_return(mock_http)
      allow(mock_http).to receive(:open_timeout=)
      allow(mock_http).to receive(:read_timeout=)
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:verify_mode=)
    end

    def mock_response(code, body, headers = {})
      resp = instance_double(Net::HTTPResponse)
      allow(resp).to receive_messages(code: code.to_s, body: body)
      headers.each do |key, value|
        allow(resp).to receive(:[]).with(key).and_return(value)
      end
      # Default nil for unset headers
      allow(resp).to receive(:[]).with('location').and_return(headers['location']) unless headers.key?('location')
      resp
    end
  end

  describe '#get' do
    include_context 'with mocked http'

    it 'performs GET and parses JSON' do
      resp = mock_response(200, '{"rows":[]}')
      allow(mock_http).to receive(:request).and_return(resp)

      result = client.get('firewall/alias/search_item')
      expect(result).to eq('rows' => [])
    end

    it 'raises on HTTP error' do
      resp = mock_response(500, 'Internal Server Error')
      allow(mock_http).to receive(:request).and_return(resp)

      expect { client.get('bad/path') }.to raise_error(Puppet::Error, %r{API error 500})
    end

    it 'returns empty hash on empty body' do
      resp = mock_response(200, '')
      allow(mock_http).to receive(:request).and_return(resp)

      expect(client.get('empty')).to eq({})
    end
  end

  describe '#post' do
    include_context 'with mocked http'

    it 'performs POST with JSON body and parses response' do
      resp = mock_response(200, '{"result":"saved"}')
      allow(mock_http).to receive(:request).and_return(resp)

      result = client.post('firewall/filter/add_rule', { 'rule' => { 'action' => 'pass' } })
      expect(result).to eq('result' => 'saved')
    end

    it 'raises on JSON parse error' do
      resp = mock_response(200, 'not json')
      allow(mock_http).to receive(:request).and_return(resp)

      expect { client.post('bad/json', {}) }.to raise_error(Puppet::Error, %r{parse error})
    end
  end

  describe 'redirect handling' do
    include_context 'with mocked http'

    let(:url) { 'http://fw.example.com/api' }

    it 'follows 308 redirect preserving method' do
      redirect_resp = mock_response(308, '', 'location' => 'https://fw.example.com/api/test')
      ok_resp = mock_response(200, '{"ok":true}')
      allow(mock_http).to receive(:request).and_return(redirect_resp, ok_resp)

      expect(client.post('test', {})).to eq('ok' => true)
    end

    it 'follows 302 redirect switching to GET' do
      redirect_resp = mock_response(302, '', 'location' => 'https://fw.example.com/api/redir')
      ok_resp = mock_response(200, '{"redirected":true}')
      allow(mock_http).to receive(:request).and_return(redirect_resp, ok_resp)

      expect(client.post('redir', {})).to eq('redirected' => true)
    end

    it 'raises on too many redirects' do
      redirect_resp = mock_response(301, '', 'location' => 'http://fw.example.com/api/loop')
      allow(mock_http).to receive(:request).and_return(redirect_resp)

      expect { client.get('loop') }.to raise_error(Puppet::Error, %r{too many redirects})
    end
  end

  describe 'connection errors' do
    include_context 'with mocked http'

    it 'raises Puppet::Error on connection refused' do
      allow(mock_http).to receive(:request).and_raise(Errno::ECONNREFUSED)
      expect { client.get('test') }.to raise_error(Puppet::Error, %r{connection failed})
    end

    it 'raises Puppet::Error on timeout' do
      allow(mock_http).to receive(:request).and_raise(Net::OpenTimeout)
      expect { client.get('test') }.to raise_error(Puppet::Error, %r{timeout})
    end
  end
end
