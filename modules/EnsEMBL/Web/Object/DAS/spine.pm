package EnsEMBL::Web::Object::DAS::spine;

use strict;
use warnings;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Object::DAS);
use Data::Dumper;

my $MAX_LEN = 100;

sub Types {
  my $self = shift;

  return [
	  {
	      'REGION' => '*',
	      'FEATURES' => [
			     { 'id' => 'spine'  }
			     ]
			     }
	  ];
}


sub Features {
  my $self = shift;

  $self->{_feature_label} = 'gene';
  my @segments      = $self->Locations;
  my %feature_types = map { $_ ? ($_=>1) : () } @{$self->FeatureTypes  || []};
  my @group_ids     = grep { $_ }               @{$self->GroupIDs      || []};
  my @feature_ids   = grep { $_ }               @{$self->FeatureIDs    || []};

  my @features;

  my $base_url = $self->species_defs->ENSEMBL_BASE_URL;
  if ($base_url =~ /ensembl/) {
      $base_url =~ s/\:\d+//;
  }
  #View templates
  $self->{'templates'} ||= {};
  $self->{'templates'}{'geneview_URL'}  = sprintf( '%s%s/Gene/Summary?g=%%s;db=%%s', $base_url,        $self->species_defs->species_path($self->real_species ));
  $self->{'templates'}{'location_URL'}  = sprintf( '%s%s/Location/View?g=%%s;db=%%s', $base_url,      $self->species_defs->species_path($self->real_species ));
  $self->{'templates'}{'regulation_URL'}  = sprintf( '%s%s/Gene/Regulation?g=%%s;db=%%s',    $base_url,      $self->species_defs->species_path($self->real_species ));
#  $self->{'templates'}{'image_URL'}  = sprintf( '%s%s/Component/Gene/Web/TranscriptsImage?export=png;g=%%s;db=%%s;i_width=400', $base_url,      $self->species_defs->species_path($self->real_species ));
  $self->{'templates'}{'image2_URL'}  = sprintf( '%s%s/Component/Location/Web/MultiBottom?export=png;g=%%s;db=%%s;i_width=750', $base_url,      $self->species_defs->species_path($self->real_species ));
  $self->{'templates'}{'varview_URL'}  = sprintf( '%s%s/Gene/Variation_Gene/Image?g=%%s;db=%%s',    $base_url,      $self->species_defs->species_path($self->real_species ));
  $self->{'templates'}{'compara_URL'}  = sprintf( '%s%s/Gene/Compara_%%s?g=%%s;db=%%s',   $base_url,       $self->species_defs->species_path($self->real_species ));
  $self->{'templates'}{'sequence_URL'}  = sprintf( '%s%s/Gene/Sequence?g=%%s;db=%%s',   $base_url,       $self->species_defs->species_path($self->real_species ));


  my $h =  $self->{data}->{_databases}->get_databases('core', 'variation', 'compara', 'funcgen', 'compara_pan_ensembl');

  my $sversion = $self->species_defs->SITE_RELEASE_VERSION ||  $self->species_defs->ENSEMBL_VERSION;
  my $slabel = $self->species_defs->SITE_NAME ||  $self->species_defs->ENSEMBL_SITE_NAME_SHORT;
  my $sdate =  $self->species_defs->SITE_RELEASE_DATE || $self->species_defs->ENSEMBL_RELEASE_DATE;

  my $enote1 = $self->species_defs->SITE_MISSION || qq{ The Ensembl project produces genome databases for vertebrates and other eukaryotic species, and makes this information freely available online.}; 

  my $enote2 = sprintf qq{
      The current release %s ( %s ) of the %s provides access to the genomic, comparative, functional and variation data from %d species.}, $sversion, $sdate, $slabel, scalar($self->species_defs->valid_species);

  my $ef = {
              'ID'          => "ensembl",
              'LABEL'       => "About $slabel",
              'TYPE'        => 'ensembl-provenance',
              'NOTE' => [ $enote1, $enote2 ],
              'LINK' => [
                         { 'text' => "View more information in $slabel.",
                           'href' => $base_url,
                       }
                         ],
          };




  my $mcimage;

  if (my $cdb = $h->{'core'}) {
      my $ga = $cdb->get_adaptor('Gene');

      foreach my $segment (@segments) {
	  if( ref($segment) eq 'HASH' && $segment->{'TYPE'} eq 'ERROR' ) {
	      push @features, $segment;
	      next;
	  }

	  my $gene_id = $segment->{REGION} or next;
	  
	  my $gene = $ga->fetch_by_stable_id($gene_id);

	  next unless $gene;

	  push @{$self->{_features}{$gene_id}{'FEATURES'}}, $ef;

	  my $description =  $gene->description() ;

	  $description =~ s/\[.+// if ($description);

	  if (length($description) > $MAX_LEN) {
	      $description = substr($description, 0, $MAX_LEN);
	      my $sindex = rindex($description, ' ');
	      $description = substr($description, 0, $sindex). ' ...';
	  }

	  my $gene_name = $gene->display_xref ? $gene->display_xref->display_id : $gene->stable_id;

	  my $f = {
	      'ID'          => "description:".$gene->stable_id,
	      'LABEL'       => $gene_name,
	      'TYPE'        => 'description',
	      'ORIENTATION' => $self->ori($gene->strand),
	      'NOTE' => [ ucfirst($description) ],
	      'LINK' => [
			 { 'text' => "View in $slabel",
			   'href' => sprintf( $self->{'templates'}{'geneview_URL'}, $gene->stable_id, 'core' ),
		       }
			 ],
	  };

	  push @{$self->{_features}{$gene_id}{'FEATURES'}}, $f;
if (0) {
# Dont send the gene summary image - it will be replaced by karyotype image
	  my $fi = {
	      'ID'          => "image:".$gene->stable_id,
	      'LABEL'       => "Image ".$gene_name,
	      'TYPE'        => 'image',
	      'LINK' => [
			 { 'text' => "View the gene summary page in $slabel.",
			   'href' => sprintf( $self->{'templates'}{'image_URL'}, $gene->stable_id, 'core' ),
		       }
			 ],
	      
	  };

	  push @{$self->{_features}{$gene_id}{'FEATURES'}}, $fi;
}


	  $mcimage = {
	      'ID'          => "image:".$gene->stable_id,
	      'LABEL'       => "Image ".$gene_name,
	      'TYPE'        => 'image-block',
	      'LINK' => [
			 { 'text' => "Gene structure.",
			   'href' => sprintf( $self->{'templates'}{'image2_URL'}, $gene->stable_id, 'core' ),
		       }
			 ],
	      
	  };

	  my $notes;

	  push @$notes, sprintf ("%s spans %d bps of %s %s from %d to %d.", $gene_name, ($gene->seq_region_end - $gene->seq_region_start), $gene->slice->coord_system()->name, $gene->slice->seq_region_name, $gene->seq_region_start, $gene->seq_region_end);

	  my $tnum =  scalar(@{ $gene->get_all_Transcripts });
	  my $enum = scalar(@{ $gene->get_all_Exons });

	  push @$notes, sprintf ("%s has %d transcript%s containing a total of %d exon%s on the %s strand.", $gene_name, $tnum, $tnum > 1 ? 's' : '',  $enum, $enum > 1 ? 's' : '', $gene->strand > 0 ? 'forward' : 'reverse' );

	  if ($gene->can('analysis') && $gene->analysis && $gene->analysis->description) {
	      push @$notes, $gene->analysis->description;
	  }

	  my $s1 = {
	      'ID'          => "core_summary:".$gene->stable_id,
	      'LABEL'       => "Gene Information and Sequence",
	      'TYPE'        => 'summary',
	      'NOTE' => $notes,
	      'LINK' => [
			 { 'text' => "View the gene sequence in $slabel.",
			   'href' => sprintf( $self->{'templates'}{'sequence_URL'}, $gene->stable_id, 'core' ),
		       },
			 { 'text' => "View the chromosome region for this gene in $slabel",
			   'href' => sprintf( $self->{'templates'}{'location_URL'}, $gene->stable_id, 'core' ),
		       }
			 ],
	      
	  };

	  push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s1;

	  if (my $vdb = $h->{'variation'}) {
	      my $fs = $gene->feature_Slice();
	      my $snps = $fs->get_all_VariationFeatures;
	      my $notes1;
	      my $snum = scalar (@{ $snps });

	      push @$notes1, sprintf ("%s has %s SNP%s.", $gene_name, $snum || 'no', $snum == 1 ? '' : 's');
	  
	      my $s2 = {
		  'ID'          => "var_summary:".$gene->stable_id,
		  'LABEL'       => "Variations",
		  'TYPE'        => 'summary',
		  'NOTE' => $notes1,
		  'LINK' => $snum > 0 ? [
			     { 'text' => "View sequence variations such as polymorphisms, along with genotypes and disease associations in $slabel.",
			       'href' => sprintf( $self->{'templates'}{'varview_URL'}, $gene->stable_id, 'core' ),
			   }
			     ] : [],
	      
	      };
	      
	      push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s2;
	  }


	  if (my $cmpdb = $h->{'compara_pan_ensembl'} || $h->{'compara'}) {
	      my %homologues;
	      my $member_adaptor = $cmpdb->get_adaptor('Member');
	      my $query_member = $member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE",$gene_id);

	      next unless defined $query_member ;
	      my $homology_adaptor = $cmpdb->get_adaptor('Homology');
#  It is faster to get all the Homologues and discard undesired entries
#  my $homologies_array = $homology_adaptor->fetch_all_by_Member_method_link_type($query_member,$homology_source);
	      my $hmgs = $homology_adaptor->fetch_all_by_Member($query_member);

	      my $hHash ;
	      foreach my $homology (@{$hmgs}){
		  $hHash->{ortholog} += 1 if ($homology->description =~ /ortholog/);
#		  next if ($homology->description =~ /between_species_paralog/);
		  next if ($homology->description =~ /possible_ortholog/);
		  $hHash->{paralog} += 1 if ($homology->description =~ /paralog|gene_split/);
	      }

	      my $notes2;
	      my $onum = $hHash->{ortholog} || 0;

	      push @$notes2, sprintf ("%s has %s orthologue%s.", $gene_name, $onum || 'no', $onum == 1 ? '' : 's' );

	  
	      my $s3 = {
		  'ID'          => "orthologue_summary:".$gene->stable_id,
		  'LABEL'       => "Orthologues",
		  'TYPE'        => 'summary',
		  'NOTE' => $notes2,
		  'LINK' =>  $onum ? [
			     { 'text' => "View homology between species inferred from a gene tree in $slabel.",
			       'href' => sprintf( $self->{'templates'}{'compara_URL'}, 'Ortholog', $gene->stable_id, 'core' ),
			   }
			     ] : [ ],
	      };
	      push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s3;

	      my $pnum = $hHash->{paralog};
	      my $notes3;
	      push @$notes3, sprintf ("%s has %s paralogue%s.", $gene_name, $pnum || 'no', $pnum == 1 ? '' : 's' );
	  
	      my $s4 = {
		  'ID'          => "paralogue_summary:".$gene->stable_id,
		  'LABEL'       => "Paralogues",
		  'TYPE'        => 'summary',
		  'NOTE' => $notes3,
		  'LINK' => $pnum ? [
			     { 'text' => "View homology arising from a duplication event, inferred from a gene tree in $slabel.",
			       'href' => sprintf( $self->{'templates'}{'compara_URL'}, 'Paralog', $gene->stable_id, 'core' ),
			   }
			     ] : [ ],
	      };
	      push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s4;


	  }

	  if (my $fgdb = $h->{'funcgen'}) {
	      my $fs = $gene->feature_Slice();
	      my $reg_feat_adaptor = $fgdb->get_adaptor("RegulatoryFeature");
	      my $feats = $reg_feat_adaptor->fetch_all_by_Slice($fs);


	      my $reg_feats = scalar(@{$feats || []});
	      my $notes1;
	      
	      push @$notes1, sprintf ("There %s %s regulatory element%s located in the region of %s.", $reg_feats == 1 ? 'is' : 'are', $reg_feats || 'no', $reg_feats == 1 ? '' : 's', $gene_name);
	  
	      my $s2 = {
		  'ID'          => "fg_summary:".$gene->stable_id,
		  'LABEL'       => "Regulation",
		  'TYPE'        => 'summary',
		  'NOTE' => $notes1,
		  'LINK' => $reg_feats ? [
			     { 'text' => "View the gene regulatory elements, such as promoters, transcription binding sites, and enhancers in $slabel.",
			       'href' => sprintf( $self->{'templates'}{'regulation_URL'}, $gene->stable_id, 'core' ),
			   }
			     ] : [ ],
	      
	      };
	      push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s2;
	  }

	  push @{$self->{_features}{$gene_id}{'FEATURES'}}, $mcimage if $mcimage;
      }
  }

  foreach my $geneid (keys %{$self->{_features} || {}}) {
      push @features, {
	  FEATURES => $self->{_features}{$geneid}{'FEATURES'},
	  REGION=> $geneid
	  };
  }

  return \@features;
}

1;

