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

Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadCactusMaf

=head1 DESCRIPTION

Load Cactus MAF to Compara database.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadCactusMaf;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing;
use Bio::EnsEMBL::Compara::Utils::IDGenerator qw(:all);
use Bio::EnsEMBL::Hive::Utils qw(destringify);
use Bio::EnsEMBL::Utils::IO qw(slurp_to_array);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub pre_cleanup {
    my $self = shift;

    my $mlss_id = $self->param_required('mlss_id');
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    $self->warning("Deleting previously loaded alignments before retrying");
    Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing::delete_alignments($self, $mlss);
}


sub fetch_input {
    my $self = shift;

    my $mlss_id = $self->param_required('mlss_id');

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor();

    my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);

    my $hal_species_mapping = destringify($mlss->get_value_for_tag('hal_mapping', '{}'));

    my %hal_reverse_mapping;
    while (my ($map_gdb_id, $hal_genome_name) = each %{$hal_species_mapping}) {
        $hal_reverse_mapping{$hal_genome_name} = $map_gdb_id;
    }

    my $maf_src_regex = $self->_compile_maf_src_regex([keys %hal_reverse_mapping]);

    $self->param('hal_reverse_mapping', \%hal_reverse_mapping);
    $self->param('maf_src_regex', $maf_src_regex);
    $self->param('mlss', $mlss);
}

sub write_output {
    my $self = shift;

    my $maf_seq_count = $self->param_required('maf_seq_count');
    my $maf_file = $self->param_required('maf_file');
    my $mlss_id = $self->param_required('mlss_id');

    my $hal_reverse_mapping = $self->param('hal_reverse_mapping');
    my $maf_src_regex = $self->param('maf_src_regex');
    my $mlss = $self->param('mlss');

    if ($maf_seq_count == 0) {
        $self->complete_early("No MAF data to load");
    }

    my $compara_dba = $self->compara_dba;
    my $gab_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor();
    my $ga_adaptor = $compara_dba->get_GenomicAlignAdaptor();
    my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();
    my $gdb_adaptor = $compara_dba->get_GenomeDBAdaptor();

    my $ga_id = get_id_range(
        $compara_dba->dbc,
        "genomic_align_${mlss_id}",
        $maf_seq_count,
        $self->get_requestor_id,
    );

    my $maf_lines = slurp_to_array($maf_file);
    my $maf_blocks = $gab_adaptor->_parse_maf($maf_lines);

    my %maf_src_id_map;
    for my $maf_block (@{$maf_blocks}) {

        my $gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
            -dbID => $ga_id,
            -length => length($maf_block->[0]->{seq}),
            -method_link_species_set => $mlss,
            -adaptor => $gab_adaptor,
        );

        my @genomic_align_array;
        foreach my $rec (@{$maf_block}) {

            my $maf_src_id = $rec->{display_id};
            if (!exists $maf_src_id_map{$maf_src_id}) {
                if ($maf_src_id =~ $maf_src_regex) {
                    $maf_src_id_map{$maf_src_id} = [$1, $2];
                } else {
                    $self->die_no_retry("Cannot map MAF src field '$maf_src_id' to any HAL genome name");
                }
            }
            my ($hal_genome_name, $hal_seq_name) = @{$maf_src_id_map{$maf_src_id}};

            my $map_gdb = $gdb_adaptor->fetch_by_dbID($hal_reverse_mapping->{$hal_genome_name});
            my $principal = $map_gdb->principal_genome_db();
            my $this_gdb = defined $principal ? $principal : $map_gdb;
            my $this_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($this_gdb, $hal_seq_name);

            if ( ! defined $this_dnafrag ) {
                $self->die_no_retry(sprintf("Could not find a DnaFrag named '%s' for species '%s' (%s)", $hal_seq_name, $this_gdb->name, $hal_genome_name));
            }

            if ( $rec->{end} > $this_dnafrag->length ) {
                $self->die_no_retry(sprintf('Alignment position of %s does not fall within the length of the chromosome', $this_gdb->name));
            }

            my $cigar_line = Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string($rec->{seq});

            my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                -dbID => $ga_id,
                -genomic_align_block => $gab,
                -aligned_sequence => $rec->{seq},
                -dnafrag => $this_dnafrag,
                -dnafrag_start => $rec->{start},
                -dnafrag_end => $rec->{end},
                -dnafrag_strand => $rec->{strand},
                -method_link_species_set => $mlss,
                -cigar_line => $cigar_line,
                -visible => 1,
                -adaptor => $ga_adaptor,
            );
            push( @genomic_align_array, $genomic_align );
            $ga_id += 1;
        }

        $gab->genomic_align_array(\@genomic_align_array);
        $gab = $gab_adaptor->store($gab);
    }
}


sub post_healthcheck {
    my $self = shift;

    my $maf_block_count = $self->param_required('maf_block_count');
    my $maf_seq_count = $self->param_required('maf_seq_count');
    my $mlss_id = $self->param_required('mlss_id');

    my $range_info = get_previously_assigned_range(
        $self->compara_dba->dbc,
        "genomic_align_${mlss_id}",
        $self->get_requestor_id,
    );

    my ($min_id, $num_ids) = @{$range_info};
    my $max_id = $min_id + $num_ids - 1;

    my $sql_gab = 'SELECT COUNT(*) FROM genomic_align_block WHERE genomic_align_block_id BETWEEN ? AND ?';
    my $sql_ga  = 'SELECT COUNT(*) FROM genomic_align       WHERE genomic_align_id       BETWEEN ? AND ?';

    my $helper = $self->compara_dba->dbc->sql_helper;
    my $failures = 0;

    my $gab_count = $helper->execute_single_result( -SQL => $sql_gab, -PARAMS => [$min_id, $max_id] );
    if ($gab_count != $maf_block_count) {
        $self->warning(
            "Loaded GenomicAlignBlock count ($gab_count) does not match input MAF block count ($maf_block_count)"
        );
        $failures += 1;
    }

    my $ga_count = $helper->execute_single_result( -SQL => $sql_ga, -PARAMS => [$min_id, $max_id] );
    if ($ga_count != $maf_seq_count) {
        $self->warning(
            "Loaded GenomicAlign count ($ga_count) does not match input MAF sequence count ($maf_seq_count)"
        );
        $failures += 1;
    }

    $self->throw("$failures HCs failed.") if $failures;
}


sub _compile_maf_src_regex {
    my ($self, $genome_names) = @_;

    unless (defined $genome_names && scalar(@{$genome_names})) {
        $self->die_no_retry("MAF src regex requires at least one genome name");
    }

    my %genome_name_set = map { $_ => 1 } @{$genome_names};

    foreach my $genome_name (@{$genome_names}) {
        while ($genome_name =~ /[.]/g) {
            my $prefix = substr($genome_name, 0, $-[0]);
            print($prefix ."\n");
            if (exists $genome_name_set{$prefix}) {
                $self->die_no_retry("cannot create MAF src regex - genome name '$prefix' is a prefix of '$genome_name'");
            }
        }
    }

    my $genome_patt = join('|', map { quotemeta } @{$genome_names});
    my $maf_src_regex = qr/^($genome_patt)[.](.+)$/;
    return $maf_src_regex;
}


1;
