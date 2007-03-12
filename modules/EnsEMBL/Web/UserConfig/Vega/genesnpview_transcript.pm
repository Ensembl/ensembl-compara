package EnsEMBL::Web::UserConfig::Vega::genesnpview_transcript;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

#despite it's name this is the config for vega genespliceview !

sub init {
  my ($self) = @_;

  #retrieve the colour sets for each type of vega gene, replacing the name in the colourmap with the logicname
  my $vega_colours;
  foreach my $name  ( ['vega_gene_havana'  ,'otter'],
					  ['vega_gene_corf'    ,'otter_corf'],
					  ['vega_gene_external','otter_external'],
					  ['vega_gene_igsf'    ,'otter_igsf'],
					  ['vega_gene_eucomm'  ,'otter_eucomm'] ) {
	  $vega_colours->{$name->[1]} = { $self->{'_colourmap'}->colourSet($name->[0]) };
  }

  $self->{'_userdatatype_ID'} = 36;
  $self->{'_transcript_names_'} = 'yes';
  $self->{'_add_labels' }  = 1;
  $self->{'general'}->{'genesnpview_transcript'} = {
    '_artefacts' => [qw(vega_GSV_transcript)],
    '_options'  => [qw(pos col known unknown)],
    '_settings' => {
      'opt_pdf' => 0, 'opt_svg' => 0, 'opt_postscript' => 0,
      'opt_zclick'     => 1,
      'show_labels' => 'no',
      'width'   => 900,
      'bgcolor'   => 'background1',
      'bgcolour1' => 'background1',
      'bgcolour2' => 'background1',

      'features' => [],
     },
    'vega_GSV_transcript' => {
      'on'          => "on",
      'pos'         => '100',
      'str'         => 'b',
	  'src'         => 'all',
      'colours'     => $vega_colours,
    },													
  };

#  warn Data::Dumper::Dumper($vega_colours);
#warn "in vega---"Data::Dumper::Dumper($self->{'_colourmap'});													

  $self->ADD_ALL_PROTEIN_FEATURE_TRACKS_GSV;
} 
1;
