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

