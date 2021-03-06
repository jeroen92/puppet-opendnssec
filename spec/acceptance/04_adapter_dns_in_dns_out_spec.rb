# frozen_string_literal: true

require 'spec_helper_acceptance'

# this test is flaxy due to a bug in opendnssec but
# i have never seen centos-7 work in travis-ci
describe 'opendnssec dns adapter -> dns adapter', tier_high: true do
  context 'defaults' do
    if fact('osfamily') == 'RedHat'
      enforcer = 'ods-enforcerd'
      signer = 'ods-signerd'
    else
      enforcer = 'opendnssec-enforcer'
      signer = 'opendnssec-signer'
    end
    it 'work with no errors' do
      pp = <<-EOF
      class {'::softhsm':
        tokens => {
          'OpenDNSSEC' => {
            'pin'    => '1234',
            'so_pin' => '1234',
          },
        },
      }
      contain softhsm
      class {'::opendnssec':
        zones => {
          'root-servers.net' => {
            'masters' => [
              'lax.xfr.dns.icann.org',
              'iad.xfr.dns.icann.org',
            ],
            'provide_xfrs' => ['localhost'],
          },
        },
        remotes  => {
          'lax.xfr.dns.icann.org' => {
            'address4' => '192.0.32.132',
            'address6' => '2620:0:2d0:202::132',
          },
          'iad.xfr.dns.icann.org' => {
            'address4' => '192.0.47.132',
            'address6' => '2620:0:2830:202::132',
          },
          'localhost' => {
            'address4' => '127.0.0.1',
            'port' => 5353,
          },
        },
      }
      contain opendnssec
      class {'::nsd':
        port    => 5353,
        zones   => { 'root-servers.net' => { 'masters' => ['localhost'] } },
        remotes => { 'localhost' => { 'address4' => '127.0.0.1', } },
      }
      EOF
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_failures: true)
      expect(apply_manifest(pp, catch_failures: true).exit_code).to eq 0
    end
    describe service(enforcer) do
      it { is_expected.to be_running }
    end
    describe service(signer) do
      it { is_expected.to be_running }
    end
    describe port(53) do
      it { is_expected.to be_listening }
    end
    describe command('/usr/sbin/ods-signer running') do
      its(:stdout) { is_expected.to match(%r{Engine running\.$}) }
    end
    describe command('/usr/bin/ods-hsmutil list') do
      its(:stdout) { is_expected.to match('RSA/1024') }
      its(:stdout) { is_expected.to match('RSA/2048') }
    end
    describe command('/usr/bin/ods-ksmutil repository list') do
      its(:stdout) { is_expected.to match(%r{SoftHSM\s+0\s+No}) }
    end
    describe command('/usr/bin/ods-ksmutil policy list') do
      its(:stdout) do
        is_expected.to match(
          %r{default\s+default - Deny:NSEC3; KSK:RSASHA1-NSEC3-SHA1; ZSK:RSASHA1-NSEC3-SHA1},
        )
      end
    end
    describe command('/usr/bin/ods-ksmutil zone list') do
      its(:stdout) do
        is_expected.to match('Found Zone: root-servers.net; on policy default')
      end
    end
    describe command('/usr/bin/ods-ksmutil key list') do
      its(:stdout) { is_expected.to match(%r{root-servers.net\s+KSK\s+publish}) }
      its(:stdout) { is_expected.to match(%r{root-servers.net\s+ZSK\s+active}) }
    end
    describe command('/usr/sbin/ods-signer zones') do
      its(:stdout) { is_expected.to match('root-servers.net') }
    end
    describe command('/usr/sbin/ods-signer queue') do
      its(:stdout) { is_expected.to match(%r{I will \[sign\] zone root-servers.net\b}) }
    end
    describe command(
      '/usr/bin/dig -p 5353 +dnssec soa root-servers.net @localhost',
    ) do
      its(:stdout) { is_expected.to match(%r{\bRRSIG\b}) }
    end
    describe command(
      '/usr/bin/dig -p 5353 +dnssec DNSKEY root-servers.net @localhost',
    ) do
      its(:stdout) { is_expected.to match(%r{\bDNSKEY\s+257\b}) }
      its(:stdout) { is_expected.to match(%r{\bDNSKEY\s+256\b}) }
      its(:stdout) { is_expected.to match(%r{\bRRSIG\b}) }
    end
  end
end
