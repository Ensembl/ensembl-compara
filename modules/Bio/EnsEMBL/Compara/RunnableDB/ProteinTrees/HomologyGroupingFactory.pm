#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HomologyGroupingFactory');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory(
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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'group_size'         => 1000,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";

    my $sql = "SELECT homology_id FROM homology WHERE method_link_species_set_id = ? ORDER BY homology_id";
    my $sth = $self->compara_dba->dbc->prepare($sql);

    my @homology_ids = ();
    $sth->execute($mlss_id);
    while( my ($homology_id) = $sth->fetchrow() ) {
        push @homology_ids, $homology_id;
    }

    $self->param('inputlist', \@homology_ids);
}


sub write_output {
    my $self = shift @_;

    my $inputlist  = $self->param('inputlist');
    my $group_size = $self->param('group_size');

    while (@$inputlist) {
        my @job_array = splice(@$inputlist, 0, $group_size);
        $self->dataflow_output_id( { 'mlss_id' => $self->param('mlss_id'), 'min_homology_id' => $job_array[0], 'max_homology_id' => $job_array[-1] }, 2);
    }
}

1;
