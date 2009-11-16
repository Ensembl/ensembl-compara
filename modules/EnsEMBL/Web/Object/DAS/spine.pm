package EnsEMBL::Web::Object::DAS::spine;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

use CGI qw(escapeHTML);

use Data::Dumper;

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
  $self->{'templates'}{'image_URL'}  = sprintf( '%s%s/Component/Gene/Web/TranscriptsImage?export=png;g=%%s;db=%%s;i_width=400', $base_url,      $self->species_defs->species_path($self->real_species ));
  $self->{'templates'}{'varview_URL'}  = sprintf( '%s%s/Gene/Variation_Gene/Image?g=%%s;db=%%s',    $base_url,      $self->species_defs->species_path($self->real_species ));
  $self->{'templates'}{'compara_URL'}  = sprintf( '%s%s/Gene/Compara_%%s?g=%%s;db=%%s',   $base_url,       $self->species_defs->species_path($self->real_species ));


  my $h =  $self->{data}->{_databases}->get_databases('core', 'variation', 'compara', 'funcgen');

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

	  my $description =  escapeHTML( $gene->description() );
	  $description =~ s/\(.+//;

	  my $f = {
	      'ID'          => "description:".$gene->stable_id,
	      'LABEL'       => $gene->display_xref->display_id,
	      'TYPE'        => 'description',
	      'ORIENTATION' => $self->ori($gene->strand),
	      'NOTE' => [ $description ],
	      'LINK' => [
			 { 'text' => 'Ensembl Gene View',
			   'href' => sprintf( $self->{'templates'}{'geneview_URL'}, $gene->stable_id, 'core' ),
		       }
			 ],
	  };

	  push @{$self->{_features}{$gene_id}{'FEATURES'}}, $f;

	  my $gene_name = $gene->display_xref->display_id;

	  my $fi = {
	      'ID'          => "image:".$gene->stable_id,
	      'LABEL'       => "Image ".$gene_name,
	      'TYPE'        => 'image',
	      'LINK' => [
			 { 'text' => 'Gene Image',
			   'href' => sprintf( $self->{'templates'}{'image_URL'}, $gene->stable_id, 'core' ),
		       }
			 ],
	      
	  };

	  push @{$self->{_features}{$gene_id}{'FEATURES'}}, $fi;



	  my $notes;
	  push @$notes, sprintf ("%s spans %d bp of %s %s from %d to %d", $gene_name, ($gene->seq_region_end - $gene->seq_region_start), $gene->slice->coord_system()->name, $gene->slice->seq_region_name, $gene->seq_region_start, $gene->seq_region_end);
	  push @$notes, sprintf ("%s has %d exons", $gene_name, scalar(@{ $gene->get_all_Exons }));
	  push @$notes, sprintf ("%s has %d transcripts", $gene_name, scalar(@{ $gene->get_all_Transcripts }));

	  my $s1 = {
	      'ID'          => "core_summary:".$gene->stable_id,
	      'LABEL'       => "Gene Summary ",
	      'TYPE'        => 'summary',
	      'NOTE' => $notes,
	      'LINK' => [
			 { 'text' => 'Location View',
			   'href' => sprintf( $self->{'templates'}{'location_URL'}, $gene->stable_id, 'core' ),
		       }
			 ],
	      
	  };

	  push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s1;

	  if (my $vdb = $h->{'variation'}) {
	      my $fs = $gene->feature_Slice();
	      my $snps = $fs->get_all_VariationFeatures;
	      my $notes1;
	      push @$notes1, sprintf ("%s has %d SNPs", $gene_name, scalar(@{ $snps }));
	  
	      my $s2 = {
		  'ID'          => "var_summary:".$gene->stable_id,
		  'LABEL'       => "Variation Summary ",
		  'TYPE'        => 'summary',
		  'NOTE' => $notes1,
		  'LINK' => [
			     { 'text' => 'Variation Summary',
			       'href' => sprintf( $self->{'templates'}{'varview_URL'}, $gene->stable_id, 'core' ),
			   }
			     ],
	      
	      };
	      push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s2;
	  }

	  if (my $cmpdb = $h->{'compara'}) {
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
		  next if ($homology->description =~ /between_species_paralog/);
		  $hHash->{paralog} += 1 if ($homology->description =~ /paralog|gene_split/);
	      }

	      my $notes2;
	      push @$notes2, sprintf ("%s has %d orthologues", $gene_name, $hHash->{ortholog});

	  
	      my $s3 = {
		  'ID'          => "orthologue_summary:".$gene->stable_id,
		  'LABEL'       => "Orthologue Summary",
		  'TYPE'        => 'summary',
		  'NOTE' => $notes2,
		  'LINK' => [
			     { 'text' => 'Orthologues',
			       'href' => sprintf( $self->{'templates'}{'compara_URL'}, 'Ortholog', $gene->stable_id, 'core' ),
			   }
			     ],
	      };
	      push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s3;

	      my $notes3;
	      push @$notes3, sprintf ("%s has %d paralogues", $gene_name, $hHash->{paralog});

	  
	      my $s4 = {
		  'ID'          => "paralogue_summary:".$gene->stable_id,
		  'LABEL'       => "Paralogue Summary",
		  'TYPE'        => 'summary',
		  'NOTE' => $notes3,
		  'LINK' => [
			     { 'text' => 'Paralogues',
			       'href' => sprintf( $self->{'templates'}{'compara_URL'}, 'Paralog', $gene->stable_id, 'core' ),
			   }
			     ],
	      };
	      push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s4;


	  }

	  if (my $fgdb = $h->{'funcgen'}) {
	      my $fs = $gene->feature_Slice();
	      my $reg_feat_adaptor = $fgdb->get_adaptor("RegulatoryFeature");
	      my $feats = $reg_feat_adaptor->fetch_all_by_Slice($fs);


	      my @reg_feats = @{$feats || []};
	      my $notes1;
	      push @$notes1, sprintf ("There are %d regulatory elements located in the region of %s", scalar(@reg_feats), $gene_name);
	  
	      my $s2 = {
		  'ID'          => "fg_summary:".$gene->stable_id,
		  'LABEL'       => "Functional Summary",
		  'TYPE'        => 'summary',
		  'NOTE' => $notes1,
		  'LINK' => [
			     { 'text' => 'Regulation',
			       'href' => sprintf( $self->{'templates'}{'regulation_URL'}, $gene->stable_id, 'core' ),
			   }
			     ],
	      
	      };
	      push @{$self->{_features}{$gene_id}{'FEATURES'}}, $s2;
	  }


      }
  }

  push @features, values %{ $self->{'_features'} };

  return \@features;
}

1;

