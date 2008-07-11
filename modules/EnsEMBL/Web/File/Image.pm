package EnsEMBL::Web::File::Image;

use strict;
use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::File::Driver::Disk;
use EnsEMBL::Web::File::Driver::Memcached;

use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);

our $TMP_IMG_FORMAT = 'XXX/X/X/XXXXXXXXXXXXXXX';
our $DEFAULT_FORMAT = 'png';

#  ->cache   = G/S 0/1
#  ->ticket  = G/S ticketname (o/w uses random date stamp)
#  ->dc      = G/S E::W::DC
#  ->render(format) 
#  ->imagemap = [ Note a cached image will store this when called & DC exists ]

sub new {
  my $class = shift;

  my $self = {
    cache        => 0,
    species_defs => shift,
    token        => '',
    filename     => '',
    file_root    => '',
    URL_root     => '',
    dc           => undef,
    driver       => undef,
  };

  bless $self, $class;
 
  $self->driver = EnsEMBL::Web::File::Driver::Memcached->new ||
                  EnsEMBL::Web::File::Driver::Disk->new;
  
  return $self;
}

sub dc     :lvalue { $_[0]->{'dc'}; }
sub driver :lvalue { $_[0]->{'driver'}; }
sub cache  :lvalue { $_[0]->{'cache'}; }

sub set_cache_filename {
  my $self     = shift;
  my $type     = shift;
  my $filename = shift;
  $self->cache = 1;
  my $MD5 = hex(substr( md5_hex($filename), 0, 6 )); ## Just the first 6 characters will do!
  my $c1  = $EnsEMBL::Web::Root::random_ticket_chars[($MD5>>5)&31];
  my $c2  = $EnsEMBL::Web::Root::random_ticket_chars[$MD5&31];
  
  $self->{'token'}      = "$type:$c1$c2$filename";
  $self->{'filename'}   = "$type/$c1/$c2/$filename";

  $self->{'file_root' } = $self->{'species_defs'}->ENSEMBL_TMP_DIR_CACHE;
  $self->{'URL_root'}   = $self->{'species_defs'}->ENSEMBL_TMP_URL_CACHE;
}

sub set_tmp_filename {
  my $self     = shift;
  my $filename = shift || $self->{'token'} || $self->ticket;
  $self->{'cache'}      = 0;
  $self->{'token'}      = $filename;
  $self->{'filename'}   = $self->templatize( $filename, $TMP_IMG_FORMAT ); 
  $self->{'file_root' } = $self->{'species_defs'}->ENSEMBL_TMP_DIR_IMG;
  $self->{'URL_root'}   = $self->{'species_defs'}->ENSEMBL_TMP_URL_IMG;
}

sub extraHTML {
  my $self = shift;
  my $extra = '';
  if( $self->{'id'} ) {
    $extra .= qq(id="$self->{'id'}" )
  }
  if( $self->{'img_map'} ) {
    if( $self->{'id'} ) {
      $extra .= qq(usemap="#$self->{'id'}_map" );
    } else {
      $extra .= qq(usemap="#$self->{'token'}" );
    }
  }
  return $extra;
}

sub filename { 
  my $self = shift;
  my $extn = shift;
  $extn .= '.gz'  if $extn eq 'imagemap';
  $extn .= '.eps' if $extn eq 'postscript';
  return $self->{'file_root'}.'/'.$self->{'filename'}.".$extn";
}

sub URL { 
  my $self = shift;
  my $extn = shift;
  return $self->{'URL_root'}.'/'.$self->{'filename'}.".$extn";
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

sub render_image_tag {
  my $self = shift;

  #$self->{'species_defs'}{'timer'}->push("Starting render",6);
  my $IF = $self->render( @_ );
  #$self->{'species_defs'}{'timer'}->push("Finished render",6);

  my ($width, $height) = $self->driver->imgsize($IF->{'file'});
  #$self->{'species_defs'}{'timer'}->push("Got image size",6);

  my $HTML;
  if ($width > 5000) {
    my $url = $IF->{'URL'};
    $HTML = qq(<p style="text-align:left">The image produced was $width pixels wide, which may be too large for some web browsers to display. If you would like to see the image, please right-click (MAC: Ctrl-click) on the link below and choose the 'Save Image' option from the pop-up menu. Alternatively, try reconfiguring KaryoView, either merging the features into a single track (step 1) or selecting one chromosome at a time (Step 3).</p>
<p><a href="$url">Image download</a></p>);
  } else {
    $HTML = sprintf '<img src="%s" alt="%s" title="%s" style="width: %dpx; height: %dpx; %s display: block" %s />',
                       $IF->{'URL'}, $self->{'text'}, $self->{'text'},
                       $width, $height,
                       $self->extraStyle,
                       $self->extraHTML;
    $self->{'width'}  = $width;
    $self->{'height'} = $height;
  }
  return $HTML;
} 

sub render_image_button {
  my $self = shift;
  my $IF = $self->render( @_ );
  my ($width, $height) = $self->driver->imgsize($IF->{'file'});
  $self->{'width'}  = $width;
  $self->{'height'} = $height;
  my $HTML = sprintf '<input style="width: %dpx; height: %dpx; display: block" type="image" name="%s" id="%s" src="%s" alt="%s" title="%s" />', $width, $height, $self->{'name'}, $self->{'id'}||$self->{'name'}, $IF->{'URL'}, $self->{'text'}, $self->{'text'};
  return $HTML;
} 

sub render_image_link {
  my $self   = shift;
  my $format = shift;
  my $IF     = $self->render( lc($format) );
  my $HTML   = sprintf '<a target="_blank" href="%s">Render as %s</a>', $IF->{'URL'}, uc($format);
  return $HTML;
}

sub render_image_map {
  my $self = shift;
  my $IF   = $self->render( 'imagemap' );
  my $map_name = $self->{'id'} ? ($self->{'id'}.'_map') : $self->{'token'};
  return sprintf( qq(<map name="%s" id="%s">\n$IF->{'imagemap'}\n</map>), $map_name, $map_name);
}

sub exists { 
  my ($self, $format) = @_;
  $format ||= $DEFAULT_FORMAT;
  my $file = $self->filename( $format );
  
  return $self->cache && $self->driver->exists($file);
}
 
sub render {
  my( $self, $format ) = @_;

  $format ||= $DEFAULT_FORMAT;

  my $file = $self->filename($format);

  if ( $self->exists($file) ) {
    ## If cached image required and it exists return it!
    if ( $format eq 'imagemap' ) {
      my $imagemap = $self->driver->get($file, {format => 'imagemap', compress => 1});
      return { 'imagemap' => $imagemap };
    } else {
      return { 'URL' => $self->URL($format), 'file' => $file };
    }
  }
  
  my $image;
  # $self->{'species_defs'}{'timer'}->push( "RAW RENDER START", 7);
  # warn ".... $format ....";
  eval { $image = $self->dc->render($format); };
  # $self->{'species_defs'}{'timer'}->push( "RAW RENDER END", 7);
  if ($image) {
    if ($format eq 'imagemap') {

      $self->driver->save(
        $image,
        $file,
        {
          format   => 'imagemap',
          compress => 1,
        }
      ) if $self->cache;
      
      return { 'imagemap' => $image };
    } else {

      $self->driver->save(
        $image,
        $file, 
        {
          format  => $format,
          exptime => $self->cache ? 60*60*24 : 60*60,
        }
      );

      ## TODO: ERROR exception !!!
      return { 'URL' => $self->URL($format), 'file' => $file };
    }
  } else {
    warn $@;
    return {};
  }
}

                                                                                

1; 
