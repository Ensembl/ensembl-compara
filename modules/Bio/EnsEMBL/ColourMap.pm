package Bio::EnsEMBL::ColourMap;
use strict;
use Sanger::Graphics::ColourMap;
use EnsWeb;
use vars qw(@ISA);
@ISA = qw(Sanger::Graphics::ColourMap);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  while(my($k,$v) = each %{$EnsWeb::species_defs->ENSEMBL_COLOURS||{}} ) {
    $self->{$k} = $v;
  }

  $self->{'colour_sets'} = {};
  $self->colourSet( 'core_gene',
    '_KNOWN'     => 'rust',
    '_KNOWNXREF' => 'rust',
    '_XREF'      => 'black',
    '_ORTH'     => 'green3',
    '_PREDXREF'  => 'red3',
    '_PRED'      => 'red3',
    '_'          => 'black', 
    'hi'        => 'highlight1',
    'superhi'   => 'highlight2'
  );
  $self->colourSet( 'vega_gene',
    'hi'               => 'highlight1',
    'superhi'          => 'highlight2',
    'Novel_CDS'        => 'blue',
    'Putative'         => 'lightslateblue',
    'Known'            => 'dodgerblue4',
    'Pseudogene'       => 'grey38',
    'Novel_Transcript' => 'skyblue3',
    'Ig_Segment'       => 'midnightblue',
    'Ig_Pseudogene'    => 'mediumpurple4',
    'Predicted_Gene'   => 'steelblue4',
  );
  $self->colourSet( 'est_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    'genomewise' => 'purple1',
    'estgene'    => 'purple1',
  );
  $self->colourSet( 'cdna',
    'col'    => 'chartreuse3',
    'refseq' => 'mediumspringgreen',
    'riken'  => 'olivedrab4',
  );
  $self->colourSet( 'snp',
    '_coding'      => 'red',
    '_utr'         => 'orange',
    '_intron'      => 'contigblue2',
    '_local'       => 'contigblue1',
    '_'            => 'gray50',
    'label_coding' => 'white',
    'label_utr'    => 'black',
    'label_intron' => 'white',
    'label_local'  => 'black',
    'label_'       => 'black',
  );
  $self->colourSet( 'marker',
    ''               => 'magenta',
    'est'            => 'magenta',
    'microsatellite' => 'plum4',
  );
  $self->colourSet( 'protein',
    'col'        => 'gold',
    'refseq'     => 'orange',
  );
  $self->colourSet( 'prot_gene',
    'hi'         => 'highlight1',
    'superhi'    => 'highlight2',
    '_col'       => 'orchid4',
  );
  $self->colourSet( 'refseq_gene',
        'hi'         => 'highlight1',
        'superhi'    => 'highlight2',
        '_refseq' => 'blue',
  );
  return $self;
}

sub colourSet {
  my $self = shift;
  my $name = shift;
  if(@_) {
    $self->{'colour_sets'}{$name} = {@_};
  }
  return %{$self->{'colour_sets'}{$name}||{}};
}
1;
