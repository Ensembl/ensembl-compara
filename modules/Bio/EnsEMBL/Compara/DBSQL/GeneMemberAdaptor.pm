=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

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









#
# INTERNAL METHODS
#
###################



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

