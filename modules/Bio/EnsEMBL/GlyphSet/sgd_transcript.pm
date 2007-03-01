package Bio::EnsEMBL::GlyphSet::sgd_transcript;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::GlyphSet_transcript;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
  my $self = shift;
  return $self->{'config'}->{'_draw_single_Transcript'} || $self->{'config'}->{'geneid'} || "SGD trans.";
}

sub colours {
  my $self = shift;
  my $Config = $self->{'config'};
  return $Config->get('sgd_transcript','colours');
}

sub features {
  my ($self) = @_;
  my $track = 'sgd_transcript';
  my $slice = $self->{'container'};
  my $sp = $self->{'_config_file_name_'};
  my @analyses = ( 'sgd', 'pseudogene');
  my $db_alias = $self->{'config'}->get($track,'db_alias') || '';
  my @genes;
  foreach my $analysis( @analyses ){
    push @genes, @{ $slice->get_all_Genes( $analysis, $db_alias||() ) }
  }
  return [@genes];
}


sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;

  my $genecol = $colours->{ $transcript->analysis->logic_name."_".$transcript->biotype."_".$transcript->status };

  if(exists $highlights{lc($transcript->stable_id)}) {
    return (@$genecol, $colours->{'superhi'});
  } elsif(exists $highlights{lc($transcript->external_name)}) {
    return (@$genecol, $colours->{'superhi'});
  } elsif(exists $highlights{lc($gene->stable_id)}) {
    return (@$genecol, $colours->{'hi'});
  }
    
  return (@$genecol, undef);
}

sub gene_colour {
  my ($self, $gene, $colours, %highlights) = @_;
  my $genecol = $colours->{ $gene->analysis->logic_name."_".$gene->biotype."_".$gene->status };

  if(exists $highlights{lc($gene->stable_id)}) {
    return (@$genecol, $colours->{'hi'});
  }

  return (@$genecol, undef);
}

sub href {
  my ($self, $gene, $transcript, %highlights ) = @_;

  my $gid = $gene->stable_id();
  my $tid = $transcript->stable_id();
  
  my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
  return ( $self->{'config'}->get('sgd_transcript','_href_only') eq '#tid' && exists $highlights{lc($gene->stable_id)} ) ?
    "#$tid" : 
    qq(/@{[$self->{container}{_config_file_name_}]}/$script_name?gene=$gid);

}

sub gene_href {
  my ($self, $gene, %highlights ) = @_;

  my $gid = $gene->stable_id();

  my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
  return ( $self->{'config'}->get('sgd_transcript','_href_only') eq '#gid' && exists $highlights{lc($gene->stable_id)} ) ?
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
    'caption'                       => "SGD Gene",
    "00:$id"			=> "",
    "01:Gene:$gid"                  => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
    "02:Transcr:$tid"    	        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=core",                	
    '04:Export cDNA'                => "/@{[$self->{container}{_config_file_name_}]}/exportview?option=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
  };
    
  if($pid) {
    $zmenu->{"03:Peptide:$pid"}   = qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid;db=core);
    $zmenu->{'05:Export Peptide'} = qq(/@{[$self->{container}{_config_file_name_}]}/exportview?option=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid);	
  }
  $zmenu->{'05:Gene SNP view'}= "/@{[$self->{container}{_config_file_name_}]}/genesnpview?gene=$gid;db=core" if $ENV{'ENSEMBL_SCRIPT'} =~ /snpview/;
  return $zmenu;
}

sub gene_zmenu {
  my ($self, $gene ) = @_;
  my $gid = $gene->stable_id();
  my $id   = $gene->external_name() eq '' ? $gid : ( $gene->external_db.": ".$gene->external_name() );
  my $zmenu = {
    'caption'                       => "EnsEMBL Gene",
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
 my $colours = $self->colours();

  my $short_labels = $Config->get('_settings','opt_shortlabels');

  if( $self->{'config'}->{'_both_names_'} eq 'yes') {
    $id .= $eid ? " ($eid)" : '';
  }
  unless( $short_labels ){
    $id .= "\n";
    $id .= $colours->{ $transcript->analysis->logic_name."_".$transcript->biotype."_".$transcript->status }[1];
  }
  return $id;
}

sub gene_text_label {
  my ($self, $gene ) = @_;
  my $gid    = $gene->stable_id;
  my $eid    = $gene->external_name;
  my $id     = $eid || $gid;
  my $Config = $self->{config};
 my $colours = $self->colours();

  my $short_labels = $Config->get('_settings','opt_shortlabels');

  if( $self->{'config'}->{'_both_names_'} eq 'yes') {
    $id .= $eid ? " ($eid)" : '';
  }
  unless( $short_labels ){
    $id .= "\n";
    if( $gene->type eq 'bacterial_contaminant' ) {
      $id.= 'Bacterial cont.';
    } else {
      $id .= $colours->{ $gene->analysis->logic_name."_".$gene->biotype."_".$gene->status }[1];
    }
  }
  return $id;
}

sub legend {
  my ($self, $colours) = @_;
  return ('genes', 900, [
    'SGD predicted genes (known)' => $colours->{'_KNOWN'}[0],
    'SGD predicted genes (novel)' => $colours->{'_'}[0],
    'SGD pseudogenes'             => $colours->{'_PSEUDO'}[0],
  ]);
}

sub error_track_name { return 'SGD transcripts'; }

1;
