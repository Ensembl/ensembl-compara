package EnsEMBL::Web::Document::HTML::JavascriptDiv;
use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'divs' => {}, 'div_order' => [] ) ; }

sub add_div { 
  my( $self, $ID, $attributes, $content ) = @_;
  push @{ $self->{'div_order'} }, $ID unless exists $self->{'divs'}{$ID};
  $self->{'divs'}{$ID} = [ $attributes, $content ];
}

sub render {
  my $self = shift;
  foreach my $ID ( @{ $self->{'div_order'}||[] } ) {
    $self->printf( '<div id="%s"%s>%s</div>', 
      $ID,
      join( '', map { qq( $_="@{[ $self->{'divs'}{$ID}[0]{$_}]}") } keys %{$self->{'divs'}{$ID}[0]} ),
      $self->{'divs'}{$ID}[1]
    );
  }
}
 
1;


