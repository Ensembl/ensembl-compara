package Bio::EnsEMBL::GlyphSet::prediction_transcript;
use strict;
use vars qw(@ISA);
use EnsWeb;
use Bio::EnsEMBL::GlyphSet_transcript;
use Bio::EnsEMBL::Gene;

@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub analysis_logic_name{
  my $self = shift;
  return $self->my_config('LOGIC_NAME'); # E.g. 'Genscan, SNAP etc
}

sub my_label {
  my $self = shift;
  return $self->analysis_logic_name;
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

sub colour {
  my ($self, $gene, $transcript, $colours, %highlights) = @_;

  if($transcript && exists $highlights{$transcript->stable_id()}) {
    return ($colours->{'col'}, $colours->{'hi'});
  }
  return ( $colours->{'col'}, undef );
}

sub href {
  my ($self, $gene, $transcript) = @_;
  my $id = $transcript->stable_id();
  my( $tld ) = @{[$self->{container}{_config_file_name_}]};
  return "/$tld/transview?transcript=$id&db=core";
}

sub zmenu {
  my ($self, $gene, $transcript) = @_;
  my $id = $transcript->stable_id();
  my( $tld )= @{[$self->{container}{_config_file_name_}]};
  my $ev_link = 
    ( "/$tld/exportview?tab=fasta&type=feature&ftype=transcript&".
      "fasta_option=%s&id=%s" );
  return
    {
     'caption' => $id,
     '01:Transcript'     =>$self->href( $gene, $transcript ),
     '02:Peptide'        =>"/$tld/protview?transcript=$id&db=core",
     '03:Export cDNA'    =>sprintf( $ev_link, 'cdna', $id ),
     '04:Export peptide' =>sprintf( $ev_link, 'peptide', $id ),
    };
}

sub text_label {
  my ($self, $gene, $transcript) = @_;
  my $id = $transcript->stable_id();

  my $Config = $self->{config};
  my $short_labels = $Config->get('_settings','opt_shortlabels');

  if( ! $short_labels ){
    my $analysis = $transcript->analysis || last;
    my $logic_name = $analysis->logic_name || last;
    $id .= "\nAb-initio $logic_name trans";
  }
  return $id;
}

sub legend {
  my ($self, $colours) = @_;
  return undef;
}

sub error_track_name { return $_[0]->analysis_logic_name; }

1;

