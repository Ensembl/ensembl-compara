
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory

=head1 DESCRIPTION

This is a Compara-specific generic job factory that:
    1) creates an object adaptor
    2) runs a fetch_all_by... method on that adaptor (which returns a list of objects)
    3) flows each object into a job using a given getter-to-column mapping

It also serves as a good simple example of a Compara job factory:
    1) Inherits main factory functionality from Hive::RunnableDB::JobFactory
    2) Inherits Compara-specific functionality (like $self->compara_dba ) from Compara::RunnableDB::BaseRunnable
    3) Only defines fetch_input() method that takes specific parameters, uses API to fetch data and sets the $self->param('inputlist') in the end.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory;

use strict;

    # Note: the order is important, this is a true example of Multiple Inheritance:
use base ('Bio::EnsEMBL::Hive::RunnableDB::JobFactory', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $adaptor_name            = $self->param('adaptor_name')   or die "'adaptor_name' is an obligatory parameter";
    my $adaptor_method          = $self->param('adaptor_method') or die "'adaptor_method' is an obligatory parameter";

    my $method_param_list       = $self->param_substitute( $self->param('method_param_list') || [] );

    my $getters2column_names    = $self->param_substitute( $self->param('getters2column_names') || die "'getters2column_names' mapping is an obligatory parameter" );
    my @getters                 = keys %$getters2column_names;
    my @column_names            = values %$getters2column_names;

    my $get_adaptor             = 'get_'.$adaptor_name;
    my $adaptor                 = $self->compara_dba->$get_adaptor or die "Could not create a '$adaptor_name' on the database";

    my $object_list             = $adaptor->$adaptor_method( @$method_param_list ) or die "Could not call '$adaptor_method'(".stringify(@$method_param_list).") on '$adaptor_name'";

    my @inputlist = ();
    foreach my $object (@$object_list) {
        push @inputlist, [ map { $object->$_ } @getters ];
    }
    $self->param('inputlist',    \@inputlist);
    $self->param('column_names', \@column_names);
}

1;
