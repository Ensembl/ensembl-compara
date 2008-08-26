package Bio::EnsEMBL::GlyphSet::_prediction_transcript;
use strict;

use base qw(Bio::EnsEMBL::GlyphSet_transcript);
use Bio::EnsEMBL::Gene;

sub analysis_logic_name{
  my $self = shift;
  return $self->my_config('LOGIC_NAME'); # E.g. 'Genscan, SNAP etc
}

sub my_label {
  my $self = shift;
  return $self->my_config('track_label') || $self->analysis_logic_name;
}

sub das_link {
  my $self = shift;
  my $database    = $self->my_config( 'db' ) || 'core';
  my $slice   = $self->{container};
  my $species = $slice->{_config_file_name_};
  my $assembly = $self->{'config'}->species_defs->other_species($species, 'ENSEMBL_GOLDEN_PATH' );

  my $dsn = "$species.$assembly.".join('-','prediction_transcript', $database, $self->analysis_logic_name);
  return "/das/$dsn/features?segment=".$slice->seq_region_name.':'.$slice->start.','.$slice->end;
}

sub colours {
    my $self = shift;
    my $confkey = lc( $self->analysis_logic_name );
    my $Config = $self->{'config'};
    return {
        'hi'    => $Config->get($confkey,'hi')      || 'white',
        'col'   => $Config->get($confkey,'col')     || 'black',
        'super' => $Config->get($confkey,'superhi') || 'white',
    };
}

sub features {
  my $self = shift;
  my @genes = ();
  #obtain genscan transcripts
  my $type = $self->analysis_logic_name;
  my $adapt = $self->{'container'};
  foreach my $transcript( @{$adapt->get_all_PredictionTranscripts($type)}) {
    my $gene = new Bio::EnsEMBL::Gene();
    $gene->add_Transcript($transcript);
    push @genes, $gene;
  }
  return \@genes;
}

sub gene_colour {
  my ($self, $gene, @X ) = @_;
  $self->colour( $gene, $gene->get_all_Transcripts->[0], @X );
}
sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;
  if($transcript && exists $highlights{lc($transcript->stable_id)}) {
    return ($colours->{'col'}, $colours->{'hi'});
  }
  return ( $colours->{'col'}, ucfirst($self->analysis_logic_name), undef );
}

sub href {
  my ($self, $gene, $transcript) = @_;
  my $id = $transcript->stable_id();
  my( $tld ) = @{[$self->{container}{_config_file_name_}]};
  return "/$tld/transview?transcript=$id;db=core";
}

sub zmenu {
  my ($self, $gene, $transcript) = @_;
  my $id = $transcript->stable_id();
  my( $tld )= @{[$self->{container}{_config_file_name_}]};
  my $ev_link =  "/$tld/exportview?action=select;format=fasta;option=%s;type1=transcript;anchor1=%s";
  my $zmenu = 
    {
     'caption' => $id,
     '01:Transcript'     =>$self->href( $gene, $transcript ),
     '02:Peptide'        =>"/$tld/protview?transcript=$id;db=core",
     '03:Export cDNA'    =>sprintf( $ev_link, 'cdna', $id ),
     '04:Export peptide' =>sprintf( $ev_link, 'peptide', $id ),
    };
  my $ADD = $self->{'config'}->get(lc( $self->analysis_logic_name ),'ADDITIONAL_ZMENU');
  if( $ADD && ref($ADD) eq 'HASH' ) {
    foreach (keys %$ADD) {
      $zmenu->{ $_ } = $self->ID_URL( $ADD->{$_}, $id );
    }
  }
  return $zmenu;
}

sub gene_text_label {
  my ($self, $gene ) = @_;
  $self->text_label( $gene, $gene->get_all_Transcripts->[0] );
}
sub text_label {
  my ($self, $gene, $transcript) = @_;
  my $id = $transcript->stable_id();

  my $Config = $self->{config};
  my $short_labels = $Config->get('_settings','opt_shortlabels');

  if( ! $short_labels ){
    $id .= "\nAb-initio ".$self->my_label." trans";
  }
  return $id;
}

sub legend {
  my ($self, $colours) = @_;
  return undef;
}

sub error_track_name { return $_[0]->analysis_logic_name; }

1;

