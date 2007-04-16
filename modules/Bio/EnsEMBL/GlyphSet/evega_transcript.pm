package Bio::EnsEMBL::GlyphSet::evega_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
use EnsEMBL::Web::ExtURL;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
  my $self = shift;
  return $self->my_config('label') || $self->{'config'}->{'_draw_single_Transcript'} || 'Vega trans.';
}

sub colours {
  my $self = shift;
  return $self->{'config'}->get($self->check, 'colours');
}

sub transcript_type {
  my $self = shift;
  return 'vega';
}

sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;
  my $highlight = undef;
  my $type = $gene->biotype.'_'.$gene->status;
  my @colour = @{$colours->{$type}||['black','transcript']};
  $colour[1] = $self->label_type($colour[1],$self->my_config('logic_name'));
  if(exists $highlights{lc($transcript->stable_id)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($transcript->external_name)}) {
    $highlight = $colours->{'superhi'};
  } elsif(exists $highlights{lc($gene->stable_id)}) {
    $highlight = $colours->{'hi'};
  } elsif( my $ccds_att = $transcript->get_all_Attributes('ccds')->[0] ) {
    $highlight = $colours->{'ccdshi'};
  }
  return (@colour, $highlight); 
}

sub gene_colour {
  my ($self, $gene, $colours, %highlights) = @_;
  my $highlight = undef;
  my $type = $gene->biotype."_".$gene->status;
  my @colour = @{$colours->{$type}||['black','transcript']};
  $colour[1] = $self->label_type($colour[1],$self->my_config('logic_name'));
  if(exists $highlights{lc($gene->stable_id)}) {
    $highlight = $colours->{'hi'};
  }
  return (@colour, $highlight);
}

sub label_type {
	my ($self,$colour,$logic_name) = @_;
	my %sourcenames = (
					   'otter' => 'Vega Havana ',
					   'otter_external' => 'Vega External ',
					  );
	my $prefix = $sourcenames{$logic_name};
	return $prefix.$colour;
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
  my $author;
  if ( defined (@{$transcript->get_all_Attributes('author')}) ) {
    $author =  shift( @{$transcript->get_all_Attributes('author')} )->value || 'unknown';
  }
  else {
	$author =   'not defined';
  }
  my $pid = $translation->stable_id() if $translation;
  my $gid = $gene->stable_id();
  my $id   = $transcript->external_name() eq '' ? $tid : $transcript->external_name();
  my $gtype = $self->format_vega_name($gene);
  my $ttype = $self->format_vega_name($gene,$transcript);

  my $ExtUrl = EnsEMBL::Web::ExtURL->new($self->{'config'}->{'species'}, $self->species_defs);
  my $caption = $self->my_config('caption'); 
  my $zmenu = {
    'caption'             => $self->my_config('caption'),
    "00:$id"              => '',
    "01:Transcript class: ".$ttype     => '',
    "02:Gene type: ".$gtype     => '',
    "03:Author: ".$author => '',
    "04:Gene:$gid"        => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=vega",
    "05:Transcr:$tid"     => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=vega",

    "07:Export cDNA"      => "/@{[$self->{container}{_config_file_name_}]}/exportview?options=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
    "10:View in Vega"     => $ExtUrl->get_url('Vega_transcript', $tid),
  };
  
  if($pid) {
  $zmenu->{"06:Peptide:$pid"}=
    qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid;db=vega);
  $zmenu->{'08:Export Peptide'}=
    qq(/@{[$self->{container}{_config_file_name_}]}/exportview?options=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid);  
  }
  
  return $zmenu;
}

sub gene_zmenu {
  my ($self, $gene ) = @_;
  my $gid = $gene->stable_id();
  my $id   = $gene->external_name() eq '' ? $gid : $gene->external_name();
  my $author;
  if ( defined (@{$gene->get_all_Attributes('author')}) ) {
    $author =  shift( @{$gene->get_all_Attributes('author')} )->value || 'unknown';
  }
  else {
    $author =   'not defined';
  }
  my $type = $self->format_vega_name($gene);
  my $ExtUrl = EnsEMBL::Web::ExtURL->new($self->{'config'}->{'species'}, $self->species_defs);
  my $caption = $self->my_config('caption');
  my $zmenu = {
    'caption'             => "$caption",
    "00:$id"	          => "",
    '01:Gene type: ' . $type   => "",
	'02:Author: '.$author => "",
    "03:Gene:$gid"        => qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=vega),
    "07:View in Vega"     => $ExtUrl->get_url('Vega_gene', $gid),
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
    $id .= " \nVega $type ";
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
  my $genes = $self->{'container'}->get_all_Genes($self->my_config('logic_name'),'vega'); 
  $VEGA_TO_SHOW_ON_ENS = [@$genes];
  return $genes;
}


=head2 format_vega_name

  Arg [1]    : $self
  Arg [2]    : gene object
  Arg [3]    : transcript object (optional)
  Example    : my $type = $self->format_vega_name($g,$t);
  Description: retrieves status and biotype of a transcript, or failing that the parent gene. 
               Then retrieves the display name from the Colourmap
  Returntype : string

=cut

sub format_vega_name {
	my ($self,$gene,$trans) = @_;
	my ($status,$biotype);
	my %gm = $self->{'config'}->colourmap()->colourSet($self->my_config('colour_set'));
	my ($t,$label);
	if ($trans) {
		$label = $trans->biotype()||$gene->biotype();
		$label =~ s/_/ /;
	} else {
		$status = $gene->status;
		$biotype = $gene->biotype();
		$t = $biotype.'_'.$status;
		$label = $gm{$t}[1];
	}
	return $label;
}

sub error_track_name { return 'Vega transcripts'; }


1;
