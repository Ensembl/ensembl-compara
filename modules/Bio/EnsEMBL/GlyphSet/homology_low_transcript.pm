package Bio::EnsEMBL::GlyphSet::homology_low_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
  my $self = shift;
  return "Bee genes";
}

sub colours {
  my $self = shift;
  my $Config = $self->{'config'};
  return $Config->get('homology_low_transcript','colours');
}

sub transcript_type {
  my $self = shift;
  return 'refseq';
}

sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;
  my $colour = $colours->{$gene->analysis->logic_name};
  my $highlight;
  if( exists $highlights{lc($gene->stable_id)} ){
    $highlight = $colours->{'hi'};
  }
  return ( @$colour, $highlight );
}

sub gene_colour {
  my ($self, $gene, $colours, %highlights) = @_;
  return $self->colour( $gene, undef, $colours, %highlights);
}
                    
                      
sub href {
  my ($self, $gene, $transcript, %highlights ) = @_;

  my $gid = $gene->stable_id();
  my $tid = $transcript->stable_id();

  my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
  return ( $self->{'config'}->get('homology_low_transcript','_href_only') eq '#tid' && exists $highlights{lc($gene->stable_id)} ) ?
    "#$tid" :
    qq(/@{[$self->{container}{_config_file_name_}]}/$script_name?gene=$gid);

}

sub features {
  my ($self) = @_;

  my @T = map { @{$self->{'container'}->get_all_Genes_by_type($_)} } ( 'Homology_low', 'Homology_medium', 'Homology_high', 'BeeProtein' );
  return \@T;
}

sub gene_href {
  my ($self, $gene, %highlights ) = @_;

  my $gid = $gene->stable_id();

  my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
  return ( $self->{'config'}->get('homology_low_transcript','_href_only') eq '#gid' && exists $highlights{lc($gene->stable_id)} ) ?
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
    'caption'                       => "Bee Gene",
    "00:$id"            => "",
    "01:Gene:$gid"                  => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
    "02:Transcr:$tid"               => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=core",
    '04:Export cDNA'                => "/@{[$self->{container}{_config_file_name_}]}/exportview?options=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
  };

  if($pid) {
    $zmenu->{"03:Peptide:$pid"}   = qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid;db=core);
    $zmenu->{'05:Export Peptide'} = qq(/@{[$self->{container}{_config_file_name_}]}/exportview?options=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid);
  }
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
    $id .= "\n". $gene->analysis->logic_name;
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
    $id .= "\n". $gene->analysis->logic_name;
  }
  return $id;
}

sub legend {
  my ($self, $colours) = @_;
  return ('genes', 900, [
    'Homology high'   => $colours->{'Homology_high'}[0],
    'Homology medium' => $colours->{'Homology_medium'}[0],
    'Homology low'    => $colours->{'Homology_low'}[0],
    'Bee proteins'    => $colours->{'BeeProtein'}[0],
  ]);
}

sub error_track_name { return 'Bee Genes'; }

1;
