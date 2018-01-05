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

Bio::EnsEMBL::Compara::RunnableDB::BaseAge::BaseAge

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BaseAge::BaseAge;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Variation::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
  $genome_db_adaptor->dbc($self->compara_dba->dbc);

  my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlss_adaptor->fetch_by_method_link_type_species_set_name('EPO', $self->param_required('species_set_name'));

  $self->param('mlss', $mlss);

  my $seq_region = $self->param_required('seq_region');

  my $species = $self->param_required('species');
  my $genome_db = $genome_db_adaptor->fetch_by_registry_name($species);
  $genome_db->db_adaptor->dbc->disconnect_when_inactive(0);
  $self->param('ref_genome_db', $genome_db);

  my $anc_genome_db = $genome_db_adaptor->fetch_by_name_assembly('ancestral_sequences');
  $anc_genome_db->db_adaptor->dbc->disconnect_when_inactive(0);

  my $slice_adaptor = $genome_db->db_adaptor->get_SliceAdaptor;

  throw("Registry configuration file has no data for connecting to <$species>") if (!$slice_adaptor);

  my $slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region);
  throw("No Slice can be created on seq_region $seq_region") if (!$slice);

  $self->param('slice', $slice);

  my $dnafrag = $self->compara_dba->get_DnaFragAdaptor->fetch_by_Slice($slice);
  $self->param('dnafrag', $dnafrag);

  print "mlss " . $mlss->dbID . " seq_region $seq_region $species\n" if ($self->debug);
   
  #load variation database
  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_registry_from_url($self->param('variation_url'));

  #get adaptor to VariationFeature object
  my $vf_adaptor = $reg->get_adaptor($species, 'variation', 'variationfeature'); 
  $self->param('vf_adaptor', $vf_adaptor);

  #Check bed_dir ends in a final /
  unless ($self->param('bed_dir') =~ /\/$/) {
      $self->param('bed_dir', ($self->param('bed_dir')."/"));
  }

  return 1;
}

sub write_output {
  my $self = shift;

  $self->base_age();
#  $self->quick_base_age();
  return 1;
}

sub base_age {
    my ($self) = @_;
    my $gap = "-"; #gap character

    $self->dbc && $self->dbc->disconnect_if_idle;

    my $mlss = $self->param('mlss');
    my $slice = $self->param('slice');
    my $dnafrag = $self->param('dnafrag');
    my $seq_region = $self->param('seq_region');
    my $name_mode = $self->param('name'); #can be either "name" or "node_id"

    #Check we have a valid name_mode ('name' or 'node_id')
    unless ($name_mode eq "name" || $name_mode eq "node_id") {
        throw("name_mode must either be 'name' or 'node_id', not $name_mode");
    }

    #
    my $compara_dba = $self->compara_dba;
    my $gat_adaptor = $compara_dba->get_GenomicAlignTreeAdaptor;
    # Fetching all the GenomicAlignTrees corresponding to this Slice:
    my $genomic_align_trees =
      $gat_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice);
#      $gat_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice, undef, undef, 1);
    
    print "Number of trees " . @$genomic_align_trees . "\n" if ($self->debug);

    my $ref_genome_db = $self->param('ref_genome_db');
    #create tag name
    my $gdb_name = $ref_genome_db->get_short_name;
    
    #return clade of this species and all the species in this clade (as genome_db_ids)
    my $clade = $compara_dba->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($self->param('clade_taxon_id'))->scientific_name();
    my $all_clade_species_name = {map {$_->get_short_name => 1} @{ $compara_dba->get_GenomeDBAdaptor->fetch_all_by_ancestral_taxon_id($self->param('clade_taxon_id')) } };

    print "CLADE $clade\n" if ($self->debug);

    #generate bed_file location
    my $bed_file = $self->param('bed_dir') . $ref_genome_db->get_short_name . "_ages_" . $mlss->dbID . "_" . $seq_region . ".bed";
    open (BED, ">$bed_file") || die "ERROR writing ($bed_file) file\n";

    foreach my $gat (@$genomic_align_trees) {
        my $tree_string = $gat->newick_format('simple');
        print "$tree_string\n" if ($self->debug);
                
        my @aligned_seq;
        my $ancestral_seqs;
        my $genome_dbs;
        my $ref_node;
        
        my $depth = 0;
        my $clade_age = 0;
        my $ref_start;

        #Only expect a single genomic_align for EPO alignments
        my $reference_node = $gat->reference_genomic_align_node;
        my $ref_genomic_align = $gat->reference_genomic_align;
        @aligned_seq = split(//,$ref_genomic_align->aligned_sequence);
        $ref_start = $ref_genomic_align->dnafrag_start unless $ref_start;
        
        #Get snps 
        my $snp_list = $self->get_snps($ref_genomic_align->get_Slice);
        if ($snp_list) {
            print "Number of snps " . (scalar keys %$snp_list) . "\n" if ($self->debug);
        }
        my $ancestors = $reference_node->get_all_ancestors;
        my $max_age = @$ancestors;

        print "ROOT " . $reference_node->distance_to_root . "\n" if ($self->debug);
        my $root_distance = $reference_node->distance_to_root ;

        foreach my $this_node (@$ancestors) {
            print "node " . $this_node->name . "\n" if ($self->debug);
            print "node " . $this_node->node_id . " " . $this_node->name . " node " . $this_node->distance_to_node($reference_node) . " parent " . $this_node->distance_to_parent . " " . ($this_node->distance_to_node($reference_node)/$root_distance) . "\n" if ($self->debug);

            #expect only a single genomic_align for an ancestor
            my $genomic_aligns = $this_node->get_all_genomic_aligns_for_node;
            if (@$genomic_aligns > 1) {
                print "Warning! More than one ancestral genomic_align\n";
            }
            my $genomic_align = $genomic_aligns->[0];
            
            #Store the sequence of all ancestral nodes containing this species
            my $ancestral_seq;
            %$ancestral_seq = (name => $this_node->name,
                               node_id => $this_node->node_id,
                               age => $this_node->distance_to_node($reference_node),
                               aligned_seq => [split(//,$genomic_align->aligned_sequence)]);
            push @$ancestral_seqs, $ancestral_seq;
            
            #Find depth of clade
            unless ($clade_age) {
                #split node name into constitutent species
                my @node_names = split "-", $this_node->name;
                foreach my $node_name (@node_names) {
                    $node_name =~ s/(\w*)\[\d+\]{0,1}/$1/;
                    #stop when find a name that is not in the clade
                    unless ($all_clade_species_name->{$node_name}) {
                        $clade_age=$depth;
                        print "SET depth $depth $node_name\n" if ($self->debug);
                        last;
                    }
                }
            }
            $depth++;
        }
        #If $clade_age has not been set, all the ancestors must be in this clade so set to $max_age
        $clade_age = $max_age unless ($clade_age);
        print "Clade age $clade_age max_age $max_age ref_start=$ref_start\n" if ($self->debug);

        my $base = $ref_start; 

        #Compare ref sequence with ancestral nodes to find the first difference
        for (my $i = 0; $i < @aligned_seq; $i++) {
            next if ($aligned_seq[$i] eq $gap); #skip gaps in ref sequence
            my $age = 0;
            my $node_distance = 0;
            my $clade_name = $gdb_name;
            my $node_id = $reference_node->node_id; #default to reference node_id
            foreach my $ancestral_seq (@$ancestral_seqs) {
                
                #Skip over any ancestors which are gaps
                if ($ancestral_seq->{aligned_seq}[$i] ne $gap) { 
                    if ($aligned_seq[$i] eq $ancestral_seq->{aligned_seq}[$i]) {
                        #ref and ancestor are the same, continue
                        #print "SAME " . ($i+1) . " $base " . $aligned_seq[$i] . " " . $ancestral_seq->{aligned_seq}[$i]. " " . $ancestral_seq->{name} . "\n";
                        $clade_name = $ancestral_seq->{name};
                        $node_id = $ancestral_seq->{node_id};
                        $node_distance = $ancestral_seq->{age};
                    } else {
                        #Found a difference between ref and ancestor. Stop
                        #print "DIFF " . ($i+1) . " $base " . $aligned_seq[$i] . " " . $ancestral_seq->{aligned_seq}[$i]. " " . $ancestral_seq->{name} . "\n";
                        last;
                    }
                }
                $age++;
            }
            print "age=$age $node_distance $clade_name\n" if ($self->debug);

            my $specificity;
            if ($age < $max_age) {

                #store the ratio of branch length to ancestor / branch length to root. The score field of a bed file should be between 0 and 1000.
                my $normalised_age = int((($node_distance/$root_distance)*1000)+0.5);
                my $rgb;
                my $shade = int($normalised_age*256/1000);
                #Ensure the BED score is larger than 0 for display purposes
                $normalised_age = 1 if ($normalised_age < 1);
                
                #Any base on a snp has an age of -1
                if ($snp_list->{$base}) {
                    $age = -1;
                    $specificity = 'POPULATION';
                    $rgb = "255,127,0"; #orange
                } elsif ($age == 0) {
                    $specificity = 'SPECIES';
                    $rgb = "255,0,0"; #red
                } elsif ($age <= $clade_age) {
                    $specificity = 'CLADE';
                    $rgb = "$shade,$shade,255"; #shades of blue
                } else {
                    $specificity = 'OTHER';
                    $rgb = "$shade,$shade,$shade"; 
                }

                my $name_field;
                if ($name_mode eq "name") {
                    $name_field = $clade_name;
                } else {
                    $name_field = $node_id;
                }
                printf BED "chr%s\t%d\t%d\t%s\t%d\t%s\n", $seq_region, ($base-1), $base, $name_field, $normalised_age, $rgb;
            }
            
            $base++;
        }
        $gat->release_tree;
    }
    close BED;

    #Do not sort here in case the sort command fails, which means having to rerun the entire job
    #my $sorted_bed_file = sort_bed($bed_file);
    my $output;
    #%$output = ('bed_files' => $sorted_bed_file);
    %$output = ('bed_files' => $bed_file);
    $self->dataflow_output_id($output, 2);
}


#Get all snps
sub get_snps {
    my ($self, $slice) = @_;

    my $snp_list;
    my $vf_adaptor = $self->param('vf_adaptor');

    return $snp_list unless ($vf_adaptor);
    my $vfs = $vf_adaptor->fetch_all_by_Slice($slice); #return ALL variations defined in $slice
    my $frags;

    foreach my $vf (@{$vfs}){
        #print "TYPE " . $vf->class_SO_term . "\n";
        #print "  Variation: ", $vf->variation_name, " with alleles ", $vf->allele_string . " class=" . $vf->class_SO_term . " in chromosome ", $slice->seq_region_name, " and position ", $vf->start,"-",$vf->end, " strand=", $vf->strand, "\n";
        if ($vf->class_SO_term eq "SNV") {
            #check start = end
            if ($vf->seq_region_start == $vf->seq_region_end) {
                $snp_list->{$vf->seq_region_start} = 1;
            } else {
                print "Ignore case where snp start " . $vf->seq_region_start . " does not equal snp end " . $vf->seq_region_end . "\n";
            }
        }
    }
    return $snp_list;
}

#use for debugging the pipeline only
sub quick_base_age {
    my ($self) = @_;

    my $seq_region = $self->param('seq_region');
    my $bed_file = $self->param('bed_dir') . "Test_ages_" . $seq_region . ".bed";

    open (BED, ">$bed_file") || die "ERROR writing ($bed_file) file\n";
    my $base = 123;
    my $node_id = 61900000001;
    my $normalised_age = 500;
    my $strand = "+";
    my $rgb = "255,255,255";

    printf BED "chr%s\t%d\t%d\t%s\t%d\t%s\t%d\t%d\t%s\n", $seq_region, ($base-1), $base, $node_id, $normalised_age, $strand, 0, 0, $rgb;

    close(BED);
    my $output;
    %$output = ('bed_files' => $bed_file);
    $self->dataflow_output_id($output, 2);

}


1;
