package Bio::EnsEMBL::DrawableContainer;
use Bio::Root::RootI;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Composite;
use Bio::EnsEMBL::GlyphSetManager::das;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use ExtURL;

@ISA = qw(Bio::Root::RootI);

sub new {
    my ($class, $Container, $Config, $highlights, $strandedness, $Storage) = @_;

    my @strands_to_show = $strandedness == 1 ? (1) : (1, -1);

    unless(defined $Container) {
        print STDERR qq(Bio::EnsEMBL::DrawableContainer::new No container defined\n);
        return;
    }

    unless(defined $Config) {
        print STDERR qq(Bio::EnsEMBL::DrawableContainer::new No Config object defined\n);
        return;
    }

    my $self = {
        'vc'            => $Container,
        'glyphsets'     => [],
        'config'        => $Config,
        'spacing'       => 5,
        'button_width'  => 16,
        'storage'       => $Storage
    };
    bless($self, $class);

    ########## loop over all the glyphsets the user wants:
    my $black = $Config->colourmap()->id_by_name('red');
    $Config->{'ext_url'} = ExtURL->new;

    for my $strand (@strands_to_show) {

        my $tmp_glyphset_store = {};
        for my $row ($Config->subsections()) {
        ########## skip this row if user has it turned off
            next unless ($Config->get($row, 'on') eq "on");
            next if ($Config->get($row, 'str') eq "r" && $strand != -1);
            next if ($Config->get($row, 'str') eq "f" && $strand != 1);
        
            if(substr($row, 0, 4) ne "das_") {
                ########## create a new glyphset for this row
                my $classname = qq(Bio::EnsEMBL::GlyphSet::$row);
                ########## require & import the package
                eval "require $classname";
                if($@) {
                    print STDERR qq(DrawableContainer::new failed to require $classname: $@\n);
                    next;
                }
                $classname->import();
                ########## generate a set for both strands
                my $GlyphSet;
                eval {
                    $GlyphSet = new $classname($Container, $Config, $highlights, $strand);
                };
                if($@) {
                    print STDERR "GLYPHSET $classname failed\n";
                } else {
                    $tmp_glyphset_store->{$Config->get($row, 'pos')} = $GlyphSet;
                }
            }
        }

        ########## install the glyphset managers
        ########## DAS first....
        my $DasManager = new Bio::EnsEMBL::GlyphSetManager::das($Container, $Config, $highlights, $strand);
        my $das_offset = 200;
        for my $glyphset ($DasManager->glyphsets()) {
            my $row = $glyphset->das_name();
            ########## skip this row if user has it turned off
            next unless ($Config->get($row, 'on') eq "on");
            $tmp_glyphset_store->{$Config->get($row, 'pos') || $das_offset++} = $glyphset;
        }
    
        ########## sort out the resulting mess
        my @tmp = map { $tmp_glyphset_store->{$_} } sort { $a <=> $b } keys %{ $tmp_glyphset_store };
        push @{$self->{'glyphsets'}}, ($strand == 1 ? reverse @tmp : @tmp);
    }
    
    ########## calculate real scaling here
    my $spacing      = $self->{'spacing'};
    my $button_width = $self->{'button_width'};
    
    ########## calculate the maximum label width (plus margin)
    my $label_length_px = 0;
    
    for my $glyphset (@{$self->{'glyphsets'}}) {
        my $composite;
        next unless defined $glyphset->label();
    
        my $pixels = length($glyphset->label->text()) *
                     $Config->texthelper->width($glyphset->label->font());
    
        $label_length_px = $pixels if($pixels > $label_length_px);
    
        ########## just for good measure:
        $glyphset->label->width($label_length_px);
        next unless defined $glyphset->bumped();
        print STDERR "creating composite for bumped button\n";
        $composite = new Bio::EnsEMBL::Glyph::Composite({
                'y'            => 0,
				'x'            => 0,
				'absolutey'    => 1,
                'width'        => 10
        });
        
        my $NAME = ref($glyphset);
        $NAME =~ s/^.*:://;
        my $URL = $Config->get( '_settings', 'URL')."$NAME%3A";
        if($glyphset->bumped() eq 'yes') {
            $URL .= 'off';
        } else {
            $URL .= 'on';
            my $vert_glyph = new Bio::EnsEMBL::Glyph::Rect({
                'y'      	=> 2,
		    	'x'      	=> 6,
		    	'width'  	=> 1,
		    	'height' 	=> 4,
		    	'colour' 	=> $black,
		    	'absolutey' => 1,
				'absolutex' => 1
            });
            $composite->push($vert_glyph);
        }
        my $box_glyph = new Bio::EnsEMBL::Glyph::Rect({
    	        'x'      	=> 2,
		    	'y'      	=> 0,
		    	'width'  	=> 10,
		    	'height' 	=> 8,
		    	'bordercolour'	=> $black,
		    	'absolutey' => 1,
				'absolutex' => 1,
                'href'      => $URL
        });
        
        my $horiz_glyph = new Bio::EnsEMBL::Glyph::Rect({
    	        'x'      	=> 4,
		    	'y'      	=> 4,
		    	'width'  	=> 5,
		    	'height' 	=> 0,
		    	'colour' 	=> $black,
		    	'absolutey' => 1,
				'absolutex' => 1
        });
        
        $composite->push($box_glyph);
        $composite->push($horiz_glyph);
        $glyphset->bumpbutton($composite);
    }
    
    ########## add spacing before and after labels
    $label_length_px += $spacing * 2;
    
    ########## calculate scaling factors
    my $pseudo_im_width = $Config->image_width() - $label_length_px - $spacing - $button_width;
    my $scalex = $pseudo_im_width / $Config->container_width();
    
    ########## set scaling factor for base-pairs -> pixels
    $Config->{'transform'}->{'scalex'} = $scalex;
    
    ########## set scaling factor for 'absolutex' coordinates -> real pixel coords
    $Config->{'transform'}->{'absolutescalex'} = $pseudo_im_width / $Config->image_width();
    
    ########## because our text label starts are < 0, translate everything back onto the canvas
    my $extra_translation = $label_length_px;
    $Config->{'transform'}->{'translatex'} += $extra_translation + $button_width;
    
    ########## set the X-locations for each of the bump buttons/labels
    for my $glyphset (@{$self->{'glyphsets'}}) {
        next unless defined $glyphset->label();
        $glyphset->label->x(-($extra_translation - $spacing) / $scalex);
        next unless defined $glyphset->bumpbutton;
        $glyphset->bumpbutton->x(-($extra_translation + $button_width - $spacing) / $scalex);
        foreach( @{$glyphset->bumpbutton->{'composite'}} ) {
#           delete $_->{'absolutex'};
            print STDERR join "\t", "BUTTON: ",$_->x, $scalex, $glyphset->bumpbutton->x, $_->width, 0+$_->pixelwidth, "\n";
        }
    }
    
    ########## pull out alternating background colours for this script
    my $white  = $Config->bgcolour() || $Config->colourmap->id_by_name('white');
    my $bgcolours = [ $Config->get('_settings', 'bgcolour1') || $white,
                      $Config->get('_settings', 'bgcolour2') || $white ];
    
    my $bgcolour_flag;
    $bgcolour_flag = 1 if($bgcolours->[0] ne $bgcolours->[1]);
    
    ########## go ahead and do all the database work
    my $yoffset = $spacing;
    my $iteration = 0;
    for my $glyphset (@{$self->{'glyphsets'}}) {
        ########## load everything from the database
        my $ref_glyphset = ref($glyphset);
        &eprof_start($ref_glyphset . "_database_work");
        $glyphset->_init();
        &eprof_end($ref_glyphset . "_database_work");
        &eprof_start($ref_glyphset . "_drawing_work");
        ########## don't waste any more time on this row if there's nothing in it
        if(scalar @{$glyphset->{'glyphs'}} == 0) {
            &eprof_end($ref_glyphset . "_drawing_work");
            next;
        };
        ########## remove any whitespace at the top of this row
        my $gminy = $glyphset->miny();
        $Config->{'transform'}->{'translatey'} = -$gminy + $yoffset + ($iteration * $spacing);
    
        if(defined $bgcolour_flag) {
            ########## colour the area behind this strip
            my $background = new Bio::EnsEMBL::Glyph::Rect({
                'x'         => 0,
                'y'         => $gminy,
                'width'     => $Config->image_width(),
                'height'    => $glyphset->maxy() - $gminy,
                'colour'    => $bgcolours->[$iteration % 2],
                'absolutex' => 1,
            });
            ########## this accidentally gets stuffed in twice (for gif & imagemap)
            ########## so with rounding errors and such we shouldn't track this for maxy & miny values
            unshift @{$glyphset->{'glyphs'}}, $background;
        }

        ########## set up the "bumping button" label for this strip
        if(defined $glyphset->label()) {
            my $gh = $Config->texthelper->height($glyphset->label->font());
            $glyphset->label->y((($glyphset->maxy() - $glyphset->miny() - $gh) / 2) + $gminy);
            $glyphset->label->height($gh);
            $glyphset->push($glyphset->label());
            if( defined $glyphset->bumpbutton()) {
                $glyphset->bumpbutton->y(int(($glyphset->maxy() - $glyphset->miny() - 8) / 2 + $gminy));
                $glyphset->push($glyphset->bumpbutton());
                print STDERR "TRACK -- button -- $ref_glyphset (",
                    $glyphset->bumpbutton->x,",",$glyphset->bumpbutton->y,
                ")\n";
                foreach( @{$glyphset->bumpbutton->{'composite'}} ) {
#                    $_->y( $_->y + $glyphset->bumpbutton->y );
                    print STDERR "COMPOSITE(",$_->pixelx,",",$_->pixely,")\n";
                }
                print STDERR "TRACK -- label -- $ref_glyphset (",
                    $glyphset->label->pixelx,",",$glyphset->label->pixely,
                ")\n";
            }
        }
    
        $glyphset->transform();
        ########## translate the top of the next row to the bottom of this one
        $yoffset += $glyphset->height();
        $iteration ++;
        &eprof_end($ref_glyphset . "_drawing_work");
    }
    return $self;
}

########## render does clever drawing things

sub render {
    my ($self, $type) = @_;
    
    ########## build the name/type of render object we want
    my $renderer_type = qq(Bio::EnsEMBL::Renderer::$type);

    ########## dynamic require of the right type of renderer
    eval "require $renderer_type";

    if($@) {
        print STDERR qq(DrawableContainer::new failed to require $renderer_type\n);
        return;
    }
    $renderer_type->import();

    ########## big, shiny, rendering 'GO' button
    &eprof_start("$renderer_type");
    my $renderer = $renderer_type->new($self->{'config'}, $self->{'vc'}, $self->{'glyphsets'});
    &eprof_end("$renderer_type");
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

sub storage {
    my ($self, $Storage) = @_;
    $self->{'storage'} = $Storage if(defined $Storage);
    return $self->{'storage'};
}
1;

=head1 RELATED MODULES

See also: Bio::EnsEMBL::GlyphSet Bio::EnsEMBL::Glyph WebUserConfig

=head1 AUTHOR - Roger Pettett

Email - rmp@sanger.ac.uk

=cut
