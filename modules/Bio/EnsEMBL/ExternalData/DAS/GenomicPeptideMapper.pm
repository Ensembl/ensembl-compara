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

# Proxy object to adapt TranscriptMapper genomic2pep and pep2genomic methods
# to the core Mapper interface.
# Differences:
#   TranscriptMapper uses different named methods to do conversions rather than
#     having a Mapper per pair of coordinate systems.
#   Transcript Mapper uses slice-relative coordinates...
package Bio::EnsEMBL::ExternalData::DAS::GenomicPeptideMapper;

############################################################################
#
# DEPRECATED MODULE - DAS SUPPORT WILL BE REMOVED FROM ENSEMBL IN RELEASE 83
#
#############################################################################


use strict;
use warnings;
use Bio::EnsEMBL::TranscriptMapper;
use base qw(Bio::EnsEMBL::Mapper);

sub new {
  my ( $proto, $from, $to, $from_cs, $to_cs, $transcript ) = @_;
  my $class = ref $proto || $proto;
  
  my $self = {
    '_mapper' => Bio::EnsEMBL::TranscriptMapper->new( $transcript->transfer($transcript->slice->seq_region_Slice) ),
    'from'    => $from,
    'to'      => $to,
    'from_cs' => $from_cs,
    'to_cs'   => $to_cs,
  };
  bless $self, $class;
  
  my $is_forward = $to_cs->name =~ m/peptide/;
  $self->{'genomic_id'} = $transcript->slice->seq_region_name;
  $self->{'peptide_id'} = $transcript->translation->stable_id;
  $self->{'genomic'}    = $is_forward ? $from : $to;
  $self->{'peptide'}    = $is_forward ? $to   : $from;
  $self->{'genomic_cs'} = $is_forward ? $from_cs : $to_cs;
  $self->{'peptide_cs'} = $is_forward ? $to_cs   : $from_cs;
  
  return $self;
}

sub map_coordinates {
  my $self = shift;
  
  my (@coords, $out_id, $out_cs);
  # Query is genomic
  if ( $_[4] eq $self->{'genomic'} ) {
    @coords = $self->{'_mapper'}->genomic2pep(@_[1 .. 3]);
    $out_id = $self->{'peptide_id'};
    $out_cs = $self->{'peptide_cs'};
  # Query is peptide
  } elsif ( $_[4] eq $self->{'peptide'} ) {
    @coords = $self->{'_mapper'}->pep2genomic(@_[1 .. 2]);
    $out_id = $self->{'genomic_id'};
    $out_cs = $self->{'genomic_cs'};
  } else {
    throw($_[4].' is neither the genomic or peptide coordinate system');
  }
  
  for my $c ( @coords ) {
    if ($c->isa('Bio::EnsEMBL::Mapper::Coordinate')) {
      $c->id( $out_id );
      $c->coord_system( $out_cs ); # TranscriptMapper doesn't set this
    }
  }
  return @coords;
}

1;
