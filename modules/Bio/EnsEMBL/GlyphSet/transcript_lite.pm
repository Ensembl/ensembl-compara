package Bio::EnsEMBL::GlyphSet::transcript_lite;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::GlyphSet_transcript;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
  my $self = shift;
  return $self->{'config'}->{'_draw_single_Transcript'} || $self->{'config'}->{'geneid'} || "@{[$self->species_defs->AUTHORITY]} trans.";
}

sub colours {
  my $self = shift;
  my $Config = $self->{'config'};
  return $Config->get('transcript_lite','colours');
}

sub features {
  my ($self) = @_;
  my $track = 'transcript_lite';
  my $slice = $self->{'container'};
  my $sp = $self->{'_config_file_name_'};
  my @analyses = ( lc( $self->species_defs->get_config($sp,'AUTHORITY') ),
                   'pseudogene');
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

  my $genecol = $colours->{ "_".$transcript->external_status }[0];

  if( $gene->type eq 'bacterial_contaminant' ) {
    $genecol = $colours->{'_BACCOM'}[0];
  } elsif( $transcript->external_status eq '' and ! $translation_id ) {
    $genecol = $colours->{'_PSEUDO'}[0];
  }
  if(exists $highlights{$transcript->stable_id()}) {
    return ($genecol, $colours->{'superhi'}[0]);
  } elsif(exists $highlights{$transcript->external_name()}) {
    return ($genecol, $colours->{'superhi'}[0]);
  } elsif(exists $highlights{$gene->stable_id()}) {
    return ($genecol, $colours->{'hi'}[0]);
  }
    
  return ($genecol, undef);
}

sub gene_colour {
  my ($self, $gene, $colours, %highlights) = @_;
  my $genecol = $colours->{ "_".$gene->external_status }[0];

  if( $gene->type eq 'bacterial_contaminant' ) {
    $genecol = $colours->{'_BACCOM'}[0];
  }
  if(exists $highlights{$gene->stable_id()}) {
    return ($genecol, $colours->{'hi'}[0]);
  }

  return ($genecol, undef);
}

sub href {
  my ($self, $gene, $transcript, %highlights ) = @_;

  my $gid = $gene->stable_id();
  my $tid = $transcript->stable_id();
  
  my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
  return ( $self->{'config'}->get('transcript_lite','_href_only') eq '#tid' && exists $highlights{$gene->stable_id()} ) ?
    "#$tid" : 
    qq(/@{[$self->{container}{_config_file_name_}]}/$script_name?gene=$gid);

}

sub gene_href {
  my ($self, $gene, %highlights ) = @_;

  my $gid = $gene->stable_id();

  my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
  return ( $self->{'config'}->get('transcript_lite','_href_only') eq '#gid' && exists $highlights{$gene->stable_id()} ) ?
    "#$gid" :
    qq(/@{[$self->{container}{_config_file_name_}]}/$script_name?gene=$gid);

}

sub zmenu {
  my ($self, $gene, $transcript) = @_;
  my $translation = $transcript->translation;
  my $tid = $transcript->stable_id();
  my $pid = $translation ? $translation->stable_id() : '';
  my $gid = $gene->stable_id();
  my $id   = $transcript->external_name() eq '' ? $tid : ( $transcript->external_db.": ".$transcript->external_name() );
  my $zmenu = {
    'caption'                       => $self->species_defs->AUTHORITY." Gene",
    "00:$id"			=> "",
    "01:Gene:$gid"                  => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
    "02:Transcr:$tid"    	        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=core",                	
    '04:Export cDNA'                => "/@{[$self->{container}{_config_file_name_}]}/exportview?options=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
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
  my $id   = $gene->external_name() eq '' ? $gid : ( $gene->external_db.": ".$gene->external_name() );
  my $zmenu = {
    'caption'                       => $self->species_defs->AUTHORITY." Gene",
    "01:Gene:$gid"                  => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
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
      $id.= $eid ? "Ensembl known trans" : "Ensembl novel trans";
    } else {
      $id .= "Ensembl pseudogene";
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
      $id.= $eid ? "Ensembl known trans" : "Ensembl novel trans";
    }
  }
  return $id;
}

sub legend {
  my ($self, $colours) = @_;
  return ('genes', 900, [
    $self->species_defs->AUTHORITY.' predicted genes (known)' => $colours->{'_KNOWN'},
    $self->species_defs->AUTHORITY.' predicted genes (novel)' => $colours->{'_'},
    $self->species_defs->AUTHORITY.' pseudogenes' => $colours->{'_PSEUDO'},
  ]);
}

sub error_track_name { return $_[0]->species_defs->AUTHORITY.' transcripts'; }

1;
