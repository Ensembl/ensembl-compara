#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Threshold_on_dS

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('Threshold_on_dS');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::Threshold_on_dS(
                         -input_id   => [[1,2,3,14],[4,13],[11,16]]
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a homology compara specific runnableDB, that based on an input
of arrayrefs of genome_db_ids, calculates the median dS for each paired species
where dS values are available, and stores 2*median in the threshold_on_ds column
in the homology table.

=cut

=head1 CONTACT

abel@ebi.ac.uk, jessica@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Threshold_on_dS;

use strict;
use Statistics::Descriptive;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'method_link_types'  => ['ENSEMBL_ORTHOLOGUES'],
    };
}


sub run {
    my $self = shift @_;

    my $species_sets      = $self->param('species_sets') or die "'species_sets' is an obligatory parameter";
    my $method_link_types = $self->param('method_link_types');

    if(@$species_sets) {
        $self->calc_threshold_on_dS($species_sets, $method_link_types);
    }
}


##########################################
#
# internal methods
#
##########################################

sub calc_threshold_on_dS {
    my ($self, $species_sets, $method_link_types) = @_;

    my $compara_dbc = $self->compara_dba->dbc;

    my $sql = "select ds from homology where method_link_species_set_id = ? and ds is not NULL";
    my $sth = $compara_dbc->prepare($sql);

    my $sql2 = "update homology set threshold_on_ds = ? where method_link_species_set_id = ?";
    my $sth2 = $compara_dbc->prepare($sql2);

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    foreach my $species_set (@{$species_sets}) {
        while (my $genome_db_id1 = shift @{$species_set}) {
            foreach my $genome_db_id2 (@{$species_set}) {
                foreach my $method_link_type(@$method_link_types) {

                    my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($method_link_type,[$genome_db_id1,$genome_db_id2]);
                    $sth->execute($mlss->dbID);

                    my $stats = new Statistics::Descriptive::Full;
                    my $dS;
                    $sth->bind_columns(\$dS);
                    my $count = 0;
                    while ($sth->fetch) {
                        $stats->add_data($dS);
                        $count++;
                    }
                    if ($count) {
                        my $median = $stats->median;
                        print STDERR "method_link_species_set_id: ",$mlss->dbID,"; median: ",$median,"; 2\*median: ",2*$median;

                        if($median >1.0) {
                            print STDERR "  threshold exceeds 2.0 - to distant -> set to 2\n";
                            $median = 1.0;
                        }
                        if($median <1.0) {
                            print STDERR "  threshold below 1.0 -> set to 1\n";
                            $median = 0.5;
                        }
                        $sth2->execute(2*$median, $mlss->dbID);
                        print STDERR " stored\n";
                    }
                }
            }
        }
    }

    $sth->finish;
}

1;

