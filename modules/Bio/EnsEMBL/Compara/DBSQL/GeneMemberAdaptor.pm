=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor

=head1 DESCRIPTION

Adaptor to retrieve GeneMember objects.
Most of the methods are shared with the SeqMemberAdaptor.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor;

use strict; 
use warnings;

use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning stack_trace_dump deprecate);
use DBI qw(:sql_types);

use base qw(Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor);








#
# GLOBAL METHODS
#
#####################















































































#
# SeqMember only methods
#
############################




































#
# GeneMember only methods
############################


=head2 fetch_all_homology_orphans_by_GenomeDB

 Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
 Example    : $GenomeDBAdaptor->fetch_all_homology_orphans_by_GenomeDB($genome_db);
 Description: fetch the members for a genome_db that have no homologs in the database
 Returntype : an array reference of Bio::EnsEMBL::Compara::Member objects
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::GenomeDB
 Caller     : general

=cut

sub fetch_all_homology_orphans_by_GenomeDB {
  my $self = shift;
  my $gdb = shift;

  assert_ref($gdb, 'Bio::EnsEMBL::Compara::GenomeDB');

  my $constraint = 'm.source_name = "ENSEMBLGENE"';
  $constraint .= ' AND m.genome_db_id = ?';
  $self->bind_param_generic_fetch($gdb->dbID, SQL_INTEGER);

  # The LEFT JOIN condition is actually below and therefore shared by all the fetch methods
  # To activate it, a fetch has to alias "homology_member" into "left_homology"
  my $join = [[['homology_member', 'left_homology'], 'left_homology.member_id IS NULL']];

  return $self->generic_fetch($constraint, $join);
}






#
# INTERNAL METHODS
#
###################

sub _left_join {
    return (
        ['homology_member left_homology', 'left_homology.member_id = m.member_id'],
    );
}



sub create_instance_from_rowhash {
	my ($self, $rowhash) = @_;
	
	my $obj = $self->SUPER::create_instance_from_rowhash($rowhash);
	bless $obj, 'Bio::EnsEMBL::Compara::GeneMember';
	return $obj;
}







#
# STORE METHODS
#
################


sub store {
    my ($self, $member) = @_;
   
    assert_ref($member, 'Bio::EnsEMBL::Compara::GeneMember');


    my $dbID = $self->SUPER::store($member);
    if ($dbID) {
        my $sth = $self->prepare('UPDATE member SET canonical_member_id = ? WHERE member_id = ?');
        $sth->execute($member->canonical_member_id, $dbID);
        $sth->finish;
    }

    return $dbID;
}



































### SECTION 9 ###
#
# WRAPPERS
###########













1;

