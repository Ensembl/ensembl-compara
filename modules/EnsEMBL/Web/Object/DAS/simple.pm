=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::DAS::simple;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;
  return [
	  {
	      'REGION' => '*',
	      'FEATURES' => [
			     { 'id' => 'simple feature'  }
			     ]
			     }
	  ];
}

sub Features {
  my $self = shift;
  return $self->base_features( 'SimpleFeature', 'simple_alignment' );
}

sub _feature {
  my( $self, $feature ) = @_;

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my $type          = $feature->analysis->logic_name;
  my $display_label = $feature->display_label;
  warn $feature;
  my $slice_name = $self->slice_cache( $feature->slice );
  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
    'ID'          => $type,
    'TYPE'        => "simple feature:$type",
    'SCORE'       => $feature->score,
    'METHOD'      => $type,
    'CATEGORY'    => $type,
    'ORIENTATION' => $self->ori( $feature->seq_region_strand ),
    'START'       => $feature->seq_region_start,
    'END'         => $feature->seq_region_end,
  };
## Return the reference to an array of the slice specific hashes.
}

1;
