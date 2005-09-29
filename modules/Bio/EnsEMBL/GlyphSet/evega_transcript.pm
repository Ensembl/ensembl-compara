package Bio::EnsEMBL::GlyphSet::evega_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
use EnsEMBL::Web::ExtURL;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
  my $self = shift;
  return $self->{'config'}->{'_draw_single_Transcript'} || 'Vega trans.';
}

sub colours {
  my $self = shift;
  return $self->{'config'}->get('evega_transcript','colours');
}

sub transcript_type {
  my $self = shift;
  return 'vega';
}

sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;

  my $highlight = undef;
  my $type = $transcript->type() ? $transcript->type.'_'.$gene->confidence :  $gene->biotype.'_'.$gene->confidence;
  # $type =~ s/HUMACE-//g;
  my $colour = $colours->{$type}[0] || 'black';

  if(exists $highlights{lc($transcript->stable_id)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($transcript->external_name)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($gene->stable_id)}) {
    $highlight = $colours->{'hi'};
  }

  return ($colour, $highlight); 
}

sub gene_colour {
  my ($self, $gene, $colours, %highlights) = @_;

  my $highlight = undef;
  my $type = $gene->biotype."_".$gene->confidence;
  $type =~ s/HUMACE-//g;
  my $colour = $colours->{$type}[0];

  if(exists $highlights{lc($gene->stable_id)}) {
    $highlight = $colours->{'hi'};
  }

  return ($colour, $highlight);

}
sub href {
  my ($self, $gene, $transcript, %highlights ) = @_;

  my $tid = $transcript->stable_id();
  my $gid = $gene->stable_id();

  return ($self->{'config'}->get('evega_transcript','_href_only') eq '#tid' && exists $highlights{lc($gene->stable_id)} ) ?
     "#$tid" :
     qq(/@{[$self->{container}{_config_file_name_}]}/geneview?db=vega;gene=$gid);
}

sub gene_href {
  my ($self, $gene,  %highlights ) = @_;

  my $gid = $gene->stable_id();
  return ($self->{'config'}->get('evega_transcript','_href_only') eq '#gid' && exists $highlights{lc($gene->stable_id)} ) ?
    "#$gid" :
    qq(/@{[$self->{container}{_config_file_name_}]}/geneview?db=vega;gene=$gid);
}

sub zmenu {
  my ($self, $gene, $transcript) = @_;
  my $tid = $transcript->stable_id();
  my $translation = $transcript->translation;
  my $pid = $translation->stable_id() if $translation;
  my $gid = $gene->stable_id();
  my $id   = $transcript->external_name() eq '' ? $tid : $transcript->external_name();
  my $type = $self->format_vega_name($gene,$transcript);
  $type =~ s/HUMACE-//g;
  my $ExtUrl = EnsEMBL::Web::ExtURL->new($self->{'config'}->{'species'}, $self->species_defs);
  
  my $zmenu = {
    'caption'             => "Vega Gene",
    "00:$id"    => "",
  "01:Gene:$gid"          => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=vega",
    "02:Transcr:$tid"        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=vega",          
    '04:Export cDNA'        => "/@{[$self->{container}{_config_file_name_}]}/exportview?option=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
    "06:$type"   => '',
    "07:View in Vega" => $ExtUrl->get_url('Vega_gene', $gid),
  };
  
  if($pid) {
  $zmenu->{"03:Peptide:$pid"}=
    qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid;db=vega);
  $zmenu->{'05:Export Peptide'}=
    qq(/@{[$self->{container}{_config_file_name_}]}/exportview?option=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid);  
  }
  
  return $zmenu;
}


sub gene_zmenu {
  my ($self, $gene ) = @_;
  my $gid = $gene->stable_id();
  my $id   = $gene->external_name() eq '' ? $gid : $gene->external_name();
  my $type = $self->format_vega_name($gene);
  $type =~ s/HUMACE-//g;
  my $ExtUrl = EnsEMBL::Web::ExtURL->new($self->{'config'}->{'species'}, $self->species_defs);
  my $zmenu = {
    'caption'             => "Vega Gene",
    "01:Gene:$gid"          => qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=vega),
    "06:$type"   => '',
    "07:View in Vega" => $ExtUrl->get_url('Vega_gene', $gid),
  };
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

our $VEGA_TO_SHOW_ON_ENS;

sub features {
  my ($self) = @_;
  my $track = 'evega_transcript';

  if( my $alias = $self->{'config'}->get($track,'db_alias') ){
	  my $genes = $self->{'container'}->get_all_Genes('otter',$alias);
	  $VEGA_TO_SHOW_ON_ENS = [@$genes];
	  return $genes;
  } elsif( $self->{'config'}->{'fakecore'} ) {
	  my $genes = $self->{'container'}->get_all_Genes('otter');
	  $VEGA_TO_SHOW_ON_ENS = [@$genes];
	  return $genes;
  } else {
	  my $genes = $self->{'container'}->get_all_Genes('otter','vega');
	  $VEGA_TO_SHOW_ON_ENS = [@$genes];
	  return $genes;
  }
}

sub legend {
	my ($self, $colours) = @_;
	my %gtypes;

	if (defined $VEGA_TO_SHOW_ON_ENS) {
		foreach my $gene (@$VEGA_TO_SHOW_ON_ENS){
			my $type = $gene->biotype.'_'.$gene->status;
			$gtypes{$type}++;
		}
		my $labels;
		foreach my $k (keys %gtypes) {
			if (@{$colours->{$k}}) {
				push @$labels,$colours->{$k}[1]; 
				push @$labels,$colours->{$k}[0];
			} else {
				warn "WARNING - no colour map entry for $k";
			}
		}
		return ('vega_genes', 1000, $labels);
	} else {
		warn "WARNING - using default colour map";
		return ('vega_genes', 1000,
				[
				 'Known Protein coding'           => $colours->{'protein_coding_KNOWN'}[0],
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

sub error_track_name { return 'Vega transcripts'; }


1;
