#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('Threshold_on_dS');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS(
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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS;

use strict;
use Statistics::Descriptive;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift @_;

    my $mlss_id = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";
    $self->calc_threshold_on_dS($mlss_id);
}


##########################################
#
# internal methods
#
##########################################

sub calc_threshold_on_dS {
    my ($self, $mlss_id) = @_;

    my $compara_dbc = $self->compara_dba->dbc;

    my $sql = "select ds from homology where method_link_species_set_id = ? and ds is not NULL";
    my $sth = $compara_dbc->prepare($sql);

    my $sql2 = "update homology set threshold_on_ds = ? where method_link_species_set_id = ?";
    my $sth2 = $compara_dbc->prepare($sql2);

    $sth->execute($mlss_id);

    my $stats = new Statistics::Descriptive::Full;
    my $count = 0;
    my $dS;

    $sth->bind_columns(\$dS);
    while ($sth->fetch) {
        $stats->add_data($dS);
        $count++;
    }

    if ($count) {
        my $median = $stats->median;
        print STDERR "method_link_species_set_id: $mlss_id; median: $median; 2\*median: ",2*$median;

        if($median >1.0) {
            print STDERR "  threshold exceeds 2.0 - to distant -> set to 2\n";
            $median = 1.0;
        }
        if($median <1.0) {
            print STDERR "  threshold below 1.0 -> set to 1\n";
            $median = 0.5;
        }
        $sth2->execute(2*$median, $mlss_id);
        print STDERR " stored\n";
    }

    $sth->finish;
}

1;

