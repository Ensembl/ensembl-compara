
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MLSSfactory

=head1 DESCRIPTION

This is a Compara-specific job factory that creates one job per MLSS object, given method_link.type as the only argument.
It is used by GeneTrees pipeline to fan on ENSEMBL_ORTHOLOGUES and ENSEMBL_PARALOGUES homology MLSS objects.

It also serves as a good simple example of a Compara job factory:
    1) Inherits main factory functionality from Hive::RunnableDB::JobFactory
    2) Inherits Compara-specific functionality (like $self->compara_dba ) from Compara::RunnableDB::BaseRunnable
    3) Only defines fetch_input() method that takes specific parameters, uses API to fetch data and sets the $self->param('inputlist') in the end.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MLSSfactory;

use strict;

    # Note: the order is important, this is a true example of Multiple Inheritance:
use base ('Bio::EnsEMBL::Hive::RunnableDB::JobFactory', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'column_names' => [ 'mlss_id' ],
    };
}



sub fetch_input {
    my $self = shift @_;

    my $method_link_type = $self->param('method_link_type') or die "'method_link_type' is an obligatory parameter";

    my $mlsss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type( $method_link_type );

    $self->param('inputlist', [ map { $_->dbID() } @$mlsss ] );
}

1;
