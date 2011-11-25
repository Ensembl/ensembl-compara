#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HomologyGroupingFactory

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HomologyGroupingFactory');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::HomologyGroupingFactory(
                         -input_id   => [[1,2,3,14],[4,13],[11,16]]
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a homology compara specific runnableDB, that based on an input
of arrayrefs of genome_db_ids, creates Homology_dNdS jobs in the hive 
analysis_job table.

=cut

=head1 CONTACT

abel@ebi.ac.uk, jessica@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyGroupingFactory;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'method_link_types'  => ['ENSEMBL_ORTHOLOGUES'],
            'group_size'         => 20,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $species_sets      = $self->param('species_sets') or die "'species_sets' is an obligatory parameter";
    my $method_link_types = $self->param('method_link_types');

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;

    my $sql = "select homology_id from homology where method_link_species_set_id = ?";
    my $sth = $self->compara_dba->dbc->prepare($sql);

    my @homology_ids = ();
    foreach my $species_set (@$species_sets) {
        while (my $genome_db_id1 = shift @{$species_set}) {
            foreach my $mlt (@$method_link_types) {
                if(my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($mlt,[$genome_db_id1])) {
                    $sth->execute($mlss->dbID);
                    while( my ($homology_id) = $sth->fetchrow() ) {
                        push @homology_ids, $homology_id;
                    }
                }
            }
            foreach my $genome_db_id2 (@{$species_set}) {
                foreach my $mlt (@$method_link_types) {
                    if(my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($mlt,[$genome_db_id1,$genome_db_id2])) {
                        $sth->execute($mlss->dbID);
                        while( my ($homology_id) = $sth->fetchrow() ) {
                            push @homology_ids, $homology_id;
                        }
                    }
                }
            }
        }
    }

    $self->param('inputlist', \@homology_ids);
}


sub write_output {
    my $self = shift @_;

    my $inputlist  = $self->param('inputlist');
    my $group_size = $self->param('group_size');

    while (@$inputlist) {
        my @job_array = splice(@$inputlist, 0, $group_size);
        $self->dataflow_output_id( { 'ids' => [@job_array] }, 2);
    }
}

1;
