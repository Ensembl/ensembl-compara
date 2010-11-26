#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinMemberGroupingFactory

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('ProteinMemberGroupingFactory');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinMemberGroupingFactory();
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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinMemberGroupingFactory;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = @_;

    $self->param('member_adaptor',   $self->compara_dba->get_MemberAdaptor);
    $self->param('genomedb_adaptor', $self->compara_dba->get_GenomeDBAdaptor);
}

sub run {
    my $self = shift;
}

sub write_output {
    my $self = shift;

    my $species_set = $self->param('species_set') or return 1;

    my $genomedb_adaptor = $self->param('genomedb_adaptor');

    foreach my $gdb (@$species_set) {
        $self->create_jobs_for_genome( $genomedb_adaptor->fetch_by_dbID($gdb) );
    }
}

##########################################
#
# internal methods
#
##########################################

sub create_jobs_for_genome {
    my ($self, $genome_db) = @_;

    my $member_adaptor = $self->param('member_adaptor');

    my @member_ids = ();
    foreach my $member (@{$member_adaptor->fetch_all_by_source_taxon('ENSEMBLPEP', $genome_db->taxon_id)}) {
        push @member_ids, $member->member_id;
    }

    my $job_size = int(((scalar @member_ids)/1000));
    $job_size = 1 if ($job_size < 1);
    $job_size = 20 if ($job_size > 20); # limit of 255 chars in input_id

    while (@member_ids) {
      my @job_array = splice(@member_ids, 0, $job_size);
      $self->dataflow_output_id( { 'ids' => @job_array }, 2);
    }
}

1;
