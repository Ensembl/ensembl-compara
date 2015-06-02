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

=head1 NAME

Bio::EnsEMBL::ExternalData::DAS::FeatureGroup

############################################################################
#
# DEPRECATED MODULE - DAS SUPPORT WILL BE REMOVED FROM ENSEMBL IN RELEASE 83
#
#############################################################################


=head1 SYNOPSIS

  my $g = Bio::EnsEMBL::ExternalData::DAS::FeatureGroup->new( {
    'group_id'    => 'group1',
    'group_label' => 'Group 1',
    'group_type'  => 'transcript',
    'note'        => [ 'Something interesting' ],
    'link'        => [
                      { 'href' => 'http://...',
                        'txt'  => 'Group Link'  }
                     ],
    'target'      => [
                      { 'target_id'    => 'Seq 1',
                        'target_start' => '400',
                        'target_stop'  => '800'  }
                     ]
  } );
  
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

=head1 DESCRIPTION

An object representation of a DAS feature group.

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

package Bio::EnsEMBL::ExternalData::DAS::FeatureGroup;

use strict;
use warnings;

=head2 new

  Arg [1]    : Hash reference (see SYNOPSIS for details and example)
  Description: Constructs a new Bio::EnsEMBL::ExternalData::DAS::FeatureGroup.
  Returntype : Bio::EnsEMBL::ExternalData::DAS::FeatureGroup
  Exceptions : none
  Caller     : Bio::EnsEMBL::ExternalData::DAS::Feature
  Status     : Stable

=cut

sub new {
  my $proto = shift;
  my $class = ref $proto || $proto;
  my $raw   = shift;
  
  my $self = {};
  for my $key (qw( group_id group_label
                  group_type
                  note link target )) {
    $self->{$key} = $raw->{$key} if exists $raw->{$key};
  }
  
  bless $self, $class;
  return $self;
}

=head2 display_id

  Arg [1]    : none
  Example    : print $g->display_id();
  Description: This method returns the DAS group identifier.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub display_id {
  my $self = shift;
  return $self->{'group_id'};
}

=head2 display_label

  Arg [1]    : none
  Example    : print $g->display_label();
  Description: This method returns the DAS group label.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub display_label {
  my $self = shift;
  return $self->{'group_label'} || $self->display_id;
}

=head2 type_label

  Arg [1]    : none
  Example    : print $g->type_label();
  Description: This method returns the DAS group type label.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub type_label {
  my $self = shift;
  return $self->{'group_type'};
}

# The following are zero-to-many, thus return arrayrefs:

=head2 notes

  Arg [1]    : none
  Example    : @notes = @{ $g->notes() };
  Description: This method returns the DAS group notes.
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
  Example    : @links = @{ $g->links() };
  Description: This method returns the DAS group external links.
  Returntype : arrayref of { href=>$, txt=>$ } hashes
  Exceptions : none
  Caller     : web drawing code
  Status     : Stable

=cut

sub links {
  my $self = shift;
  return $self->{'link'} || [];
}

=head2 targets

  Arg [1]    : none
  Example    : @targets = @{ $g->targets() };
  Description: This method returns the DAS group targets.
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
