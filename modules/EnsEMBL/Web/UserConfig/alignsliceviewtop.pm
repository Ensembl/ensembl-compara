package EnsEMBL::Web::UserConfig::alignsliceviewtop;
use strict;
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

sub init {
  my ($self) = @_;
  $self->{'_userdatatype_ID'} = 2;
  $self->{'general'}->{'alignsliceviewtop'} = {
    '_artefacts'   => [],
    '_settings'    => {
      'width'             => 800,
      'draw_red_box'      => 'yes',
      'default_vc_size'   => 1000000,
      'show_alignsliceview'   => 'yes',
      'imagemap'          => 1,
      'bgcolor'           => 'background1',
      'bgcolour1'         => 'background1',
      'bgcolour2'         => 'background1',
    }
  };

  $self->ADD_GENE_TRACKS();
  $self->ADD_SYNTENY_TRACKS();
  my $POS = 0;
  
  $self->add_track( 'contig',   'on'=>'on', 'pos' => $POS++ );
  $self->add_track( 'scalebar', 'on'=>'on', 'pos' => $POS++, 'str' => 'f', 'abbrev' => 'on' );
}

1;
