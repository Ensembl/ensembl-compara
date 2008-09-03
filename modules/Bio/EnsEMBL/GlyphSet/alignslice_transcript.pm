package Bio::EnsEMBL::GlyphSet::_transcript;
use strict;
use base qw( Bio::EnsEMBL::GlyphSet_transcript );

sub analysis_logic_name{
  my $self = shift;
  return $self->my_config('LOGIC_NAME');
}

sub my_label { 
  my $self = shift;
  return $self->my_config('caption');
}

sub colours {
  my $self = shift;
  my $colour_set = $self->my_config('colour_map') || 'genes';
  return $self->{'config'}->species_defs->multi( 'colour_map', $colour_set );
}

sub features {
  my ($self) = @_;
  my $slice = $self->{'container'};

  my $db_alias = $self->my_config('db');

  my $analyses = $self->my_config('logicnames');

  warn "fetching features for $db_alias [@{$analyses}]";
  my @T = map { @{$slice->get_all_Genes( $_, $db_alias )||[]} } @$analyses;
  return \@T;
}


sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;

  my $highlight = $self->my_config('db') ne $self->{'config'}{'_core'}{'parameters'}{'db'} ? undef
                : $transcript->stable_id eq $self->{'config'}{'_core'}{'parameters'}{'t'}  ? 'superhi'
                : $gene->stable_id       eq $self->{'config'}{'_core'}{'parameters'}{'g'}  ? 'hi'
	        : undef
		;
  my $col = $colours->{ $transcript->biotype.'='.$transcript->status } || [ 'orange', 'Other' ];
  return( @$col, $highlight );
}

sub gene_colour {
  my ($self, $gene, $colours, %highlights) = @_;

  my $highlight = $self->my_config('db') ne $self->{'config'}{'_core'}{'parameters'}{'db'} ? undef
                : $gene->stable_id       eq $self->{'config'}{'_core'}{'parameters'}{'g'}  ? 'hi'
		: undef
		;
  my $col = $colours->{ $gene->biotype.'='.$gene->status } || [ 'orange', 'Other' ];
  return( @$col, $highlight );
}

sub href {
  my ($self, $gene, $transcript, %highlights ) = @_;

  my $gid = $gene->stable_id();
  my $tid = $transcript->stable_id();
  return $self->_url({'type'=>'Transcript','action'=>'Summary','t'=>$tid,'g'=>$gid, 'db' => $self->my_config('db')});
}

sub gene_href {
  my ($self, $gene, %highlights ) = @_;

  my $gid = $gene->stable_id();

  return $self->_url({'type'=>'Gene','action'=>'Summary','g'=>$gid, 'db' => $self->my_config('db') });
}

sub href {
  my ($self, $gene, $transcript, %highlights ) = @_;

  my $gid = $gene->stable_id();
  my $tid = $transcript ? $transcript->stable_id() : '';
  
  my $script_name = ( $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 
		      'genesnpview' : 
		      'geneview' );

  # Check whether href is internal on gene_id or transcript_id
  if( $self->my_config('_href_only') eq '#gid' and
      exists $highlights{lc($gid)} ){ return( "#$gid" ) }
  if( $self->my_config('_href_only') eq '#tid' and
      exists $highlights{lc($gid)} ){ return( "#$tid" ) }

  my $species = $self->{container}{web_species};
  my $db = $self->my_config('db_alias') || 'core';
  return "/$species/$script_name?db=$db;gene=$gid";
}

sub gene_href {
  my ($self, $gene, %highlights ) = @_;
  return $self->href( $gene, undef, %highlights );
}

sub zmenu {
  my ($self, $gene, $transcript) = @_;

  my $sp = $self->{container}{web_species};
  my $db = $self->my_config('db_alias') || 'core';
  my $name = $self->my_config('db_alias') || 'Ensembl';

  my $gid = $gene->stable_id();
  my $zmenu = {
    'caption'          => "$name Gene",
    "01:Gene:$gid"     => "/$sp/geneview?gene=$gid;db=$db",
    '04:Export Gene'   => "/$sp/exportview?action=select;format=fasta;type1=gene;anchor1=$gid"
  };

  if( $transcript ){
    my $tid = $transcript->stable_id;
    my $tname  = $transcript->external_name || $tid;
    my $ext_db = $transcript->external_db   || '';
    $tname = $ext_db ? "$ext_db:$tname" : $tname;
    $zmenu->{"00:$tname"}       = '';
    $zmenu->{"02:Transcr:$tid"} = "/$sp/transview?transcript=$tid;db=$db";
    $zmenu->{'05:Export cDNA'}  = "/$sp/exportview?action=select;format=fasta;type1=transcript;anchor1=$tid;options=cdna";

   # Variation: TranscriptSNP view
  # if meta_key in variation meta table has default strain listed
    if ( $self->species_defs->VARIATION_STRAIN ) {
      $zmenu->{'07:Transcript SNP view'}= "/$sp/transcriptsnpview?transcript=$tid;db=$db";
    }
    my $translation = $transcript->translation;
    if( $translation ){
      my $pid = $translation->stable_id;
      $zmenu->{"03:Peptide:$pid"}   = "/$sp/protview?transcript=$tid;db=$db";
      $zmenu->{'06:Export Peptide'} = "/$sp/exportview?action=select;format=fasta;type1=peptide;anchor1=$pid;options=peptide";
    }
  } else { # No transcript
    my $gname  = $gene->external_name || $gid;
    my $ext_db = $gene->external_db   || '';
    $gname = $ext_db ? "$ext_db:$gname" : $gname;
    $zmenu->{"01:$gname"}       = '';
  }

  if( $ENV{'ENSEMBL_SCRIPT'} =~ /snpview/ ){
    $zmenu->{'07:Gene SNP view'}= "/$sp/genesnpview?gene=$gid;db=$db";
  }
  return $zmenu;
}

sub gene_zmenu {
  my ($self, $gene ) = @_;
  return $self->zmenu( $gene );
}


sub text_label {
  my ($self, $gene, $transcript) = @_;

  my $obj = $transcript || $gene || return '';

  my $tid = $obj->stable_id();
  my $eid = $obj->external_name();
  my $id = $eid || $tid;

  my $Config = $self->{config};
  my $short_labels = $Config->get_parameter( 'opt_shortlabels');

  if( $Config->{'_both_names_'} eq 'yes') {
    $id .= $eid ? " ($eid)" : '';
  }
  if( ! $Config->get_parameter( 'opt_shortlabels') ){
    my $type = ( $gene->analysis ? 
                 $gene->analysis->logic_name : 
                 'Generic trans.' );
    $id .= "\n$type";
  }
  return $id;
}

sub gene_text_label {
  my ($self, $gene ) = @_;
  return $self->text_label($gene);
}

sub legend {
  my ($self, $colours) = @_;
  # TODO; make generic
  return undef;
#  return ('genes', 900, [
#    'Ensembl predicted genes (known)' => $colours->{'_KNOWN'}[0],
#    'Ensembl predicted genes (novel)' => $colours->{'_'}[0],
#    'Ensembl pseudogenes'             => $colours->{'_PSEUDO'}[0],
#  ]);
}

sub error_track_name { return $_[0]->my_label }

1;
