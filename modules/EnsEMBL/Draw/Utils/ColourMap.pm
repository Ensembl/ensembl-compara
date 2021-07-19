=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2./

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::Utils::ColourMap;
use strict;

use EnsEMBL::Draw::Utils::NamedColours;

use List::Util qw(min max);

### Store errors outside the object, which contains only a colour hash
our $errors;

sub new {
  my ($class, $species_defs) = @_;

  $errors = {};

  my $self = EnsEMBL::Draw::Utils::NamedColours::named_colours;

  bless $self, $class;

  if ($species_defs) {
    ## Optionally, add drawing code colours from Ensembl "stylesheet"
    my %ensembl_colours = qw(
      IMAGE_BG0         background0
      IMAGE_BG1         background1
      IMAGE_BG2         background2
      IMAGE_BG3         background3

      CONTIGBLUE1       contigblue1
      CONTIGBLUE2       contigblue2

      HIGHLIGHT1        highlight1
      HIGHLIGHT2        highlight2
    );

    while (my($k,$v) = each %{$species_defs->ENSEMBL_STYLE||{}} ) {
      my $k2 = $ensembl_colours{ $k };
      next unless $k2;
      $self->{$k2} = $v;
    }
  }

  return $self;
}

sub is_defined {
  my ($self, $name) = @_;
  return exists $self->{$name};
}

sub hex_by_name {
  my ($self, $name) = @_;
  return '#' . ($self->{$name} || (
    $name =~ /^#?([0-9a-fA-F]{6})$/ ? $1 : 
    $name =~ /^(\d+),(\d+),(\d+)$/  ? sprintf '%02x%02x%02x', $1, $2, $3 : 'ff0000'
  )); 
}

sub rgb_by_name {
### Convert the provided colour to RGB
### Note that despite the method name, it can accept a colour in hex format
### or stringified RGB, as well as by Unix colour name
### @param colour String - colour to be converted 
### @param flag Boolean - ??
### @return Array - RGB values
  my ($self, $colour, $flag) = @_;
  $colour = lc($colour);
  my $hex;
  
  if ($colour =~ /(\d+,\d+,\d+)/) { ## RGB
    return split(/,/, $1);
  }
  elsif ($colour =~ /^#?([0-9a-f]{6})$/) { ## Hex
    $hex = $1;
  }
  else { ## Colour name - look up from list
    $hex = $self->{$colour};
  }

  if ($hex) {
    return $self->rgb_by_hex($hex);
  }
  else {
    warn "Unknown colour name {$colour}" unless $errors->{$colour};
    $errors->{$colour} = 1;
    return $flag ? () : (0,0,0);
  }

}


sub names {
    my ($self) = @_;
    return values %{$self};
}

sub hex_by_rgb {
  my ($self, $triple_ref) = @_;
  return sprintf("%02x%02x%02x", @{$triple_ref});
}

sub mix {
  my( $self, $colour1, $colour2, $ratio ) = @_;
  my @c1 = $self->rgb_by_name( $colour1, 1 );
  my @c2 = $self->rgb_by_name( $colour2, 1 );
  if( @c1 && @c2 ) {
    return $self->hex_by_rgb([
      $c1[0] + $ratio * ($c2[0]-$c1[0]),
      $c1[1] + $ratio * ($c2[1]-$c1[1]),
      $c1[2] + $ratio * ($c2[2]-$c1[2])
    ]);
  } elsif( @c1 ) {
    return $colour1;
  } elsif( @c2 ) {
    return $colour2;
  } else {
    return 'red';
  }
}
sub rgb_by_hex {
    my ($self, $hex) = @_;

    unless($hex){
      warn "Cannot map hex colour in colourmap\n";
      return(hex(0), hex(0), hex(0));
    }
    my ($hred, $hgreen, $hblue) = unpack("A2A2A2", $hex);
    return (hex($hred), hex($hgreen), hex($hblue));
}

sub tint_by_hex {
    my ($self, $hex, $rtone, $gtone, $btone) = @_;
    return $self->hex_by_rgb([
        $self->tint_by_rgb([ $self->rgb_by_hex($hex) ], $rtone, $gtone, $btone)
    ]);
}

sub brightness {
    my ($self, $name) = @_;
    my ($r, $g, $b);
    if ($name =~ /^#?([0-9a-f]{6})$/) { #Hex
      ($r, $g, $b) = $self->rgb_by_hex( $name );
    }
    else {
      ($r, $g, $b) = $self->rgb_by_name( $name );
    }
    return (($r * 299) + ($g * 587) + ($b * 114)) / 1000;
}

sub contrast {
    my ($self, $name) = @_;
    my $brightness = $self->brightness( $name );
    my $contrast;
    if ($brightness > 140) {
      $contrast = 'black';
    }
    else {
      $contrast = 'white';
    }
    return $contrast;
    #return ($r + 3*$g * $b) <= 8*51 ? 'white' : 'black';
}

sub hivis {
  my ($self,$contrast,@rgb) = @_;

  my $w = 220; # Watershed whither divergeth intensity

  # No, exponentiation isn't slow: takes 100ns even for perl
  return map {
    int(255*(($_/255)**$contrast))
  } @rgb;
}

sub tint_by_rgb {
    my ($self, $triple_ref, $rtone, $gtone, $btone) = @_;

    $rtone = 1      unless defined $rtone;
    $gtone = $rtone unless defined $gtone;
    $btone = $gtone unless defined $btone;

    my ($r, $g, $b) = @$triple_ref;
    my $SHADES = 256;

    $r += $rtone;
    $g += $gtone;
    $b += $btone;

    ########## boundary checks
    $r = $SHADES - 1 if $r >= $SHADES;
    $g = $SHADES - 1 if $g >= $SHADES;
    $b = $SHADES - 1 if $b >= $SHADES;
    $r = 0           if $r <  0;
    $g = 0           if $g <  0;
    $b = 0           if $b <  0;

    return ($r, $g, $b);
}

sub add_rgb {
    my ($self, $triple_ref) = @_;
    return $self->add_hex( $self->hex_by_rgb($triple_ref) );
}

sub add_hex {
    my ($self, $hex) = @_;
    $self->{$hex} = $hex;
    return $hex;
}

sub add_colour {
  my( $self, $string ) = @_;
  return $string if exists $self->{$string};
  return $self->add_hex( $string )    if $string =~/([\dabcdef]{6})/i;
  return $self->add_rgb( [$1,$2,$3] ) if $string =~/(\d+),(\d+),(\d+)/;
}

sub build_linear_gradient {
  my ($self, $grades_total, $start, @colours) = @_;

  my @finished_gradient = ();

  #########
  # deal with a single arrayref argument if supplied
  #
  if(scalar @colours == 0 && ref($start) eq "ARRAY") {
    @colours = @{$start};
    $start   = shift @colours;
  }

  my $tgrades  = scalar @colours || 1;
  my $sgrades  = $grades_total / $tgrades;

  while(my $end = shift @colours) {
    my ($sr, $sg, $sb) = $self->rgb_by_name($start);
    my ($er, $eg, $eb) = $self->rgb_by_name($end);
    my $dr             = ($er - $sr) / $sgrades;
    my $dg             = ($eg - $sg) / $sgrades;
    my $db             = ($eb - $sb) / $sgrades;
    my ($r, $g, $b)    = ($sr, $sg, $sb);
    
    for (my $i = 0; $i < $sgrades; $i++) {
      push @finished_gradient, $self->add_rgb([$r, $g, $b]);
      $r += $dr;
      $g += $dg;
      $b += $db;
    }

    $start = $end;
  }

  #########
  # work around for rounding error (incorrect number of colours returned under certain conditions)
  #
  pop @finished_gradient if(scalar @finished_gradient > $grades_total);

  return @finished_gradient;
}

sub shout {
  my $self = shift;
  warn join "\n", map { sprintf "%20s %6s", $_, $self->{$_} } sort keys %$self;
}

#########
# deprecated. here for compatibility
#
sub id_by_name {
  my ($self, $name) = @_;
  warn qq(id_by_name deprecated [use the quoted colour name!]);
  return defined $self->{$name} ? $name : 'black';
}

#########
# deprecated. here for compatibility
#
sub rgb_by_id {
  my ($self, $id) = @_;
  warn qq(rgb_by_id Deprecated!);
  return $self->rgb_by_name($id);
}

1;
