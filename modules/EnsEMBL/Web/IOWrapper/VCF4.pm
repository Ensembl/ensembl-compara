=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::IOWrapper::VCF4;

### Wrapper for Bio::EnsEMBL::IO::Parser::VCF4, which builds
### simple hash features suitable for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

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

  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $start         = $feature_start - $slice->start + 1;
  my $end           = $feature_end - $slice->start + 1;
  return if $end < 0 || $start > $slice->length;

  my $seqname       = $self->parser->get_seqname;
  my @feature_ids   = @{$self->parser->get_IDs};

  ## Work out what kind of variant we have
  my $type;
  my $ref = $self->parser->get_raw_reference;
  foreach my $alt (@{$self->parser->get_alternatives}) {
    if (length($alt) > length($ref)) {
      $type = 'insertion';
      last;
    }
    elsif (length($alt) < length($ref)) {
      $type = 'deletion';
      last;
    }
  }

  $metadata ||= {};

  my $href = $self->href({
                        'seq_region'  => $seqname,
                        'start'       => $feature_start,
                        'end'         => $feature_end,
                        });

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my @alleles = ($self->parser->get_reference);
  push @alleles, @{$self->parser->get_alternatives};
  my $feature = {
    'seq_region'    => $seqname,
    'label'         => join(',', @feature_ids),
    };
  my $parsed_info   = $self->parser->get_info || {};
  use Data::Dumper; warn Dumper($parsed_info);
  my $allele_string = join('/', @alleles);
  my $vf_name       = $feature_ids[0] eq '.' ? sprintf('%s_%s_%s', $seqname, $feature_start, $allele_string) : $feature_ids[0];
  if ($metadata->{'display'} eq 'text') {
    $feature->{'start'} = $feature_start;
    ## Indels include the base pair before the actual variant
    $feature->{'end'}   = $feature_end == $feature_start ? $feature_end : $feature_end - 1;

    $feature->{'extra'} = [
                        {'name' => 'Alleles', 'value' => $allele_string},
                        {'name' => 'Quality', 'value' => $self->parser->get_score},
                        {'name' => 'Filter',  'value' => $self->parser->get_raw_filter_results},
                        ];

    ## Convert INFO field into a hash
    foreach my $field (sort keys %$parsed_info) {
      push @{$feature->{'extra'}}, {'name' => $field, 'value' => $parsed_info->{$field}};   
    }
  }
  else {
    my ($consequence, $ambig_code);
    if (defined($parsed_info->{'VE'})) {
      $consequence = (split /\|/, $parsed_info->{'VE'})[0];
      ## Set flag so we know we don't need to recalculate in glyphset
      $metadata->{'has_consequences'} = 1;
    }

    ## Set colour by consequence if possible
    my $colours       = $metadata->{'colours'};
    my $colour        = $colours->{'default'}->{'default'} || $metadata->{'colour'};
    my %overlap_cons  = %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
    if ($consequence && defined($overlap_cons{$consequence})) {
      $colour = $colours->{lc $consequence}->{'default'};
    }


    $feature->{'start'}             = $start;
    $feature->{'end'}               = $end;
    $feature->{'href'}              = $href;
    $feature->{'type'}              = $type;
    $feature->{'colour'}            = $colour;
    $feature->{'label_colour'}      = $metadata->{'label_colour'} || $colour;
    $feature->{'text_overlay'}      = $ambig_code;
    $feature->{'vf_name'}           = $vf_name;
    $feature->{'alleles'}           = join('/', @alleles);
    $feature->{'consequence_type'}  = $parsed_info->{'SVTYPE'} ? ['COMPLEX_INDEL'] : ['INTERGENIC'];
  }
  return $feature;
}

1;
