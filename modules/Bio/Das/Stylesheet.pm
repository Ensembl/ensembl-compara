package Bio::Das::Stylesheet;

use strict;

use Carp 'croak';

use vars qw($VERSION);
$VERSION = '1.00';


#
# Bio::Das::Stylesheet->new();
#
sub new {
  my $class = shift;
  $class = ref($class) if ref($class);

  return bless { categories => {},
		 lowzoom    => 500_000,
		 highzoom   => 200,
	       },$class;
}

sub categories {
  my $self = shift;
  keys %{$self->{categories}};
}

# in a scalar context, return name of glyph
# in array context, return name of glyph followed by attribute/value pairs
sub glyph {
  local $^W = 0;

  my $self    = shift;
  my $feature = shift;
  my $length  = shift || 0;
  unless ($length =~ /^\d+$/) {
    $length = $length eq 'low' ? $self->lowzoom : $self->highzoom;
  }

  $feature = $feature->[0]
    if ref($feature) eq 'ARRAY';  # hack to prevent common error

  my ($category,$type);
  if (ref $feature) {
    $category = lc $feature->category;
    $type     = lc $feature->type;
  } else {
    $type     = $feature;
  }
  $category ||= 'default';
  $type     ||= 'default';

  # my $cat    = $self->{categories}{$category} || $self->{categories}{default};
  # my $zoom   = $cat->{$type}                  || $cat->{default} || {};
  (my $base = $type) =~ s/:.+$//;
  my $zoom   =  $self->{categories}{$category}{$type};
  $zoom     ||= $self->{categories}{$category}{$base};
  $zoom    ||= $self->{categories}{'default'}{$type};
  $zoom    ||= $self->{categories}{'default'}{$base};
  $zoom    ||= $self->{categories}{'default'}{'default'};

  my $glyph;

  # find the best zoom level -- this is a Schwartzian Transform
  my @zoomlevels = map  {$_->[0]}
                   sort {$b->[1]<=>$a->[1]}
                   grep {!$length or $_->[1] <= $length}
                   map  {  $_ eq 'low'  ? [$_ => $self->lowzoom]
	                 : $_ eq 'high' ? [$_ => $self->highzoom]
		         : [$_ => $_ || 0] } keys %$zoom;

  my ($base_glyph,@base_attributes)     = _format_glyph($zoom->{$zoomlevels[-1]});
  my ($zoom_glyph,@zoom_attributes)     = _format_glyph($zoom->{$zoomlevels[0]}) if $length;
  my %attributes = (@base_attributes,@zoom_attributes);
  $glyph = $zoom_glyph || $base_glyph;

  return wantarray ? ($glyph,%attributes) : $glyph;
}

# turn configuration into a set of -name=>value pairs suitable for add_track()
sub style {
  my $self = shift;
  my ($glyph,%attributes) = $self->glyph(@_);
  return ($glyph,map {("-$_" => $attributes{$_})} keys %attributes);
}

# warning: not a method
sub _format_glyph {
  my $glyph = shift;
  return unless $glyph;
  my $name = $glyph->{name};
  return $name unless wantarray;
  return ($name,%{$glyph->{attr}});
}

sub add_type {
  my $self     = shift;
  my ($category,$type,$zoom,$glyph_name,$attributes) = @_;
  $zoom ||= 0;
  $self->{categories}{lc $category}{lc $type}{lc $zoom} = { name => $glyph_name,  # a string
							    attr => $attributes,  # a hashref
						 };
  $self->{categories}{'default'}{lc $type}{lc $zoom} = $self->{categories}{lc $category}{lc $type}{lc $zoom};
}

sub lowzoom {
  my $self = shift;
  my $d    = $self->{lowzoom};
  $self->{lowzoom} = shift if @_;
  $d;
}

sub highzoom {
  my $self = shift;
  my $d    = $self->{highzoom};
  $self->{highzoom} = shift if @_;
  $d;
}

1;

__END__

=head1 NAME

Bio::Das::Stylesheet - Access to DAS stylesheets

=head1 SYNOPSIS

  use Bio::Das;

  # contact the DAS server at wormbase.org (0.18 version API)
  my $das      = Bio::Das->new('http://www.wormbase.org/db/das'=>'elegans');

  # get the stylesheet
  my $style    = $das->stylesheet;

  # get features
  my @features = $das->segment(-ref=>'Locus:unc-9')->features;

  # for each feature, ask the stylesheet what glyph to use
  for my $f (@features) {
    my ($glyph_name,@attributes) = $style->glyph($f);
  }


=head1 DESCRIPTION

The Bio::Das::Stylesheet class contains information about a remote DAS
server's preferred visualization style for sequence features.  Each
server has zero or one stylesheets for each of the data sources it is
responsible for.  Stylesheets can provide stylistic guidelines for
broad feature categories (such as "transcription"), or strict
guidelines for particular feature types (such as "Prosite motif").

The glyph names and attributes are broadly compatible with the
Bio::Graphics library.

=head2 OBJECT CREATION

Bio::Das::Stylesheets are created by the Bio::Das object in response
to a call to the stylesheet() method.  The Bio::Das object must
previously have been associated with a data source.

=head2 METHODS

=over 4

=item ($glyph,@attributes) = $stylesheet->glyph($feature)

The glyph() method takes a Bio::Das::Segment::Feature object and
returns the name of a suggested glyph to use, plus zero or more
attributes to apply to the glyph.  Glyphs names are described in the
DAS specification, and include terms like "box" and "arrow".

Attributes are name/value pairs, for instance:
	   
   (-width => '10', -outlinecolor => 'black')

The initial "-" is added to the attribute names to be consistent with
the Perl name/value calling style.  The attribute list can be passed
directly to the Ace::Panel->add_track() method.

In a scalar context, glyph() will return just the name of the glyph
without the attribute list.

=item @categories = $stylesheet->categories

Return a list of all the categories known to the stylesheet.

=item $source = $stylesheet->source

Return the Bio::Das object associated with the stylesheet.

=head2 HOW GLYPH() RESOLVES FEATURES

When a feature is passed to glyph(), the method checks the feature's
type ID and category against the stylesheet.  If an exact match is
found, then the method returns the corresponding glyph name and
attributes.  Otherwise, glyph() looks for a default style for the
category and returns the glyph and attributes for that.  If no
category default is found, then glyph() returns its global default.

=head2 USING Bio::Das::Stylesheet WITH Bio::Graphics::Panel

The stylesheet class was designed to work hand-in-glove with
Bio::Graphics::Panel.  You can rely entirely on the stylesheet to
provide the glyph name and attributes, or provide your own default
attributes to fill in those missing from the stylesheet.

It is important to bear in mind that Bio::Graphics::Panel only allows
a single glyph type to occupy a horizontal track.  This means that you
must sort the different features by type, determine the suggested
glyph for each type, and then create the tracks.

The following code fragment illustrates the idiom.  After sorting the
features by type, we pass the first instance of each type to glyph()
in order to recover a glyph name and attributes applicable to the
entire track.

  use Bio::Das;
  use Bio::Graphics::Panel;

  my $das        = Bio::Das->new('http://www.wormbase.org/db/das'=>'elegans');
  my $stylesheet = $das->stylesheet;
  my $segment    = $das->segment(-ref=>'Locus:unc-9');
  @features      = $segment->features;

  my %sort;
  for my $f (@features) {
     my $type = $f->type;
     # sort features by their type, and push them onto anonymous
     # arrays in the %sort hash.
     push @{$sort{$type}},$f;   
  }
  my $panel = Bio::Graphics::Panel->new( -segment => $segment,
                                         -width   => 800 );
  for my $type (keys %sort) {
      my $features = $sort{$type};
      my ($glyph,@attributes) = $stylesheet->glyph($features->[0]);
      $panel->add_track($features=>$glyph,@attributes);
  }

To provide your own default attributes to be used in place of those
omitted by the stylesheet, just change the last line so that your
own attributes follow those provided by the stylesheet:

      $panel->add_track($features=>$glyph,
                        @attributes,
                        -connectgroups => 1,
			-key           => 1,
			-labelcolor    => 'chartreuse'
                        );

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das>, L<Bio::Graphics::Panel>, L<Bio::Graphics::Track>

=cut
