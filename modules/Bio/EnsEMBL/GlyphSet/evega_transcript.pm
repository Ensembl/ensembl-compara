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
  my $type = $transcript->type() || $gene->type();
  $type =~ s/HUMACE-//g;
  my $ExtUrl = EnsEMBL::Web::ExtURL->new($self->{'config'}->{'species'}, $self->species_defs);
  
  my $zmenu = {
    'caption'             => "Vega Gene",
    "00:$id"    => "",
  "01:Gene:$gid"          => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=vega",
    "02:Transcr:$tid"        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=vega",          
    '04:Export cDNA'        => "/@{[$self->{container}{_config_file_name_}]}/exportview?option=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
    "06:Vega curated ($type)"   => '',
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
  my $type = $gene->type();
     $type =~ s/HUMACE-//g;
  my $ExtUrl = EnsEMBL::Web::ExtURL->new($self->{'config'}->{'species'}, $self->species_defs);
  my $zmenu = {
    'caption'             => "Vega Gene",
    "01:Gene:$gid"          => qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=vega),
    "06:Vega curated ($type)"   => '',
    "07:View in Vega" => $ExtUrl->get_url('Vega_gene', $gid),
  };
  return $zmenu;
}

my %legend_map = (
  'protein_coding_KNOWN'    => 'Known gene',
  'protein_coding_NOVEL'    => 'Novel CDS',
  'unclassified_PUTATIVE'   => 'Putative',
  'unclassified_PUTATIVE'   => 'Novel Trans' ,
  'pseudogene_KNOWN'        => 'Pseudogenes' ,
  'processed_pseudogene_KNOWN'  => 'Processed pseudogenes' ,
  'unprocessed_pseudogene_KNOWN'=> 'Unprocessed pseudogenes' ,
  'protein_coding_KNOWN'    => 'Predicted gene' ,
  'Ig_Segment_KNOWN'      => 'Immunoglobulin segment' ,
  'Ig_Pseudogene_segment_KNOWN' => 'Immunoglobulin pseudogene' ,
  'Polymorphic'       => 'Polymorphic'  );

sub text_label {
  my ($self, $gene, $transcript) = @_;
  my $id = $transcript->external_name() || $transcript->stable_id();

  my $Config = $self->{config};
  my $short_labels = $Config->get('_settings','opt_shortlabels');
  unless( $short_labels ){
    my $tt = ( $transcript->biotype ? $transcript->biotype : $gene->biotype ) . '_'. $gene->confidence;
    my $type = $legend_map{$tt} || $tt;
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
    my $type = $legend_map{ $gene->biotype.'_'.$gene->confidence } || $gene->type;
      $id .= " \n$type ";
  }
  return $id;
}

sub features {
  my ($self) = @_;
  my $track = 'evega_transcript';

  if( $self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice")) {
      my $all_slices = $self->{'container'}->get_all_Slices;
      my @all_genes;
      foreach my $this_slice (@{$all_slices}) {
	  push @all_genes, @{$this_slice->get_all_Genes()};
      }
      return \@all_genes;
  }

  if( my $alias = $self->{'config'}->get($track,'db_alias') ){
    return $self->{'container'}->get_all_Genes('otter',$alias);
  } elsif( $self->{'config'}->{'fakecore'} ) {
    return $self->{'container'}->get_all_Genes('otter');
  } else {
    return $self->{'container'}->get_all_Genes('otter','vega');
  }
}

sub legend {
  my ($self, $colours) = @_;
  return ('vega_genes', 1000,
      [
        'Known genes'  => $colours->{'protein_coding_KNOWN'}[0],
        'Novel CDS'    => $colours->{'protein_coding_NOVEL'}[0],
        'Putative'     => $colours->{'unclassified_PUTATIVE'}[0],
        'Novel Trans'  => $colours->{'protein_coding_NOVEL'}[0],
        'Pseudogenes'  => $colours->{'pseudogene_KNOWN'}[0],
        'Processed pseudogenes'  => $colours->{'processed_pseudogene_KNOWN'}[0],
        'Unprocessed pseudogenes'  => $colours->{'unprocessed_pseudogene_KNOWN'}[0],
        'predicted gene'     => $colours->{'protein_coding_PREDICTED'}[0],
        'Immunoglobulin segment' => $colours->{'Ig_segment_KNOWN'}[0],
        'Immunoglobulin pseudogene' => $colours->{'Ig_pseudogene_segment_KNOWN'}[0],
        'Polymorphic' => $colours->{'Polymorphic'}[0],
      ]
  );
}

sub error_track_name { return 'Vega transcripts'; }

1;
