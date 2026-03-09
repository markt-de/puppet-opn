# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/opn/service_reconfigure'

describe PuppetX::Opn::ServiceReconfigure do
  let(:client) { instance_double('PuppetX::Opn::ApiClient') }

  # Each test registers its own instances; clean up afterwards.
  after(:each) do
    described_class.reset!
  end

  # -- Registration and Registry --

  describe '.register' do
    it 'registers a new reconfigure group' do
      instance = described_class.register(:test_svc,
        endpoint: 'test/service/reconfigure', log_prefix: 'opn_test')
      expect(instance).to be_a(described_class)
    end

    it 'is idempotent — second call returns the same instance' do
      inst1 = described_class.register(:test_svc,
        endpoint: 'test/service/reconfigure', log_prefix: 'opn_test')
      inst2 = described_class.register(:test_svc,
        endpoint: 'other/endpoint', log_prefix: 'other')
      expect(inst2).to equal(inst1)
    end
  end

  describe '.[]' do
    it 'returns a registered instance' do
      described_class.register(:test_svc,
        endpoint: 'test/service/reconfigure', log_prefix: 'opn_test')
      expect(described_class[:test_svc]).to be_a(described_class)
    end

    it 'raises error for unknown name' do
      expect { described_class[:nonexistent] }.to raise_error(Puppet::Error, %r{unknown group})
    end
  end

  describe '.registered_names' do
    it 'lists all registered groups' do
      described_class.register(:alpha,
        endpoint: 'a/reconfigure', log_prefix: 'a')
      described_class.register(:beta,
        endpoint: 'b/reconfigure', log_prefix: 'b')
      expect(described_class.registered_names).to contain_exactly(:alpha, :beta)
    end
  end

  describe '.reset!' do
    it 'clears registry and instance state' do
      described_class.register(:test_svc,
        endpoint: 'test/service/reconfigure', log_prefix: 'opn_test')
      described_class[:test_svc].mark('opnsense01', client)
      described_class.reset!
      expect(described_class.registered_names).to be_empty
    end
  end

  # -- Simple Reconfigure (no configtest) --

  context 'simple reconfigure (no configtest)' do
    let(:instance) do
      described_class.register(:simple,
        endpoint: 'test/service/reconfigure', log_prefix: 'opn_test')
    end

    describe '#mark' do
      it 'registers a device' do
        instance.mark('opnsense01', client)
        # Verification via run — mark alone has no observable side-effect.
        expect(client).to receive(:post)
          .with('test/service/reconfigure', {})
          .and_return({ 'status' => 'ok' })
        instance.run
      end

      it 'does not overwrite existing entry' do
        other = instance_double('PuppetX::Opn::ApiClient')
        instance.mark('opnsense01', client)
        instance.mark('opnsense01', other)
        # First client should be used, not the second.
        expect(client).to receive(:post)
          .with('test/service/reconfigure', {})
          .and_return({ 'status' => 'ok' })
        expect(other).not_to receive(:post)
        instance.run
      end
    end

    describe '#run' do
      it 'calls POST on the reconfigure endpoint' do
        instance.mark('opnsense01', client)
        expect(client).to receive(:post)
          .with('test/service/reconfigure', {})
          .and_return({ 'status' => 'ok' })
        instance.run
      end

      it 'clears tracking hash after execution' do
        instance.mark('opnsense01', client)
        allow(client).to receive(:post).and_return({ 'status' => 'ok' })
        instance.run
        # Second run should be a no-op.
        expect(client).not_to receive(:post)
        instance.run
      end

      it 'logs warning on unexpected status' do
        instance.mark('opnsense01', client)
        allow(client).to receive(:post).and_return({ 'status' => 'error' })
        expect(Puppet).to receive(:warning).with(%r{unexpected status})
        instance.run
      end

      it 'catches API errors and logs as err' do
        instance.mark('opnsense01', client)
        allow(client).to receive(:post).and_raise(Puppet::Error, 'connection failed')
        expect(Puppet).to receive(:err).with(%r{failed})
        instance.run
      end

      it 'is a no-op when no devices are marked' do
        expect(client).not_to receive(:post)
        instance.run
      end

      it 'reconfigures multiple devices' do
        client2 = instance_double('PuppetX::Opn::ApiClient')
        instance.mark('opnsense01', client)
        instance.mark('opnsense02', client2)
        expect(client).to receive(:post)
          .with('test/service/reconfigure', {})
          .and_return({ 'status' => 'ok' })
        expect(client2).to receive(:post)
          .with('test/service/reconfigure', {})
          .and_return({ 'status' => 'ok' })
        instance.run
      end
    end
  end

  # -- HAProxy pattern: configtest + error tracking --

  context 'reconfigure with configtest' do
    let(:instance) do
      described_class.register(:haproxy_test,
        endpoint: 'haproxy/service/reconfigure',
        log_prefix: 'opn_haproxy',
        configtest_endpoint: 'haproxy/service/configtest')
    end

    describe '#run with configtest' do
      it 'runs configtest then reconfigure on success' do
        instance.mark('opnsense01', client)
        expect(client).to receive(:get)
          .with('haproxy/service/configtest')
          .and_return({ 'result' => 'Configuration file is valid' })
        expect(client).to receive(:post)
          .with('haproxy/service/reconfigure', {})
          .and_return({ 'status' => 'ok' })
        instance.run
      end

      it 'skips reconfigure on ALERT' do
        instance.mark('opnsense01', client)
        allow(client).to receive(:get)
          .with('haproxy/service/configtest')
          .and_return({ 'result' => '[ALERT] some error' })
        expect(client).not_to receive(:post)
        instance.run
      end

      it 'proceeds on WARNING' do
        instance.mark('opnsense01', client)
        allow(client).to receive(:get)
          .with('haproxy/service/configtest')
          .and_return({ 'result' => '[WARNING] some warning' })
        expect(client).to receive(:post)
          .with('haproxy/service/reconfigure', {})
          .and_return({ 'status' => 'ok' })
        instance.run
      end
    end

    describe '#mark_error' do
      it 'skips reconfigure for errored devices' do
        instance.mark('opnsense01', client)
        instance.mark_error('opnsense01')
        expect(client).not_to receive(:get)
        expect(client).not_to receive(:post)
        instance.run
      end
    end

    it 'clears both tracking hashes after run' do
      instance.mark('opnsense01', client)
      instance.mark_error('opnsense02')
      allow(client).to receive_messages(
        get: { 'result' => 'ok' },
        post: { 'status' => 'ok' },
      )
      instance.run
      # Second call should be a no-op.
      expect(client).not_to receive(:get)
      expect(client).not_to receive(:post)
      instance.run
    end
  end

  # -- Error tracking without configtest --

  context 'error tracking without configtest' do
    let(:instance) do
      described_class.register(:simple_error,
        endpoint: 'test/service/reconfigure', log_prefix: 'opn_test')
    end

    it 'skips reconfigure for errored devices' do
      instance.mark('opnsense01', client)
      instance.mark_error('opnsense01')
      expect(client).not_to receive(:post)
      expect(Puppet).to receive(:err).with(%r{skipping reconfigure.*opnsense01})
      instance.run
    end

    it 'still reconfigures non-errored devices' do
      client2 = instance_double('PuppetX::Opn::ApiClient')
      instance.mark('opnsense01', client)
      instance.mark('opnsense02', client2)
      instance.mark_error('opnsense01')
      # opnsense01 should be skipped, opnsense02 should proceed.
      expect(client).not_to receive(:post)
      expect(Puppet).to receive(:err).with(%r{skipping reconfigure.*opnsense01})
      expect(client2).to receive(:post)
        .with('test/service/reconfigure', {})
        .and_return({ 'status' => 'ok' })
      instance.run
    end
  end

  # -- State isolation between groups --

  describe 'state isolation' do
    it 'group_b run does not trigger group_a devices' do
      inst_a = described_class.register(:group_a,
        endpoint: 'a/reconfigure', log_prefix: 'a')
      inst_b = described_class.register(:group_b,
        endpoint: 'b/reconfigure', log_prefix: 'b')

      client_a = instance_double('PuppetX::Opn::ApiClient')
      inst_a.mark('opnsense01', client_a)

      # group_b has no marked devices — run must not call group_a's client
      expect(client_a).not_to receive(:post)
      inst_b.run
    end

    it 'group_a run triggers only its own marked devices' do
      inst_a = described_class.register(:group_a,
        endpoint: 'a/reconfigure', log_prefix: 'a')

      client_a = instance_double('PuppetX::Opn::ApiClient')
      inst_a.mark('opnsense01', client_a)

      expect(client_a).to receive(:post)
        .with('a/reconfigure', {})
        .and_return({ 'status' => 'ok' })
      inst_a.run
    end
  end
end
