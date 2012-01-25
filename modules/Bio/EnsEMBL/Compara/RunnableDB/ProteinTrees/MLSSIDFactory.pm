#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('MLSSIDFactory');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory(
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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'method_link_types'  => ['ENSEMBL_ORTHOLOGUES'],
    };
}


sub fetch_input {
    my $self = shift @_;

    my $species_sets      = $self->param('species_sets') or die "'species_sets' is an obligatory parameter";
    my $method_link_types = $self->param('method_link_types');

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;

    my @mlss_ids = ();
    foreach my $species_set (@$species_sets) {
        while (my $genome_db_id1 = shift @{$species_set}) {
            foreach my $mlt (@$method_link_types) {
                if(my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($mlt,[$genome_db_id1])) {
                    push @mlss_ids, $mlss->dbID;
                }
            }
            foreach my $genome_db_id2 (@{$species_set}) {
                foreach my $mlt (@$method_link_types) {
                    if(my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($mlt,[$genome_db_id1,$genome_db_id2])) {
                        push @mlss_ids, $mlss->dbID;
                    }
                }
            }
        }
    }

    $self->param('inputlist', \@mlss_ids);
}


sub write_output {
    my $self = shift @_;

    my $inputlist  = $self->param('inputlist');

    while (@$inputlist) {
        $self->dataflow_output_id( { 'mlss_id' => shift @$inputlist }, 2);
    }
}

1;
