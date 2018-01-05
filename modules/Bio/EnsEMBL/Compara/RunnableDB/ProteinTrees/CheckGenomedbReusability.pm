=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


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

    'registry_dbs'  => <list_of_dbconn_hashes>
        list of hashes with registry connection parameters (tried in succession).

    'reuse_this'    => <0|1>
        (optional) if defined, the code is skipped and this value is passed to the output

    'do_not_reuse_list' => <list_of_species_ids_or_names>
        (optional)  is a 'veto' list of species we definitely do not want to be reused this time
=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability;

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::GenomeDB;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

my $suffix_separator = '__cut_here__';

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        check_gene_content  => 1,

        # "reuse_this" is used throughout the Runnable. Default value is
        # undef, so that the calling job can set it to 0 or 1
        reuse_this  => undef,
    }
}

sub fetch_input {
    my $self = shift @_;

    my $genome_db_adaptor   = $self->compara_dba->get_GenomeDBAdaptor;
    $genome_db_adaptor->_id_cache->clear_cache();

    my $genome_db_id = $self->param('genome_db_id');
    my $genome_db    = $genome_db_adaptor->fetch_by_dbID($genome_db_id) or die "Could not fetch genome_db with genome_db_id='$genome_db_id'";
    my $species_name = $self->param('species_name', $genome_db->name());

    # For polyploid genomes, the reusability is only assessed on the principal genome
    if ($genome_db->genome_component) {
        # -1 means that we haven't checked the species
        $self->param('reuse_this', -1);
        return;

    # But in fact, we can't assess the reusability of a polyploid genomes
    # that comes from files. This is because we would have to read the
    # files of the components, which shouldn't be done in this module (this
    # module only deals with *1* genome at a time)
    } elsif ($genome_db->is_polyploid and not comes_from_core_database($genome_db)) {
        $self->param('reuse_this', 0);
        return;
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

            if( $do_not_reuse_candidate eq $genome_db->name ) {
                $self->param('reuse_this', 0);
                return;
            }
        }
    }

    if(my $reuse_db = $self->param('reuse_db')) {

            # Need to check that the genome_db_id has not changed (treat the opposite as a signal not to reuse) :
        my $reuse_compara_dba       = $self->get_cached_compara_dba('reuse_db');    # may die if bad parameters
        my $reuse_genome_db_adaptor = $reuse_compara_dba->get_GenomeDBAdaptor();
        my $reuse_genome_db = $reuse_genome_db_adaptor->fetch_by_name_assembly($species_name, $genome_db->assembly);
        if (not $reuse_genome_db) {
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

        if (not comes_from_core_database($reuse_genome_db) and comes_from_core_database($genome_db)) {
            $self->warning("Cannot compare a 'core' species to a reused 'file' species ($species_name)");
            $self->param('reuse_this', 0);
            return;
        }

        $self->param('genome_db', $genome_db);
        $self->param('reuse_genome_db', $reuse_genome_db);

        if (not $self->param('check_gene_content')) {
            $self->warning("As requested, will not check that the gene-content is the same for ".$genome_db->name);
            $self->param('reuse_this', 1);
            return;
        }

        my $prev_core_dba;

        if (comes_from_core_database($genome_db)) {
            
            # now use the registry to find the previous release core database candidate:

            Bio::EnsEMBL::Registry->no_version_check(1);

            my $prev_release = $reuse_compara_dba->get_MetaContainer->get_schema_version;

            # load the prev.release registry:
            foreach my $prev_reg_conn (@{ $self->param('registry_dbs') }) {
                my %reg_params = %{ $prev_reg_conn };
                $reg_params{'-db_version'} = $prev_release unless $reg_params{'-db_version'};
                Bio::EnsEMBL::Registry->load_registry_from_db( %reg_params, -species_suffix => $suffix_separator.$prev_release, -verbose => $self->debug );
            }
            $prev_core_dba = $self->param('prev_core_dba', Bio::EnsEMBL::Registry->get_DBAdaptor($species_name.$suffix_separator.$prev_release, 'core'));

        } else {

            $prev_core_dba = $reuse_genome_db->db_adaptor;

        }

        if ($prev_core_dba) {
            my $curr_core_dba = $self->param('curr_core_dba', $genome_db->db_adaptor);

            my $curr_assembly = $curr_core_dba->assembly_name;
            my $prev_assembly = $prev_core_dba->assembly_name;

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

    my ($prev_hash, $curr_hash);
    if (comes_from_core_database($self->param('genome_db'))) {
        $prev_hash = hash_all_exons_from_dbc( $self->param('prev_core_dba') );
        $curr_hash = hash_all_exons_from_dbc( $self->param('curr_core_dba') );
    } else {
        $prev_hash = hash_all_sequences_from_db( $self->param('reuse_genome_db') );
        $curr_hash = hash_all_sequences_from_file( $self->param('genome_db') );
    }
    my ($removed, $remained1) = check_hash_equals($prev_hash, $curr_hash);
    my ($added, $remained2)   = check_hash_equals($curr_hash, $prev_hash);

    my $coding_objects_differ = $added || $removed;
    if($coding_objects_differ) {
        $self->warning("The coding objects changed: $added hash keys were added and $removed were removed");
    }

    $self->param('reuse_this', $coding_objects_differ ? 0 : 1);
}


sub write_output {      # store the genome_db and dataflow
    my $self = shift;

    my $genome_db_id        = $self->param('genome_db_id');
    my $reuse_this          = $self->param('reuse_this');

        # same composition of the output, independent of the branch:
    my $output_hash = {
        'genome_db_id'       => $genome_db_id,
        'reuse_this'         => $reuse_this,
    };

        # all jobs dataflow into branch 1:
    $self->dataflow_output_id( $output_hash, 1);

        # in addition, the flow is split between branches 2 and 3 depending on $reuse_this:
        # reuse_this=-1 is ignored
    $self->dataflow_output_id( $output_hash, $reuse_this ? 2 : 3) if $reuse_this >= 0;
}


# ------------------------- non-interface subroutines -----------------------------------

sub comes_from_core_database {
    my $genome_db = shift;
    return (($genome_db->locator and ($genome_db->locator =~ /^Bio::EnsEMBL::Compara::GenomeMF/)) ? 0 : 1);
}


sub hash_all_exons_from_dbc {
    my $dba = shift @_;
    my $dbc = $dba->dbc();

    my $sql = qq{
        SELECT CONCAT(t.stable_id, ':', e.seq_region_start, ':', e.seq_region_end)
          FROM transcript t, exon_transcript et, exon e, seq_region sr, coord_system cs
         WHERE t.transcript_id=et.transcript_id
           AND et.exon_id=e.exon_id
           AND t.seq_region_id = sr.seq_region_id
           AND sr.coord_system_id = cs.coord_system_id
           AND t.canonical_translation_id IS NOT NULL
           AND cs.species_id =?
    };

    my %exon_set = ();

    my $sth = $dbc->prepare($sql);
    $sth->execute($dba->species_id());

    while(my ($key) = $sth->fetchrow()) {
        $exon_set{$key} = 1;
    }

    return \%exon_set;
}

sub hash_all_sequences_from_db {
    my $genome_db = shift;

    my $sql = 'SELECT stable_id, MD5(sequence) FROM seq_member JOIN sequence USING (sequence_id) WHERE genome_db_id = ?';
    my $sth = $genome_db->adaptor->dbc->prepare($sql);
    $sth->execute($genome_db->dbID);

    my %sequence_set = ();

    while(my ($stable_id, $seq_md5) = $sth->fetchrow()) {
        $sequence_set{$stable_id} = lc $seq_md5;
    }

    return \%sequence_set;
}

sub hash_all_sequences_from_file {
    my $genome_db = shift;

    my $prot_seq = $genome_db->db_adaptor->get_protein_sequences;

    my %sequence_set = ();

    foreach my $stable_id (keys %$prot_seq) {
        $sequence_set{$stable_id} = lc md5_hex($prot_seq->{$stable_id}->seq);
    }
    return \%sequence_set;
}

sub check_hash_equals {
    my ($from_hash, $to_hash) = @_;

    my @presence = (0, 0);

    foreach my $stable_id (keys %$from_hash) {
        $presence[ (exists($to_hash->{$stable_id}) and ($to_hash->{$stable_id} eq $from_hash->{$stable_id})) ? 1 : 0 ]++;
    }
    return @presence;
}

1;
