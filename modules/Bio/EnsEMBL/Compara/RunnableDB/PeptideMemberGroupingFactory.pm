#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PeptideMemberGroupingFactory

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('PeptideMemberGroupingFactory');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::PeptideMemberGroupingFactory();
$rdb->fetch_input;
$rdb->run;

=cut

=head1 DESCRIPTION

Given a list of genomedb_ids dataflows a fan of jobs with ENSEMBLPEP member_ids.
One job will contain 20 or less member_ids belonging to the same taxon_id.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PeptideMemberGroupingFactory;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'group_size'        => 20,
        'species_set'       => [],
    };
}


sub fetch_input {
    my $self = @_;

    my $species_set = $self->param('species_set');

    my $genomedb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    my $member_adaptor   = $self->compara_dba->get_MemberAdaptor;

    my @member_ids = ();
    foreach my $gdb_id (@$species_set) {
        my $taxon_id = $genomedb_adaptor->fetch_by_dbID($gdb_id)->taxon_id;

        foreach my $member (@{$member_adaptor->fetch_all_by_source_taxon('ENSEMBLPEP', $taxon_id)}) {
            push @member_ids, $member->member_id;
        }
    }

    $self->param('inputlist', \@member_ids);
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
