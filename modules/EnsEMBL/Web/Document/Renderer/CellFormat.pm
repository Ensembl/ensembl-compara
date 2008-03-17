package EnsEMBL::Web::Document::Renderer::CellFormat;

use strict;
use Class::Std;

{
  my %Align_of    :ATTR( :get<align>   :set<align>   );
  my %Valign_of   :ATTR( :get<valign>  :set<valign>  );
  my %BgColor_of  :ATTR( :get<bgcolor> :set<bgcolor> );
  my %FgColor_of  :ATTR( :get<fgcolor> :set<fgcolor> );
  my %Rowspan_of  :ATTR( :get<rowspan> :set<rowspan> );
  my %Colspan_of  :ATTR( :get<colspan> :set<colspan> );
  my %Bold_of     :ATTR( :get<bold>    :set<bold>    );
  my %Italic_of   :ATTR( :get<italic>  :set<italic>  );
  my %Format_hashref_of :ATTR( :name<format_hashref> );

  my $alignments = {
    'center' => 'center',
    'centre' => 'center',
    'c'      => 'center',
    'right'  => 'right',
    'r'      => 'right',
    'left'   => 'left',
    'l'      => 'left',
  };

  my $valignments = {
    'middle' => 'middle',
    'm'      => 'middle',
    'top'    => 'top',
    't'      => 'top',
    'bottom' => 'bottom',
    'b'      => 'bottom',
  };

  sub key {
    my $self = shift;

    return join '::', 
      $self->get_align,
      $self->get_valign,
      $self->get_bgcolor,
      $self->get_fgcolor,
      $self->get_rowspan,
      $self->get_colspan,
      $self->get_italic,
      $self->get_bold;
  }

  sub set_valid_align {
### Setter
### Sets horizontal alignment after checking value is valid
    my( $self, $val ) = @_; 
    $Align_of{ ident $self } = $alignments->{$val} if exists $alignments->{$val};
  }

  sub set_valid_valign {
### Setter
### Sets vertical alignment after checking value is valid
    my( $self, $val ) = @_; 
    $Valign_of{ ident $self } = $valignments->{$val} if exists $valignments->{$val};
  }

  sub set_valid_bold {
    my( $self, $val ) = @_; 
    $Bold_of{ ident $self } = $val if $val eq '0' or $val eq '1';
  }

  sub set_valid_italic {
    my( $self, $val ) = @_; 
    $Italic_of{ ident $self } = $val if $val eq '0' or $val eq '1';
  }

  sub BUILD {
    my( $self, $ident, $arg_ref ) = @_;
    my %args = %{$arg_ref||{}};
## Set default values...
    $self->set_align(   'left' );
    $self->set_valign(  'middle' );
    $self->set_bold(    0 );
    $self->set_italic(  0 );
    $self->set_rowspan( 1 );
    $self->set_colspan( 1 );
    $self->set_bgcolor( 'ffffff' );
    $self->set_fgcolor( '000000' );
## Now set values set by code...
    $self->set_valid_align(   $arg_ref->{'align'}   ) if exists $arg_ref->{'align'  };
    $self->set_valid_valign(  $arg_ref->{'valign'}  ) if exists $arg_ref->{'valign' };
    $self->set_valid_bold(    $arg_ref->{'bold'}    ) if exists $arg_ref->{'bold'   };
    $self->set_valid_italic(  $arg_ref->{'italic'}  ) if exists $arg_ref->{'italic' };
    $self->set_rowspan( $arg_ref->{'rowspan'} ) if exists $arg_ref->{'rowspan'};
    $self->set_colspan( $arg_ref->{'colspan'} ) if exists $arg_ref->{'colspan'};
    $self->set_bgcolor( $arg_ref->{'bgcolor'} ) if exists $arg_ref->{'bgcolor'};
    $self->set_fgcolor( $arg_ref->{'fgcolor'} ) if exists $arg_ref->{'fgcolor'};
  } 
}

1;
