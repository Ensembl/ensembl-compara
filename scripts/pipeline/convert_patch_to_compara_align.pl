use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

use Bio::EnsEMBL::Registry;


my $gap_cutoff_size = 50; # size of the gap (base pairs) in the reference or patch sequence greater than (>) this value will end the block

my $mlssid;
my $species_name = "human";
my $db_user;
my $db_host;
my $release_version;
my $compara_master;
my $dnafrags_file;


my $description = q'
	PROGRAM: convert_patch_to_compara_align.pl

	DESCRIPTION: converts DnaAlignFeature alignments from the "otherfeatures"
		     db to compara genomic_align(s) and genomic_align_block(s).
	EXAMPLE: perl convert_patch_to_compara_align.pl --mlssid 556 --species_name human \
		 --db_host server_name --db_user user_name --release_version 65 --dnafrags_file dnafrags_file
';

my $help = sub {
	print $description;
};

unless(@ARGV){
	$help->();
	exit(0);
}

GetOptions(
	"mlssid=s" => \$mlssid,
	"species_name=s" => \$species_name,
	"db_user=s" => \$db_user,
	"db_host=s" => \$db_host,
	"release_version=s" => \$release_version,
	"dnafrags_file=s" => \$dnafrags_file,
);

unless(defined $mlssid && defined $db_user && defined $db_host && defined $release_version && (-f $dnafrags_file)){
	$help->();
	exit(0);
}

Bio::EnsEMBL::Registry->load_registry_from_db(
        -host=>"$db_host", -user=>"$db_user",
        -port=>'3306', -db_version=>"$release_version");

my (%hum_dfs, %aligned_patch);

open(INF, $dnafrags_file) or die;

while(<INF>){
	chomp;
	my($name,$dbID)=split("\t",$_);
	$hum_dfs{$name}=$dbID;
}

my $daf_a = Bio::EnsEMBL::Registry->get_adaptor(
	"$species_name", "otherfeatures", "DnaAlignFeature");

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


my $mlss_pref = $mlssid . "0000000000";
foreach my $ref_name(keys %aligned_patch){
	foreach my $patch_name(keys %{$aligned_patch{$ref_name}}){
                our $arr;
                *arr = \$aligned_patch{$ref_name}{$patch_name};
		foreach my $gab(@{ $arr }){
			my $align_len=$gab->{ref_aln_bases};
			$align_len =~s/[MD]/+/g;
			$align_len = eval $align_len . 0;
			$gab->{ref_aln_bases}=~s/M1D/MD/g;
			$gab->{patch_aln_bases}=~s/M1D/MD/g;
			$gab->{ref_aln_bases}=~s/M0D/M/g; # just in case (should never be used)
			$gab->{patch_aln_bases}=~s/M0D/M/g; # just in case (should never be used)
			my $gab_perc_id = int($gab->{gab_perc_num} / $align_len * 100);
			print join("\t", "GenomicAlignBlock", ($gab->{genomic_align_block_id} + $mlss_pref), 
				$mlssid, '\N', $gab_perc_id, $align_len, '\N'), "\n";
			print join("\t", "GenomicAlign", ($gab->{ref_genomic_align_id} + $mlss_pref), 
				($gab->{genomic_align_block_id} + $mlss_pref), $mlssid, $hum_dfs{ $ref_name }, 
				$gab->{ref_start}, $gab->{ref_end}, $gab->{ref_strand}, $gab->{ref_aln_bases}, "1"), "\n"; 
			print join("\t", "GenomicAlign", ($gab->{patch_genomic_align_id} + $mlss_pref), 
				($gab->{genomic_align_block_id} + $mlss_pref), $mlssid, $hum_dfs{ $patch_name }, 
				$gab->{patch_start}, $gab->{patch_end}, $gab->{patch_strand}, $gab->{patch_aln_bases}, "1"), "\n";
		}
	}
}
