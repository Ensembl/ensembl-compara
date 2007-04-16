package Bio::EnsEMBL::GlyphSet::rna_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
  my $self = shift;
  return $self->{'config'}->{'_draw_single_Transcript'} || 'ncRNA';
}

sub colours {
  my $self = shift;
  return $self->{'config'}->get('rna_transcript','colours');
}

sub transcript_type {
  my $self = shift;
  return 'ncRNA';
}

sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;

  my $highlight = undef;
  my $type = $transcript->biotype() || $gene->biotype();
  my $colour = $colours->{ ($type =~ /pseudo/i ? 'rna-pseudo' : 'rna-real'). ($transcript->status||$gene->status) };

  if(exists $highlights{lc($transcript->stable_id)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($transcript->external_name)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($gene->stable_id)}) {
    $highlight = $colours->{'hi'};
  }

  return (@$colour, $highlight); 
}

sub gene_colour {
  my ($self, $gene, $colours, %highlights) = @_;

  my $highlight = undef;
  my $type = $gene->biotype();
  my $colour = $colours->{ ($type =~ /pseudo/i ? 'rna-pseudo' : 'rna-real').$gene->status };

  if(exists $highlights{lc($gene->stable_id)}) {
    $highlight = $colours->{'hi'};
  }

  return (@$colour, $highlight);
}

sub href {
  my ($self, $gene, $transcript, %highlights ) = @_;

  my $tid = $transcript->stable_id();
  my $gid = $gene->stable_id();

  return ($self->{'config'}->get('rna_transcript','_href_only') eq '#tid' && exists $highlights{lc($gene->stable_id)} ) ?
     "#$tid" :
     qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid);
}

sub gene_href {
  my ($self, $gene,  %highlights ) = @_;

  my $gid = $gene->stable_id();
  return ($self->{'config'}->get('rna_transcript','_href_only') eq '#gid' && exists $highlights{lc($gene->stable_id)} ) ?
    "#$gid" :
    qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid);
}


sub zmenu {
  my ($self, $gene, $transcript) = @_;
  my $tid = $transcript->stable_id();
  my $translation = $transcript->translation;
  my $pid = $translation->stable_id() if $translation;
  my $gid = $gene->stable_id();
  my $id   = $transcript->external_name() eq '' ? $tid : $transcript->external_name();
  my $type = $transcript->biotype() || $gene->biotype();
  
  my $zmenu = {
    'caption'             => $type.' ('.($transcript->status||$gene->status).')',
    "00:$id"    => "",
    "01:Gene:$gid"          => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid",
    "02:Transcr:$tid"        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid",          
    '04:Export cDNA'        => "/@{[$self->{container}{_config_file_name_}]}/exportview?options=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
    "06:$type"   => '',
  };
  
  if($pid) {
  $zmenu->{"03:Peptide:$pid"}=
    qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid);
  $zmenu->{'05:Export Peptide'}=
    qq(/@{[$self->{container}{_config_file_name_}]}/exportview?options=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid);  
  }
  
  return $zmenu;
}

sub gene_zmenu {
  my ($self, $gene ) = @_;
  my $gid = $gene->stable_id();
  my $id   = $gene->external_name() eq '' ? $gid : $gene->external_name();
  my $type = $gene->biotype();
  my $zmenu = {
    'caption'             => $type.' ('.($gene->status).')',
    "01:Gene:$gid"          => qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid),
    "06:$type"   => '',
  };
  return $zmenu;
}

my %legend_map = ( 'Known'         => 'Curated known gene',
  'Novel_CDS'       => 'Curated novel CDS',
  'Putative'        => 'Curated putative',
  'Novel_Transcript'    => 'Curated novel Trans' ,
  'Pseudogene'      => 'Curated pseudogenes' ,
  'Processed_pseudogene'  => 'Curated processed pseudogenes' ,
  'Unprocessed_pseudogene'=> 'Curated unprocessed pseudogenes' ,
  'Predicted_Gene'    => 'Curated predicted gene' ,
  'Ig_Segment'      => 'Curated Immunoglobulin segment' ,
  'Ig_Pseudogene_Segment' => 'Curated Immunoglobulin pseudogene' ,
  'Polymorphic'       => 'Curated Polymorphic'  );

sub text_label {
  my ($self, $gene, $transcript) = @_;
  my $id = $transcript->external_name() || $transcript->stable_id();

  my $Config = $self->{config};
  my $short_labels = $Config->get('_settings','opt_shortlabels');
  unless( $short_labels ){
  my $type = $legend_map{$transcript->biotype} || $transcript->biotype;
     $type .= ' ('.($transcript->status||$gene->status).')';
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
    my $type = $legend_map{$gene->biotype} || $gene->biotype;
       $type .= ' ('.($gene->status).')';
      $id .= " \n$type ";
  }
  return $id;
}

sub features {
  my ($self) = @_;
  my @T =  @{$self->{'container'}->get_all_Genes('ncRNA')||[]};
  push @T, @{$self->{'container'}->get_all_Genes('miRNA')||[]};
  push @T, @{$self->{'container'}->get_all_Genes('tRNA')||[]};
  return \@T;
}

sub legend {
  my ($self, $colours) = @_;
  return ('ncRNA', 1000,
      [
        'RNA (Known)'		=> $colours->{'rna-realKNOWN'}[0],
        'RNA (Predicted)'       => $colours->{'rna-realPREDICTED'}[0],
        'RNA (Novel)'		=> $colours->{'rna-realNOVEL'}[0],
        'RNA pseudogene (Known)'=> $colours->{'rna-psuedoKNOWN'}[0],
        'RNA pseudogene (Novel)'=> $colours->{'rna-psuedoNOVEL'}[0],
      ]
  );
}

sub error_track_name { return 'ncRNAs'; }

1;
