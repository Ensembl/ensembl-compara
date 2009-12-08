package EnsEMBL::Web::Document::HTML::Stylesheet;
use strict;
use EnsEMBL::Web::Document::HTML;

@EnsEMBL::Web::Document::HTML::Stylesheet::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'media' => {}, 'media_order' => [] ); }

sub add       {
  my( $self, $media, $CSS ) = @_;
  push @{$self->{'media_order'}}, $media unless $self->{'media'}{$media};
  $self->{'media'}{$media}.="    $CSS\n";
}

sub add_sheet { $_[0]->add( $_[1], "\@import url($_[2]);" ); }
sub render { 
  foreach my $media ( @{$_[0]{'media_order'}} ) {
    $_[0]->printf( qq(  <style type="text/css" media="%s">\n%s  </style>\n),
            $media, $_[0]{'media'}{$media} );
  }
}

1;


