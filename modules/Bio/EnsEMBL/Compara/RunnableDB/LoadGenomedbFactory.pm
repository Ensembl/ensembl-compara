#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::LoadGenomedbFactory

=cut

=head1 DESCRIPTION

This is a job factory that starts with an MLSS or SpeciesSet object, takes it apart and dataflows the ids

=cut

=head1 CONTACT

Contact anybody in Compara.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadGenomedbFactory;

use strict;

use Data::Dumper;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::SpeciesSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $mlss_id        = $self->param('mlss_id');
    my $species_set_id = $self->param('species_set_id');

    if($mlss_id and $species_set_id) {
        $self->input_job->transient_error(0);
        die "Please specify either 'mlss_id' or 'species_set_id', but not both";
    } elsif(!$mlss_id and !$species_set_id) {
        $self->input_job->transient_error(0);
        die "Please specify either 'mlss_id' or 'species_set_id'";
    }

    my $species_set;

    if($mlss_id) {
        my $mlss     = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
        $species_set = $mlss->species_set;
    } else {
        $species_set = $self->compara_dba()->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id) or die "Could not fetch species_set with dbID=$species_set_id";
    }

    $self->param('species_set', $species_set);
}

sub run {
    my $self = shift @_;

}

sub write_output {  
    my $self = shift;

    my $species_set = $self->param('species_set');

    my $genome_dbs = (ref($species_set) eq 'ARRAY') ? $species_set : $species_set->genome_dbs();

    foreach my $genome_db (@$genome_dbs) {

        $self->dataflow_output_id( {
            'genome_db_id'  => $genome_db->dbID(),
            'species_name'  => $genome_db->name(),
            'assembly_name' => $genome_db->assembly(),
	    'genebuild'     => $genome_db->genebuild(),
        }, 2);
    }
}

1;

