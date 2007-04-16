package Bio::EnsEMBL::GlyphSet::gsten_transcript;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::GlyphSet_transcript;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
  my $self = shift;
  return $self->{'config'}->{'_draw_single_Transcript'} || $self->{'config'}->{'geneid'} || "Genoscope trans.";
}

sub colours {
  my $self = shift;
  my $Config = $self->{'config'};
  return $Config->get('gsten_transcript','colours');
}

sub features {
  my ($self) = @_;
  my $track = 'gsten_transcript';
  my $slice = $self->{'container'};
  my $sp = $self->{'_config_file_name_'};
  my @analyses = ( 'GSTEN', 'HOX', 'CYT' );
  my $db_alias = $self->{'config'}->get($track,'db_alias') || '';
  my @genes;
  foreach my $analysis( @analyses ){
    push @genes, @{ $slice->get_all_Genes( $analysis, $db_alias||() ) }
  }
  return [@genes];
}


sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;
  my $translation = $transcript->translation;
  my $translation_id = $translation ? $translation->stable_id : '';

  my $genecol;
  if( $gene->type eq 'Genoscope_predicted' ) {
    $genecol = '_GSTEN';
  } else {
    $genecol = '_HOX' ;
  }

  my $highlight = undef;
  if(exists $highlights{lc($transcript->stable_id)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($transcript->external_name)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($gene->stable_id)}) {
    $highlight = $colours->{'hi'};
  }
    
  return (@{$colours->{$genecol}}, $highlight);
}

sub gene_colour {
  my ($self, $gene, $colours, %highlights) = @_;
  my $genecol;  $colours->{ "_".$gene->external_status }[0];

  if( $gene->type eq 'Genoscope_predicted' ) {
    $genecol = '_GSTEN';
  } else {
    $genecol = '_HOX' ;
  }

  my $highlight = undef;
  if(exists $highlights{lc($gene->stable_id)}) {
    $highlight = $colours->{'hi'};
  }

  return (@{$colours->{$genecol}}, $highlight);
}

sub href {
  my ($self, $gene, $transcript, %highlights ) = @_;

  my $gid = $gene->stable_id();
  my $tid = $transcript->stable_id();
  
  my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
  return ( $self->{'config'}->get('gsten_transcript','_href_only') eq '#tid' && exists $highlights{lc($gene->stable_id)} ) ?
    "#$tid" : 
    qq(/@{[$self->{container}{_config_file_name_}]}/$script_name?gene=$gid);

}

sub gene_href {
  my ($self, $gene, %highlights ) = @_;

  my $gid = $gene->stable_id();

  my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
  return ( $self->{'config'}->get('gsten_transcript','_href_only') eq '#gid' && exists $highlights{lc($gene->stable_id)} ) ?
    "#$gid" :
    qq(/@{[$self->{container}{_config_file_name_}]}/$script_name?gene=$gid);

}

sub zmenu {
  my ($self, $gene, $transcript) = @_;
  my $translation = $transcript->translation;
  my $tid = $transcript->stable_id();
  my $pid = $translation ? $translation->stable_id() : '';
  my $gid = $gene->stable_id();
  my $zmenu = {
    'caption'             => "Genoscope Gene",
    "00:$tid"		  => "",
    "01:Genoscope gene"   => $gene->type eq 'Genoscope_predicted' ? $self->ID_URL( 'TETRAODON_PRED', $tid ) : $self->ID_URL( 'TETRAODON_ANNOT', $tid ),
    "03:Gene:$gid"        => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
    "04:Transcr:$tid"     => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=core",                	
    '05:Export cDNA'      => "/@{[$self->{container}{_config_file_name_}]}/exportview?options=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
  };
    
  if($pid) {
    $zmenu->{"03:Peptide:$pid"}   = qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid;db=core);
    $zmenu->{'05:Export Peptide'} = qq(/@{[$self->{container}{_config_file_name_}]}/exportview?options=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid);	
  }
  $zmenu->{'05:Gene SNP view'}= "/@{[$self->{container}{_config_file_name_}]}/genesnpview?gene=$gid;db=core" if $ENV{'ENSEMBL_SCRIPT'} =~ /snpview/;
  return $zmenu;
}

sub gene_zmenu {
  my ($self, $gene ) = @_;
  my $gid = $gene->stable_id();
  my $zmenu = {
    'caption'                       => "Genoscope Gene",
    "01:Genescope"                  => $gene->type eq 'Genoscope_prediction' ? $self->ID_URL( 'TETRAODON_PRED', $gid ) : $self->ID_URL( 'TETRAODON_ANNOT', $gid ),
    "02:Gene:$gid"                  => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
  };
  $zmenu->{'05:Gene SNP view'}= "/@{[$self->{container}{_config_file_name_}]}/genesnpview?gene=$gid;db=core" if $ENV{'ENSEMBL_SCRIPT'} =~ /snpview/;
  return $zmenu;
}


sub text_label {
  my ($self, $gene, $transcript) = @_;
  my $tid = $transcript->stable_id();
  my $eid = $transcript->external_name();
  my $id = $eid || $tid;
  my $Config = $self->{config};
  my $short_labels = $Config->get('_settings','opt_shortlabels');

  if( $self->{'config'}->{'_both_names_'} eq 'yes') {
    $id .= $eid ? " ($eid)" : '';
  }
  unless( $short_labels ){
    $id .= "\n";
    if( $gene->type eq 'bacterial_contaminant' ) {
      $id.= 'Bacterial cont.';
    } elsif( $transcript->translation ) {
      $id.= $gene->type eq 'Genoscope_annotated' ? "Genoscope annotated trans" : "Genoscope predicted trans";
    } else {
      $id .= "Genoscope pseudogene";
    }
  }
  return $id;
}

sub gene_text_label {
  my ($self, $gene ) = @_;
  my $gid    = $gene->stable_id;
  my $eid    = $gene->external_name;
  my $id     = $eid || $gid;
  my $Config = $self->{config};
  my $short_labels = $Config->get('_settings','opt_shortlabels');

  if( $self->{'config'}->{'_both_names_'} eq 'yes') {
    $id .= $eid ? " ($eid)" : '';
  }
  unless( $short_labels ){
    $id .= "\n";
    if( $gene->type eq 'bacterial_contaminant' ) {
      $id.= 'Bacterial cont.';
    } else {
      $id.= $gene->type eq 'Genoscope_annotated' ? "Genoscope annotated trans" : "Genoscope annotated trans";
    }
  }
  return $id;
}

sub legend {
  my ($self, $colours) = @_;
  return ('genes', 900, [
    'Genoscope predicted genes' => $colours->{'_GSTEN'}[0],
    'Genoscope annotated genes' => $colours->{'_HOX'}[0],
  ]);
}

sub error_track_name { return 'Genoscope transcripts'; }

1;
