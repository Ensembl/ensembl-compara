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

# Check if the gene expresion atlas site is up or down; if down display down message in component, if up show widget

package EnsEMBL::Web::Tools::FailOver::Wasabi;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Tools::FailOver);

sub new {
  my ($proto,$hub) = @_;

  my $self        = $proto->SUPER::new("wasabi");
  $self->{'hub'}  = $hub;
  $self->{'check_url'}  = $hub->get_ExtURL('WASABI_ENSEMBL'); # www.ebi.ac.uk/gxa/home
  return $self;
}

sub endpoints         { return ['direct']; }
sub fail_for          { return 120; } # seconds after a failure to try checking again
sub failure_dir       { return $_[0]->{'hub'}->species_defs->ENSEMBL_FAILUREDIR; }
sub min_initial_dead  { return 5; }
sub successful        { return $_[1]; }

sub attempt {
  my ($self,$endpoint,$payload,$tryhard) = @_;
  my $check_url = $self->{'check_url'};
  return 0 unless defined $check_url;
  my $ua = LWP::UserAgent->new;
  my $proxy = $self->{'hub'}->web_proxy;
  $ua->proxy('http',$proxy) if $proxy;
  $ua->timeout(2);
  my $response = $ua->get($check_url);

  if($response->is_success) {
    return 1;
  }
  else {
    return 0;
  }
}

1;
