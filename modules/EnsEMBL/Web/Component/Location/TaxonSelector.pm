=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::TaxonSelector;

use strict;

use base qw(EnsEMBL::Web::Component::TaxonSelector);

sub _init {
  my $self = shift;
  my $hub  = $self->hub;
  my $species = $hub->species;
  $self->{multiselect} = 0;

  # For region comparison
  if ($hub->param('referer_action') eq 'Multi') {
    my $urlParams = { map { ($_ => $hub->param($_)) } $hub->param };
    my @default_species = [];
    # Get default keys (default selected) for region comparison
    my $shown = [ map { $urlParams->{$_} } grep m/^s(\d+)/, keys %$urlParams ]; # get species (and parameters) already shown on the page
    push @{$self->{default_species}}, @$shown if scalar @$shown;
    $self->{multiselect} = 1;
  }
  else {
    my $alignment = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$hub->param('align')};
    $self->{align_label} = $alignment->{name} if ($alignment->{'class'} !~ /pairwise/);

    my $sp;
    my $vc_key;
    my $vc_val = 0;
    my $alignment_selector_vc = $hub->session->get_record_data({type => 'view_config', code => 'alignments_selector'});
    $self->{default_species} = [];
    $self->{title} = 'Alignments Selector';


    foreach (keys %{$alignment->{species}}) {
      next if ($_ eq $hub->species);
      if ($alignment->{'class'} !~ /pairwise/) { # Multiple alignments
        $vc_key = join '_', ('species', $alignment->{id}, lc($_));
        if (keys %$alignment_selector_vc && $alignment_selector_vc->{$species}) {
          $vc_val = $alignment_selector_vc->{$species}->{$vc_key};
          push @{$self->{default_species}}, $vc_key if $vc_val eq 'yes';
        }
      }
      else {
        push @{$self->{default_species}}, $_;
      }
    }
  }
  $self->SUPER::_init();
}

1;

