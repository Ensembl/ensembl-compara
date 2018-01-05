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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::RunAncestralAllelesComplete

=head1 SYNOPSIS

This RunnableDB module is part of the AncestralAllelesForIndels pipeline.

=head1 DESCRIPTION

This RunnableDB module creates and analyses the consequences of an indel event for each base in an alignment. It writes the 'event' to a file which can used with the Variant Effect Predictor.


=cut

package Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::RunAncestralAllelesComplete;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::AncestralAllelesCompleteBase');
use Bio::EnsEMBL::DBSQL::DBAdaptor;

sub fetch_input {
    my $self = shift;

}

sub run {
    my $self = shift;

    $self->run_cmd();

}

sub write_output {
    my $self = shift @_;

    my $output = $self->param('output');

    my $sql = "INSERT INTO statistics (seq_region, seq_region_start, seq_region_end, total_bases, all_N, low_complexity, multiple_gats, no_gat, insufficient_gat, long_alignment, align_all_N, num_bases_analysed) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)";
    my $sth = $self->compara_dba->dbc->prepare($sql);

    $sth->execute($output->{'seq_region'}, $output->{'seq_region_start'},  $output->{'seq_region_end'}, $output->{'total_bases'}, $output->{'all_N'},$output->{'count_low_complexity'}, $output->{'multiple_gats'},$output->{'no_gat'},$output->{'insufficient_gat'},$output->{'long_alignment'},$output->{'align_all_N'},$output->{'num_bases_analysed'});
    my $statistics_id = $self->dbc->db_handle->last_insert_id(undef, undef, 'statistics', 'statistics_id');
    $sth->finish;

    $sql = "INSERT INTO event (statistics_id, indel, type, detail, detail1, improvement, detail2, count) VALUES (?,?,?,?,?,?,?,?)";
    $sth = $self->compara_dba->dbc->prepare($sql);

    foreach my $event (keys %{$output->{'sum_types'}}) {
        my $count = $output->{'sum_types'}{$event};

        my ($indel, $type, $detail, $detail1, $improve, $detail2) = $event =~ /(insertion|deletion)_(novel|recovery|unsure)_(of_allele_base|strict|shuffle|realign|neighbouring_deletion|neighbouring_insertion|complex)_{0,1}(strict1|shuffle1){0,1}_{0,1}(better|worse){0,1}_{0,1}(polymorphic_insertion|polymorphic_deletion|complex_polymorphic_insertion|complex_polymorphic_deletion|funny_polymorphic_insertion|funny_polymorphic_deletion){0,1}/;

        $sth->execute($statistics_id, $indel, $type, $detail, $detail1, $improve, $detail2, $count);
    }
    $sth->finish;

};

#
# Run ortheus and parse the output
#
sub run_ortheus {
    my ($self, $compara_dba, $dump_dir, $ordered_fasta_files, $ordered_fasta_headers, $ga_lookup, $tree_string, $mlss, $ref_ga, $flank, $curr_pos, $verbose) = @_;

    #Call ortheus
    my $fasta_str = join " ", @{$ordered_fasta_files};

    my $ortheus_exe = $self->param('ortheus_bin');

    my $tree_state_file = $dump_dir . "/output.$$.tree";
    my $out_align = $dump_dir . "/output.$$.mfa";
    my $out_score = $dump_dir . "/output.$$.score";
    my $nuc_freq = "0.3 0.2 0.2 0.3";

    #my $ortheus_cmd = "$ortheus_exe -b '$tree_string' -c $align_fasta -a $fasta_str -u $tree_state_file -s 0 -j 0 -d $out_align -n $nuc_freq -x $out_score";

    my $ortheus_cmd = "$ortheus_exe -b '$tree_string' -a $fasta_str -u $tree_state_file -s 0 -j 0 -d $out_align -n $nuc_freq -x $out_score";

    #Capture error messages
    my $cmd = $self->run_command($ortheus_cmd);
    if (!$cmd->exit_code) {
        #print "OK\n";
    } else {
        print "ERR: ", $cmd->err, "\n";
        print "Failed $!\n";
        $self->warning("ortheus execution failed at position $curr_pos\n$ortheus_cmd\n");
        return;
    }

    my ($new_tree, $new_score) = $self->parse_results($compara_dba, $dump_dir, $ga_lookup, $ordered_fasta_files, $tree_string, $ordered_fasta_headers, $verbose);
    $new_tree = $self->finalise_tree($compara_dba, $new_tree, $mlss, $ref_ga);

    if ($verbose) {
        foreach my $genomic_align_node (@{$new_tree->get_all_sorted_genomic_align_nodes()}) {
            foreach my $genomic_align (@{$genomic_align_node->genomic_align_group->get_all_GenomicAligns}) {
                my $name;
                if ($genomic_align->dnafrag_id == -1) {
                    $name = "Ancestral";
                    next;
                } else {
                    $name = $genomic_align->genome_db->name;
                }
                if ($flank && $ref_ga && ($name eq $ref_ga->genome_db->name &&
                                          $genomic_align->dnafrag_id == $ref_ga->dnafrag_id &&
                                          $genomic_align->dnafrag_start == $ref_ga->dnafrag_start &&
                                          $genomic_align->dnafrag_end == $ref_ga->dnafrag_end)) {
                    my $highlight = $self->get_highlighter($genomic_align, $flank);
                    print OUT "$highlight\n";
                }
                
                print OUT $genomic_align->aligned_sequence . " " . $name . " " . $genomic_align->dnafrag_id . " " . $genomic_align->dnafrag_start . " " . $genomic_align->dnafrag_end . " " .$genomic_align->cigar_line . "\n" if ($verbose);
            }
        }
    }

    $self->tidy_up_files($dump_dir);
    return ($new_tree, $new_score);
}

1;
