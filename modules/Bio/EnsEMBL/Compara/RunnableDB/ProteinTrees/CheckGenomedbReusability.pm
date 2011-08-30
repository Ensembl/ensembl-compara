
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

    'prev_release'  => <number>
        (optional) number of the previous release for reuse purposes (may coincide, may be 2 or more releases behind, etc)

    'registry_dbs'  => <list_of_dbconn_hashes>
        list of hashes with registry connection parameters (tried in succession).

    'reuse_this'    => <0|1>
        (optional) if defined, the code is skipped and this value is passed to the output

    'do_not_reuse_list' => <list_of_species_ids_or_names>
        (optional)  is a 'veto' list of species we definitely do not want to be reused this time
=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability;

use strict;
use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Compara::GenomeDB;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

my $suffix_separator = '__cut_here__';

sub fetch_input {
    my $self = shift @_;

    my $genome_db_adaptor   = $self->compara_dba->get_GenomeDBAdaptor;

    my $genome_db_id = $self->param('genome_db_id');
    my $genome_db    = $genome_db_adaptor->fetch_by_dbID($genome_db_id) or die "Could not fetch genome_db with genome_db_id='$genome_db_id'";
    my $species_name = $self->param('species_name', $genome_db->name());

    unless($self->param('per_genome_suffix')) {
        $self->param('per_genome_suffix', "${species_name}_${genome_db_id}");
    }

    return if(defined($self->param('reuse_this')));  # bypass fetch_input() and run() in case 'reuse_this' has already been passed


    my $do_not_reuse_list = $self->param('do_not_reuse_list') || [];
    foreach my $do_not_reuse_candidate (@$do_not_reuse_list) {
        if( looks_like_number( $do_not_reuse_candidate ) ) {

            if( $do_not_reuse_candidate == $genome_db_id ) {
                $self->param('reuse_this', 0);
                return;
            }

        } else {    # not using registry names here to avoid clashes with previous release registry entries:

            my $do_not_reuse_candidate_genome_db = $genome_db_adaptor->fetch_by_name_assembly( $do_not_reuse_candidate )
                or die "Could not fetch genome_db with name='$do_not_reuse_candidate', please check the 'do_not_reuse_list' parameter";

            if( $do_not_reuse_candidate_genome_db == $genome_db ) {
                $self->param('reuse_this', 0);
                return;
            }
        }
    }

    my $curr_release = $self->param('release');
    my $prev_release = $self->param('prev_release') || ($curr_release - 1);

    if(my $reuse_db = $self->param('reuse_db')) {

            # Need to check that the genome_db_id has not changed (treat the opposite as a signal not to reuse) :
        my $reuse_compara_dba       = $self->go_figure_compara_dba($reuse_db);    # may die if bad parameters
        my $reuse_genome_db_adaptor = $reuse_compara_dba->get_GenomeDBAdaptor();
        my $reuse_genome_db;
        eval {
            $reuse_genome_db = $reuse_genome_db_adaptor->fetch_by_name_assembly($species_name, $genome_db->assembly);
        };
        unless($reuse_genome_db) {
            $self->warning("Could not fetch genome_db object for name='$species_name' and assembly='".$genome_db->assembly."' from reuse_db");
            $self->param('reuse_this', 0);
            return;
        }
        my $reuse_genome_db_id = $reuse_genome_db->dbID();

        if ($reuse_genome_db_id != $genome_db_id) {
            $self->warning("Genome_db_ids for '$species_name' ($reuse_genome_db_id -> $genome_db_id) do not match, so cannot reuse");
            $self->param('reuse_this', 0);
            return;
        }

            # now use the registry to find the previous release core database candidate:

        Bio::EnsEMBL::Registry->no_version_check(1);

            # load the prev.release registry:
        foreach my $prev_reg_conn (@{ $self->param('registry_dbs') }) {
            Bio::EnsEMBL::Registry->load_registry_from_db( %{ $prev_reg_conn }, -db_version => $prev_release, -species_suffix => $suffix_separator.$prev_release );
        }

        if( my $prev_core_dba = $self->param('prev_core_dba', Bio::EnsEMBL::Registry->get_DBAdaptor($species_name.$suffix_separator.$prev_release, 'core')) ) {
            my $curr_core_dba = $self->param('curr_core_dba', $genome_db->db_adaptor);

            my $curr_assembly = $curr_core_dba->extract_assembly_name;
            my $prev_assembly = $prev_core_dba->extract_assembly_name;

            if($curr_assembly ne $prev_assembly) {

                $self->warning("Assemblies for '$species_name'($prev_assembly -> $curr_assembly) do not match, so cannot reuse");
                $self->param('reuse_this', 0);
            }

        } else {
            $self->warning("Could not find the previous core database for '$species_name', so reuse is naturally impossible");
            $self->param('reuse_this', 0);
        }

    } else {
        $self->warning("reuse_db hash has not been set, so cannot reuse");
        $self->param('reuse_this', 0);
        return;
    }
}


sub run {
    my $self = shift @_;

    return if(defined($self->param('reuse_this')));  # bypass run() in case 'reuse_this' has either been passed or already computed

    my $species_name    = $self->param('species_name');
    my $prev_core_dba   = $self->param('prev_core_dba');
    my $curr_core_dba   = $self->param('curr_core_dba');

    my $prev_exons = hash_all_exons_from_dbc( $prev_core_dba );
    my $curr_exons = hash_all_exons_from_dbc( $curr_core_dba );
    my ($removed, $remained1) = check_presence($prev_exons, $curr_exons);
    my ($added, $remained2)   = check_presence($curr_exons, $prev_exons);

    my $coding_exons_differ = $added || $removed;
    if($coding_exons_differ) {
        $self->warning("The coding exons changed: $added hash keys were added and $removed were removed");
    }

    $self->param('reuse_this', $coding_exons_differ ? 0 : 1);
}


sub write_output {      # store the genome_db and dataflow
    my $self = shift;

    my $genome_db_id        = $self->param('genome_db_id');
    my $reuse_this          = $self->param('reuse_this');
    my $per_genome_suffix   = $self->param('per_genome_suffix');

        # same composition of the output, independent of the branch:
    my $output_hash = {
        'genome_db_id'       => $genome_db_id,
        'reuse_this'         => $reuse_this,
        'per_genome_suffix'  => $per_genome_suffix,
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
    my $dba = shift @_;
    my $dbc = $dba->dbc();

    my $sql = qq{
        SELECT CONCAT(tsi.stable_id, ':', e.seq_region_start, ':', e.seq_region_end)
          FROM transcript_stable_id tsi, transcript t, exon_transcript et, exon e, seq_region sr, coord_system cs
         WHERE tsi.transcript_id=t.transcript_id
           AND t.transcript_id=et.transcript_id
           AND et.exon_id=e.exon_id
           AND t.seq_region_id = sr.seq_region_id
           AND sr.coord_system_id = cs.coord_system_id
           AND t.biotype=?
           AND cs.species_id =?
    };

    my %exon_set = ();

    my $sth = $dbc->prepare($sql);
    $sth->execute('protein_coding', $dba->species_id());

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
