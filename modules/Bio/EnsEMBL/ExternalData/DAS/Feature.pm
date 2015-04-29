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

#
# EnsEMBL module for Bio::EnsEMBL::ExternalData::DAS::Feature
#
#

=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::Feature

=head1 SYNOPSIS

  my $f = Bio::EnsEMBL::ExternalData::DAS::Feature->new( {
  
    # Core Ensembl attributes:
    'start'  => 100,
    'end'    => 200,
    'strand' => -1,     # or can use "orientation"
    'slice'  => $slice, # optional, for genomic features
    'seqname'=> 'foo',  # optional, for non-genomic features
    
    # DAS-specific attributes:
    'orientation'   => '+', # + or - or .
    'feature_id'    => 'feature1',
    'feature_label' => 'Feature 1',
    'type'          => 'exon',
    'type_id'       => 'SO:0000147',
    'type_category' => 'inferred from electronic annotation (ECO:00000067)',
    'score'         => 85,
    'note'          => [ 'Something useful to know' ],
    'link'          => [
                        { 'href' => 'http://...',
                          'txt'  => 'Feature Link' }
                       ],
    'group'         => [
                        #  hashref, see Bio::EnsEMBL::ExternalData::DAS::FeatureGroup
                       ],
    'target'        => [
                        { 'target_id'    => 'Seq 1',
                          'target_start' => '500',
                          'target_stop'  => '600'  }
                       ]
    
  } );
  
  printf "ID:           %s\n"     , $f->display_id();
  printf "Label:        %s\n"     , $f->display_label();
  printf "Start:        %d (%d)\n", $f->start(), $f->seq_region_start;
  printf "End:          %d (%d)\n", $f->end()  , $f->seq_region_end;
  printf "Type Label:   %s\n"     , $f->type_label();
  printf "Type ID:      %s\n"     , $f->type_id();
  printf "Category:     %s\n"     , $f->type_category();
  printf "Score:        %s\n"     , $f->score();
  
  for my $l ( @{ $f->links() } ) {
    printf "Link:         %s -> %s\n", $l->{'href'}, $l->{'txt'};
  }
  
  for my $n ( @{ $f->notes() } ) {
    printf "Note:         %s\n", $n;
  }
  
  for my $t ( @{ $f->targets() } ) {
    printf "Target:       %s:%s,%s\n", $t->{'target_id'},
                                       $t->{'target_start'},
                                       $t->{'target_stop'};
  }
  
  for my $g ( @{ $f->groups() } ) {
    printf "Group ID:     %s\n", $g->display_id();
    printf "Group Label:  %s\n", $g->display_label();
    printf "Group Type:   %s\n", $g->type_label();
    
    for my $l ( @{ $g->links() } ) {
      printf "Group Link:   %s -> %s\n", $l->{'href'}, $l->{'txt'};
    }
    
    for my $n ( @{ $g->notes() } ) {
      printf "Group Note:   %s\n", $n;
    }
    
    for my $t ( @{ $g->targets() } ) {
      printf "Group Target: %s:%s,%s\n", $t->{'target_id'},
                                         $t->{'target_start'},
                                         $t->{'target_stop'};
    }
  }

=head1 DESCRIPTION

An object representation of a DAS feature using Bio::EnsEMBL::Feature as a base.

The constructor is designed to work with the output of the DAS features command,
as obtained from the Bio::Das::Lite module.

See L<http://www.biodas.org/documents/spec.html> for more information about DAS
and its data types.

=head1 AUTHOR

Andy Jenkinson

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

package Bio::EnsEMBL::ExternalData::DAS::Feature;

use strict;
use warnings;

use Bio::EnsEMBL::ExternalData::DAS::FeatureGroup;
use base qw(Bio::EnsEMBL::Feature);

=head2 new

  Arg [1]    : Hash reference (see SYNOPSIS for details and example)
  Description: Constructs a new Bio::EnsEMBL::ExternalData::DAS::Feature.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::Feature
  Exceptions : none
  Caller     : Bio::EnsEMBL::ExternalData::DAS::Coordinator
  Status     : Stable

=cut

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my $raw   = shift;
  
  # DAS-style "orientation" is fine:
  if (!defined $raw->{'strand'} && defined $raw->{'orientation'}) {
    $raw->{'strand'} = $raw->{'orientation'} eq '+'   ?  1
                     : $raw->{'orientation'} eq '-'   ? -1
                     : 0;
  }
  $raw->{'strand'} ||= 0;
  $raw->{'start'}  ||= 0;
  $raw->{'end'}    ||= 0;
  
  my $self = {};
  for my $key (qw( start end strand slice seqname
                  feature_id feature_label
                  type type_id type_category
                  score method method_id
                  note link target )) {
    $self->{$key} = $raw->{$key} if exists $raw->{$key};
  }
  
  if ( $raw->{'group'} && ref $raw->{'group'} eq 'ARRAY' ) {
    $self->{'group'} = [
      map {
        Bio::EnsEMBL::ExternalData::DAS::FeatureGroup->new($_)
      } @{ $raw->{'group'} }
    ];
  }
  
  bless $self, $class;
  return $self;
}

=head2 display_id

  Arg [1]    : none
  Example    : print $f->display_id();
  Description: This method returns the DAS feature identifier.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub display_id {
  my $self = shift;
  return $self->{'feature_id'};
}

=head2 display_label

  Arg [1]    : none
  Example    : print $f->display_label();
  Description: This method returns the DAS feature label.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub display_label {
  my $self = shift;
  return $self->{'feature_label'} || $self->display_id;
}

=head2 method_id

  Arg [1]    : none
  Example    : print $f->method_id();
  Description: This method returns the DAS feature method identifier.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub method_id {
  my $self = shift;
  return $self->{'method_id'};
}

=head2 method_label

  Arg [1]    : none
  Example    : print $f->method_label();
  Description: This method returns the DAS feature method label.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub method_label {
  my $self = shift;
  return $self->{'method'} || $self->method_id;
}

=head2 type_label

  Arg [1]    : none
  Example    : print $f->type_label();
  Description: This method returns the DAS feature type label.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub type_label {
  my $self = shift;
  return $self->{'type'} || $self->type_id;
}

=head2 type_id

  Arg [1]    : none
  Example    : print $f->type_id();
  Description: This method returns the DAS feature type identifier.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub type_id {
  my $self = shift;
  return $self->{'type_id'};
}

=head2 type_category

  Arg [1]    : none
  Example    : print $f->type_category();
  Description: This method returns the DAS feature type category.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub type_category {
  my $self = shift;
  return $self->{'type_category'};
}

=head2 score

  Arg [1]    : none
  Example    : print $f->score();
  Description: This method returns the DAS feature score.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub score {
  my $self = shift;
  return $self->{'score'};
}

# The following are zero-to-many, thus return arrayrefs:

=head2 notes

  Arg [1]    : none
  Example    : @notes = @{ $f->notes() };
  Description: This method returns the DAS feature notes.
  Returntype : arrayref of strings
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub notes {
  my $self = shift;
  return $self->{'note'} || [];
}

=head2 links

  Arg [1]    : none
  Example    : @links = @{ $f->links() };
  Description: This method returns the DAS feature external links.
  Returntype : arrayref of { href=>$, txt=>$ } hashes
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub links {
  my $self = shift;
  return $self->{'link'} || [];
}

=head2 groups

  Arg [1]    : none
  Example    : @groups = @{ $f->groups() };
  Description: This method returns the DAS feature groups.
  Returntype : arrayref of Bio::EnsEMBL::ExternalData::DAS::FeatureGroup ojects
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub groups {
  my $self = shift;
  return $self->{'group'} || [];
}

=head2 targets

  Arg [1]    : none
  Example    : @targets = @{ $f->targets() };
  Description: This method returns the DAS feature targets.
  Returntype : arrayref of { target_id=>$, target_start=>$, target_stop=>$ } hashes
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub targets {
  my $self = shift;
  return $self->{'target'} || [];
}

1;
