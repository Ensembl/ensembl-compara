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

package EnsEMBL::Web::Object::DAS::base_align;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub base_align_features {
### Return das features...
  my( $self, $feature_type, $feature_label ) = @_;
  $self->{'featureview_url'} = sprintf( '%s/%s/Location/Genome?ftype=%s;id=%%s', # what about db???
    $self->species_defs->ENSEMBL_BASE_URL, $self->real_species, $feature_type
  );
  $self->base_features( $feature_type, $feature_label );
}

sub _feature {
  my( $self, $feature ) = @_;

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my $feature_id    = $feature->hseqname;
  my $type          = $feature->analysis->logic_name;
  my $display_label = $feature->analysis->display_label;
  my $links =  [
    { 'href' => sprintf( $self->{'featureview_url'}, $feature_id ), 'text' => "View $feature_id on genome" },
    { 'href' => sprintf( $self->{'r_url'}, $type, $feature_id ),    'text' => "$display_label $feature_id" }
  ];

  my $group = {
    'ID'    => $feature_id, 
    'TYPE'  => "$self->{_feature_label}:$type",
    'LABEL' =>  sprintf( '%s (%s)', $display_label, $feature_id ),
    'LINK'  => $links,
  };
  my $slice_name = $self->slice_cache( $feature->slice );
  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
   'ID'       => $feature_id,
   'LABEL'       => $feature_id.' ('.$feature->hstart.'-'.$feature->hend.':'.$self->ori($feature->hstrand).')',
   'TYPE'        => $self->{_feature_label}.':'.$type,
   'SCORE'       => $feature->score,
   'TARGET'      => {
     'ID'        => $feature_id,
     'START'     => $feature->hstart,
     'STOP'      => $feature->hend,
   },
   'NOTE'        => [ 'CIGAR: '.$feature->cigar_string ],
   'METHOD'      => $type,
   'CATEGORY'    => $type,
   'ORIENTATION' => $self->ori( $feature->seq_region_strand ),
   'START'       => $feature->seq_region_start,
   'END'         => $feature->seq_region_end,
   'GROUP'       => [$group]
  };
## Return the reference to an array of the slice specific hashes.
}
1;
