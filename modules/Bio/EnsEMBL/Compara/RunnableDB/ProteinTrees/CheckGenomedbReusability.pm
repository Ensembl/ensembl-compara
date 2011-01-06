
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability

=head1 DESCRIPTION

This Runnable checks whether a certain genome_db data can be reused for the purposes of ProteinTrees pipeline

The format of the input_id follows the format of a Perl hash reference.
Example:
    { 'genome_db_id' => 90 }

supported keys:
    'genome_db_id'  => <number>
        the id of the genome to be checked (main input_id parameter)
        
    'release'       => <number>
        number of the current release

    'registry_dbs'  => <list_of_dbconn_hashes>
        list of hashes with registry connection parameters (tried in succession)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability;

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Compara::GenomeDB;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

my $suffix_separator = '__cut_here__';

sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param('genome_db_id');
    my $curr_release = $self->param('release');
    my $prev_release = $curr_release-1;

    my $genome_db_obj = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "Could not fetch genome_db with genome_db_id='$genome_db_id'";
    my $species_name  = $genome_db_obj->name();

    $self->param('species_name', $species_name);
    $self->param('curr_core_dba', $genome_db_obj->db_adaptor);

    Bio::EnsEMBL::Registry->no_version_check(1);

        # load the prev.release registry:
    foreach my $prev_reg_conn (@{ $self->param('registry_dbs') }) {
        Bio::EnsEMBL::Registry->load_registry_from_db( %{ $prev_reg_conn }, -db_version => $prev_release, -species_suffix => $suffix_separator.$prev_release );
    }

    unless( $self->param('prev_core_dba', Bio::EnsEMBL::Registry->get_DBAdaptor($species_name.$suffix_separator.$prev_release, 'core')) ) {

        warn "Could not find the previous core database for '$species_name', so reuse is naturally impossible";

        $self->param('reuse_this', 0);
    }
}

sub run {
    my $self = shift @_;

    my $species_name = $self->param('species_name');
    my $curr_release = $self->param('release');
    my $prev_release = $curr_release-1;

    my $curr_core_dba   = $self->param('curr_core_dba');
    my $prev_core_dba   = $self->param('prev_core_dba') or return;  # see prev.warning

    my $curr_assembly = $curr_core_dba->extract_assembly_name;
    my $prev_assembly = $prev_core_dba->extract_assembly_name;

    if($curr_assembly ne $prev_assembly) {

        warn "Assemblies for '$species_name'($prev_assembly -> $curr_assembly) do not match, so cannot reuse\n";

        $self->param('reuse_this', 0);

    } else {

        warn "Comparing coding exons for '$species_name'(rel.$prev_release to rel.$curr_release) ...\n";

        my $prev_exons = hash_all_exons_from_dbc( $prev_core_dba->dbc() );
        my $curr_exons = hash_all_exons_from_dbc( $curr_core_dba->dbc() );
        my ($removed, $remained1) = check_presence($prev_exons, $curr_exons);
        my ($added, $remained2) = check_presence($curr_exons, $prev_exons);

        my $coding_exons_differ = $added || $removed;
        if($coding_exons_differ) {
            warn "The coding exons changed: $added hash keys were added and $removed were removed\n";
        } else {
            warn "No change\n";
        }

        $self->param('reuse_this', $coding_exons_differ ? 0 : 1);
    }
}

sub write_output {      # store the genome_db and dataflow
    my $self = shift;

    my $reuse_this     = $self->param('reuse_this');
    my $genome_db_id = $self->param('genome_db_id');

        # same composition of the output, independent of the branch:
    my $output_hash = {
        'genome_db_id' => $genome_db_id,
        'reuse_this'   => $reuse_this,
    };

        # all jobs dataflow into branch 1:
    $self->dataflow_output_id( $output_hash, 1);

        # in addition, the flow is split between branches 2 and 3 depending on $reuse_this:
    $self->dataflow_output_id( $output_hash, $reuse_this ? 2 : 3);
}

# ------------------------- non-interface subroutines -----------------------------------

sub Bio::EnsEMBL::DBSQL::DBAdaptor::extract_assembly_name {
    my $self = shift @_;

    my ($cs) = @{$self->get_CoordSystemAdaptor->fetch_all()};
    my $assembly_name = $cs->version;

    return $assembly_name;
}

sub hash_all_exons_from_dbc {
    my $dbc = shift @_;

    my $sql = qq{
        SELECT CONCAT(tsi.stable_id, ':', e.seq_region_start, ':', e.seq_region_end)
          FROM transcript_stable_id tsi, transcript t, exon_transcript et, exon e
         WHERE tsi.transcript_id=t.transcript_id
           AND t.transcript_id=et.transcript_id
           AND et.exon_id=e.exon_id
           AND t.biotype='protein_coding'
    };

    my %exon_set = ();

    my $sth = $dbc->prepare($sql);
    $sth->execute();

    while(my ($key) = $sth->fetchrow()) {
        $exon_set{$key} = 1;
    }

    return \%exon_set;
}

sub check_presence {
    my ($from_exons, $to_exons) = @_;

    my @presence = (0, 0);

    foreach my $from_exon (keys %$from_exons) {
        $presence[ exists($to_exons->{$from_exon}) ? 1 : 0 ]++;
    }
    return @presence;
}

1;
