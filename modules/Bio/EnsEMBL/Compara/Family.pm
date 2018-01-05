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

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 NAME

Bio::EnsEMBL::Compara::Family

=head1 DESCRIPTION

Family is the object to store the Ensembl Families, and is an implementation
of AlignedMemberSet.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::Family
  `- Bio::EnsEMBL::Compara::AlignedMemberSet

=head1 SYNOPSIS

Implemented methods:
 - stable_id()
 - version()
 - description()
 - description_score()

=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::Family;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::AlignedMemberSet');

=head2 new

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : Bio::EnsEMBL::Compara::Family (but without members; caller has to fill using
               add_member)
  Exceptions : 
  Caller     : 

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);
  
  if (scalar @args) {
     #do this explicitly.
     my ($description_score) = rearrange([qw(DESCRIPTION_SCORE)], @args);
      
      $description_score && $self->description_score($description_score);
  }
  
  return $self;
}   

=head2 description_score

  Description: The quality of the prediction of the description string.
               description_score() is an integer between 0 and 100

=cut

sub description_score {
  my $self = shift;
  $self->{'_description_score'} = shift if(@_);
  return $self->{'_description_score'};
}

=head2 _attr_to_copy_list

  Description: Returns the list of all the attributes to be copied by deep_copy()
  Returntype : Array of String
  Caller     : General

=cut

sub _attr_to_copy_list {
    my $self = shift;
    my @sup_attr = $self->SUPER::_attr_to_copy_list();
    push @sup_attr, qw(_description_score);
    return @sup_attr;
}

=head2 preload

  Arg [1]     : (optional) Arrayref of strings $species. If given, family members that
                do not belong to those species are removed from the family
  Description : Method to load all the family data in one go. This currently
                includes (if not loaded yet) the seq members, the alignments, and the
                gene Members.
  Returntype  : node
  Example     : $family->preload();
  Caller      : General

=cut

sub preload {
    my $self = shift;
    return unless defined $self->adaptor;

        # Loads all the gene members in one go
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($self->adaptor->db->get_GeneMemberAdaptor, $self->get_all_Members);

}

1;
