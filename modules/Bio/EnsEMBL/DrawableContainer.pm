package Bio::EnsEMBL::DrawableContainer;
use lib "../../../../bioperl-live";
use Bio::Root::RootI;
use strict;
use lib "../../../../modules";
use vars qw(@ISA);
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);

use constant DRAW_PATH => '/mysql/ensembl/www/server/ensembl-draw/modules';

@ISA = qw(Bio::Root::RootI);

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

#    if($display !~ /transview|contigviewbottom|protview/) {
#	print STDERR qq(Bio::EnsEMBL::DrawableContainer::new Unknown display type $display\n);
#	return;
#    }

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

    &eprof_start('glyphset_creation');

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

    &eprof_end('glyphset_creation');

    bless($self, $class);
    return $self;
}

#########
# render does clever drawing things
#
sub render {
    my ($self, $type) = @_;

    my $transform_ref = {
	'translatex' => 0,
	'translatey' => 0,
#	'scaley' => 2,
    };

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
    &eprof_start(qq(renderer_creation_$type));
    my $renderer = $renderer_type->new($self->{'config'}, $self->{'vc'}, $self->{'glyphsets'}, $transform_ref);
    &eprof_end(qq(renderer_creation_$type));

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
