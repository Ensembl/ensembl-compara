###


write EnsEMBL::Web::File module

and

EnsEMBL::Web::File::Image module

  ->cache   = G/S 0/1
  ->ticket  = G/S ticketname (o/w uses random date stamp)
  ->dc      = G/S E::W::DC
  ->render(format) 
  ->imagemap = [ Note a cached image will store this when called & DC exists ]

sub new {
  my $self = {
    'cache'     => 0,
    'file_root' => TMP_DIR,
    'URL_root'  => TMP_URL,
  }
}

sub set_cache {
  my $self = shift;
  $self->{'cache'} = 1;
  $self->{'file_root' } = CACHE_DIR;
  $self->{'URL_root'}   = CACHE_URL
}

sub filename {
  my( $self, $format ) = @_;
  
}

sub extraHTML {
  my $self = shift;
  my $extra = '';
  if( $self->{'img_map'} ) {
    $extra .= qq(usemap="#$self->{'img_map'}" );
  }
  return $extra;
}

sub extraStyle {
  my $self = shift;
  my $extra = '';
  if( $self->{'border'} ) {
    $extra .= sprintf qq(border: %s %dpx %s;),
              $self->{'border_colour'} || '#000', $self->{'border'},
              $self->{'border_style'}||'solid'; 
  }
  return $extra;
}

sub render_img_tag {
  my $self = shift;
  my $IF = $self->render();
  my($width, $height ) = imgsize( $IF->{'file'} );
  my $HTML = sprintf '<img src="%s" alt="%s" title="%s" width="%dpx" height="%dpx" style="%s" %s />',
                       $IF->{'URL'}, $self->{'text'}, $self->{'text'},
                       imgsize( $IF->{'name'} ),
                       $self->extraStyle,
                       $self->extraHTML );
} 

sub render {
  my( $self, $format ) = @_;
  my $format ||= $self->{'default_format'};
  my $file = $self->file( $format );
  if( $self->cache && -e $file && -f $file ) {
      ## If cached image required and it exists return it!
    if( $format eq 'imagemap' ) {
      open( I, $file );
      local $/ = undef;
      my $imagemap = <I>;
      close I;
      return { 'imagemap' => $imagemap };
    } else {
      return { 'URL' => $self->URL($format), 'file' => $file };
    }
  }
  my $image;
  eval { $image    = $self->dc->render($format); };
  if( $image ) {
    if( $format eq 'imagemap' ) {
      return { 'imagemap' => $image }
    } else { 
      open(IMG_OUT, ">$file") || warn qq(Cannot open temporary image file for $format image: $!);
      binmode IMG_OUT;
      print IMG_OUT $image;
      close(IMG_OUT);
      return { 'URL' => $self->URL($format), 'file' => $file };
    }
  }
}
  
