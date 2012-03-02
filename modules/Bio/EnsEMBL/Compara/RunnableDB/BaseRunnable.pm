
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
use Carp;
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

        croak "Sorry, could not figure out how to make a Compara DBAdaptor out of $foo";
    }
}


=head2 _load_species_tree_tag_from_mlss

Loads into param() the tag describing the species tree, from the method link species set (using the 'mlss_id' param)

=cut

sub _load_species_tree_tag_from_mlss {
    my $self = shift @_;

    my $mlss_id = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    die "Could not fetch MethodLinkSpeciesSet with the dbID '$mlss_id'" unless defined $mlss;

    my $species_tree_string = $mlss->get_value_for_tag('species_tree');
    $self->param('species_tree_string', $species_tree_string) or die "Could not fetch the 'species_tree' tag from the MethodLinkSpeciesSet dbID=$mlss_id";

}

=head2 get_species_tree_file

Returns the name of a file containing the species tree to be used.
 1. param('species_tree_file') if exists
 2. dumps param('species_tree_string') if exists
 3. dumps the 'species_tree' tag for the mlss param('mlss_id')

By default, it creates a file named 'spec_tax.nh' in the worker temp directory

=cut

sub get_species_tree_file {
    my $self = shift @_;

    unless( $self->param('species_tree_file') ) {

        $self->_load_species_tree_tag_from_mlss unless $self->param('species_tree_string');

        my $species_tree_string = $self->param('species_tree_string');
        eval {
            use Bio::EnsEMBL::Compara::Graph::NewickParser;
            my $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string);
            my @leaves = @{$eval_species_tree->get_all_leaves};
        };
        if($@) {
            die "Error parsing species tree from the string '$species_tree_string'";
        }

            # store the string in a local file:
        my $file_basename = shift or "spec_tax.nh";
        my $species_tree_file = $self->worker_temp_directory . $file_basename;
        open SPECIESTREE, ">$species_tree_file" or die "Could not open '$species_tree_file' for writing : $!";
        print SPECIESTREE $species_tree_string;
        close SPECIESTREE;
        $self->param('species_tree_file', $species_tree_file);
    }
    return $self->param('species_tree_file');
}


=head2 get_species_tree_string

Return a string containing the species tree to be used
 1. param('species_tree_string') if exists
 2. content from param('species_tree_file') if exists
 3. 'species_tree' tag for the mlss param('mlss_id')

=cut

sub get_species_tree_string {
    my $self = shift @_;

    unless( $self->param('species_tree_string') ) {
        if( my $species_tree_file = $self->param('species_tree_file') ) {
            $self->param('species_tree_string', $self->_slurp( $species_tree_file ));
        } else {
            $self->_load_species_tree_tag_from_mlss;
        }
    }
    return  $self->param('species_tree_string');
}


=head2

Reads the whole content of a file and returns it as a string

=cut
sub _slurp {
  my ($self, $file_name) = @_;
  my $slurped;
  {
    local $/ = undef;
    open(my $fh, '<', $file_name);
    $slurped = <$fh>;
    close($fh);
  }
  return $slurped;
}




1;
