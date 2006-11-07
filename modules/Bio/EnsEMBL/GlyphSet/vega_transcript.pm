package Bio::EnsEMBL::GlyphSet::vega_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::evega_transcript;

@ISA = qw(Bio::EnsEMBL::GlyphSet::evega_transcript);

our %VEGA_TO_SHOW_ON_VEGA;

sub features {
    my ($self) = @_;
    
    my $genes = $self->{'container'}->get_all_Genes($self->my_config('logic_name'));
    
    # make a list of gene types for the legend
    foreach my $g (@$genes) {
        my $status = $g->status;
        my $biotype = $g->biotype;
        $VEGA_TO_SHOW_ON_VEGA{"$biotype".'_'."$status"}++;
    }
 
    return $genes;
}

sub my_label {
    my $self = shift;
    return $self->my_config('label');
}

sub colours {
    my $self = shift;
    return $self->{'config'}->get($self->check, 'colours');
}

sub href {
    my ($self, $gene, $transcript, %highlights) = @_;
    my $gid = $gene->stable_id();
    my $tid = $transcript->stable_id();
    my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
    return ( $self->{'config'}->get($self->check, '_href_only') eq '#tid' && exists $highlights{lc($gene->stable_id)} ) ?
        "#$tid" : 
        qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core);
}

sub gene_href {
    my ($self, $gene, %highlights) = @_;
    my $gid = $gene->stable_id();
    return ($self->{'config'}->get($self->check,'_href_only') eq '#gid' && exists $highlights{lc($gene->stable_id)} ) ?
        "#$gid" :
        qq(/@{[$self->{container}{_config_file_name_}]}/geneview?db=core;gene=$gid);
}

=head2 get_hap_alleles_and_orthologs_urls

 Arg[1]	     : B::E::gene
 Example     : $href = $self->get_hap_alleles_and_orthologs($gene)
 Description : called by zmenu, used to get details of all orthogs and alleles for the gene of focus and to generate
               a URL to add to the zmenu
 Return type : string on success, undef on failure (ie none found)

=cut

sub get_hap_alleles_and_orthologs_urls {
	my ($self, $gene) = @_;
	my $script_name        = $ENV{'ENSEMBL_SCRIPT'};	
	my $primary_slice      = $self->{'config'}{'primary_slice'}; 
	my $primary_slice_name = $self->{'config'}{'primary_slice'}{'seq_region_name'};
	my $this_species       = $self->{'container'}{'_config_file_name_'};
	my $this_gene_id       = $gene->stable_id;
	my $this_slice_name    = $gene->seq_region_name;

	##get all slices and all species on the display
	my @all_slices;
	my %species_shown;
	#secondary slices and species
	if (my @T =  @{ $self->{'config'}->{'other_slices'}||[]}) {
		foreach my $T ( @T ) {
			push @all_slices,$T->{'location'}[1]{'_object'};
			$species_shown{ $T->{'location'}[1]{'_object'}{'real_species'} }++;
		}
	}
	#primary slice and species
	unless (grep {$_->{'seq_region_name'} eq $primary_slice_name} @all_slices) {
		push @all_slices, $primary_slice;
		$species_shown{ $primary_slice->{'real_species'} }++;
	}

	my $href;
	my $no = 1;

	##get haplotype alleles and add to the URL
	if ( my $alleles = $gene->get_all_alt_alleles ) {
		foreach my $allele (@{$alleles}) {
			my $allele_location = $allele->seq_region_name;
			#pull out the haplotype allele for each slice on the display
			foreach my $slice_shown (@all_slices) {
				if ($slice_shown->{'seq_region_name'} eq $allele_location) {						
					#initialise the URL if this is the first allele found
					$href = "/".$this_species."/".$script_name."?gene=".$this_gene_id if $no==1;

					$href .= ";s$no=".$slice_shown->{'real_species'}.";g$no=".$allele->stable_id;
					$no++;
				}
			}
		}
	}

	#get details of all orthologs
	my @orth_details;
	foreach my $other_species (keys %species_shown) {
		next if ($this_species eq $other_species);
		eval {
		if (my @orthologs = $self->get_ortholog_gene_details($this_gene_id,$other_species)) {
			foreach my $ortholog (@orthologs) {
				#save details of orthologs on the slices shown on the display
			SLICE:
				foreach my $t (@all_slices) {
					next SLICE if ($this_species eq $t->{'real_species'});
						eval {
							if ( my $ortholog_slice = $t->{'slice'}{'adaptor'}->fetch_by_gene_stable_id($ortholog->[0]) ) {
								push @orth_details, {
											 species          => $t->{'real_species'},
											 slice_name       => $ortholog_slice->{'seq_region_name'},
											 gene_start       => $ortholog_slice->{'start'},
											 gene_end         => $ortholog_slice->{'end'},
											 ortholog_id      => $ortholog->[0],
											 ortholog_details => $ortholog->[1],
											};
							}
					};
				}
			}
		}
	}
	}

	#check each slice to:
	#(i) get the context (needed so as to not change the size of the region displayed after navigation)
#######

	#this block of code adds an amount of  padding dependent on the size of the slice
	#however not actually used since it probably leads to confusion and also fails with very small slices

	#(ii) see if there's an ortholog on it, and if so add to the URL
	my $context;
	foreach my $slice (@all_slices) {
		#(i) get the slice padding at each end of this gene
		if ($this_slice_name eq $slice->{'seq_region_name'}) {
			my $this_slice_length = $slice->{'seq_region_end'} - $slice->{'seq_region_start'} + 1;
			my $gene_length = $gene->length;
			$context = int (($this_slice_length - $gene_length) / 2);
		}
		#(ii) get orthologs on this slice and add to the URL
		my $poss_orths;
		my $extra_href;
		foreach my $orth (@orth_details) {
			next unless ( ($slice->{'real_species'} eq $orth->{'species'}) && ($slice->{'seq_region_name'} eq $orth->{'slice_name'}) );
			#initialise the url if it's not been started with a haplotype allele
			$href = "/".$this_species."/".$script_name."?gene=".$this_gene_id unless ($href);
			push @$poss_orths, $orth;
		}
		if ( defined $poss_orths ) {
			$extra_href = best_orthologue_url($slice,$poss_orths,$no);
			$href .= $extra_href;
			$no++;
		}
	}
	#add the context argument to the URL if either orthologs or haplotype alleles have been found	
	#	$href .= ";context=$context" if ($href);
######	

	#instead just set the context to a straight 1000
	$href .= ";context=1000" if ($href);
	return $href;
}

=head2 get_ortholog_gene_details

 Arg[1]	     : Gene stable_id
 Arg[2]	     : species
 Example     : @orthologs = $self->get_ortholog_gene_details($this_gene_id,$other_species)
 Description : gets orthologs in a particular species for a given stable_id
 Return type : array of array_refs (ortholog stable id and properties such as score)

=cut

sub get_ortholog_gene_details {
	my( $self, $gene_id, $species ) = @_;
	Bio::EnsEMBL::Registry->add_alias("Multi","compara");
	my $compara_db = Bio::EnsEMBL::Registry->get_DBAdaptor("compara","compara");
	my $ma         = $compara_db->get_MemberAdaptor;
	my $qy_member  = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_id);
	return () unless (defined $qy_member);
	my $ha = $compara_db->get_HomologyAdaptor;
	my @orthologs;
	foreach my $homology (@{$ha->fetch_by_Member_paired_species($qy_member, $species)}){
		foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
			my ($member, $attribute) = @{$member_attribute};
			my $member_stable_id = $member->stable_id;
			next if ($member_stable_id eq $qy_member->stable_id);
			push @orthologs, [$member_stable_id,$attribute];
		}
	}
	return @orthologs;
}

=head2 best_ortholog_url

 Arg[1]	     : B::E::Slice (corresponding to the region displayed in mcv)
 Arg[2]	     : listref
 Arg[3]      : string
 Example     : $extra_href = best_orthologue_url($slice,$poss_orths,$no)
 Description : looks at a set of orthologs (in an arbritrary data structure) and finds the 'best one':
               (i) if only one on the chromosome then uses that
               (ii) otherwise if there are some on the slice shown in mcv then uses the one nearest to the middle of that slice
               (iii) if there are none on slice shown then uses the one wit the best 'score'
 Return type : string (URL to pastes into zmenu)

=cut

sub best_orthologue_url {
	my ($slice,$poss_orths,$no) = @_;
	my $best_orth;
	my $extra_href;
	#if there's only one orthologue for this slice then add it to the URL
	if ( scalar(@$poss_orths) == 1 )  {
		$extra_href = ";s$no=".$slice->{'real_species'}.";g$no=".$poss_orths->[0]{'ortholog_id'};
	}
	#if there's more than one then 
	#(i)if there's some on the slice displayed then use the nearest,
	#(ii)use the one with the best score
	#(ideally should use 'score' from peptide_align feature for no ii,
	#however this table is not cleaned up in the vega self-compara so don't!)
	else {
		my $none_on_slice_display = 1;
		foreach my $orth (@$poss_orths) {
			#is this ortholog on the slice ?
			if ( ( ($orth->{'gene_end'} > $slice->{'seq_region_start'})
				  && ($orth->{'gene_start'} < $slice->{'seq_region_end'}) )
				 ||
				 ( ($orth->{'gene_start'} < $slice->{'seq_region_end'})
				  && ($orth->{'gene_end'} > $slice->{'seq_region_start'}) ) ) {
				$best_orth = ['','',100000000] if ($none_on_slice_display);
				$none_on_slice_display = 0;
				my $gene_midpoint  = $orth->{'gene_end'} - $orth->{'gene_start'};
				my $slice_midpoint = $slice->{'seq_region_end'} - $slice->{'seq_region_start'};
				my $displacement   = abs ($slice_midpoint - $gene_midpoint);
				#find the one closest to the middle of the slice if there's more than one
				$best_orth = [$orth->{'ortholog_id'},$orth->{'species'},$displacement] if ($displacement < $best_orth->[2]);
			}
			#otherwise use the orthologue match (ideally should use 'score' from peptide_align feature for this
			#however this table is not properly cleaned up in vega self-compara so don't use it !)
			elsif ($none_on_slice_display) {				
				my $score = $orth->{'ortholog_details'}{'perc_cov'} * $orth->{'ortholog_details'}{'perc_id'};
				$best_orth = [$orth->{'ortholog_id'},$orth->{'species'},$score] if ($score > $best_orth->[2]);
			}
		}
		$extra_href = ";s$no=".$best_orth->[1].";g$no=".$best_orth->[0];
	}
	return $extra_href;;
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
	my $script_name =  $ENV{'ENSEMBL_SCRIPT'};
	my $tid = $transcript->stable_id();
	my $author;
	if ( defined (@{$transcript->get_all_Attributes('author')}) ) {
		$author =  shift( @{$transcript->get_all_Attributes('author')} )->value || 'unknown';
	}
	else {
		$author =   'not defined';
	}
    my $translation = $transcript->translation;
    my $pid = $translation->stable_id() if $translation;
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : ( $transcript->external_db.": ".$transcript->external_name() );
	my $gtype = $self->format_vega_name($gene);
	my $ttype = $self->format_vega_name($gene,$transcript);
    my $zmenu = {
        'caption' 	               => $self->my_config('zmenu_caption'),
        "00:$id"	               => "",
		"01:Transcript class: ".$ttype => "",
        '02:Gene type: '.$gtype     => "",
		'03:Author: '.$author      => "",
    	"07:Gene:$gid"             => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
        "08:Transcr:$tid"          => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=core",
        "10:Exon:$tid"	           => "/@{[$self->{container}{_config_file_name_}]}/exonview?transcript=$tid;db=core",
        '11:Supporting evidence'   => "/@{[$self->{container}{_config_file_name_}]}/exonview?transcript=$tid;db=core#evidence",
        '12:Export cDNA'           => "/@{[$self->{container}{_config_file_name_}]}/exportview?option=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
    };

    if ($pid) {
        $zmenu->{"09:Peptide:$pid"}   =  "/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid";
        $zmenu->{'13:Export Peptide'} = "/@{[$self->{container}{_config_file_name_}]}/exportview?option=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid";
    }

	if (my $ccds_att = $transcript->get_all_Attributes('ccds')->[0]) {
		my $id = $ccds_att->value;
		$zmenu->{"04:CCDS:$id"} = $self->ID_URL( 'CCDS', $id );
	}

	if ($script_name eq 'multicontigview') {
		if (my $href = $self->get_hap_alleles_and_orthologs_urls($gene)) {
			$zmenu->{"05:Realign display around this gene"} =  "$href";
		}
	}



    return $zmenu;
}

sub gene_zmenu {
    my ($self, $gene) = @_;
	my $script_name =  $ENV{'ENSEMBL_SCRIPT'};
    my $gid = $gene->stable_id();
    my $id   = $gene->external_name() eq '' ? $gid : $gene->external_name();
	my $type = $self->format_vega_name($gene);
	my $author;
	if ( defined (@{$gene->get_all_Attributes('author')}) ) {
		$author =  shift( @{$gene->get_all_Attributes('author')} )->value || 'unknown';
	}
	else {
		$author =   'not defined';
	}
    my $zmenu = {
        'caption' 	             => $self->my_config('zmenu_caption'),
        "00:$id"	             => "",
        '01:Gene Type: ' . $type => "",
		'02:Author: '.$author    => "",
        "04:Gene:$gid"           => qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core),
    };
	if ($script_name eq 'multicontigview') {
		if (my $href = $self->get_hap_alleles_and_orthologs_urls($gene)) {
			$zmenu->{"03:Realign display around this gene"} =  "$href";
		}
	}
    return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    my $id = $transcript->external_name() || $transcript->stable_id();
    my $Config = $self->{config};
    my $short_labels = $Config->get('_settings','opt_shortlabels');
    unless( $short_labels ){
        my $type = $self->format_vega_name($gene,$transcript);
        $id .= " \n$type ";
    }
    return $id;
}

sub gene_text_label {
    my ($self, $gene) = @_;
    my $id = $gene->external_name() || $gene->stable_id();
    my $Config = $self->{config};
    my $short_labels = $Config->get('_settings','opt_shortlabels');
    unless( $short_labels ){
        my $type = $self->format_vega_name($gene);
        $id .= " \n$type ";
    }
    return $id;
}

sub legend {
    my ($self, $colours) = @_;
	my $labels;
	if (%VEGA_TO_SHOW_ON_VEGA) {
		foreach my $k (keys %VEGA_TO_SHOW_ON_VEGA) {
			if (@{$colours->{$k}}) {
				push @$labels,$colours->{$k}[1]; 
				push @$labels,$colours->{$k}[0]; 
			} else {
				warn "WARNING - no colour map entry for $k";
			}
		}
		return ('genes',1000,$labels);
	} else {
		warn "WARNING - using default colour map";
		return ('genes',1000,
				['Known Protein coding'           => $colours->{'protein_coding_KNOWN'}[0],
				 'Novel Protein coding'           => $colours->{'protein_coding_NOVEL'}[0],
				 'Novel Processed transcript'     => $colours->{'processed_transcript_NOVEL'}[0],
				 'Putative Processed transcript'  => $colours->{'processed_transcript_PUTATIVE'}[0],
				 'Novel Pseudogene'               => $colours->{'pseudogene_NOVEL'}[0],
				 'Novel Processed pseudogenes'    => $colours->{'processed_pseudogene_NOVEL'}[0],
				 'Novel Unprocessed pseudogenes'  => $colours->{'unprocessed_pseudogene_NOVEL'}[0],
				 'Predicted Protein coding'       => $colours->{'protein_coding_PREDICTED'}[0],
				 'Novel Ig segment'               => $colours->{'Ig_segment_NOVEL'}[0],
				 'Novel Ig pseudogene'            => $colours->{'Ig_pseudogene_segment_NOVEL'}[0],
				]
			   );
	}
}

sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;
  my $highlight = undef;
  my $type = $gene->biotype.'_'.$gene->status;
  my @colour = @{$colours->{$type}||['black','transcript']};
  if(exists $highlights{lc($transcript->stable_id)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($transcript->external_name)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($gene->stable_id)}) {
    $highlight = $colours->{'hi'};
  } elsif( my $ccds_att = $transcript->get_all_Attributes('ccds')->[0] ) {
    $highlight = $colours->{'ccdshi'};
  }

  return (@colour, $highlight); 
}

sub error_track_name { 
    my $self = shift;
    return $self->my_config('track_label');
}

1;


