package Bio::EnsEMBL::DrawableContainer;
use lib "../../../../bioperl-live";
use Bio::Root::RootI;
use strict;
use lib "../../../../modules";
use WMF;
use GD;
use vars qw(@ISA);

#########
# take out this 'use' eventually:
#
use Bio::EnsEMBL::Renderer::gif;

use constant DRAW_PATH => '/mysql/ensembl/www/server/ensembl-draw/modules';

@ISA = qw(Bio::Root::RootI);

=head1 NAME

Bio::EnsEMBL::DrawableContainer - top level container for ensembl-draw drawing code.

=head1 SYNOPSIS

Bio::EnsEMBL::DrawableContainer is a container class for any number of GlyphSets.

=cut

@ISA = qw(Exporter);

=head1 METHODS

=head2 new - Class constructor.

my $gss = new Bio::EnsEMBL::DrawableContainer($display, $Container, $ConfigObject);

	$display       - contigviewtop|contigviewbottom|protview
	$Container     - vc|other_container_obj on which the image will be built
	$ConfigObject  - WebUserConfig object

=cut

sub new {
    my ($class, $display, $Container, $Config, $highlights, $strandedness) = @_;

    my @strands_to_show = (1, -1);

    if($strandedness == 1) {
       @strands_to_show = (1);
    }

    if(!defined $display) {
	print STDERR qq(Bio::EnsEMBL::DrawableContainer::new No display type defined\n);
	return;
    }

    if($display !~ /transview|contigviewbottom|protview/) {
	print STDERR qq(Bio::EnsEMBL::DrawableContainer::new Unknown display type $display\n);
	return;
    }

    if(!defined $Container) {
	print STDERR qq(Bio::EnsEMBL::DrawableContainer::new No container defined\n);
	return;
    }

    if(!defined $Config) {
	print STDERR qq(Bio::EnsEMBL::DrawableContainer::new No Config object defined\n);
	return;
    }

    my $self = {
	'vc'         => $Container,
	'display'    => $display,
	'glyphsets'  => [],
	'config'     => $Config,
    };

    #########
    # loop over all the glyphsets the user wants:
    #

    my @subsections = $Config->subsections($self->{'display'});

    my @order = sort { $Config->get($self->{'display'}, $a, 'pos') <=> $Config->get($self->{'display'}, $b, 'pos') } @subsections;

    for my $strand (@strands_to_show) {
      my @tmp;

      if($strand == 1) {
	@tmp = reverse @order;
      } else {
        @tmp = @order;
      }

      for my $row (@tmp) {
	#########
	# skip this row if user has it turned off
	#
	next if ($Config->get($self->{'display'}, $row, 'on') eq "off");
	next if ($Config->get($self->{'display'}, $row, 'str') eq "r" && $strand != -1);
	next if ($Config->get($self->{'display'}, $row, 'str') eq "f" && $strand != 1);

	#########
	# create a new glyphset for this row
	#
	my $classname = qq(Bio::EnsEMBL::GlyphSet::$row);
	my $classpath = &DRAW_PATH . qq(/Bio/EnsEMBL/GlyphSet/${row}.pm);

	#########
	# require & import the package
	#
	eval {
	    require($classpath);
	};
	if($@) {
	    print STDERR qq(DrawableContainer::new failed to require $classname: $@\n);
	    next;
	}

	$classname->import();

	#########
	# generate a set for both strands
	#
	my $GlyphSet = new $classname($Container, $Config, qq(|$highlights|), $strand);

	push @{$self->{'glyphsets'}}, $GlyphSet if(scalar @{$GlyphSet->{'glyphs'}} > 0);
      }
    }

    bless($self, $class);
    return $self;
}

=head2 render - renders object data into an image

my $imagestring = $gss->render($type);

	$type        - imagemap|gif|png|ps|pdf|tiff|wmf|fla

=cut

#########
# render does clever drawing things
#
sub render {
    my ($self, $type) = @_;

    #########
    # query boundary conditions of glyphsets?
    # set up canvas?
    # DO GLOBBING & BUMPING!!!
    #

    my ($width, $height) = $self->config()->dimensions();

#    my ($minx, $maxx, $miny, $maxy);

#    for my $gs ($self->glyphsets()) {
#	next if($gs->maxx() == 0 || $gs->maxy() == 0);
#	$minx = $gs->minx() if($gs->minx() < $minx || !defined($minx));
#	$maxx = $gs->maxx() if($gs->maxx() > $maxx || !defined($maxx));
#	$miny = $gs->miny() if($gs->miny() < $miny || !defined($miny));
#	$maxy = $gs->maxy() if($gs->maxy() > $maxy || !defined($maxy));
#    }

#    my $scalex = $width / ($maxx - $minx);
#    my $scaley = $height / ($maxy - $miny);

#print STDERR qq(Using y scaling factor $scaley and x scaling factor $scalex\n);

    my $transform_ref = {
	'translatex' => 0,
	'translatey' => 0,
#	'scalex'     => $scalex,
#	'scaley'     => $scaley,
#	'rotation'   => 90,
	'scalex'     => $self->config()->scalex(),
	'scaley'     => $self->config()->scaley(),
    };

    #########
    # initialise canvasses for specific image types
    #
    my $canvas;
    if($type eq "gif") {
	$canvas = new GD::Image($width, $height);
	$canvas->colorAllocate($self->{'config'}->colourmap()->rgb_by_id($self->{'config'}->bgcolor()));

    } elsif($type eq "wmf") {
	$canvas = new WMF($width, $height);
	$canvas->colorAllocate($self->{'config'}->colourmap()->rgb_by_id($self->{'config'}->bgcolor()));

    }

    #########
    # build the name/type of render object we want
    #
    my $renderer_type = qq(Bio::EnsEMBL::Renderer::$type);
    my $renderer_path = &DRAW_PATH . qq(/Bio/EnsEMBL/Renderer/${type}.pm);

    #########
    # dynamic require of the right type of renderer
    #
    eval {
	require($renderer_path);
    };
    if($@) {
	print STDERR qq(DrawableContainer::new failed to require $renderer_path\n);
	return;
    }
    $renderer_type->import();

    #########
    # big, shiny, rendering 'GO' button
    #
    my $renderer = $renderer_type->new($self->{'config'}, $self->{'vc'}, $self->{'glyphsets'}, $transform_ref, $canvas);

    return $renderer->canvas();
}

sub config {
    my ($self, $Config) = @_;
    $self->{'config'} = $Config if(defined $Config);
    return $self->{'config'};
}

sub glyphsets {
    my ($self) = @_;
    return @{$self->{'glyphsets'}};
}

1;

=head1 RELATED MODULES

See also: Bio::EnsEMBL::GlyphSet Bio::EnsEMBL::Glyph WebUserConfig

=head1 AUTHOR - Roger Pettett

Email - rmp@sanger.ac.uk

=cut
