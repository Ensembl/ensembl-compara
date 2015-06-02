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

# Proxy object to make IdentityXref mappers play nice with the core Mapper
# interface. Differences:
#   does not use real identifiers for the sequences it is mapping between,
#     it uses 'external_id' and 'ensembl_id' strings
#   names the from/to coordinate systems as 'external' and 'ensembl'.
package Bio::EnsEMBL::ExternalData::DAS::XrefPeptideMapper;

############################################################################
#
# DEPRECATED MODULE - DAS SUPPORT WILL BE REMOVED FROM ENSEMBL IN RELEASE 83
#
#############################################################################


use strict;
use warnings;

use base qw(Bio::EnsEMBL::Mapper);

sub new {
  my ( $proto, $from, $to, $from_cs, $to_cs, $identity_xref, $translation ) = @_;
  
  my $is_forward = 1;
  if ($identity_xref->isa('Bio::EnsEMBL::Translation')) {
    $is_forward = 0;
    ($identity_xref, $translation) = ($translation, $identity_xref);
  }
  $identity_xref->can('get_mapper') || throw('Xref does not support mapping');
  
  my $class = ref $proto || $proto;
  my $mapper = $identity_xref->get_mapper;
  my $self = {
    %{ $mapper }
  };
  bless $self, $class;
  
  $self->{'from'}    = $from;
  $self->{'to'}      = $to;
  $self->{'from_cs'} = $from_cs;
  $self->{'to_cs'}   = $to_cs;
  
  $self->{'external'}    = $is_forward ? $from : $to;
  $self->{'ensembl'}     = $is_forward ? $to   : $from;
  $self->{'external_cs'} = $is_forward ? $from_cs : $to_cs;
  $self->{'ensembl_cs'}  = $is_forward ? $to_cs   : $from_cs;
  
  return $self;
}

sub external_id {
  my ($self, $tmp) = @_;
  if ($tmp) {
    $self->{'external_id'} = $tmp;
  }
  return $self->{'external_id'};
}

sub ensembl_id {
  my ($self, $tmp) = @_;
  if ($tmp) {
    $self->{'ensembl_id'} = $tmp;
  }
  return $self->{'ensembl_id'};
}

sub map_coordinates {
  my $self = shift;
  
  my ($in_id, $out_id, $in_name, $out_cs);
  if ( $_[4] eq $self->{'external'} ) {
    $in_id   = 'external_id';
    $in_name = 'external';
    $out_id  = $self->{'ensembl_id'};
    $out_cs  = $self->{'ensembl_cs'};
  } elsif ( $_[4] eq $self->{'ensembl'} ) {
    $in_id   = 'ensembl_id';
    $in_name = 'ensembl';
    $out_id  = $self->{'external_id'};
    $out_cs  = $self->{'external_cs'};
  } else {
    throw($_[4].' is neither the xref or peptide coordinate system');
  }
  
  my @coords = $self->SUPER::map_coordinates( $in_id, @_[1..3], $in_name );
  for my $c ( @coords ) {
    if ($c->isa('Bio::EnsEMBL::Mapper::Coordinate')) {
      $c->id( $out_id );
      $c->coord_system( $out_cs ); # IdentityXref mapper doesn't set this
    }
  }
  return @coords;
}

1;
