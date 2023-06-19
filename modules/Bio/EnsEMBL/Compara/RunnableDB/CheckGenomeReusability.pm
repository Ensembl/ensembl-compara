=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CheckGenomeReusability

=head1 DESCRIPTION

This is a base Runnable to check the reusability of a certain GenomeDB

supported parameters:
    'genome_db_id'  => <number>
        the id of the genome to be checked (main input_id parameter)

    'registry_dbs'  => <list_of_dbconn_hashes>
        list of hashes with registry connection parameters (tried in succession).

    'reuse_this'    => <0|1>
        (optional) if defined, the code is skipped and this value is passed to the output

    'do_not_reuse_list' => <list_of_species_ids_or_names>
        (optional)  is a 'veto' list of species we definitely do not want to be reused this time

    'must_reuse_collection_file' => <json_file>
        (optional)  file configuring the collections for which species MUST be reused this time

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CheckGenomeReusability;

use strict;
use warnings;

use JSON qw(decode_json);

use File::Temp qw(tempfile);
use Scalar::Util qw(looks_like_number);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::Utils::Registry;
use Bio::EnsEMBL::Compara::Utils::RunCommand;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},

        # If set to true, the runnable will try to find the genomes
        # (current and previous) in the Registry
        'needs_core_db' => undef,

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
    my $genome_db    = $genome_db_adaptor->fetch_by_dbID($genome_db_id) or $self->die_no_retry("Could not fetch genome_db with genome_db_id='$genome_db_id'");
    $self->param('genome_db', $genome_db);
    my $species_name = $genome_db->name();

    # We need to read the must-reuse list before doing any assessment of reusability.
    my $reuse_required = 0;
    if ( $self->param_is_defined('must_reuse_collection_file') ) {

        my ($fh, $must_reuse_list_file) = tempfile(UNLINK => 1);
        my $cmd_args = [
            $self->param('list_must_reuse_species_exe'),
            "--input-file",
            $self->param('must_reuse_collection_file'),
            "--mlss-conf-file",
            $self->param('mlss_conf_file'),
            "--ensembl-release",
            $self->param('ensembl_release'),
            "--output-file",
            $must_reuse_list_file,
        ];
        Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd_args, {'die_on_failure' => 1});
        close($fh);

        my $must_reuse_list = decode_json($self->_slurp($must_reuse_list_file));

        foreach my $must_reuse_candidate (@$must_reuse_list) {
            if( $must_reuse_candidate eq $species_name ) {
                $reuse_required = 1;
                last;
            }
        }
    }
    $self->param('reuse_required', $reuse_required);

    # For polyploid genomes, the reusability is only assessed on the principal genome
    if ($genome_db->genome_component) {
        # -1 means that we haven't checked the species
        $self->param('reuse_this', -1);
        return;

    # But in fact, we can't assess the reusability of a polyploid genomes
    # that comes from files. This is because we would have to read the
    # files of the components, which shouldn't be done in this module (this
    # module only deals with *1* genome at a time)
    } elsif ($genome_db->is_polyploid and not $self->comes_from_core_database($genome_db)) {
        $self->param('reuse_this', 0);
        return;
    }

    return if(defined($self->param('reuse_this')));  # bypass fetch_input() in case 'reuse_this' has already been passed

    my $reuse_forbidden = 0;
    my $do_not_reuse_list = $self->param('do_not_reuse_list') || [];
    foreach my $do_not_reuse_candidate (@$do_not_reuse_list) {
        if( looks_like_number( $do_not_reuse_candidate ) ) {

            if( $do_not_reuse_candidate == $genome_db_id ) {
                $reuse_forbidden = 1;
                last;
            }

        } else {    # not using registry names here to avoid clashes with previous release registry entries:

            if( $do_not_reuse_candidate eq $genome_db->name ) {
                $reuse_forbidden = 1;
                last;
            }
        }
    }

    if ($reuse_required && $reuse_forbidden) {
        $self->die_no_retry("cannot both require and forbid reuse of genome_db '$species_name' (genome_db_id: $genome_db_id)");
    } elsif ($reuse_forbidden) {
        $self->param('reuse_this', 0);
        return;
    }

    if(my $reuse_db = $self->param('reuse_db')) {

            # Need to check that the genome_db_id has not changed (treat the opposite as a signal not to reuse) :
        my $reuse_compara_dba       = $self->get_cached_compara_dba('reuse_db');    # may die if bad parameters
        $self->param('reuse_dba', $reuse_compara_dba);
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

        if (not $self->comes_from_core_database($reuse_genome_db) and $self->comes_from_core_database($genome_db)) {
            $self->warning("Cannot compare a 'core' species to a reused 'file' species ($species_name)");
            $self->param('reuse_this', 0);
            return;
        }

        $self->param('reuse_genome_db', $reuse_genome_db);

        return unless $self->param('needs_core_db');

        my $prev_core_dba;

        if ($self->comes_from_core_database($genome_db)) {
            
            # now use the registry to find the previous release core database candidate:
            Bio::EnsEMBL::Registry->no_version_check(1);
            $prev_core_dba = $self->param('prev_core_dba', Bio::EnsEMBL::Compara::Utils::Registry::get_previous_core_DBAdaptor($species_name));

        } else {

            $prev_core_dba = $reuse_genome_db->db_adaptor;

        }

        if ($prev_core_dba) {
            my $curr_core_dba = $self->param('curr_core_dba', $genome_db->db_adaptor);

            if ($prev_core_dba and ($prev_core_dba eq $curr_core_dba)) {
                $self->warning("The current and previous core databases appear to be the same, so reuse will happen");
                $self->param('reuse_this', 1);
                return;
            }

            my $curr_assembly = $curr_core_dba->assembly_name;
            my $prev_assembly = $prev_core_dba->assembly_name;

            if($curr_assembly ne $prev_assembly) {
                # This is very unlikely since at this stage, genome_db_ids must be equal
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

    # bypass run_comparison() if 'reuse_this' has either been passed or already computed
    if (!defined $self->param('reuse_this')) {
        # run_comparison is to be implemented in a sub-class
        $self->param('reuse_this', $self->run_comparison());
    }

    if ($self->param('reuse_required')) {
        my $genome_db = $self->param('genome_db');
        my $species_name = $genome_db->name;
        my $genome_db_id = $genome_db->dbID;
        if ($self->param('reuse_this') < 0) {
            $self->warning("GenomeDB '$species_name' (genome_db_id: $genome_db_id) must be reused, but cannot assess its reusability");
        } elsif (!$self->param('reuse_this')) {
            $self->die_no_retry("GenomeDB '$species_name' (genome_db_id: $genome_db_id) must be reused, but is configured as non-reusable");
        }
    }
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
    my $self = shift;
    my $genome_db = shift;
    return (($genome_db->locator and ($genome_db->locator =~ /^Bio::EnsEMBL::Compara::GenomeMF/)) ? 0 : 1);
}


sub hash_rows_from_dba {
    my $self = shift;
    my $dba = shift @_;
    my $sql = shift @_;

    my %rows = ();

    my $sth = $dba->dbc->prepare($sql);
    $sth->execute(@_);

    while(my ($key) = $sth->fetchrow()) {
        $rows{$key} = 1;
    }

    return \%rows;
}


sub do_one_comparison {
    my $self = shift @_;
    my ($label, $prev_hash, $curr_hash) = @_;

    return if(defined($self->param('reuse_this')));  # bypass run() in case 'reuse_this' has either been passed or already computed

    my ($removed, $remained1) = check_hash_equals($prev_hash, $curr_hash);
    my ($added, $remained2)   = check_hash_equals($curr_hash, $prev_hash);

    my $objects_differ = $added || $removed;
    if ($objects_differ) {
        $self->warning("$label changes: $added hash keys were added and $removed were removed");
    }

    return $objects_differ ? 0 : 1;
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
