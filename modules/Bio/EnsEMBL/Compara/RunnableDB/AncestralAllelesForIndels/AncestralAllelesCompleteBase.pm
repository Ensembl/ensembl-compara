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

Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::AncestralAllelesCompleteBase

=head1 SYNOPSIS

This RunnableDB module is part of the AncestralAllelesForIndels pipeline.

=head1 DESCRIPTION

This RunnableDB module contains all the methods used by RunAncestralAllelesComplete.pm and RunAncestralAllelesCompleteFork.pm

=cut

package Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::AncestralAllelesCompleteBase;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Time::HiRes;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

#Mapping of the simple_events for compact output
my %event_type = ('polymorphic_deletion' => 1,
                  'complex_polymorphic_deletion' => 2,
                  'funny_polymorphic_deletion' => 3,
                  'polymorphic_insertion' => 4,
                  'complex_polymorphic_insertion' => 5,
                  'funny_polymorphic_insertion' => 6,
                  'unsure' => 7);

my $show_time = 0; #writes the time for each iteration to a file. Used for development purposes only.

    #=====================================================================
    # Default values
    #=====================================================================
sub param_defaults {
    return {
    # Default flank regions for the alignment of the alleles
        'flank'             => 10,

    # If an alignment is longer than this, skip this indel!
        'max_alignment_length'  => 100,

    # Old way of outputing the info for the VEP tabix file. Diable this.
        'verbose_output'    => 0,

    # Location of the Ortheus executable
        'ortheus_bin'       => '/software/ensembl/compara/OrtheusC/bin/OrtheusC',

    # Default values for selecting the multiple alignment
        'method_link_type'  => 'EPO',
        'species_set_name'  => 'primates',
    #=====================================================================
    }
}


#
# set up 
#
sub run_cmd {
    my ($self) = @_;

    
    my $registry = 'Bio::EnsEMBL::Registry';

    my $output; #hash to contain all the variables I want to write to the database

    #=====================================================================
    # Example parameters (just to test the code or extract example alignments)
    #=====================================================================
    if ($self->param_is_defined('example')) {

        # Sets an example query region (human:6:133078660-133078700)
        $self->param('ref_species', 'homo_sapiens') if (!$self->param_is_defined('ref_species'));
        $self->param('seq_region', '6') if (!$self->param_is_defined('seq_region'));
        $self->param('seq_region_start', '133078660') if (!$self->param_is_defined('seq_region_start'));
        $self->param('seq_region_end', '133078700') if (!$self->param_is_defined('seq_region_end'));

        # Work dir set to current directory and sub_dir ignored.
        $self->param('work_dir', '.') if (!$self->param_is_defined('work_dir'));
        $self->param('sub_dir', '') if (!$self->param_is_defined('sub_dir'));
        
        # Connect to the public databases. The registry is required to connect to all the primates and the compara_url is required by the module)
        use Bio::EnsEMBL::Registry;
        Bio::EnsEMBL::Registry->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org/');
        use Bio::EnsEMBL::ApiVersion;
        $self->param('compara_url', 'mysql://anonymous@ensembldb.ensembl.org/ensembl_compara_'.software_version()) if (!$self->param_is_defined('compara_url'));
        
        # This enable the output of the Ortheus alignments
        $self->param('verbose', '1') if (!$self->param_is_defined('verbose'));
        
        # Disable the write_output step, which is meant to store the stats on the DB.
        $self->execute_writes(0);
    }
    #=====================================================================

    my $ref_species = $self->param('ref_species');
    my $seq_region = $self->param('seq_region');
    my $seq_region_start = $self->param('seq_region_start');
    my $seq_region_end = $self->param('seq_region_end');
    my $work_dir = $self->param('work_dir');
    my $ancestor_dir = $self->param('ancestor_dir');
    my $verbose = $self->param('verbose');
    my $verbose_vep = $self->param('verbose_output');
    my $method_link_type = $self->param('method_link_type');
    my $species_set_name = $self->param('species_set_name');

    #any alignment greater than 100 will be discarded since this means a large insertion which
    #causes difficulties for ortheus.
    my $max_alignment_length = $self->param('max_alignment_length');

    #Set of bases to insert to the left of the current base
    my $inserts;
    %$inserts = ('A' => ['C','G','T'],
                 'C' => ['A','G','T'],
                 'G' => ['A','C','T'],
                 'T' => ['A','C','G'],
                 'N' => ['A','C','G','T']);

    #compara database adaptor
    my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$self->param('compara_url'));
    my $genome_db_adaptor = $compara_dba->get_genomeDBAdaptor;
    my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($ref_species);

    $self->param('ancestor_genome_db', $genome_db_adaptor->fetch_by_name_assembly("ancestral_sequences"));

    my $slice_adaptor = $registry->get_adaptor($ref_species, 'Core', 'Slice');

    my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_method_link_type_species_set_name($method_link_type, $species_set_name);

    my $as_adaptor = $compara_dba->get_AlignSliceAdaptor;
    my $gab_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;
    my $gat_adaptor = $compara_dba->get_GenomicAlignTreeAdaptor;
    my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor;

    $output->{'seq_region'} = $seq_region;
    $output->{'seq_region_start'} = $seq_region_start;
    $output->{'seq_region_end'} = $seq_region_end;

    my $flank = $self->param('flank');
    my $sub_dir = $self->param('sub_dir');

    my $outfile = "$work_dir/$sub_dir/indel_${seq_region}_${seq_region_start}_${seq_region_end}";
    my $vepfile = "$work_dir/$sub_dir/vep_${seq_region}_${seq_region_start}_${seq_region_end}";
    my $time_file = "$work_dir/$sub_dir/time_${seq_region}_${seq_region_start}_${seq_region_end}";

    my $nt_counts;

    #Set directory to dump ortheus and fasta files
    my $dump_dir = $self->worker_temp_directory;

    $output->{'multiple_gats'} = 0;
    $output->{'no_gat'} = 0;
    $output->{'all_N'} = 0;
    $output->{'count_low_complexity'} = 0;
    $output->{'insufficient_gat'} = 0;
    $output->{'num_bases_analysed'} = 0;
    $output->{'long_alignment'} = 0;
    $output->{'align_all_N'} = 0;

    if ($verbose) {
        open OUT, ">$outfile" or die "Unable to open $outfile for writing";
    }
    if ($show_time) {
        open TIME, ">$time_file" or die "Unable to open $time_file for writing";
    }

    #get 1bp variants from ancestor file (as opposed to 1bp insertions/deletions)
    my $ancestor_file = $ancestor_dir . $ref_species . "_ancestor_" . $seq_region . ".fa";
    my $original_anc_alleles = parse_ancestor_file($ancestor_file, $seq_region_start, $seq_region_end);

    open VEP, ">$vepfile" or die "Unable to open $vepfile for writing";
    my $concat_line;

    my $left = $flank;
    my $right = $flank;

    my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($genome_db, $seq_region);

    $slice_adaptor->dbc->prevent_disconnect( sub {

    #Skip if near the start or end of the chromosome
    if ($seq_region_start <= $left) {
        print OUT "Skipped start of chromosome\n" if ($verbose);
        $self->param('output', $output);
        for (my $i = $seq_region_start; $i <= $left; $i++) {
            if ($verbose_vep) {
                print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i] . "\tsubstitution\n";
            } else {
                print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i] . "\ts;\n";
            }
        }
        $seq_region_start = $left+1;
        $output->{'total_bases'}+=$left;
    }
    if ($seq_region_end > ($dnafrag->length - $right)) {
        print OUT "Skipped end of chromosome\n" if ($verbose);
        $self->param('output', $output);
        $seq_region_end = $dnafrag->length - $right;
        $output->{'total_bases'}+=$right;
    }

    my $whole_slice = $slice_adaptor->fetch_by_region('toplevel',$seq_region, ($seq_region_start-$left), ($seq_region_end+$right));
    my $all_gats = $gat_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $whole_slice, undef, undef, 1);

    for (my $i = $seq_region_start; $i <= $seq_region_end; $i++) {
        $concat_line = "";

        my $time_start1 = Time::HiRes::time;
        #All bases
        $output->{'total_bases'}++;

        #Set allele_start and allele_end in chr coords. 
        my $allele_start = $i;
        my $allele_end = $allele_start;

        #Extend slice
        my $slice_start = $allele_start-$left;
        my $slice_end = $allele_end+$right;
        my $this_slice = $whole_slice->sub_Slice(($slice_start-($seq_region_start-$left)+1), ($slice_end-($seq_region_start-$left)+1));

        my $seq = $this_slice->seq;

        #Sequence is all N
        my $n_cnt = ($seq =~ tr/Nn/Nn/);
        if ($n_cnt == length($seq)) {
            $output->{'all_N'}++;
            if ($verbose_vep) {
                print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i-$seq_region_start] . "\tsubstitution\n";
            } else {
                print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i-$seq_region_start] . "\ts;\n";
            }
            next;
        }

        my @seq_array = split //,$seq;

        my $left_base = $seq_array[$left-1]; #counting from 0, and so $left is actually the deleted base
        my $right_base = $seq_array[$left+1];
        my $this_base = $seq_array[$left];

        if ($verbose) {
            print OUT "==============================================================================================\n";
            print OUT " chromosome $seq_region and position $allele_start ($this_base)\n";
        }

        my $left_seq = substr $seq, 0, $left;
        my $right_seq = substr $seq, (-1 * $right);
        
        my $left_low_complexity = check_for_low_complexity($left_seq);
        my $right_low_complexity = check_for_low_complexity($right_seq);
        
        if ($left_low_complexity || $right_low_complexity) {
            $output->{'count_low_complexity'}++;

            if ($verbose_vep) {
                print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i-$seq_region_start] . "\tsubstitution\n";
            } else {
                print VEP "$seq_region\t$i\t". $original_anc_alleles->[$i-$seq_region_start]. "\ts;\n";
            }
            if ($verbose) {
                print OUT "found low complexity sequence\n";
                print OUT "$left_seq:$this_base:$right_seq\n";
            }
            next;
        }

        my $gats;
        my $skip_empty_GenomicAligns = 1;
        foreach my $this_gat (@$all_gats) {
            #Skip blocks that are not in range (prevents a warning from restrict_between_reference_positions)
            my $reference_genomic_align ||= $this_gat->reference_genomic_align;

            next unless ($reference_genomic_align);
            next if ($this_slice->start > $reference_genomic_align->dnafrag_end or $this_slice->end < $reference_genomic_align->dnafrag_start);
            my $restrict_gat = $this_gat->restrict_between_reference_positions($this_slice->start, $this_slice->end, undef, $skip_empty_GenomicAligns);
            push @$gats, $restrict_gat if ($restrict_gat);
        }

        print OUT "num gats " . @$gats . "\n" if ($verbose && $gats);
        if (!$gats) {
            print OUT "  No genomic_align_trees found in this region\n" if ($verbose);
            $output->{'no_gat'}++;
            if ($verbose_vep) {
                print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i-$seq_region_start] . "\tsubstitution\n";
            } else {
                print VEP "$seq_region\t$i\t". $original_anc_alleles->[$i-$seq_region_start]. "\ts;\n";
            }
            next;
        }

        my $boundary_cases;
        foreach my $original_gat (@$gats) {
            #Check length of alignment is below max_alignment_length
            if ($original_gat->length > $max_alignment_length) {
                $output->{'long_alignment'}++;
                if ($verbose_vep) {
                    print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i-$seq_region_start] . "\tsubstitution\n";
                } else {
                    print VEP "$seq_region\t$i\t". $original_anc_alleles->[$i-$seq_region_start]. "\ts;\n";
                }
                next;
            }

            if ($original_gat->reference_genomic_align->dnafrag_start > $slice_start || 
                $original_gat->reference_genomic_align->dnafrag_end < $slice_end) {
                #Need to keep track of the regions crossing a boundary so that we don't call this twice (one for each gat at the boundary)
                next if ($boundary_cases->{$i});
                $boundary_cases->{$i} = 1;

                print OUT "  WARNING: genomic_align_tree (" . $original_gat->reference_genomic_align->dnafrag_start . "_" .  $original_gat->reference_genomic_align->dnafrag_end . ") does not cover the whole slice (" . $slice_start . "-" . $slice_end . ")\n" if ($verbose);
                
                
                $output->{'insufficient_gat'}++;
                if ($verbose_vep) {
                    print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i-$seq_region_start] . "\tsubstitution\n";
                } else {
                    print VEP "$seq_region\t$i\t". $original_anc_alleles->[$i-$seq_region_start]. "\ts;\n";
                }
                next;
            }

            #Check if have alignments of only N or gap in the other species (ie no sequence)
            if (check_for_alignments_all_N_or_gap($original_gat)) {
                $output->{'align_all_N'}++;
                if ($verbose_vep) {
                    print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i-$seq_region_start] . "\tsubstitution\n";
                } else {
                    print VEP "$seq_region\t$i\t". $original_anc_alleles->[$i-$seq_region_start]. "\ts;\n";
                }
                next;
            }

            $output->{'num_bases_analysed'}++;

            if ($verbose) {
                print OUT "Original alignment length " . $original_gat->length . "\n";
                print_gat($original_gat, $verbose);
                print OUT "\n";
            }

            #Remove any sequences from original_gat that contain only Ns
            my $num_sequences_of_all_N;
            ($original_gat,$num_sequences_of_all_N) = remove_sequence_of_all_N_or_gap($original_gat);

            if ($verbose) {
                if ($num_sequences_of_all_N) {
                    print OUT "Pruned original alignment length " . $original_gat->length . "\n";
                    print_gat($original_gat, $verbose);
                    print OUT "\n";
                }
            }

            if ($verbose_vep) {
                print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i-$seq_region_start] . "\tsubstitution\n";
            } else {
                $concat_line .= "$seq_region\t$i\t". $original_anc_alleles->[$i-$seq_region_start]. "\ts;";
            }
            my $ref_ga = $original_gat->reference_genomic_align;
            
            #Set up the files needed for running ortheus ie fasta_files and the tree_string
            my ($ordered_fasta_files, $ga_lookup, $tree_string, $ordered_fasta_headers) = $self->init_files($dump_dir, $original_gat);
            
            #Run ortheus to create the 'reference' alignment
            print OUT "\nREFERENCE\n" if ($verbose);
            my ($reference_gat, $reference_score);

            ($reference_gat, $reference_score) = $self->run_ortheus($compara_dba, $dump_dir, $ordered_fasta_files, $ordered_fasta_headers, $ga_lookup, $tree_string, $mlss, $ref_ga, $left-1, $i, $verbose);
            
            #Check that ortheus ran OK, ie returned a tree
            next unless($reference_gat);

            my $ref_alignments = convert_gat_to_alignment($reference_gat, $reference_score, "REFERENCE");
            
            $ref_alignments = call_ancestral_allele($reference_gat->reference_genomic_align_node,$ref_alignments, "REFERENCE", $verbose);

            #Run ortheus to create the 'modified' alignment (ie using the allele)
            print OUT "\nMODIFIED\n" if ($verbose);
            
            foreach my $indel_type ("insertion", "deletion") {
                my $alignments;
                #Get the slice sequence including the insertion
                my $output_line;
                if ($indel_type eq "insertion") {
                    foreach my $allele_seq (@{$inserts->{$this_base}}) {
                        $output_line = $self->find_ancestral_alleles($indel_type, $this_slice, $slice_start, $slice_end, $allele_seq, ($allele_start-1), $allele_end, $original_gat, $ref_ga, $reference_gat, $ref_alignments, $dump_dir, $compara_dba, $mlss, ($left-1), $right, $flank, $seq_region, $output, $verbose, $verbose_vep);
                        $concat_line .= $output_line unless ($verbose_vep);
                    }
                } elsif ($indel_type eq "deletion") {
                    my $allele_seq = $this_base;
                    $output_line = $self->find_ancestral_alleles($indel_type, $this_slice, $slice_start, $slice_end, $allele_seq, $allele_start, $allele_end, $original_gat, $ref_ga, $reference_gat, $ref_alignments, $dump_dir, $compara_dba, $mlss, $left, $right, $flank, $seq_region, $output, $verbose, $verbose_vep);
                    $concat_line .= $output_line unless ($verbose_vep);
                }
            }
            print VEP "$concat_line\n";
            print TIME "$i ". (Time::HiRes::time() - $time_start1) . "\n" if ($show_time);
            
            $original_gat->release_tree;
            $reference_gat->release_tree;
        }
    }
    #Print end of chr
    $concat_line = "";
    my $orig_seq_region_end = $self->param('seq_region_end');
    if ($orig_seq_region_end > ($dnafrag->length - $right)) {
        for (my $i = ($dnafrag->length - $right + 1); $i <= $orig_seq_region_end; $i++) {
            if ($verbose_vep) {
                print VEP "$seq_region\t$i\t" . $original_anc_alleles->[$i-$seq_region_start] . "\tsubstitution\n";
            } else {
                print VEP "$seq_region\t$i\t". $original_anc_alleles->[$i-$seq_region_start]. "\ts;\n";
            }
        }
    }

    print_summary($output) if ($verbose);
    close VEP;
    close OUT if ($verbose);
    close TIME if ($show_time);

    } );

    $self->param('output', $output);

}

sub find_ancestral_alleles {
    my ($self, $indel_type, $this_slice, $slice_start, $slice_end, $allele_seq, $allele_start, $allele_end, $original_gat, $ref_ga, $reference_gat, $ref_alignments, $dump_dir, $compara_dba, $mlss, $left, $right, $flank, $seq_region, $output, $verbose, $verbose_vep) = @_;

    my $vep_line;

    print OUT "------\n" if ($verbose);
    print OUT "$indel_type $allele_seq\n" if ($verbose);

    #Create new sequence with insertion or deletion to the left of the current base
    #eg TTTGATTGCA CTGTGGTCTGA (before) 
    #   TTTGATTGCAACTGTGGTCTGA (after adding an 'A' to the left of 'C')
    my $variant_seq = get_variant_sequence($indel_type, $this_slice, $slice_start, $slice_end, $allele_seq, $allele_start, $allele_end); 

    #Create files ready for running with ortheus
    my ($ordered_fasta_files, $ga_lookup, $tree_string, $ordered_fasta_headers) = $self->init_files($dump_dir, $original_gat);
    my ($var_ordered_fasta_files, $var_tree_string, $var_ordered_fasta_headers) = $self->init_variant_files($dump_dir, $variant_seq, $ordered_fasta_files, $ordered_fasta_headers, $ga_lookup, $ref_ga, $tree_string);
    
    #Run ortheus and parse output 
    my ($modified_gat, $modified_score) = $self->run_ortheus($compara_dba, $dump_dir, $var_ordered_fasta_files, $var_ordered_fasta_headers, $ga_lookup, $var_tree_string, $mlss, $ref_ga, $left, $allele_end, $verbose);

    #Check that ortheus ran OK and returned a tree
    return unless ($modified_gat);

    #Convert the alternative GenomicAlignTree to a set of annotated alignments
    my $alt_alignments = convert_gat_to_alignment($modified_gat, $modified_score, "MODIFIED");
    $alt_alignments = call_ancestral_allele($modified_gat->reference_genomic_align_node, $alt_alignments, "MODIFIED", $verbose);

    my $ref_alignment = $ref_alignments->{"REFERENCE"};
    my $alt_alignment = $alt_alignments->{"MODIFIED"};

    #Create verbose 'event'
    my $event = annotate_alignments($indel_type, $allele_seq, $ref_alignment, $alt_alignment, $reference_gat);
    
    my ($ref_strict_ancestral_allele, $ref_flank_ancestral_allele) = get_ancestral_allele_calls($ref_alignment);
    my ($alt_strict_ancestral_allele, $alt_flank_ancestral_allele) = get_ancestral_allele_calls($alt_alignment);
    print_report($ref_alignment, $alt_alignment, $ref_strict_ancestral_allele, $ref_flank_ancestral_allele, $alt_strict_ancestral_allele, $alt_flank_ancestral_allele, $allele_seq, $verbose) if ($verbose);

    $event = check_ortheus_calls($indel_type, $event, $ref_alignment,$alt_alignment,$ref_flank_ancestral_allele,$alt_flank_ancestral_allele);

    if ($ref_alignment->{alignment}->[0]->{strict_center} !~ /^[$allele_seq\-]*$/ or
        ($alt_alignment->{alignment}->[0]->{strict_center} !~ /^[$allele_seq-]*$/)) {
        print OUT "Error in indel: $indel_type $allele_seq -- ".$ref_alignment->{alignment}->[0]->{strict_center}, "\n" if ($verbose);
        next;
    }
    
    my $allele_string = $ref_alignment->{alignment}->[0]->{flank_center}."/".$ref_flank_ancestral_allele.":".
      $alt_alignment->{alignment}->[0]->{flank_center}."/".$alt_flank_ancestral_allele;

#    if ($event =~ /unsure/) {
#        resolve_unsure($event, $alt_alignment->{alignment}->[0]->{flank_center}, $alt_flank_ancestral_allele);
#    }

    print OUT $allele_string, "\n" if ($verbose);

    #output chr start end ref alt anc

    #Remove gaps and then check if these are empty and set to "-" if they are.
    my $ref_flank_allele = $ref_alignment->{alignment}->[0]->{flank_center};
    $ref_flank_allele =~ tr/-_ //d;
    if ($ref_flank_allele eq "") {
        $ref_flank_allele = "-";
    }
    my $alt_flank_allele = $alt_alignment->{alignment}->[0]->{flank_center};
    $alt_flank_allele =~ tr/-_ //d;
    if ($alt_flank_allele eq "") {
        $alt_flank_allele = "-";
    }

    $ref_flank_ancestral_allele =~ tr/-_ //d;
    if ($ref_flank_ancestral_allele eq "") {
        $ref_flank_ancestral_allele = "-";
    }

    $alt_flank_ancestral_allele =~ tr/-_ //d;
    if ($alt_flank_ancestral_allele eq "") {
        $alt_flank_ancestral_allele = "-";
    }

    #Need to convert verbose event into simple tags defined in hash %event_type
    my ($indel, $type, $detail, $detail1, $improve, $detail2) = $event =~ /(insertion|deletion)_(novel|recovery|unsure)_(of_allele_base|strict|shuffle|realign|neighbouring_deletion|neighbouring_insertion|complex)_{0,1}(strict1|shuffle1){0,1}_{0,1}(better|worse){0,1}_{0,1}(polymorphic_insertion|polymorphic_deletion|complex_polymorphic_insertion|complex_polymorphic_deletion|funny_polymorphic_insertion|funny_polymorphic_deletion){0,1}/;
    
    my $simple_event = get_simple_event($indel, $type, $detail1, $detail2);

    #decide which ancestral allele is best to use (RAnc or AAnc)
    my $ancestral_allele = $self->get_ancestral_allele($indel, $type, $ref_flank_allele, $alt_flank_allele, $ref_flank_ancestral_allele, $alt_flank_ancestral_allele);

    if ($verbose_vep) {

        #tab-delimited
        #Ref: reference allele (realigned sequence, no changes ie insertions, deletions)
        #Alt: alternative allele (with changes ie insertions, deletions)
        #RAnc:ancestral sequence on the reference alignment
        #AAnc: ancestral sequence on the alternative alignment (with changes)
        print VEP "$seq_region\t$allele_end\t$allele_seq\t$event\t" . $ref_flank_allele . "\t" . $alt_flank_allele . "\t" . $ref_flank_ancestral_allele . "\t" . $alt_flank_ancestral_allele . "\n";

    } else {

        my $event_flag = $event_type{$simple_event};

        my ($ind) = $indel =~ /(.)/;

        $vep_line = "$allele_seq\t$ind\t$event_flag\t$ref_flank_allele\t$alt_flank_allele\t$ancestral_allele;";

    }

    print OUT "$seq_region $allele_start $allele_end $allele_seq $event " . $ref_flank_allele . " " . $alt_flank_allele . " " . $ref_flank_ancestral_allele . " " . $alt_flank_ancestral_allele . "\n" if ($verbose);
    print OUT "TYPE $event\n" if ($verbose);
    print OUT "FINAL CALL: Type=$simple_event Ref=$ref_flank_allele Alt=$alt_flank_allele Anc=$ancestral_allele\n" if ($verbose);
    
    $output->{sum_calls}->{$simple_event}++;
    $output->{sum_types}->{$event}++;

    $modified_gat->release_tree;

    #Delete all fasta files
    tidy_up_fasta_files($ordered_fasta_files);
    tidy_up_fasta_files($var_ordered_fasta_files);

    return $vep_line;
}

#
#Extract the set of alignments from a GenomicAlignTree object
#
sub convert_gat_to_alignment {
    my ($gat, $score, $mode) = @_;

    my $alignments;
    foreach my $this_node (@{$gat->get_all_sorted_genomic_align_nodes()}) {
	foreach my $genomic_align (@{$this_node->get_all_genomic_aligns_for_node}) {
	    next if ( $genomic_align->genome_db->name eq "ancestral_sequences");
            my $align;
            $align->{aligned_sequence} = $genomic_align->aligned_sequence;
            $align->{species} = $genomic_align->genome_db->name;

            push @{$alignments->{$mode}->{alignment}}, $align;
	}
    }
    $alignments->{$mode}->{score} = $score;
    return $alignments;
}

#
#Print out GenomicAlignTree object
#
sub print_gat {
    my ($gat, $verbose) = @_;
    
    foreach my $this_node (@{$gat->get_all_sorted_genomic_align_nodes()}) {
	foreach my $genomic_align (@{$this_node->get_all_genomic_aligns_for_node}) {
	    next if ( $genomic_align->genome_db->name eq "ancestral_sequences");
	    print OUT "   " . $genomic_align->aligned_sequence . " " . $genomic_align->genome_db->name . "\t" . $genomic_align->dnafrag->name . " " . $genomic_align->dnafrag_start . " " . $genomic_align->dnafrag_end . " " . $genomic_align->dnafrag_strand . " " . $genomic_align->cigar_line . "\n" if ($verbose);
	}
    }
}

#
#Create files ready for running with Ortheus
#
sub init_files {
    my ($self, $dump_dir, $gat) = @_;

    #Run dump_fasta first, to rename tree nodes. Create lookup between node name and genomic_align
    my $ga_lookup;
    ($gat, $ga_lookup) = change_node_names($gat);

    my $tree_string = $gat->newick_format('simple');

    #substitute any 0 branch lengths with something very small because ortheus doesn't like 0
    $tree_string =~ s/:0([,);)])/:0.000001$1/g;
    #print "gat_tree_string=$tree_string\n";
    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($tree_string);
    #Write fasta files and return array of fasta_files in the same order as the tree_string.
    my ($ordered_fasta_files, $ordered_fasta_headers) = $self->dump_fasta ($tree, $ga_lookup, $dump_dir);

    return ($ordered_fasta_files, $ga_lookup, $tree_string, $ordered_fasta_headers);
}

#
#Create variant files ready for running with Ortheus
#
sub init_variant_files {
    my ($self, $dump_dir, $variant_seq, $ordered_fasta_files, $ordered_fasta_headers, $ga_lookup, $ref_ga, $tree_string) = @_;

    #Make copy of $ordered_fasta_files
    my $var_ordered_fasta_files;
    my $var_ordered_fasta_headers;
    @$var_ordered_fasta_files = @$ordered_fasta_files;
    @$var_ordered_fasta_headers = @$ordered_fasta_headers;
    my $var_tree_string = $tree_string;

    my $num_seqs = (keys %$ga_lookup);
    my $var_seq_id = $num_seqs + 1;

    foreach my $seq_id (keys %$ga_lookup) {
	my $ga = $ga_lookup->{$seq_id}{ga};
	my $idx = $ga_lookup->{$seq_id}{idx};
	if ($ref_ga == $ga) {

	    #Need to set dnafrag_end of variant genomic_align. Only use dnafrag_start, dnafrag_end and dnafrag_strand in parse_results
	    my $var_ga = $ref_ga;
	    $var_ga->dnafrag_end($ref_ga->dnafrag_start + (length $variant_seq) - 1);

	    my $file = $dump_dir . "/kb3_var" . $seq_id . ".fa";
	    $ga_lookup->{$var_seq_id}{ga} = $var_ga;
	    $ga_lookup->{$var_seq_id}{idx} = $idx;
	    $var_tree_string =~ s/$seq_id:/$var_seq_id:/;
	    my $header = $self->write_fasta($file, $var_seq_id, $variant_seq);

	    $var_ordered_fasta_files->[$idx] = $file;
	    $var_ordered_fasta_headers->[$idx] = $header;
	} else {
	}
    }

    return ($var_ordered_fasta_files, $var_tree_string, $var_ordered_fasta_headers);
}

#
#Create lookup between node name and genomic_align
#
sub change_node_names {
    my ($gat) = @_;

    my $seq_id = 1;
    my $ga_lookup;

    #Must send the fasta_files in the same order as the tree_string but I need to change the node names 

    foreach my $this_node (@{$gat->get_all_nodes()}) {
	my $genomic_align_group = $this_node->genomic_align_group;
	next if (!$genomic_align_group);
	foreach my $genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
	    next if ($genomic_align->genome_db->name eq "ancestral_sequences");
	    #print "   " . $genomic_align->aligned_sequence . " " . $genomic_align->genome_db->name . "\t" . $genomic_align->dnafrag->name . " " . $genomic_align->dnafrag_start . " " . $genomic_align->dnafrag_end . " " . $genomic_align->dnafrag_strand . " " . $genomic_align->cigar_line . " seq_id $seq_id\n";
	    
	    #print "   " . $genomic_align->genome_db->name . " "  . $genomic_align->dnafrag->name . " " . $genomic_align->dnafrag_start . " " . $genomic_align->dnafrag_end . "\n";

	    #Change the name of the leaf in the tree
	    $this_node->name($seq_id);

	    #remove padding (- or .)
	    my $seq = $genomic_align->aligned_sequence;
	    $seq =~ s/[-\.]//g;

	    #Check still have some sequence left
	    unless (length $seq) {
		$seq_id++;
		next;
	    }
	    $ga_lookup->{$seq_id}{ga} = $genomic_align; #seq_id has to start at 1 so use hash instead of an array
	    $seq_id++;
	}
    }

    return ($gat, $ga_lookup);
}

#
# Dump FASTA files in the order given by the tree string (needed by Pecan)
#
sub dump_fasta {
    my ($self, $tree, $ga_lookup, $dump_dir) = @_;

    my $fasta_headers;
    my $fasta_files;
    my $all_leaves = $tree->get_all_leaves;

    my $idx = 0;
    foreach my $this_leaf (@$all_leaves) {
	#print OUT "  leaf_name " . $this_leaf->name . "\t";

	my $seq_id = $this_leaf->name;
	my $genomic_align = $ga_lookup->{$seq_id}{ga};
	#remove padding (- or .)
	my $seq = $genomic_align->aligned_sequence;
	$seq =~ s/[-\.]//g;
	
	#Check still have some sequence left
	unless (length $seq) {
	    $seq_id++;
	    next;
	}
	$ga_lookup->{$seq_id}{idx} = $idx;

	my $file = $dump_dir . "/kb3_seq" . $seq_id . ".fa";

	my $header = $self->write_fasta($file, $seq_id, $seq);
        push @$fasta_headers, $header;
	push @$fasta_files, $file;
	$idx++;

    }

    return ($fasta_files, $fasta_headers);
}

#
#Write fasta file
#
sub write_fasta {
    my ($self, $file, $seq_id, $seq) = @_;

    my $header = ">SeqID" . $seq_id;
    $self->_spurt($file, "$header\n$seq\n");

    return $header;
}

#
#Parse output of Ortheus command
#
sub parse_results {
    my ($self, $compara_dba, $dump_dir, $ga_lookup, $ordered_fasta_files, $tree_string, $ordered_fasta_headers, $verbose) = @_;
    my $debug = 0;

    my $alignment_file = $dump_dir . "/output.$$.mfa";
    my $score_file = $dump_dir . "/output.$$.score";

    my $score;
    open (SCORE, $score_file);
    $score = (<SCORE>);
    close SCORE;

    print OUT "score $score\n" if ($verbose);

    my $tree_file;
    my $fasta_files;

    #if haven't provided ortheus with a tree_string, then read in the tree produced by ortheus
    if ($tree_file && -e $tree_file) {
	## Ortheus estimated the tree. Overwrite the order of the fasta files and get the tree
	open(F, $tree_file) || throw("Could not open tree file <$tree_file>");
	my ($newick, $files) = <F>;
	close(F);
	$newick =~ s/[\r\n]+$//;
	$tree_string = $newick;
	$files =~ s/[\r\n]+$//;

	my $all_files = [split(" ", $files)];
	
	#store ordered fasta_files
	$ordered_fasta_files = $all_files;
	$fasta_files = @$all_files;
	#print STDOUT "**NEWICK: $newick\nFILES: ", join(" -- ", @$all_files), "\n";
    }

    my (@ordered_leaves) = $tree_string =~ /[(,]([^(:)]+)/g;

    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock;

    open(F, $alignment_file) || throw("Could not open $alignment_file");
    my $seq = "";
    my $this_genomic_align;

    #Create genomic_align_group object to store genomic_aligns for
    #each node. 
    my $genomic_align_group;

    #print "tree_string=$tree_string\n";

    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($tree_string, "Bio::EnsEMBL::Compara::GenomicAlignTree");

    print "Reading $alignment_file...\n" if ($debug);
    my $ids;
    foreach my $this_header (@$ordered_fasta_headers) {
	push(@$ids, $this_header);
	push(@$ids, undef); ## There is an internal node after each leaf..
    }
    pop(@$ids); ## ...except for the last leaf which is the end of the tree

    my %tree_nodes;

    foreach my $node (@{$tree->get_all_leaves}) {
        $tree_nodes{$node->name} = $node;
    }

    while (<F>) {
	next if (/^\s*$/);
	chomp;
	## FASTA headers correspond to the tree and the order of the leaves in the tree corresponds
	## to the order of the files
	
	if (/^>/) {
	    print "PARSING $_\n" if ($debug);
	    print $tree->newick_format(), "\n" if ($debug);
	    my ($name) = $_ =~ /^>(.+)/;
	    if (defined($this_genomic_align) and  $seq) {
		print "add aligned_sequence " . $this_genomic_align->dnafrag_id . " " . $this_genomic_align->dnafrag_start . " " . $this_genomic_align->dnafrag_end . "\n" if $debug;
		$this_genomic_align->aligned_sequence($seq);
		$this_genomic_align_block->add_GenomicAlign($this_genomic_align);
	    }
	    my $header = shift(@$ids);
	    $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
	    
	    if (!defined($header)) {
		print "INTERNAL NODE $name\n" if ($debug);
		my $this_node;
		foreach my $this_leaf_name (split("_", $name)) {
		    if ($this_node) {
			#my $other_node = $tree->find_node_by_name($this_leaf_name);
                        my $other_node = $tree_nodes{$this_leaf_name};
			if (!$other_node) {
			    throw("Cannot find node <$this_leaf_name>\n");
			}
			$this_node = $this_node->find_first_shared_ancestor($other_node);
		    } else {
			print  $tree->newick_format() if ($debug);
			print "LEAF: $this_leaf_name\n" if ($debug);
			#$this_node = $tree->find_node_by_name($this_leaf_name);
                        $this_node = $tree_nodes{$this_leaf_name};
		    }
		}

		print join("_", map {$_->name} @{$this_node->get_all_leaves}), "\n" if ($debug);
		## INTERNAL NODE: dnafrag_id and dnafrag_end must be edited somewhere else

		#print "name $name\n";
		$this_genomic_align->dnafrag_id(-1);
		$this_genomic_align->dnafrag_start(1);
		$this_genomic_align->dnafrag_end(0);
		$this_genomic_align->dnafrag_strand(1);

		$genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
		$genomic_align_group->add_GenomicAlign($this_genomic_align);

		$this_node->genomic_align_group($genomic_align_group);
		$this_node->name($name);
	    } elsif ($header =~ /^>SeqID(\d+)/) {
		#print "old $name\n";
		print "leaf_name?? $name\n" if ($debug);
                my $this_leaf = $tree_nodes{$name};

		if (!$this_leaf) {
		    print $tree->newick_format(), " ****\n" if ($debug);
		    die "Unable to find_node_by_name $name";
		}
		
		#information extracted from fasta header
		my $seq_id = ($1);

		#print "normal dnafrag_id " . $dfr->dnafrag_id . "\n" if $self->debug;
		my $ga = $ga_lookup->{$seq_id}{ga};

		$this_genomic_align->dnafrag($ga->dnafrag);
		$this_genomic_align->dnafrag_id($ga->dnafrag_id);
		$this_genomic_align->dnafrag_start($ga->dnafrag_start);
		$this_genomic_align->dnafrag_end($ga->dnafrag_end);
		$this_genomic_align->dnafrag_strand($ga->dnafrag_strand);
		
		$genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
		$genomic_align_group->add_GenomicAlign($this_genomic_align);
		
		$this_leaf->genomic_align_group($genomic_align_group);
		print "store gag2 $this_leaf\n" if $debug;

	    } else {
		throw("Error while parsing the FASTA header. It must start by \">DnaFrag#####\" where ##### is the dnafrag_id\n$_");
	    }
	    $seq = "";
	} else {
	    $seq .= $_;
	}
    }
    close F;

    #last genomic_align
    print "Last genomic align\n" if ($debug);
    if ($this_genomic_align->dnafrag_id == -1) {
    } else {
	$this_genomic_align->aligned_sequence($seq);
	$this_genomic_align_block->add_GenomicAlign($this_genomic_align);
    }

    return ($tree, $score);
}

#
#Taken for Ortheus _write_output
#
sub finalise_tree {
    my ($self, $compara_dba, $genomic_align_tree, $mlss, $ref_ga) = @_;

    my $ancestor_genome_db = $self->param('ancestor_genome_db');

    foreach my $genomic_align_node (@{$genomic_align_tree->get_all_nodes}) {
	foreach my $genomic_align (@{$genomic_align_node->genomic_align_group->get_all_GenomicAligns}) {
	    if ($genomic_align->dnafrag_id == -1) {
		my $length = length($genomic_align->original_sequence);
    
		my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
								 -name => "Ancestor",
								 -genome_db => $ancestor_genome_db,
								 -length => $length,
								 -coord_system_name => "ancestralsegment");
		
		$genomic_align->dnafrag($dnafrag);
	    } else {
		if ($ref_ga->dnafrag_id == $genomic_align->dnafrag_id &&
		    $ref_ga->dnafrag_start == $genomic_align->dnafrag_start &&
		    $ref_ga->dnafrag_end == $genomic_align->dnafrag_end) {
		    
			$genomic_align_tree->reference_genomic_align($genomic_align);
			$genomic_align_tree->reference_genomic_align_node($genomic_align_node);
		    }
	    }
	    #print "finalise tree genomic_align " . $genomic_align->genome_db->name . " " . $genomic_align->dnafrag_id . " " . $genomic_align->dnafrag_start . " " . $genomic_align->dnafrag_end . " " . $genomic_align->original_sequence . " " . $genomic_align->aligned_sequence . " " . $genomic_align->cigar_line . "\n";
	}
    }
    
    return $genomic_align_tree;

}

#
#Remove fasta files
#
sub tidy_up_fasta_files {
    my ($fasta_files) = @_;

    foreach my $fasta_file (@$fasta_files) {
	#print "deleting $fasta_file\n";
	next if (!-e $fasta_file);
	unlink $fasta_file;
    }
}

#
#Tidy up ortheus files
#
sub tidy_up_files {
    my ($self, $dump_dir) = @_;
    
    my $alignment_file = $dump_dir . "/output.$$.mfa";
    #print "deleting $alignment_file\n";
    unlink $alignment_file;

    my $score_file = $dump_dir . "/output.$$.score";
    #print "deleting $score_file\n";
    unlink $score_file;

    my $tree_file = $dump_dir . "/output.$$.tree";
    #print "deleting $tree_file\n";
    unlink $tree_file;

}

#
# Create the alternative sequence 
#
sub  get_variant_sequence {
    my ($indel_type, $slice, $slice_start, $slice_end, $allele_seq, $allele_start, $allele_end) = @_;

    my @ref_seq = split //, $slice->seq;
    my $variant_seq;

    for (my $i = $slice_start, my $j=0; $i <= $slice_end; $i++,$j++) {
        if ($indel_type eq "insertion") {
            #include insertion after allele_start
            $variant_seq .= $ref_seq[$j];
            if ($i == $allele_start) {
                $variant_seq .= $allele_seq;
            }
        } elsif ($indel_type eq "deletion") {
            #skip bases between allele_start and allele_end inclusive
            if ($i >= $allele_start && $i <= $allele_end) {
                next;
            } else {
                $variant_seq .= $ref_seq[$j];
            }
        }
    }
    return $variant_seq;
}

#Write a string highlighting the position of the insertion
sub get_highlighter {
    my ($self, $genomic_align, $flank) = @_;

    my $mapper = $genomic_align->get_Mapper;
    #position of insert (flank+1)
    my @coords = $mapper->map_coordinates("sequence",
					   $genomic_align->dnafrag_start+$flank+1,
					   $genomic_align->dnafrag_start+$flank+1,
					   1,
					   "sequence");
    #number of spaces of flanking region (insert-1)
    my $spaces = " " x ($coords[0]->start - 1);

    #insert position
    $spaces .= "*";
    return $spaces;
}

#
# Return true if only have 2 different bases in $seq
#
sub check_for_low_complexity {
    my ($seq) = @_;

    #print OUT "seq $seq\t" if ($verbose);

    my $num_diff_bases;
    my $num_base = count_bases($seq);
    foreach my $base (keys %$num_base) {
	#print OUT "$base=" . $num_base->{$base} . "\t" if ($verbose);
	$num_diff_bases++ if ($num_base->{$base});
    }
    #print OUT "\n" if ($verbose);
    if ($num_diff_bases < 3) {
	return 1;
    } else {
	return 0;
    }

}

#
#Count the number of each base in seq
#
sub count_bases {
    my ($seq) = @_;
    my $num_base;

    $num_base->{A} = $seq =~ tr/Aa/Aa/;
    $num_base->{C} = $seq =~ tr/Cc/Cc/;
    $num_base->{G} = $seq =~ tr/Gg/Gg/;
    $num_base->{T} = $seq =~ tr/Tt/Tt/;
    $num_base->{N} = $seq =~ tr/Nn/Nn/;

    return $num_base;
}

#
#Annotate a set of alignments with ancestral information
#
sub call_ancestral_allele {
    my ($ref_gat, $alignments, $mode, $verbose, $start, $end, $len_allele_seq) = @_;

    ## Reference, ancestral, sister and older (grandpa) sequences
    my $ref_aligned_sequence = $ref_gat->aligned_sequence;
    my $ancestral_sequence = $ref_gat->parent->aligned_sequence;
    my $sister_sequence;
    foreach my $child (@{$ref_gat->parent->children}) {
        if ($child ne $ref_gat) {
            $sister_sequence = $child->aligned_sequence;
        }
    }
    my $older_sequence;
    if ($ref_gat->parent->parent) {
        $older_sequence = $ref_gat->parent->parent->aligned_sequence;
    }

    #Leave this bit for now since there are difficulties with DELETIONS so print out the whole sequence
   #substr offset starts at 0
   # print "ref " . substr($ref_aligned_sequence, ($start-1), $len_allele_seq) . "\n";
   # print "anc " . substr($ancestral_sequence, ($start-1), $len_allele_seq) . "\n";
   # print "sis " . substr($sister_sequence, ($start-1), $len_allele_seq) . "\n";
   # print "old " . substr($older_sequence, ($start-1), $len_allele_seq) . "\n";

    #print OUT "refer $ref_aligned_sequence\n" if ($verbose);
    #print OUT "ances $ancestral_sequence\n" if ($verbose);
    #print OUT "siste $sister_sequence\n" if ($verbose);
    #print OUT "older $older_sequence\n" if ($verbose);

    my $seq_len = length $ref_aligned_sequence;

    my $score_sequence;
    ## Scoring scheme
    for (my $i = 0; $i < $seq_len; $i++) {
        my $ancestral_seq = substr($ancestral_sequence, $i, 1);
        my $sister_seq = substr($sister_sequence, $i, 1);
        
        # Score the consensus. A lower score means a better consensus
        my $score = 0;
        if (!$older_sequence or substr($older_sequence, $i, 1) ne $ancestral_seq) {
            $score++;
        }
        if ($sister_seq ne $ancestral_seq) {
            $score++;
        }
        # Change the ancestral allele according to the score:
        # - score == 0 -> do nothing (uppercase)
        # - score == 1 -> change to lowercase
        # - score > 1 -> change to N
        if ($score == 1) {
            $ancestral_seq = lc($ancestral_seq);
            $ancestral_seq = "_" if ($ancestral_seq eq "-"); #change "-" to "_"
        } elsif ($score > 1) {
            $ancestral_seq = "N";
        }
        $score_sequence .= $ancestral_seq;
    }

    #get allele for original_gat
    if (!$alignments) {
        #print "final $score_sequence\n";

        #find $start bases into original aligned sequence
        my ($left) = $ref_aligned_sequence =~ /^(\-*(\w\-*){$start}\w)/;

        #find in align coords the last base of left
        my $pos = length($left);

        #use this as an index into the score_sequence
        return substr $score_sequence, ($pos-1), 1;
    }

    $alignments->{$mode}->{refer}->{aligned_sequence} = $ref_aligned_sequence;
    $alignments->{$mode}->{refer}->{species} = "-REFERENCE-";
    $alignments->{$mode}->{ances}->{aligned_sequence} = $ancestral_sequence;
    $alignments->{$mode}->{ances}->{species} = "-ANCESTRAL-";
    $alignments->{$mode}->{siste}->{aligned_sequence} = $sister_sequence;
    $alignments->{$mode}->{siste}->{species} = "-SISTER-";
    $alignments->{$mode}->{older}->{aligned_sequence} = $older_sequence;
    $alignments->{$mode}->{older}->{species} = "-OLDER-";
    $alignments->{$mode}->{final}->{aligned_sequence} = $score_sequence;
    $alignments->{$mode}->{final}->{species} = "-FINAL-";

    return $alignments;
}

#
#Determine a verbose 'event' by comparing the original alignment and the alternative alignment
#
sub annotate_alignments {
  my ($indel_type, $indel_nucleotide, $orig_ref_alignment, $orig_alt_alignment, $reference_gat) = @_;

  my $ref_alignment_score = $orig_ref_alignment->{score};
  my $alt_alignment_score = $orig_alt_alignment->{score};

  get_sub_alignments($orig_ref_alignment, $indel_nucleotide, $indel_type, 0);
  get_sub_alignments($orig_alt_alignment, $indel_nucleotide, $indel_type, 1);

  $orig_ref_alignment = $orig_ref_alignment->{alignment};
  $orig_alt_alignment = $orig_alt_alignment->{alignment};

  #Sequences that are entirely N can cause problems if they contain a pad which can 
  #then move around freely between the ref and alt alignment and can affect the results.
  #Try removing such sequences from the alignments

  my $ref_alignment;
  my $alt_alignment;
  for (my $i = 0; $i < @{$orig_ref_alignment}; $i++) {
      my $n_cnt = ($orig_ref_alignment->[$i]->{aligned_sequence} =~ tr/Nn-/Nn-/);
      if ($n_cnt == length($orig_ref_alignment->[$i]->{aligned_sequence})) {
          #print STDERR "Sequence for " . $orig_ref_alignment->[$i]->{species} . " is all N or -. Ignore in annotation analysis\n"; 
      } else {
          push @$ref_alignment, $orig_ref_alignment->[$i];
          push @$alt_alignment, $orig_alt_alignment->[$i];
      }
  }

  my $ref_main_alignment = $ref_alignment->[0]->{aligned_sequence};
  my $alt_main_alignment = $alt_alignment->[0]->{aligned_sequence};

  my $have_all_strict_sequences_changed = 0;
  my $have_nonref_strict_sequences_changed = 0;
  if ($ref_alignment->[0]->{strict_right} ne $alt_alignment->[0]->{strict_right} or
      $ref_alignment->[0]->{strict_left} ne $alt_alignment->[0]->{strict_left}) {
    $have_all_strict_sequences_changed = 1;
  }
  for (my $i = 1; $i < @{$ref_alignment}; $i++) {
    if ($ref_alignment->[$i]->{strict_right} ne $alt_alignment->[$i]->{strict_right} or
        $ref_alignment->[$i]->{strict_left} ne $alt_alignment->[$i]->{strict_left}) {
      $have_all_strict_sequences_changed = 1;
      $have_nonref_strict_sequences_changed = 1;
      last;
    }
  }

  my $have_all_flank_sequences_changed = 0;
  my $have_nonref_flank_sequences_changed = 0;
  if ($ref_alignment->[0]->{flank_right} ne $alt_alignment->[0]->{flank_right} or
      $ref_alignment->[0]->{flank_left} ne $alt_alignment->[0]->{flank_left}) {
    $have_all_flank_sequences_changed = 1;
  }
  for (my $i = 1; $i < @{$ref_alignment}; $i++) {
    if ($ref_alignment->[$i]->{flank_right} ne $alt_alignment->[$i]->{flank_right} or
        $ref_alignment->[$i]->{flank_left} ne $alt_alignment->[$i]->{flank_left}) {
      $have_all_flank_sequences_changed = 1;
      $have_nonref_flank_sequences_changed = 1;
      last;
    }
  }

  #Check the lengths of the strict flanking regions between the REF and ALT alignments
  my $have_any_strict_flank_lengths_changed = 0;
  for (my $i = 0; $i < @{$ref_alignment}; $i++) {
    if (length($ref_alignment->[$i]->{strict_right}) != length($alt_alignment->[$i]->{strict_right}) or
        length($ref_alignment->[$i]->{strict_left}) != length($alt_alignment->[$i]->{strict_left})) {
        $have_any_strict_flank_lengths_changed = 1;
        last;
    }
  }
  #print "have_any_strict_flank_lengths_changed $have_any_strict_flank_lengths_changed\n";

  #Check the lengths of the flank flanking regions between the REF and ALT alignments
  my $have_any_flank_flank_lengths_changed = 0;
  for (my $i = 0; $i < @{$ref_alignment}; $i++) {
    if (length($ref_alignment->[$i]->{flank_right}) != length($alt_alignment->[$i]->{flank_right}) or
        length($ref_alignment->[$i]->{flank_left}) != length($alt_alignment->[$i]->{flank_left})) {
        $have_any_flank_flank_lengths_changed = 1;
        last;
    }
  }
  #print "have_any_flank_flank_lengths_changed $have_any_flank_flank_lengths_changed\n";

  #Check the number of bases of the strict flanking regions between the REF and ALT alignments
  my $have_any_strict_flank_num_bases_changed = 0;
  for (my $i = 0; $i < @{$ref_alignment}; $i++) {
      my ($num_bases_ref_right) = $ref_alignment->[$i]->{strict_right} =~ tr/ACGTNacgtn/ACGTNacgtn/;
      my ($num_bases_alt_right) = $alt_alignment->[$i]->{strict_right} =~ tr/ACGTNacgtn/ACGTNacgtn/;
      my ($num_bases_ref_left) = $ref_alignment->[$i]->{strict_left} =~ tr/ACGTNacgtn/ACGTNacgtn/;
      my ($num_bases_alt_left) = $alt_alignment->[$i]->{strict_left} =~ tr/ACGTNacgtn/ACGTNacgtn/;

      if (($num_bases_ref_right != $num_bases_alt_right) || ($num_bases_ref_left != $num_bases_alt_left)) {
          $have_any_strict_flank_num_bases_changed = 1;
      }
  }
#  print "have_any_strict_flank_num_bases_changed $have_any_strict_flank_num_bases_changed\n";

  my $have_any_flank_flank_num_bases_changed = 0;
  for (my $i = 0; $i < @{$ref_alignment}; $i++) {
      my ($num_bases_ref_right) = $ref_alignment->[$i]->{flank_right} =~ tr/ACGTNacgtn/ACGTNacgtn/;
      my ($num_bases_alt_right) = $alt_alignment->[$i]->{flank_right} =~ tr/ACGTNacgtn/ACGTNacgtn/;
      my ($num_bases_ref_left) = $ref_alignment->[$i]->{flank_left} =~ tr/ACGTNacgtn/ACGTNacgtn/;
      my ($num_bases_alt_left) = $alt_alignment->[$i]->{flank_left} =~ tr/ACGTNacgtn/ACGTNacgtn/;

      if (($num_bases_ref_right != $num_bases_alt_right) || ($num_bases_ref_left != $num_bases_alt_left)) {
          $have_any_flank_flank_num_bases_changed = 1;
      }
  }
#  print "have_any_flank_flank_num_bases_changed $have_any_flank_flank_num_bases_changed\n";

  #Check base nearest the "center" of each flank ie rhs for left flank, lhs for right flank
  my $have_any_strict_neighbour_center_bases_changed = 0;
  for (my $i = 0; $i< @{$ref_alignment}; $i++) {
      #print "REF LEFT " . $ref_alignment->[$i]->{strict_left} . " " . substr($ref_alignment->[$i]->{strict_left}, -1, 1) . "\n";
      #print "REF RIGHT " . $ref_alignment->[$i]->{strict_right} . " " . substr($ref_alignment->[$i]->{strict_right}, 0, 1) . "\n";

      #print "ALT LEFT " . $alt_alignment->[$i]->{strict_left} . " " . substr($alt_alignment->[$i]->{strict_left}, -1, 1) . "\n";
      #print "ALT RIGHT " . $alt_alignment->[$i]->{strict_right} . " " . substr($alt_alignment->[$i]->{strict_right}, 0, 1) . "\n";

      if (substr($ref_alignment->[$i]->{strict_left}, -1, 1) ne "-" && 
          substr($ref_alignment->[$i]->{strict_left}, -1, 1) ne substr($alt_alignment->[$i]->{strict_left}, -1, 1) || 
          substr($ref_alignment->[$i]->{strict_right}, 0, 1) ne "-" && 
          substr($ref_alignment->[$i]->{strict_right}, 0, 1) ne substr($alt_alignment->[$i]->{strict_right}, 0, 1)) {
          $have_any_strict_neighbour_center_bases_changed = 1;
        last;
      }
  }
  #print "have_any_strict_neighbour_center_bases_changed $have_any_strict_neighbour_center_bases_changed\n";

  #Check base nearest the "center" of each flank ie rhs for left flank, lhs for right flank for the "flank" regions!
  my $have_any_flank_neighbour_center_bases_changed = 0;
  for (my $i = 0; $i< @{$ref_alignment}; $i++) {
      #print "REF LEFT " . $ref_alignment->[$i]->{flank_left} . " " . substr($ref_alignment->[$i]->{flank_left}, -1, 1) . "\n";
      #print "REF RIGHT " . $ref_alignment->[$i]->{flank_right} . " " . substr($ref_alignment->[$i]->{flank_right}, 0, 1) . "\n";

      #print "ALT LEFT " . $alt_alignment->[$i]->{flank_left} . " " . substr($alt_alignment->[$i]->{flank_left}, -1, 1) . "\n";
      #print "ALT RIGHT " . $alt_alignment->[$i]->{flank_right} . " " . substr($alt_alignment->[$i]->{flank_right}, 0, 1) . "\n";

      if (substr($ref_alignment->[$i]->{flank_left}, -1, 1) ne "-" && 
          substr($ref_alignment->[$i]->{flank_left}, -1, 1) ne substr($alt_alignment->[$i]->{flank_left}, -1, 1) || 
          substr($ref_alignment->[$i]->{flank_right}, 0, 1) ne "-" && 
          substr($ref_alignment->[$i]->{flank_right}, 0, 1) ne substr($alt_alignment->[$i]->{flank_right}, 0, 1)) {
          $have_any_flank_neighbour_center_bases_changed = 1;
        last;
      }
  }
  #print "have_any_flank_neighbour_center_bases_changed $have_any_flank_neighbour_center_bases_changed\n";

  #Check if all the REF alignment contains no gaps (for insertions this must be an insertion_novel case - useful to annotate insertion_novel_complex (previously unsure) cases)
  
  my $has_ref_alignment_got_any_gaps = 0;
  for (my $i = 0; $i< @{$ref_alignment}; $i++) {
      ($has_ref_alignment_got_any_gaps) = $ref_alignment->[$i]->{aligned_sequence} =~ tr/-/-/;
      last if ($has_ref_alignment_got_any_gaps);
  }
  #print "has_ref_alignment_got_any_gaps $has_ref_alignment_got_any_gaps\n";

  #Check for neighbouring deletion in the REF alignment
  my $have_no_neighbouring_deletion = CheckForNeighbouringDeletion($reference_gat);
  #print "have_no_neighbouring_deletion $have_no_neighbouring_deletion\n";

  my $have_no_neighbouring_insertion = CheckForNeighbouringInsertion($reference_gat);
  #print "have_no_neighbouring_insertion $have_no_neighbouring_insertion\n";

  my $have_nonref_sequences_changed = 0;
  for (my $i = 1; $i < @{$ref_alignment}; $i++) {
    if ($ref_alignment->[$i]->{aligned_sequence} ne $alt_alignment->[$i]->{aligned_sequence}) {
      $have_nonref_sequences_changed = 1;
      last;
    }
  }

  my $is_strict_center_empty = length($alt_alignment->[0]->{strict_center})>0?0:1;

  my $is_flank_center_trivial = 1;
  for (my $i = 1; $i < @{$ref_alignment}; $i++) {
    if ($alt_alignment->[$i]->{flank_center} !~ /^[\-$indel_nucleotide]*$/) {
      $is_flank_center_trivial = 0;
      last;
    }
  }

  my $is_novel_deletion = 0;
  my $is_simple_variable_position = 0;
  if ($ref_alignment->[0]->{strict_center} eq $indel_nucleotide and $alt_alignment->[0]->{strict_center} eq "-") {
    $is_novel_deletion = 1;
    for (my $i = 1; $i < @{$ref_alignment}; $i++) {
      if ($ref_alignment->[$i]->{strict_center} ne "-" and $alt_alignment->[$i]->{strict_center} eq "-") {
        $is_simple_variable_position = 1;
      }
    }
  }

  my $has_flank_center_contracted = 0;
  if ($ref_alignment->[0]->{flank_center} !~ /\-/ and
      length($ref_alignment->[0]->{flank_center}) == length($alt_alignment->[0]->{flank_center})+1) {
    $has_flank_center_contracted = 1;
  }
  
  my $is_a_recovery = 0;
  for (my $pos = 0; $pos < length($ref_alignment->[0]->{flank_center}); $pos++) {
    if (substr($ref_alignment->[0]->{flank_center}, $pos, 1) eq $indel_nucleotide) {
      $is_a_recovery = 1;
      for (my $i = 1; $i < @{$ref_alignment}; $i++) {
        if (substr($ref_alignment->[$i]->{flank_center}, $pos, 1) ne "-") {
          $is_a_recovery = 0;
          last;
        }
      }
      last if ($is_a_recovery);
    }
  }
  

  my $is_a_novel_insertion = 0;
  for (my $pos = 0; $pos < length($alt_alignment->[0]->{flank_center}); $pos++) {
    if (substr($alt_alignment->[0]->{flank_center}, $pos, 1) eq $indel_nucleotide) {
      $is_a_novel_insertion = 1;
      for (my $i = 1; $i < @{$ref_alignment}; $i++) {
        if (substr($alt_alignment->[$i]->{flank_center}, $pos, 1) ne "-") {
          $is_a_novel_insertion = 0;
          last;
        }
      }
      last if ($is_a_novel_insertion);
    }
  }

  my $event = "N/A";

  # Write boolean flags. These have been used to define the rules in the next section of this sub-routine.
  $event =
      $have_all_strict_sequences_changed.     # 1. Look at left and right sequences after the strict restriction in all the sequences
      $have_nonref_strict_sequences_changed.  # 2. Look at left and right sequences after the strict restriction in non-ref sequences
      $have_all_flank_sequences_changed.      # 3. Look at left and right sequences after the tolerant restriction in all the sequences
      $have_nonref_flank_sequences_changed.   # 4. Look at left and right sequences after the tolerant restriction in non-ref sequences
      $have_nonref_sequences_changed.         # 5. Look at the entirety of the non-ref aligned sequences
      $is_strict_center_empty.                # 6. Is there any sequence left at the center after the strict restriction?
      $is_flank_center_trivial.               # 7. Check if the sequence left at the center after the tolerant restriction contains the same nucleotide or not
#      $is_novel_deletion.                     # 8. Undefined yet
#      $is_simple_variable_position.           # 9. 
      $has_flank_center_contracted.           # 9. 
#      $is_a_recovery.           # 9. 
      $is_a_novel_insertion.           # 9. 
      "";

  $event = ""; # Remove the flags

  if ($indel_type eq "deletion") {
    # This a deletion (trivial call)
    $event .= "deletion";
    if (!$have_nonref_sequences_changed) {
      # Only change is in the 'strict' center of the reference sequence
      $event .= "_novel";
    } elsif (!$have_nonref_strict_sequences_changed and $is_strict_center_empty) {
      # Other sequences have not changed outside of the strict center and it is left empty after remoding the indel
      $event .= "_recovery";
    } elsif (!$have_all_flank_sequences_changed and $has_flank_center_contracted) {
      # Other sequences have not changed outside of the strict center and it is left empty after remoding the indel
      $event .= "_recovery";
    } elsif ($is_a_recovery) {
      $event .= "_recovery";
    } else {
      $event .= "_unsure";
    }

    if (!$have_all_strict_sequences_changed and !$have_nonref_sequences_changed and !$is_strict_center_empty) {
      # 'Strict' center after removing indel is not empty
      $event .= "_of_allele_base";
    } elsif (!$have_all_strict_sequences_changed) {
      # Strict sequences have changed, but not the flanks. The alignment is shuffled in the 'tolerant' center
      $event .= "_strict";
    } elsif ($have_all_strict_sequences_changed and !$have_all_flank_sequences_changed) {
      # Strict sequences have changed, but not the flanks. The alignment is shuffled in the 'tolerant' center
      $event .= "_shuffle";
    } elsif (!$have_no_neighbouring_deletion) {
      $event .= "_neighbouring_deletion";
    } elsif (!$have_no_neighbouring_insertion) {
      $event .= "_neighbouring_insertion";
    } else {
      $event .= "_complex";
    }

    #taken straight from insertions. Need to check
    if (!$have_any_strict_flank_lengths_changed && !$have_any_strict_flank_num_bases_changed && !$have_any_strict_neighbour_center_bases_changed) {
        # Lengths of the "strict" flanks haven't changed and the base of the flanking region nearest the "center" does not change
        $event .= "_strict1";
    } elsif (!$have_any_flank_flank_lengths_changed && !$have_any_flank_flank_num_bases_changed && !$have_any_flank_neighbour_center_bases_changed) {
        # Lengths of the "strict" flanks haven't changed and the base of the flanking region nearest the "center" does not change
        $event .= "_shuffle1";
    }

  } elsif ($indel_type eq "insertion") {
    $event .= "insertion";
    if ($is_a_novel_insertion) {
      $event .= "_novel"; # OK
    } elsif (!$have_nonref_sequences_changed) {
      # Other sequences have not changed at all
      $event .= "_recovery"; # OK
    } elsif (!$has_ref_alignment_got_any_gaps) {
        #rescue some unsure cases by looking at the REF alignment. If this has no gaps, this must be a novel insertion
        $event .= "_novel";
    } else {
      $event .= "_unsure"; # OK (UNSURE/SHUFFLE_PAD)
    }

    #print OUT "strict=$have_all_strict_sequences_changed nonref=$have_nonref_sequences_changed center=$is_strict_center_empty flank=$have_all_flank_sequences_changed novel=$is_a_novel_insertion\n";

    if (!$have_all_strict_sequences_changed and !$have_nonref_sequences_changed and !$is_strict_center_empty) {
      # 'Strict' center after removing indel is not empty. This can happen for recovey insertions only.
      $event .= "_of_allele_base";
    } elsif (!$have_all_strict_sequences_changed) {
      # Strict sequences have not changed. This can happen for novel or unsure insertions only
      $event .= "_strict";
    } elsif ($have_all_strict_sequences_changed and !$have_all_flank_sequences_changed) {
      # Strict sequences have changed, but not the flanks. The alignment is shuffled in the 'tolerant' center
      $event .= "_shuffle";
    } elsif ($have_all_flank_sequences_changed and (!$have_nonref_sequences_changed or $is_a_novel_insertion)) {
      # The insertion has changed the flanks in the reference sequence only
      $event .= "_realign";
    } elsif (!$have_no_neighbouring_deletion) {
      $event .= "_neighbouring_deletion";
    } elsif (!$have_no_neighbouring_insertion) {
      $event .= "_neighbouring_insertion";
    } else {
      $event .= "_complex";
    }

    if (!$have_any_strict_flank_lengths_changed && !$have_any_strict_flank_num_bases_changed && !$have_any_strict_neighbour_center_bases_changed) {
      # Lengths of the "strict" flanks haven't changed and the base of the flanking region nearest the "center" does not change
      $event .= "_strict1";
    } elsif (!$have_any_flank_flank_lengths_changed && !$have_any_flank_flank_num_bases_changed && !$have_any_flank_neighbour_center_bases_changed) {
      # Lengths of the "strict" flanks haven't changed and the base of the flanking region nearest the "center" does not change
      $event .= "_shuffle1";
    }

    if (!$is_a_novel_insertion and !$have_nonref_sequences_changed) {
      if ($ref_alignment_score < $alt_alignment_score) {
        # This is a recovery and it has improved the alignment
        $event .= "_better";
      } else {
        # This is a recovery but it has worsen the alignment. Often times shows as a micro-inversion
        $event .= "_worse";
      }
    }

  } else {
  }


  return $event;
}


sub get_sub_alignments {
  my ($alignment, $indel_nucleotide, $indel_type, $is_alt_align) = @_;

  my $alignment_array = $alignment->{alignment};

  my $main_alignment = $alignment_array->[0]->{aligned_sequence};
  my $length_main_alignment = length($main_alignment);

  my $flank;
  my $main_sequence = $main_alignment;
  $main_sequence =~ s/-//g;
  my $length_main_sequence = length($main_sequence);

  my ($left_flank, $right_flank);

  #Flank is one less than the 'real' flank so we can use the {$left_flank}\w in the regexp to ensure we end on a base, not a pad
  #Reference alignment is always odd in length
  #Alternative alignment is always even in length
  if ($length_main_sequence % 2 == 1) {
      #ref alignment
      $left_flank = ($length_main_sequence-1)/2 - 1;
  } else {
      #alt alignment
      $left_flank = $length_main_sequence/2 - 1 - 1;
      if ($indel_type eq "deletion") {
          $left_flank++;
      }
  }

  if ($indel_type eq "insertion") {
      $right_flank = $left_flank + 1;
  } elsif ($indel_type eq "deletion") {
      $right_flank = $left_flank;
  }

  # Strict right and left sequences (avoiding the indel and the gaps in the center)
  my ($left) = $main_alignment =~ /^(\-*(\w\-*){$left_flank}\w)/;
  my ($right) = $main_alignment =~ /(\w(\-*\w){$right_flank}\-*)$/;

  if (!$left) {
    die "MAIN: $main_alignment\nLEFT:  $left\nRIGHT: $right\n";
  }
  my $length_left = length($left);
  my $length_right = length($right);

  #print OUT "flank=$left_flank $right_flank left=$left right=$right length_left=$length_left length_right-$length_right\n";

  for (my $i = 0; $i < @{$alignment_array}; $i++) {
#    print "1. $indel_nucleotide  ", $ref_alignment->[$i]->{aligned_sequence}, "\n";
    $alignment_array->[$i]->{strict_left} = substr($alignment_array->[$i]->{aligned_sequence}, 0, $length_left);
    $alignment_array->[$i]->{strict_center} = substr($alignment_array->[$i]->{aligned_sequence}, $length_left, $length_main_alignment - $length_left - $length_right);
    $alignment_array->[$i]->{strict_right} = substr($alignment_array->[$i]->{aligned_sequence}, -$length_right);
#    print "2. $indel_nucleotide  ", join(" : ", $alignment_array->[$i]->{strict_right}, $alignment_array->[$i]->{strict_center}, $alignment_array->[$i]->{strict_left}), "\n" if ($verbose);
  }
  foreach my $ancestral ("refer", "ances", "siste", "older", "final") {
    if (!$alignment->{$ancestral}->{aligned_sequence}) {
      $alignment->{$ancestral}->{aligned_sequence} = " " x length($alignment->{"refer"}->{aligned_sequence});
    }
    $alignment->{$ancestral}->{strict_left} = uc(substr($alignment->{$ancestral}->{aligned_sequence}, 0, $length_left));
    $alignment->{$ancestral}->{strict_center} = uc(substr($alignment->{$ancestral}->{aligned_sequence}, $length_left, $length_main_alignment - $length_left - $length_right));
    $alignment->{$ancestral}->{strict_right} = uc(substr($alignment->{$ancestral}->{aligned_sequence}, -$length_right));
  }

  ## Define a "softer" center by considering all gaps and identical nucleotides next to the indel
  #
  $left =~ s/\-*($indel_nucleotide\-*)+$//g; # Remove all matching positions from the end of left
  $right =~ s/^(\-*$indel_nucleotide)+\-*//g; # Remove all matching positions from the start of right
  $length_left = length($left);
  $length_right = length($right);
  for (my $i = 0; $i < @{$alignment_array}; $i++) {
#    print "3. $indel_nucleotide  ", $ref_alignment->[$i]->{aligned_sequence}, "\n";
    $alignment_array->[$i]->{flank_left} = substr($alignment_array->[$i]->{aligned_sequence}, 0, $length_left);
    $alignment_array->[$i]->{flank_center} = substr($alignment_array->[$i]->{aligned_sequence}, $length_left, $length_main_alignment - $length_left - $length_right);
    $alignment_array->[$i]->{flank_right} = substr($alignment_array->[$i]->{aligned_sequence}, -$length_right);
    #print "4.0 $indel_nucleotide  ", join(" : ", $alignment_array->[$i]->{flank_right}, $alignment_array->[$i]->{flank_center}, $alignment_array->[$i]->{flank_left}), "\n";
  }

  my $min_left = $length_left;
  my $max_right = $length_right;

  if ($is_alt_align) {
      for (my $i = 1; $i < @{$alignment_array}; $i++) {
          my $this_indel_nucleotide = $alignment_array->[$i]->{strict_center};
          #print "4. $this_indel_nucleotide  ", join(" : ", $alignment_array->[$i]->{flank_left}, $alignment_array->[$i]->{flank_center}, $alignment_array->[$i]->{flank_right}), "\n";
          
          #Ignore N's
          next if ($this_indel_nucleotide eq "N");

          #Following discussion with Javier on 21/03/2013, decided to restrict the flank_center to the same extent as [0] ie the reference sequence
          my $this_length_left = $length_left;
          my $this_length_right = $length_right;

          if ($this_length_left < $min_left) {
              $min_left = $this_length_left;
          } 
          if ($this_length_right < $max_right) {
              $max_right = $this_length_right;
          } 
      }
  }
  #print "min_left $min_left max_right $max_right\n";
  $length_left = $min_left;
  $length_right = $max_right;

  for (my $i = 0; $i < @{$alignment_array}; $i++) {
#    print "3. $indel_nucleotide  ", $ref_alignment->[$i]->{aligned_sequence}, "\n";
    $alignment_array->[$i]->{flank_left} = substr($alignment_array->[$i]->{aligned_sequence}, 0, $length_left);
    $alignment_array->[$i]->{flank_center} = substr($alignment_array->[$i]->{aligned_sequence}, $length_left, $length_main_alignment - $length_left - $length_right);
    $alignment_array->[$i]->{flank_right} = substr($alignment_array->[$i]->{aligned_sequence}, -$length_right);
    #print "4.1 $indel_nucleotide  ", join(" : ", $alignment_array->[$i]->{flank_right}, $alignment_array->[$i]->{flank_center}, $alignment_array->[$i]->{flank_left}), "\n";
  }

  foreach my $ancestral ("refer", "ances", "siste", "older", "final") {
    $alignment->{$ancestral}->{flank_left} = uc(substr($alignment->{$ancestral}->{aligned_sequence}, 0, $length_left));
    $alignment->{$ancestral}->{flank_center} = uc(substr($alignment->{$ancestral}->{aligned_sequence}, $length_left, $length_main_alignment - $length_left - $length_right));
    $alignment->{$ancestral}->{flank_right} = uc(substr($alignment->{$ancestral}->{aligned_sequence}, -$length_right));
  }
}

## This method uses the ancestral sequences inferred by Ortheus to score the ancestral allele for the indel.
# Returns : array of ancestral call for the strict position and acestral call for the entire run of nucleotides.

sub get_ancestral_allele_calls {
  my ($alignment) = @_;

  my @ancestral_alleles;
  foreach my $type ("strict_center", "flank_center") {
    my $ancestral_string = "";
    for (my $i = 0; $i < length($alignment->{ances}->{$type}); $i++) {
      my $ancestral_allele = substr($alignment->{ances}->{$type}, $i, 1);

      if ($ancestral_allele eq substr($alignment->{siste}->{$type}, $i, 1) and
          $ancestral_allele eq substr($alignment->{older}->{$type}, $i, 1)) {
        # High-confidence call. No changes
      } elsif ($ancestral_allele eq substr($alignment->{siste}->{$type}, $i, 1) or
               $ancestral_allele eq substr($alignment->{older}->{$type}, $i, 1)) {
        # Low-confidence call. Change to lowercase (or _ for gaps)
        $ancestral_allele =~ tr/ACTG-/actg_/;
      } else {
        # Unreliable call. Change to whitespace (more appropriate than N for indels).
        $ancestral_allele =~ tr/ACTGactgNn\-_/            /; # no call
      }

      $ancestral_string .= $ancestral_allele
    }
    push(@ancestral_alleles, $ancestral_string);
  }

  return (@ancestral_alleles);
}

sub resolve_unsure {
    my ($event, $alt_allele, $anc_allele) = @_;

    #Check ancestral allele contains only high confidence bases (ie all capital letters or '-' and NOT any lower case or '_'
    #What about N?
    if ($anc_allele =~ /[Nacgt_]/) {
        print OUT "found low confidence base $anc_allele\n";
        return;
    }
    if (length($anc_allele) == length($alt_allele)) {
        print OUT "Resolved $event to be recovery\n";
    } else {
        print OUT "Resolved $event to be novel\n";
    }

}


#==================================================================================
# print_report
#==================================================================================
#
# This method is called for each indel, to print the alignments in the
# indel_X_XXXX_XXXXX file, which contains the alignments.
#
#==================================================================================

sub print_report {
    my ($ref_alignment, $alt_alignment, $ref_strict_ancestral_allele, $ref_flank_ancestral_allele, $alt_strict_ancestral_allele, $alt_flank_ancestral_allele, $indel_nucleotide, $verbose) = @_;

    my $error = "\n";

      $error .= "strict\n";
      $error .= "REF ".join("\nREF ", map {$_->{strict_left}." : ".$_->{strict_center}." : ".$_->{strict_right}." ".$_->{species} }
              (@{$ref_alignment->{alignment}}, $ref_alignment->{refer}, $ref_alignment->{ances},
                $ref_alignment->{siste}, $ref_alignment->{older}, $ref_alignment->{final})). "\n\n";

      $error .= "ALT ".join("\nALT ", map {$_->{strict_left}." : ".$_->{strict_center}." : ".$_->{strict_right}." ".$_->{species} }
              (@{$alt_alignment->{alignment}}, $alt_alignment->{refer}, $alt_alignment->{ances},
                $alt_alignment->{siste}, $alt_alignment->{older}, $alt_alignment->{final})). "\n\n\n";

      $error .= "flank\n";
      $error .= "REF ".join("\nREF ", map {$_->{flank_left}." | ".$_->{flank_center}." | ".$_->{flank_right}." ".$_->{species} }
              (@{$ref_alignment->{alignment}}, $ref_alignment->{refer}, $ref_alignment->{ances},
                $ref_alignment->{siste}, $ref_alignment->{older}, $ref_alignment->{final})). "\n\n";

      $error .= "ALT ".join("\nALT ", map {$_->{flank_left}." | ".$_->{flank_center}." | ".$_->{flank_right}." ".$_->{species} }
              (@{$alt_alignment->{alignment}}, $alt_alignment->{refer}, $alt_alignment->{ances},
                $alt_alignment->{siste}, $alt_alignment->{older}, $alt_alignment->{final})). "\n\n\n";

      $error .= " Indel nucleotide: <$indel_nucleotide>\n";

      $error .= " Strict ancestral allele calls: <".
          join("> -- <",
              $ref_alignment->{alignment}->[0]->{strict_center}."/".$ref_strict_ancestral_allele,
              $alt_alignment->{alignment}->[0]->{strict_center}."/".$alt_strict_ancestral_allele).">\n";

      $error .= " Flank ancestral allele calls: <".
          join("> -- <",
              $ref_alignment->{alignment}->[0]->{flank_center}."/".$ref_flank_ancestral_allele,
              $alt_alignment->{alignment}->[0]->{flank_center}."/".$alt_flank_ancestral_allele).">\n";

      print OUT $error if ($verbose);

}


#==================================================================================
# print_summary
#==================================================================================
#
# This method is called at the end of the process, to print some stats at the end
# of the indel_X_XXXX_XXXXX file, which contains the alignments.
#
#==================================================================================

sub print_summary {
    my ($output) = @_;

    print OUT "SUMMARY\n";
    print OUT "Total bases " . $output->{'total_bases'} . "\n";

    print OUT "Low complexity regions skipped " . $output->{'count_low_complexity'} . "\n";
    print OUT "Multiple genomic_align_trees " . $output->{'multiple_gats'} . "\n";
    print OUT "No coverage on genomic_align_tree " . $output->{'no_gat'} . "\n";
    print OUT "Insufficient coverage on the genomic_align_tree " . $output->{'insufficient_gat'} . "\n";
    print OUT "Alignment to only N " . $output->{'align_all_N'} . "\n";
    print OUT "Long alignment " . $output->{'long_alignment'} . "\n";
    print OUT "Number of bases analysed " . $output->{'num_bases_analysed'} . "\n";
    print OUT "\n";

    print OUT "Summary of types\n";
    foreach my $type (keys %{$output->{'sum_types'}}) {
        print OUT "$type " . $output->{'sum_types'}{$type} . "\n";
    }
    print OUT "\n";
    
    print OUT "Summary of calls\n";
    foreach my $call (keys %{$output->{'sum_calls'}}) {
        print OUT "$call " . $output->{'sum_calls'}{$call} . "\n";
    }
    
}

#==================================================================================
# parse_ancestor_file
#==================================================================================
#
# Read 1bp variants from ancestral allele file on release ftp site. This is used
# at the begining of the execution, for the whole region
#
#==================================================================================
sub parse_ancestor_file {
    my ($file, $seq_region_start, $seq_region_end) = @_;

    open FILE, $file or die "Unable to open $file";
    
    #Skip first line
    <FILE>;
    
    #remember current position
    my $cur_pos = tell(FILE);

    #find out line length (without carriage return)
    my $line_length = length(<FILE>) - 1;
    
    #return to previous position
    seek(FILE, $cur_pos, 0);
    
    #Lines include carriage return so need to recalculate seek offset
    #first base is at position 1 therefore need to subtract 1 from seq_region_start
    my $line = (int(($seq_region_start-1)/$line_length) * ($line_length+1));

    #Calculate offset into line
    my $offset_in_line = (($seq_region_start-1)%$line_length);
    
    #Seek should start at line offset + offset into line
    my $seek_start = $line + $offset_in_line;
    
    seek FILE, $seek_start, 1;
    my $start = $seq_region_start;

    my $anc_alleles;
    while (my $line = <FILE>) {
        chomp $line;

        my @bases = split "", $line;

        my $end;
        if ($start + @bases > $seq_region_end) {
            $end = $seq_region_end;
        } else {
            $end = $start + @bases - 1;
        }
        
        for (my $i = $start, my $j = 0; $i <= $end; $i++, $j++) {
            push @$anc_alleles, $bases[$j];
        }
        
        $start += @bases;
        last if ($start > $seq_region_end);
    }
    
    my $cnt = $seq_region_start;
    foreach my $base (@$anc_alleles) {
        $cnt++;
    }
    
    close FILE;

    return $anc_alleles;

}

#
#Further annotation of the verbose 'event' 
#
sub check_ortheus_calls {
    my ($indel, $event, $ref_alignment,$alt_alignment,$ref_flank_ancestral_allele,$alt_flank_ancestral_allele) = @_;

  #  print "ref " . $ref_alignment->{alignment}->[0]->{flank_center} . " $ref_flank_ancestral_allele alt= " . $alt_alignment->{alignment}->[0]->{flank_center} . " $alt_flank_ancestral_allele\n";

    my $ref_seq = $ref_alignment->{alignment}->[0]->{flank_center};
    my $ref_anc = $ref_flank_ancestral_allele;
    my $alt_seq = $alt_alignment->{alignment}->[0]->{flank_center};
    my $alt_anc = $alt_flank_ancestral_allele;
    
    #print "before !$ref_seq! !$alt_seq! !$ref_anc! !$alt_anc!\n";

    #remove gaps
    $ref_seq =~ tr/-_ //d;
    $ref_anc =~ tr/-_ //d;
    $alt_seq =~ tr/-_ //d;
    $alt_anc =~ tr/-_ //d;

    #print "gapless !$ref_seq! !$alt_seq! !$ref_anc! !$alt_anc!\n";

    #Check ref_anc and alt_anc are the same
    if (uc($ref_anc) eq uc($alt_anc)) {
        if (uc($alt_anc) eq uc($ref_seq)) {
            if ($indel eq "insertion") {
                $event .= "_polymorphic_insertion";
            } else {
                #deletion
                $event .= "_polymorphic_deletion";
            }
        } elsif (uc($alt_anc) eq uc($alt_seq)) {
            if ($indel eq "insertion") {
                $event .= "_polymorphic_deletion";
            } else {
                #deletion
                $event .= "_polymorphic_insertion";
            }
        } else {
            #Define complex_polymorphic_insertions where the $alt_anc is the same length as the ref_seq
            if (length($alt_anc) == length($ref_seq)) {
                if ($indel eq "insertion") {
                    $event .= "_complex_polymorphic_insertion";
                } else {
                    #deletion
                    $event .= "_complex_polymorphic_deletion";
                }
            } elsif (length($alt_anc) == length($alt_seq)) {
                if ($indel eq "insertion") {
                    $event .= "_complex_polymorphic_deletion";
                } else {
                    #deletion
                    $event .= "_complex_polymorphic_insertion";
                }
            } else {
                #$event .= "_compensatory_unsure";
                my $diff_ref = abs(length($alt_anc) - length($ref_seq));
                my $diff_alt = abs(length($alt_anc) - length($alt_seq));
                #print "diff $diff_ref $diff_alt\n";
                if ($diff_ref < $diff_alt) {
                    if ($indel eq "insertion") {
                        $event .= "_funny_polymorphic_insertion";
                    } else {
                        #deletion
                        $event .= "_funny_polymorphic_deletion";
                    }
                } else {
                    if ($indel eq "insertion") {
                        $event .= "_funny_polymorphic_deletion";
                    } else {
                        #deletion
                        $event .= "_funny_polymorphic_insertion";
                    }
                }
                #print "event $event\n";
            } 

            #ALT ancestor is not the same as either the REF seq or the ALT seq
            #$event .= "_compensatory_polymorphic_deletion";
        }
    }
    return $event;
}

#
#Check for neighbouring deletion in the alignment
#
sub CheckForNeighbouringDeletion {
    my ($reference_gat) = @_;
    
    my $ref_cigar_line;
    my $non_ref_cigar_line;
    my $have_no_neighbouring_deletion = 0;

    foreach my $genomic_align_node (@{$reference_gat->get_all_sorted_genomic_align_nodes()}) {
        foreach my $genomic_align (@{$genomic_align_node->genomic_align_group->get_all_GenomicAligns}) {
            next if ($genomic_align->dnafrag->name eq "Ancestor");
            if (!$ref_cigar_line) {
                $ref_cigar_line = $genomic_align->cigar_line;
                if ($ref_cigar_line =~ /^\d*M(\d+)D\d*M$/) {
                    
                    if ($1 < 3) {
                        $have_no_neighbouring_deletion = 1;
                    } else {
                        #print "Looking good $1 is > 2\n";
                    }
                } else {
                    $have_no_neighbouring_deletion = 1;
                }
            } else {
                #check non-ref cigar_lines have no pads
                if ($genomic_align->cigar_line =~ /^\d*M$/) {
                    if ($non_ref_cigar_line) { 
                        #check if the non-ref cigar_lines are identical to each other
                        if ($non_ref_cigar_line ne $genomic_align->cigar_line) {
                          $have_no_neighbouring_deletion = 1;
                          last;
                      }
                    } else {
                        $non_ref_cigar_line = $genomic_align->cigar_line;
                    }
                } else {
                    $have_no_neighbouring_deletion = 1;
                    last;
                }
            }
        }
    }
    return $have_no_neighbouring_deletion;
}

#
#Check for neighbouring insertion in the alignment
#
sub CheckForNeighbouringInsertion {
    my ($reference_gat) = @_;
    
    my $ref_cigar_line;
    my $non_ref_cigar_line;
    my $have_no_neighbouring_insertion = 0;

    foreach my $genomic_align_node (@{$reference_gat->get_all_sorted_genomic_align_nodes()}) {
        foreach my $genomic_align (@{$genomic_align_node->genomic_align_group->get_all_GenomicAligns}) {
            next if ($genomic_align->dnafrag->name eq "Ancestor");
            #print "cigar " . $genomic_align->cigar_line . "\n";
            if (!$ref_cigar_line) {
                $ref_cigar_line = $genomic_align->cigar_line;
                #print "ref $ref_cigar_line\n";
                
                if ($ref_cigar_line !~ /^\d*M$/) {
                    $have_no_neighbouring_insertion = 1;
                    last;
                }
            } else {
                #check non-ref cigar_lines have a deletion of more than 2 bases
                if ($genomic_align->cigar_line =~ /^\d*M(\d+)D\d*M$/) {
                    if ($1 < 3) {
                        $have_no_neighbouring_insertion = 1;
                        last;
                    } else {
                        #print "Looking good $1 is > 2\n";
                    }
                    if ($non_ref_cigar_line) { 
                        #check if the non-ref cigar_lines are identical to each other
                        if ($non_ref_cigar_line ne $genomic_align->cigar_line) {
                          $have_no_neighbouring_insertion = 1;
                          last;
                      }
                    } else {
                        $non_ref_cigar_line = $genomic_align->cigar_line;
                    }
                } else {
                    $have_no_neighbouring_insertion = 1;
                    last;
                }
            }
        }
    }
    return $have_no_neighbouring_insertion;
}

#
#Return true if the non-reference alignments are all N or gap
#
sub check_for_alignments_all_N_or_gap {
    my ($gat) = @_;
    
    my $all_leaves = $gat->get_all_leaves;
    my $ref_ga = $gat->reference_genomic_align;
    
    foreach my $this_leaf (@$all_leaves) {
        foreach my $ga (@{$this_leaf->get_all_genomic_aligns_for_node}) {
            next if ($ga eq $ref_ga);
            my $seq = $ga->aligned_sequence;
            my $n_cnt = ($seq =~ tr/Nn-/Nn-/);
            #Found something other than N
            if ($n_cnt != length($seq)) {
                return 0;
            }
        }
    }
    #Only Ns found
    return 1;
}

#
#Detect and remove from the tree any sequences that are completely N or gap
#Return the number of sequences found
#
sub remove_sequence_of_all_N_or_gap {
    my ($gat) = @_;

    my $num_sequence_of_all_N = 0;
    my $all_leaves = $gat->get_all_leaves;
    foreach my $this_leaf (@$all_leaves) {
        foreach my $ga (@{$this_leaf->get_all_genomic_aligns_for_node}) {
            my $seq = $ga->aligned_sequence;
            my $n_cnt = ($seq =~ tr/Nn-/Nn-/);
            #print "name ". $this_leaf->name . " $seq\n";
            #Found something other than N
            if ($n_cnt == length($seq)) {
                #print "prune\n";
                #prune tree
                $this_leaf->disavow_parent;
 
                #these get destroyed by minimize_tree so need to reassign afterwards
                my $reference_genomic_align = $gat->reference_genomic_align;
                my $reference_genomic_align_node = $gat->reference_genomic_align_node;

                $gat = $gat->minimize_tree;

                $gat->reference_genomic_align($reference_genomic_align);
                $gat->reference_genomic_align_node($reference_genomic_align_node);
                $num_sequence_of_all_N++;
            }
        }
    }
    #return the number of sequences removed
    return ($gat, $num_sequence_of_all_N);
}

#Rules: 
#complex => complex
#novel_deletion => polymorphic_deletion
#insertion_recovery => polymorphic_deletion
#deletion_recovery => polymorphic insertion
#insertion_novel => polymorphic_insertion
#unsure => unsure

sub get_simple_event {
    my ($indel, $type, $detail1, $detail2) = @_;

    my $simple_event;

    #$detail2 contains any pre-existing polymorphic_ tag
    #return this unchanged (includes 'funny' type)
    if ($detail2) {
        return $detail2;
    }

    #detail1, if defined, contains the "complex" tag
    if ($detail1 && ($detail1 eq "complex")) {
        $simple_event = "complex_";
    }
    
    if ($indel eq "insertion") {
        if ($type eq "novel") {
            $simple_event .= "polymorphic_insertion";
        } elsif ($type eq "recovery") {
            $simple_event .= "polymorphic_deletion";
        } elsif ($type eq "unsure") {
            $simple_event .= "unsure";
        }
    } elsif ($indel eq "deletion") {
        if ($type eq "novel") {
            $simple_event .= "polymorphic_deletion";
        } elsif ($type eq "recovery") {
            $simple_event .= "polymorphic_insertion";
        } elsif ($type eq "unsure") {
            $simple_event .= "unsure";
        }
    }

    return $simple_event;
}


#For all the cases that were not assigned as *polymorphic*  ie where the ref_anc_allele ne alt_anc_allele
#Assign the ancestral allele according to following rules:
#1) Insertion Novel
#   Call Reference Ancestor unless the length($ref_allele) < length($ref_anc_allele). 
#2) Deletion Novel
#   Call Reference Ancestor unless the length($ref_allele) > length($ref_anc_allele)
#3) Insertion Recovery
#   Call Alternate Ancestor unless the length($alt_allele) > length($alt_anc_allele)
#4) Deletion Recovery
#   Call Alternate Ancestor unless the length($alt_allele) < length($alt_anc_allele)

sub get_ancestral_allele {
    my ($self, $indel, $type, $ref_allele, $alt_allele, $ref_anc_allele, $alt_anc_allele) = @_;

    my $unsure_allele = "?"; #string to use when we are unsure

    #Return if the ref ancestor and alt ancestor are the same
    if ($ref_anc_allele eq $alt_anc_allele) {
        return $alt_anc_allele;
    }

    #Remove "-" to make the lengths compatible to what is in RunAncestralAllelesComplete(Fork)
    foreach my $i ($ref_allele, $alt_allele, $ref_anc_allele, $alt_anc_allele) {
        $i =~ s/\-//;
    }

    my $final_anc_allele;
    if ($type eq "novel") {
        if ($indel eq "insertion") {
            if (length($ref_allele) < length($ref_anc_allele)) {
                $final_anc_allele = $unsure_allele;
            } else {
                $final_anc_allele = $ref_anc_allele;
            }
        } elsif ($indel eq "deletion") {
            if (length($ref_allele) > length($ref_anc_allele)) {
                $final_anc_allele = $unsure_allele;
            } else {
                $final_anc_allele = $ref_anc_allele;
            }
        }
    } elsif ($type eq "recovery") {
        if ($indel eq "insertion") {
            if (length($alt_allele) > length($alt_anc_allele)) {
                $final_anc_allele = $unsure_allele;
            } else {
                $final_anc_allele = $alt_anc_allele;
            }
        } elsif ($indel eq "deletion") {
            if (length($alt_allele) < length($alt_anc_allele)) {
                $final_anc_allele = $unsure_allele;
            } else {
                $final_anc_allele = $alt_anc_allele;
            }
        }
    } elsif ($type eq "unsure") {
        $final_anc_allele = $unsure_allele;
    }
    
    if ($final_anc_allele eq "") {
        $final_anc_allele = "-";
    }

    return $final_anc_allele;
}

1;
