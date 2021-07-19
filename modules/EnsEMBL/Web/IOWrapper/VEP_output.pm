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

package EnsEMBL::Web::IOWrapper::VEP_output;

### Wrapper for Bio::EnsEMBL::IO::Parser::VEP_output, which builds
### simple hash features suitable for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(reduce);

use Bio::EnsEMBL::Variation::Utils::Constants;

use parent qw(EnsEMBL::Web::IOWrapper);

sub colourset { return 'variation'; }

sub create_hash {
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $seqname       = $self->parser->get_seqname;
  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $start         = $feature_start - $slice->start + 1;
  my $end           = $feature_end - $slice->start + 1;
  return if $end < 0 || $start > $slice->length;

  $metadata ||= {};

  my $href = $self->href({
                        'seq_region'  => $seqname,
                        'start'       => $feature_start,
                        'end'         => $feature_end,
                        'strand'      => 0,
                        });

  my $allele    = $self->parser->get_allele;
  my $cons      = $self->parser->get_consequence;

  my $feature = {
                  'seq_region'    => $seqname,
                  'allele'        => $allele,
                  'consequence'   => $cons,
                  'href'          => $href,
                };

  if ($metadata->{'display'} eq 'text') {
    $feature->{'start'} = $feature_start;
    $feature->{'end'}   = $feature_end;
    my @uploaded  = split(/_/, $self->parser->get_uploaded_variation);
    (my $cons_text = $cons) =~ s/_/ /g; 
    $feature->{'extra'} = [
                            {'name' => 'Alleles',         'value' => $uploaded[-1]},
                            {'name' => 'Variant allele',  'value' => $allele},
                            {'name' => 'Consequence',     'value' => $cons_text},
                            ];
    ## Additional arbitrary fields (depend on plugins)
    my %extras = %{$self->parser->get_extra};
    foreach my $key (sort keys %extras) {
      (my $name = $key) =~ s/_/ /g;
      push @{$feature->{'extra'}}, {'name' => $name, 'value' => $extras{$key}};
    }
  } 
  else {
    $feature->{'start'} = $start;
    $feature->{'end'}   = $end;
  }
  return $feature;
}
  
sub post_process {
### Collapse data down into unique features
### and assign consequence colours
  my ($self, $data) = @_;

  my %overlap_cons = %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my %cons_lookup = map { $overlap_cons{$_}{'SO_term'} => $overlap_cons{$_}{'rank'} } keys %overlap_cons;  
  my $colours = $self->hub->species_defs->colour('variation');

  while (my($key, $subtrack) = each (%$data)) {
    next unless scalar(@{$subtrack->{'features'}||[]});

    ## VEP output doesn't have real metadata, so fake some
    $subtrack->{'metadata'} = {
                                  'name'          => 'VEP consequence',
                                  'zmenu_caption' => 'VEP consequence',
                                };

    ## Group results into sets by start, end and allele; and then 
    ## merge them into a set of unique variants with multiple consequences 
    my ($start, $end, $allele, @unique_features);
    foreach my $f (
      sort {$a->{'start'} <=> $b->{'start'}
          || $a->{'end'} <=> $b->{'end'}
          || $a->{'allele'} cmp $b->{'allele'}
        } @{$subtrack->{'features'}}
    ) {
      my $previous = $unique_features[-1];
      if ($previous && $previous->{'start'} == $f->{'start'} && $previous->{'end'} == $f->{'end'} 
                && $previous->{'allele'} eq $f->{'allele'}) {
        $previous->{'consequences'}{$_} = 1 for split(/,/, $f->{'consequence'}); 
      }
      else {
        $f->{'consequences'}{$_} = 1 for split(/,/, $f->{'consequence'}); 
        push @unique_features, $f;
        $start  = $f->{'start'};
        $end    = $f->{'end'};
        $allele = $f->{'allele'};
      }
    }

    ## Now select the worst consequence as the feature colour
    foreach (@unique_features) {
      my @consequences = keys %{$_->{'consequences'}||{}};
      my $worst_consequence = reduce { $cons_lookup{$a} < $cons_lookup{$b} ? $a : $b } @consequences;
      $worst_consequence  ||= 'default';
      $_->{'colour'}        = $colours->{$worst_consequence}->{'default'};
      $_->{'label_colour'}  = $subtrack->{'metadata'}{'label_colour'} || $_->{'colour'};
      $_->{'label'}         = $worst_consequence; 
    }

    $data->{$key}{'features'} = \@unique_features;
  }
}


1;
