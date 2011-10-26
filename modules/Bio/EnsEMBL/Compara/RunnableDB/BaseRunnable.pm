
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 SYNOPSIS

        # from within a Compara Runnable:
    my $FamilyAdaptor = $self->compara_dba()->get_FamilyAdaptor();

    my $ExternalFooFeatureAdaptor = $self->compara_dba($self->param('external_source'))->get_FooFeatureAdaptor();

=head1 DESCRIPTION

All Compara RunnableDBs *should* inherit from this module in order to work with module parameters and compara_dba in a neat way.

It inherits the parameter parsing functionality from Bio::EnsEMBL::Hive::Process
and provides a convenience method for creating the compara_dba from almost anything that can provide connection parameters.

Please refer to Bio::EnsEMBL::Hive::Process documentation to understand the basics of the RunnableDB interface.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable;

use strict;
use Bio::EnsEMBL::Hive::URLFactory;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Hive::Process');


=head2 compara_dba

    Description: this is an intelligent setter/getter of a Compara DBA. Resorts to magic in order to figure out how to connect.

    Example 1:   my $family_adaptor = $self->compara_dba()->get_FamilyAdaptor();    # implicit initialization and hashing

    Example 2:   my $external_foo_adaptor = $self->compara_dba( $self->param('db_conn') )->get_FooAdaptor();    # explicit initialization and hashing

=cut

sub compara_dba {
    my $self = shift @_;

    if(@_ or !$self->{'comparaDBA'}) {
        $self->{'comparaDBA'} = $self->go_figure_compara_dba( shift @_ || $self->param('compara_db') || $self );
    }

    return $self->{'comparaDBA'};
}


=head2 go_figure_compara_dba

    Description: this is a method that tries lots of different ways to find connection parameters
                 from a given object/hash and returns a Compara DBA. Does not hash anything, just does the detective magic.

=cut

sub go_figure_compara_dba {
    my ($self, $foo) = @_;

        
    if(UNIVERSAL::isa($foo, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor')) {   # it is already a Compara adaptor - just return it

        return $foo;   

    } elsif(ref($foo) eq 'HASH') {  # simply a hash with connection parameters, plug them in:

        return Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( %$foo );

    } elsif(UNIVERSAL::isa($foo, 'Bio::EnsEMBL::DBSQL::DBConnection')) { # a DBConnection itself, plug it in:

        return Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -DBCONN => $foo );

    } elsif(UNIVERSAL::can($foo, 'dbc') and UNIVERSAL::isa($foo->dbc, 'Bio::EnsEMBL::DBSQL::DBConnection')) { # another DBAdaptor, possibly Hive::DBSQL::DBAdaptor

        return Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -DBCONN => $foo->dbc );

    } elsif(UNIVERSAL::can($foo, 'db') and UNIVERSAL::can($foo->db, 'dbc') and UNIVERSAL::isa($foo->db->dbc, 'Bio::EnsEMBL::DBSQL::DBConnection')) { # another data adaptor or Runnable:

        return Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -DBCONN => $foo->db->dbc );

    } elsif(!ref($foo) and $foo=~m{^\w*://}) {

        return Bio::EnsEMBL::Hive::URLFactory->fetch( $foo . ';type=compara' );

    } else {
    
        unless(ref($foo)) {    # maybe it is simply a registry key?
        
            my $dba;
            eval {
                require Bio::EnsEMBL::Registry;
                $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($foo, 'compara');
            };
            if($dba) {
                return $dba;
            }
        }

        die "Sorry, could not figure out how to make a Compara DBAdaptor out of $foo";
    }
}

1;
