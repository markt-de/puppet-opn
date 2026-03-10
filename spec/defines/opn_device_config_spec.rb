# frozen_string_literal: true

require 'spec_helper'

describe 'opn::device_config' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'opnsense01' }

      # The defined type requires File[$config_dir] to exist
      let(:pre_condition) do
        "file { '/etc/puppet/opn': ensure => directory }"
      end

      context 'with valid parameters' do
        let(:params) do
          {
            'config_dir'    => '/etc/puppet/opn',
            'device_config' => {
              'url'        => 'https://opnsense01.example.com/api',
              'api_key'    => 'testkey',
              'api_secret' => 'testsecret',
            },
            'group'         => 'root',
            'owner'         => 'root',
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'creates the credential file with mode 0600 and hidden diff' do
          is_expected.to contain_file('/etc/puppet/opn/opnsense01.yaml').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0600',
            show_diff: false,
          )
        end

        it 'requires the config directory' do
          is_expected.to contain_file('/etc/puppet/opn/opnsense01.yaml').that_requires(
            'File[/etc/puppet/opn]',
          )
        end
      end
    end
  end
end
