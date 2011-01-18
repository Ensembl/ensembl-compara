=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::SubsetMemberFactory

=head1 DESCRIPTION

This is a Compara-specific job factory that takes apart a Subset of Members and creates one job per Member from that Subset.
It is used by GeneTrees pipeline to create Blastp jobs given subsets of longest/canonical members.

It also serves as a good simple example of a Compara job factory:
    1) Inherits main factory functionality from Hive::RunnableDB::JobFactory
    2) Inherits Compara-specific functionality (like $self->compara_dba ) from Compara::RunnableDB::BaseRunnable
    3) Only defines fetch_input() method that takes specific parameters, uses API to fetch data and sets the $self->param('inputlist') in the end.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::SubsetMemberFactory;

use strict;

    # Note: the order is important, this is a true example of Multiple Inheritance:
use base ('Bio::EnsEMBL::Hive::RunnableDB::JobFactory', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $subset_id = $self->param('subset_id') || $self->param('ss') or die "'subset_id' is an obligatory parameter";

    my $subset      = $self->compara_dba->get_SubsetAdaptor()->fetch_by_dbID($subset_id) or die "cannot fetch Subset with id '$subset_id'";

    $self->param('inputlist', $subset->member_id_list() );
}

1;
