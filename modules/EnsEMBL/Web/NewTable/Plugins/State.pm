=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::State;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(SessionState)]; }
sub requires { return children(); }

package EnsEMBL::Web::NewTable::Plugins::SessionState;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

use JSON;

sub activity_save_orient {
  my ($self,$config) = @_;

  my $hub = $self->hub;
  my $session = $hub->session;
  my $orient_in = $hub->param('orient');
  my $seq = $hub->param('seq');

  my $orient;
  eval {
    $orient = JSON->new->decode($orient_in);
  };
  warn "$@\n" if $@;
  return unless defined $orient;

  $config->filter_saved($orient);

  my %args    = ( type => 'Newtable', code => $config->class );

  # Sequence check
  my %data_in = %{$session->get_record_data(\%args)};
  my $old_seq = $data_in{'seq'}||-1;
  my $new_seq = $hub->param('seq')||0;

  return if $old_seq >= $new_seq; # Out of order

  my %data;
  eval {
    $data{'orient'} = JSON->new->encode($orient);
    $data{'seq'} = $new_seq;
  };
  warn "$@\n" if $@;

  $session->set_record_data({%args, %data}) if scalar keys %data;

  return {};
}

sub activity_load_orient {
  my ($self,$config) = @_;

  my $hub = $self->hub;
  my %args    = ( type => 'Newtable', code => $config->class );
  my $out = $hub->session->get_record_data(\%args);
  return { orient => JSON->new->decode($out->{'orient'})||{} };
}

1;
