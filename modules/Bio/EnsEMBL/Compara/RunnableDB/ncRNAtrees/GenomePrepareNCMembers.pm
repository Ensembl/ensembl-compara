#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenomePrepareNCMembers

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $g_load_members = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenomePrepareNCMembers->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$g_load_members->fetch_input(); #reads from DB
$g_load_members->run();
$g_load_members->output();
$g_load_members->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

A job factory that first iterates through all top-level slices of the corresponding core database and collects ncRNA gene stable_ids,
then creates downstream jobs that will be loading individual ncRNA members.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::GenomePrepareNCMembers;

use strict;
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Compara::Subset;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Read the parameters and set up all necessary objects.

=cut

sub fetch_input {
    my $self = shift @_;

    $self->input_job->transient_error(0);
    my $genome_db_id = $self->param('genome_db_id') || die "'genome_db_id' parameter is an obligatory one, please specify";
    $self->input_job->transient_error(1);

        # fetch the Compara::GenomeDB object for the genome_db_id
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "Could not fetch genome_db with id=$genome_db_id";
    $self->param('genome_db', $genome_db);
  
        # using genome_db_id connect to external core database
    my $core_db = $genome_db->db_adaptor() or die "Can't connect to genome database for id=$genome_db_id";
    $self->param('core_db', $core_db);


        # create subsets for the gene members, and the longest peptide members
    my $subset_adaptor = $self->compara_dba->get_SubsetAdaptor;

# FIXME: change the fan dataflow branch to 2, allowing branch 1 to output something too
    my $genome_db_name = $genome_db->name;
    my $ncrna_subset = Bio::EnsEMBL::Compara::Subset->new( -name=>"genome_db_id:${genome_db_id} ${genome_db_name} longest ncRNAs" );
    my $gene_subset  = Bio::EnsEMBL::Compara::Subset->new( -name=>"genome_db_id:${genome_db_id} ${genome_db_name} ncRNA genes" );

    my $ncrna_subset_id = $subset_adaptor->store($ncrna_subset) or die "Could not store ncRNA subset";
    my $gene_subset_id  = $subset_adaptor->store($gene_subset)  or die "Could not store gene subset";

    $self->param('ncrna_subset_id', $ncrna_subset_id);
    $self->param('gene_subset_id',  $gene_subset_id);
}


=head2 run

    Iterate through all top-level slices of the corresponding core database and collect ncRNA gene stable_ids

=cut

sub run {
    my $self = shift @_;

    $self->compara_dba->dbc->disconnect_when_inactive(0);
    $self->param('core_db')->dbc->disconnect_when_inactive(0);

    my @stable_ids = ();

        # from core database, get all slices, and then all genes in slice
        # and then all transcripts in gene to store as members in compara
    my @slices = @{$self->param('core_db')->get_SliceAdaptor->fetch_all('toplevel')};
    print("fetched ",scalar(@slices), " slices to load from\n");
    die "No toplevel slices, cannot fetch anything" unless(scalar(@slices));

    foreach my $slice (@slices) {
        foreach my $gene (sort {$a->start <=> $b->start} @{$slice->get_all_Genes}) {
            if ($gene->biotype =~ /rna/i) {
                my $gene_stable_id = $gene->stable_id or die "Could not get stable_id from gene with id=".$gene->dbID();
                push @stable_ids, $gene_stable_id;
            }
        }
    }

    $self->param('stable_ids', \@stable_ids);

    $self->param('core_db')->dbc->disconnect_when_inactive(1);
}


=head2 write_output

    Create downstream jobs that will be loading individual ncRNA members

=cut

sub write_output {
    my $self = shift @_;

    my $genome_db_id    = $self->param('genome_db_id');
    my $ncrna_subset_id = $self->param('ncrna_subset_id');
    my $gene_subset_id  = $self->param('gene_subset_id');

    foreach my $stable_id (@{ $self->param('stable_ids') }) {
        $self->dataflow_output_id( {
            'genome_db_id'    => $genome_db_id,
            'ncrna_subset_id' => $ncrna_subset_id,
            'gene_subset_id'  => $gene_subset_id,
            'stable_id'       => $stable_id,
        }, 2);
    }
}

1;

