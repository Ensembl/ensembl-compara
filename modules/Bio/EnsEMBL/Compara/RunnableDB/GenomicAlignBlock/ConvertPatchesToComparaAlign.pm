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

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::ConvertPatchesToComparaAlign

=head1 DESCRIPTION

Runnable to import the alignments between patches / haplotypes and primary
regions.  The original data are in the core database and only need to be
transformed into genomic_align(_block) entries.  The trick is that blocks
have to be split when they contain gaps of more than 50bp (to follow a rule
that applies to our LASTZ_NET pipeline).

Parameters:
  - a compara database
  - "genome_db_id"
  - "lastz_patch_method" (usually "LASTZ_PATCH")

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::ConvertPatchesToComparaAlign;

use strict;
use warnings;

use List::Util qw(sum);

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');



sub param_defaults {
    return {
        gap_cutoff_size => 50,  # size of the gap (base pairs) in the reference or patch sequence greater than (>) this value will end the block
    }
}


sub fetch_input {
    my $self = shift;

    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($self->param_required('genome_db_id'));
    my %dnafrags_hash = map {$_->name => $_->dbID} @{ $self->compara_dba->get_DnaFragAdaptor->fetch_all_by_GenomeDB_region($genome_db) };
    $self->param('dnafrags_hash', \%dnafrags_hash);

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_genome_db_ids($self->param_required('lastz_patch_method'), [$self->param('genome_db_id')]);
    $self->param('mlss_id', $mlss->dbID);

    my $gap_cutoff_size = $self->param('gap_cutoff_size');

    my %aligned_patch = ();
    $self->param('aligned_patch', \%aligned_patch);

    my $daf_a = $genome_db->db_adaptor->get_DnaAlignFeatureAdaptor;

    ##### original code from ensembl-compara/scritps/pipeline/convert_patch_to_compara_align.pl ######

my $patch_align_features = $daf_a->fetch_all_by_logic_name("alt_seq_mapping");

foreach my $patch_align(@$patch_align_features){
	my ($contig_bases) = $patch_align->cigar_string=~/(\d+)M/;
	my ($ref_strand, $patch_strand) = ($patch_align->hstrand, $patch_align->seq_region_strand);
	push(@{ $aligned_patch{$patch_align->hseqname}{$patch_align->seq_region_name} }, 
		{
			ref_genomic_align_id => undef,
			patch_genomic_align_id => undef,
			genomic_align_block_id => undef,
			ref_start => $patch_align->hstart,
			ref_end => $patch_align->hend,
			ref_strand => $ref_strand,
			ref_aln_bases => [$contig_bases],
			patch_start => $patch_align->seq_region_start,
			patch_end => $patch_align->seq_region_end,
			patch_strand => $patch_strand,
			patch_aln_bases => [$contig_bases],
			gab_perc_num => $contig_bases,
		}
	); 
}	


my($ga_id,$gab_id)=(1,1);

foreach my $ref_name(keys %aligned_patch){
	foreach my $patch_name(keys %{$aligned_patch{$ref_name}}){
		our $arr;
		*arr = \$aligned_patch{$ref_name}{$patch_name};
		@$arr = sort {$a->{ref_start} <=> $b->{ref_start}} @$arr; # sort on the basis of the reference (non-patch) coords
		for(my$i=0;$i<@$arr-1;$i++){
			my $split_here = 0;
			# reasons to break the alignment block
			next if( $arr->[$i]->{ref_strand} != $arr->[$i+1]->{ref_strand}); 
			next if($arr->[$i]->{ref_end} + 1 != $arr->[$i+1]->{ref_start} && $arr->[$i]->{patch_end} + 1 != $arr->[$i+1]->{patch_start} );	
			next if( $arr->[$i]->{ref_strand} == -1 && ($arr->[$i+1]->{patch_end} > $arr->[$i]->{patch_start}) );
			next if($arr->[$i]->{ref_strand} == 1 && ($arr->[$i+1]->{patch_end} < $arr->[$i]->{patch_end}) );
			if($arr->[$i]->{ref_strand} == -1){
				my @patch_arr = sort {$b->{patch_start} <=> $a->{patch_start}} @$arr; # reverse sort (ref strand is -ve) on the basis of the patch coords 
				if($arr->[$i]->{ref_end} + 1 == $arr->[$i+1]->{ref_start}){ # ref seqs are contiguous
					for(my$x=0;$x<@patch_arr-1;$x++){
						if($patch_arr[$x]->{ref_start} == $arr->[$i]->{ref_start}){
							unless($patch_arr[$x+1]->{patch_start} == $arr->[$i+1]->{patch_start}){
								$split_here = 1; 
								last;
							}
						}
					}
					my $patch_del = $arr->[$i]->{patch_start} - $arr->[$i+1]->{patch_end} - 1;
					$split_here = $patch_del > $gap_cutoff_size ? 1 : $split_here;
					next if $split_here; # the patch seqs are NOT adjacent OR a gap in the patch is > $gap_cutoff_size bp, so the block ends here
					push(@{ $arr->[$i]->{ref_aln_bases} }, $patch_del . "D",  @{ $arr->[$i+1]->{ref_aln_bases} });
					push(@{ $arr->[$i]->{patch_aln_bases} }, $patch_del, @{ $arr->[$i+1]->{patch_aln_bases} });
					$arr->[$i]->{patch_start} = $arr->[$i+1]->{patch_start};
				}
				else { # patch seqs are contiguous 
					my $ref_del = $arr->[$i+1]->{ref_start} - $arr->[$i]->{ref_end} - 1;
					$split_here = $ref_del > $gap_cutoff_size ? 1 : $split_here;
					next if $split_here; # block ends here if a gap in the ref is > $gap_cutoff_size bp
					push(@{ $arr->[$i]->{patch_aln_bases} }, $ref_del . "D",  @{ $arr->[$i+1]->{patch_aln_bases} });
					push(@{ $arr->[$i]->{ref_aln_bases} }, $ref_del, @{ $arr->[$i+1]->{ref_aln_bases} });
					$arr->[$i]->{patch_start} = $arr->[$i+1]->{patch_start};
				}
			}
			else{ # ref seq is +ve
				my @patch_arr = sort {$a->{patch_start} <=> $b->{patch_start}} @$arr; # sort on the basis of the patch coords
				if($arr->[$i]->{ref_end} + 1 == $arr->[$i+1]->{ref_start}){ # ref seqs are contiguous
					for(my$x=0;$x<@patch_arr-1;$x++){
						if($patch_arr[$x]->{ref_start} == $arr->[$i]->{ref_start}){
							unless($patch_arr[$x+1]->{patch_start} == $arr->[$i+1]->{patch_start}){
								$split_here = 1;
								last;
							}
						}
					}
					my $patch_del = $arr->[$i+1]->{patch_start} - $arr->[$i]->{patch_end} - 1;
					$split_here = $patch_del > $gap_cutoff_size ? 1 : $split_here; # block ends here if a gap in the patch is > $gap_cutoff_size bp
					next if $split_here;
					push(@{ $arr->[$i]->{ref_aln_bases} }, $patch_del . "D", @{ $arr->[$i+1]->{ref_aln_bases} });
					push(@{ $arr->[$i]->{patch_aln_bases} }, $patch_del, @{ $arr->[$i+1]->{patch_aln_bases} });
				}else{ # patch seq are contiguous
					my $ref_del = $arr->[$i+1]->{ref_start} - $arr->[$i]->{ref_end} - 1;
					$split_here = $ref_del > $gap_cutoff_size ? 1 : $split_here; # block ends here if a gap in the ref is > $gap_cutoff_size bp
					next if $split_here;
					push(@{ $arr->[$i]->{patch_aln_bases} }, $ref_del . "D", @{ $arr->[$i+1]->{patch_aln_bases} });
					push(@{ $arr->[$i]->{ref_aln_bases} }, $ref_del, @{ $arr->[$i+1]->{ref_aln_bases} });
				}
				$arr->[$i]->{patch_end} = $arr->[$i+1]->{patch_end};
			}
			$arr->[$i]->{gab_perc_num} += $arr->[$i+1]->{gab_perc_num};
			$arr->[$i]->{ref_end} = $arr->[$i+1]->{ref_end};
			splice(@$arr, $i+1, 1);
			$i--;
		}

		# generate the cigar string

		for(my$j=0;$j<@$arr;$j++){
			$arr->[$j]->{genomic_align_block_id} = $gab_id++;
			$arr->[$j]->{ref_genomic_align_id} = $ga_id++;
			$arr->[$j]->{patch_genomic_align_id} = $ga_id++;
			for(my$k=0;$k<@{ $arr->[$j]->{ref_aln_bases} }-1;$k++){ # create proto cigar line for the reference
				if($arr->[$j]->{ref_aln_bases}->[$k+1]=~/D/){ # reached the end of matching seq, so append an M
					$arr->[$j]->{ref_aln_bases}->[$k] .= "M" . $arr->[$j]->{ref_aln_bases}->[$k+1];
					splice(@{ $arr->[$j]->{ref_aln_bases} }, $k+1, 1);
				}else{ # not reached the end of matching seq, so sum the match lengths
					$arr->[$j]->{ref_aln_bases}->[$k] += $arr->[$j]->{ref_aln_bases}->[$k+1];
					splice(@{ $arr->[$j]->{ref_aln_bases} }, $k+1, 1);
					$k--;
				}
			}
			$arr->[$j]->{ref_aln_bases} = join("", @{$arr->[$j]->{ref_aln_bases}}) . "M";
			for(my$l=0;$l<@{ $arr->[$j]->{patch_aln_bases} }-1;$l++){
				if($arr->[$j]->{patch_aln_bases}->[$l+1]=~/D/){
					$arr->[$j]->{patch_aln_bases}->[$l] .= "M" . $arr->[$j]->{patch_aln_bases}->[$l+1];
					splice(@{ $arr->[$j]->{patch_aln_bases} }, $l+1, 1);
				}else{
					$arr->[$j]->{patch_aln_bases}->[$l] += $arr->[$j]->{patch_aln_bases}->[$l+1];
					splice(@{ $arr->[$j]->{patch_aln_bases} }, $l+1, 1);
					$l--;
				}
			}
			$arr->[$j]->{patch_aln_bases} = join("", @{$arr->[$j]->{patch_aln_bases}}) . "M";
			# reverse the strand sign so that the reference is always 1	
			($arr->[$j]->{patch_strand}, $arr->[$j]->{ref_strand}) = ($arr->[$j]->{ref_strand}, $arr->[$j]->{patch_strand}) if $arr->[$j]->{ref_strand} == -1;
		}
	}
}

    ##### end #####

    #$self->param('arr', $arr);
}


sub write_output {
    my $self = shift;

    my %aligned_patch = %{ $self->param('aligned_patch') };
    my $mlss_id = $self->param('mlss_id');
    # This works for any species, but I want to preserve the original variable name
    my %hum_dfs = %{ $self->param('dnafrags_hash') };

    ##### original code from ensembl-compara/scritps/pipeline/convert_patch_to_compara_align.pl ######

my $mlss_pref = $mlss_id . "0000000000";
foreach my $ref_name(keys %aligned_patch){
	foreach my $patch_name(keys %{$aligned_patch{$ref_name}}){
                our $arr;
                *arr = \$aligned_patch{$ref_name}{$patch_name};
		foreach my $gab(@{ $arr }){
                        my @num = split(/[MD]/, $gab->{ref_aln_bases});
                        my $align_len = sum(0,@num);
			$gab->{ref_aln_bases}=~s/M1D/MD/g;
			$gab->{patch_aln_bases}=~s/M1D/MD/g;
			$gab->{ref_aln_bases}=~s/M0D/M/g; # just in case (should never be used)
			$gab->{patch_aln_bases}=~s/M0D/M/g; # just in case (should never be used)
			my $gab_perc_id = int($gab->{gab_perc_num} / $align_len * 100);
			# the last two fields (group_id and level_id) in the genomic_align_block table are filled using this hack to set the 
			# group_id = (patch_dnafrag_id + mlss_prefix) and set level_id = 1
			single_insert($self->compara_dba->dbc, 'genomic_align_block',
                            [($gab->{genomic_align_block_id} + $mlss_pref), $mlss_id, 0, $gab_perc_id, $align_len, ($hum_dfs{ $patch_name } + $mlss_pref), 1]);
			single_insert($self->compara_dba->dbc, 'genomic_align',
                            [($gab->{ref_genomic_align_id} + $mlss_pref),
				($gab->{genomic_align_block_id} + $mlss_pref), $mlss_id, $hum_dfs{ $ref_name }, 
				$gab->{ref_start}, $gab->{ref_end}, $gab->{ref_strand}, $gab->{ref_aln_bases}, 1, undef]);
			single_insert($self->compara_dba->dbc, 'genomic_align',
                            [($gab->{patch_genomic_align_id} + $mlss_pref),
				($gab->{genomic_align_block_id} + $mlss_pref), $mlss_id, $hum_dfs{ $patch_name }, 
				$gab->{patch_start}, $gab->{patch_end}, $gab->{patch_strand}, $gab->{patch_aln_bases}, 1, undef]);
		}
	}
}

    ##### end #####

    $self->dataflow_output_id( { method_link_species_set_id => $mlss_id }, 1);
}

1;
