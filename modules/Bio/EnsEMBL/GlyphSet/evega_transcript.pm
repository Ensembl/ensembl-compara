package Bio::EnsEMBL::GlyphSet::evega_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
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
  
  my $zmenu = {
    'caption'             => "Vega Gene",
    "00:$id"    => "",
  "01:Gene:$gid"          => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=vega",
    "02:Transcr:$tid"        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=vega",          
    '04:Export cDNA'        => "/@{[$self->{container}{_config_file_name_}]}/exportview?option=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
    "06:Vega curated ($type)"   => '',
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
  my $zmenu = {
    'caption'             => "Vega Gene",
    "01:Gene:$gid"          => qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=vega),
    "06:Vega curated ($type)"   => '',
  };
  return $zmenu;
}

my %legend_map = ( 'protein_coding_KNOWN'         => 'Curated known gene',
  'protein_coding_NOVEL'       => 'Curated novel CDS',
  'unclassified_PUTATIVE'        => 'Curated putative',
  'unclassified_PUTATIVE'    => 'Curated novel Trans' ,
  'pseudogene_KNOWN'      => 'Curated pseudogenes' ,
  'processed_pseudogene_KNOWN'  => 'Curated processed pseudogenes' ,
  'unprocessed_pseudogene_KNOWN'=> 'Curated unprocessed pseudogenes' ,
  'protein_coding_KNOWN'    => 'Curated predicted gene' ,
  'Ig_Segment_KNOWN'      => 'Curated Immunoglobulin segment' ,
  'Ig_Pseudogene_segment_KNOWN' => 'Curated Immunoglobulin pseudogene' ,
  'Polymorphic'       => 'Curated Polymorphic'  );

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
        'Curated known genes'  => $colours->{'protein_coding_KNOWN'}[0],
        'Curated novel CDS'    => $colours->{'protein_coding_NOVEL'}[0],
        'Curated putative'     => $colours->{'unclassified_PUTATIVE'}[0],
        'Curated novel Trans'  => $colours->{'protein_coding_NOVEL'}[0],
        'Curated pseudogenes'  => $colours->{'pseudogene_KNOWN'}[0],
        'Curated processed pseudogenes'  => $colours->{'processed_pseudogene_KNOWN'}[0],
        'Curated unprocessed pseudogenes'  => $colours->{'unprocessed_pseudogene_KNOWN'}[0],
        'Curated predicted gene'     => $colours->{'protein_coding_PREDICTED'}[0],
        'Curated Immunoglobulin segment' => $colours->{'Ig_segment_KNOWN'}[0],
        'Curated Immunoglobulin pseudogene' => $colours->{'Ig_pseudogene_segment_KNOWN'}[0],
        'Curated Polymorphic' => $colours->{'Polymorphic'}[0],
      ]
  );
}

sub error_track_name { return 'Vega transcripts'; }

1;
